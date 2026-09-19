// Speech bridge. A single worker thread owns the platform speech engine so
// every COM/FFI call happens on one thread; the frontend talks to it through
// the Tauri commands below. Word-boundary and completion events flow back to
// the webview as `tts:boundary` / `tts:end` events, which the native-speech.js
// driver maps onto the same onboundary/ondone callbacks the web app expects.
use std::sync::mpsc::{channel, Sender};
use std::sync::OnceLock;
use std::time::Duration;

use serde::Serialize;
use tauri::{AppHandle, Emitter};

#[cfg(windows)]
mod sapi;
#[cfg(target_os = "linux")]
mod speechd;

#[cfg(windows)]
use sapi::Sapi as Platform;
#[cfg(target_os = "linux")]
use speechd::Speechd as Platform;

#[derive(Clone, Serialize)]
pub struct VoiceInfo {
    pub id: String,
    pub name: String,
    /// BCP-47 tag, lowercased ("en-us"); the JS driver matches it against TTS_LOCALE.
    pub lang: String,
}

pub enum TtsEvent {
    /// UTF-16 [start, end) range of the word about to be spoken.
    Word {
        utterance: String,
        start: u32,
        end: u32,
    },
    End {
        utterance: String,
    },
}

pub trait SpeechBackend: Send + 'static {
    fn new() -> Self
    where
        Self: Sized;
    fn voices(&mut self) -> Vec<VoiceInfo>;
    /// Returns false when the utterance could not be dispatched at all — the
    /// caller then synthesizes an end event so the engine never stalls.
    fn speak(&mut self, utterance: String, text: String, voice_id: String, rate: f64) -> bool;
    fn stop(&mut self);
    /// Drain queued engine events; called ~40x/s by the worker loop.
    fn poll(&mut self) -> Vec<TtsEvent>;
}

enum WorkerCmd {
    Speak {
        utterance: String,
        text: String,
        voice_id: String,
        rate: f64,
    },
    Stop,
    Voices {
        reply: Sender<Vec<VoiceInfo>>,
    },
}

static WORKER: OnceLock<Sender<WorkerCmd>> = OnceLock::new();

#[derive(Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct BoundaryPayload<'a> {
    utterance: &'a str,
    start: u32,
    end: u32,
}

#[derive(Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct EndPayload<'a> {
    utterance: &'a str,
}

pub fn spawn_worker(app: AppHandle) {
    let (tx, rx) = channel::<WorkerCmd>();
    if WORKER.set(tx).is_err() {
        return;
    }
    std::thread::Builder::new()
        .name("speech".into())
        .spawn(move || {
            let mut backend = Platform::new();
            loop {
                // Poll cadence bounds karaoke-highlight latency; utterances
                // themselves are async — this only services event queues.
                let cmd = rx.recv_timeout(Duration::from_millis(25)).ok();
                match cmd {
                    Some(WorkerCmd::Speak {
                        utterance,
                        text,
                        voice_id,
                        rate,
                    }) => {
                        if !backend.speak(utterance.clone(), text, voice_id, rate) {
                            let _ = app.emit(
                                "tts:end",
                                EndPayload {
                                    utterance: &utterance,
                                },
                            );
                        }
                    }
                    Some(WorkerCmd::Stop) => backend.stop(),
                    Some(WorkerCmd::Voices { reply }) => {
                        let _ = reply.send(backend.voices());
                    }
                    None => {}
                }
                for ev in backend.poll() {
                    match ev {
                        TtsEvent::Word {
                            utterance,
                            start,
                            end,
                        } => {
                            let _ = app.emit(
                                "tts:boundary",
                                BoundaryPayload {
                                    utterance: &utterance,
                                    start,
                                    end,
                                },
                            );
                        }
                        TtsEvent::End { utterance } => {
                            let _ = app.emit(
                                "tts:end",
                                EndPayload {
                                    utterance: &utterance,
                                },
                            );
                        }
                    }
                }
            }
        })
        .ok();
}

#[tauri::command]
pub fn tts_voices() -> Vec<VoiceInfo> {
    let (tx, rx) = channel();
    let Some(worker) = WORKER.get() else {
        return Vec::new();
    };
    if worker.send(WorkerCmd::Voices { reply: tx }).is_ok() {
        if let Ok(v) = rx.recv_timeout(Duration::from_secs(5)) {
            return v;
        }
    }
    Vec::new() // no engine / timed out: the UI shows its no-TTS warning
}

#[tauri::command]
pub fn tts_speak(utterance_id: String, text: String, voice_id: String, rate: f64) {
    if let Some(worker) = WORKER.get() {
        let _ = worker.send(WorkerCmd::Speak {
            utterance: utterance_id,
            text,
            voice_id,
            rate,
        });
    }
}

#[tauri::command]
pub fn tts_stop() {
    if let Some(worker) = WORKER.get() {
        let _ = worker.send(WorkerCmd::Stop);
    }
}
