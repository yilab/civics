// OS media session via souvlaki: SMTC on Windows, MPRIS on Linux — that's
// what makes headset buttons / media keys / lock-screen controls reach the
// study engine. Button presses are forwarded to the webview as `media:action`
// events; metadata updates come in through the `media_update` command. The
// souvlaki MediaControls is created on (and never leaves) its own thread.
use std::sync::mpsc::{channel, Sender};
use std::sync::Mutex;

use souvlaki::{MediaControlEvent, MediaControls, MediaMetadata, MediaPlayback, PlatformConfig};
use tauri::Emitter;

enum MediaUpdate {
    Metadata {
        title: Option<String>,
        artist: Option<String>,
    },
    Playing(bool),
}

static CHANNEL: Mutex<Option<Sender<MediaUpdate>>> = Mutex::new(None);

pub fn init(
    app: tauri::AppHandle,
    hwnd: Option<*mut std::ffi::c_void>,
) -> Result<(), Box<dyn std::error::Error>> {
    let (tx, rx) = channel::<MediaUpdate>();
    *CHANNEL.lock().unwrap() = Some(tx);
    // Raw pointers aren't Send; carry the handle through as a usize.
    let hwnd = hwnd.map(|p| p as usize);
    std::thread::Builder::new()
        .name("media".into())
        .spawn(move || {
            let hwnd = hwnd.map(|p| p as *mut std::ffi::c_void);
            let config = PlatformConfig {
                dbus_name: "civics",
                display_name: "Civics Audio Prep",
                hwnd,
            };
            let mut controls = match MediaControls::new(config) {
                Ok(c) => c,
                Err(e) => {
                    eprintln!("media controls unavailable: {e:?}");
                    return;
                }
            };
            let app_for_keys = app.clone();
            if let Err(e) = controls.attach(move |event: MediaControlEvent| {
                // Same mapping the web app registers on navigator.mediaSession.
                let action = match event {
                    MediaControlEvent::Play => "play",
                    MediaControlEvent::Pause => "pause",
                    MediaControlEvent::Toggle => "toggle",
                    MediaControlEvent::Next => "next",
                    MediaControlEvent::Previous => "previous",
                    MediaControlEvent::Stop => "stop",
                    _ => return,
                };
                let _ = app_for_keys.emit("media:action", action);
            }) {
                eprintln!("media key attach failed: {e:?}");
                return;
            }
            while let Ok(update) = rx.recv() {
                let result = match update {
                    MediaUpdate::Metadata { title, artist } => {
                        controls.set_metadata(MediaMetadata {
                            title: title.as_deref(),
                            artist: artist.as_deref(),
                            ..Default::default()
                        })
                    }
                    MediaUpdate::Playing(true) => {
                        controls.set_playback(MediaPlayback::Playing { progress: None })
                    }
                    MediaUpdate::Playing(false) => {
                        controls.set_playback(MediaPlayback::Paused { progress: None })
                    }
                };
                if let Err(e) = result {
                    eprintln!("media session update failed: {e:?}");
                }
            }
        })?;
    Ok(())
}

#[tauri::command]
pub fn media_update(title: Option<String>, artist: Option<String>, playing: bool) {
    if let Some(tx) = &*CHANNEL.lock().unwrap() {
        let _ = tx.send(MediaUpdate::Metadata { title, artist });
        let _ = tx.send(MediaUpdate::Playing(playing));
    }
}
