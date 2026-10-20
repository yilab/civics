// Linux speech-dispatcher backend, dlopen'ed so the app still runs (without
// speech) when libspeechd isn't installed. speech-dispatcher reports message
// begin/end/cancel but nothing per word, so Linux has no karaoke highlighting
// (the JS driver just never gets boundary events). END/CANCEL callbacks arrive
// on libspeechd's event thread carrying the message id spd_say returned; the
// worker matches them to the in-flight utterance when it polls.
use std::ffi::c_char;
use std::ffi::{c_int, CStr, CString};
use std::sync::Mutex;
use std::sync::OnceLock;

use libloading::Library;

use super::{SpeechBackend, TtsEvent, VoiceInfo};

#[repr(C)]
struct SpdVoice {
    name: *mut c_char,
    language: *mut c_char,
    variant: *mut c_char,
}

/// The PUBLIC head of libspeechd's SPDConnection: these six callbacks lead
/// the struct unchanged from 0.8 through 0.12. The private tail after them
/// changed in 0.9 and again in 0.12, so it is not declared; the struct is
/// only ever reached through the pointer spd_open returns.
#[repr(C)]
struct SpdConnection {
    callback_begin: Option<SpdCallback>,
    callback_end: Option<SpdCallback>,
    callback_cancel: Option<SpdCallback>,
    callback_pause: Option<SpdCallback>,
    callback_resume: Option<SpdCallback>,
    callback_im: Option<SpdCallbackIm>,
}

/// (msg_id, client_id, SPDNotificationType)
type SpdCallback = unsafe extern "C" fn(msg_id: usize, client_id: usize, state: c_int);
type SpdCallbackIm =
    unsafe extern "C" fn(msg_id: usize, client_id: usize, state: c_int, mark: *mut c_char);

const SPD_MODE_THREADED: c_int = 1;
const SPD_TEXT: c_int = 3; // priority

// SPDNotification bits (speechd_types.h)
const SPD_END: c_int = 2;
const SPD_CANCEL: c_int = 8;

struct Fns {
    spd_open: unsafe extern "C" fn(
        client_name: *const c_char,
        connection_name: *const c_char,
        user: *const c_char,
        mode: c_int,
    ) -> *mut SpdConnection,
    spd_say: unsafe extern "C" fn(
        conn: *mut SpdConnection,
        priority: c_int,
        text: *const c_char,
    ) -> c_int,
    spd_cancel: unsafe extern "C" fn(conn: *mut SpdConnection) -> c_int,
    spd_set_voice_rate: unsafe extern "C" fn(conn: *mut SpdConnection, rate: c_int) -> c_int,
    spd_set_language: unsafe extern "C" fn(conn: *mut SpdConnection, lang: *const c_char) -> c_int,
    spd_set_synthesis_voice:
        unsafe extern "C" fn(conn: *mut SpdConnection, name: *const c_char) -> c_int,
    spd_list_synthesis_voices: unsafe extern "C" fn(conn: *mut SpdConnection) -> *mut *mut SpdVoice,
    spd_set_notification_on:
        unsafe extern "C" fn(conn: *mut SpdConnection, notification: c_int) -> c_int,
}

/// Leaked library handle + resolved symbols (loaded once, used from the worker
/// thread; callbacks run on speech-dispatcher's own event thread).
fn fns() -> Option<&'static Fns> {
    static FNS: OnceLock<Option<Fns>> = OnceLock::new();
    FNS.get_or_init(|| unsafe {
        // Leak the library: symbols must stay valid for the process lifetime.
        let lib = Box::leak(Box::new(Library::new("libspeechd.so.2").ok()?));
        Some(Fns {
            spd_open: *lib.get(b"spd_open\0").ok()?,
            spd_say: *lib.get(b"spd_say\0").ok()?,
            spd_cancel: *lib.get(b"spd_cancel\0").ok()?,
            spd_set_voice_rate: *lib.get(b"spd_set_voice_rate\0").ok()?,
            spd_set_language: *lib.get(b"spd_set_language\0").ok()?,
            spd_set_synthesis_voice: *lib.get(b"spd_set_synthesis_voice\0").ok()?,
            spd_list_synthesis_voices: *lib.get(b"spd_list_synthesis_voices\0").ok()?,
            spd_set_notification_on: *lib.get(b"spd_set_notification_on\0").ok()?,
        })
    })
    .as_ref()
}

/* ---------- finished messages (single connection per process) ---------- */
/// Ids of messages that ended or were cancelled, pushed from libspeechd's
/// event thread. Never hold this lock across an spd_* call: that thread also
/// delivers the replies those calls wait for.
static FINISHED: Mutex<Vec<usize>> = Mutex::new(Vec::new());

/// Registered for both END and CANCEL: either way the message is done.
unsafe extern "C" fn on_finished(msg_id: usize, _client_id: usize, _state: c_int) {
    if let Ok(mut finished) = FINISHED.lock() {
        finished.push(msg_id);
    }
}

pub struct Speechd {
    conn: *mut SpdConnection,
    voices: Vec<VoiceInfo>,
    /// Utterance id and speech-dispatcher message id of the in-flight
    /// spd_say; the utterance id is empty when idle.
    current: String,
    current_msg: usize,
}

// The connection pointer is only dereferenced on the worker thread that owns
// it; callbacks reach the worker through the static queue, not through Self.
unsafe impl Send for Speechd {}

impl Speechd {
    fn ensure_conn(&mut self) -> bool {
        if !self.conn.is_null() {
            return true;
        }
        let Some(f) = fns() else { return false };
        unsafe {
            let name = CString::new("civics").unwrap();
            let conn = (f.spd_open)(
                name.as_ptr(),
                name.as_ptr(),
                std::ptr::null(),
                SPD_MODE_THREADED,
            );
            if conn.is_null() {
                return false;
            }
            // Callbacks first: the server sends no events until notified.
            (*conn).callback_end = Some(on_finished);
            (*conn).callback_cancel = Some(on_finished);
            let _ = (f.spd_set_notification_on)(conn, SPD_END | SPD_CANCEL);
            self.conn = conn;
        }
        true
    }
}

impl SpeechBackend for Speechd {
    fn new() -> Self {
        Speechd {
            conn: std::ptr::null_mut(),
            voices: Vec::new(),
            current: String::new(),
            current_msg: 0,
        }
    }

    fn voices(&mut self) -> Vec<VoiceInfo> {
        if !self.ensure_conn() {
            self.voices.clear();
            return Vec::new();
        }
        let Some(f) = fns() else { return Vec::new() };
        unsafe {
            let list = (f.spd_list_synthesis_voices)(self.conn);
            if list.is_null() {
                self.voices.clear();
                return Vec::new();
            }
            let mut out = Vec::new();
            let mut i = 0usize;
            while !(*list.add(i)).is_null() {
                let v: &SpdVoice = &**list.add(i);
                let name = CStr::from_ptr(v.name).to_string_lossy().into_owned();
                let lang = CStr::from_ptr(v.language).to_string_lossy().into_owned();
                out.push(VoiceInfo {
                    id: name.clone(),
                    name,
                    lang: lang.to_lowercase(),
                });
                i += 1;
            }
            // Freeing the list needs speech-dispatcher's allocator; it is
            // queried rarely (settings screen / startup) — leak it.
            self.voices = out.clone();
            out
        }
    }

    fn speak(&mut self, utterance: String, text: String, voice_id: String, rate: f64) -> bool {
        // Whatever was in flight is superseded: its END/CANCEL is stale now.
        self.current.clear();
        if !self.ensure_conn() {
            return false;
        }
        let Some(f) = fns() else { return false };
        unsafe {
            if let Some(v) = self.voices.iter().find(|v| v.id == voice_id) {
                if let Ok(lang) = CString::new(v.lang.as_str()) {
                    let _ = (f.spd_set_language)(self.conn, lang.as_ptr());
                }
                if let Ok(name) = CString::new(v.name.as_str()) {
                    let _ = (f.spd_set_synthesis_voice)(self.conn, name.as_ptr());
                }
            }
            // speech-dispatcher rate is -100..100 (1.0x -> 0).
            let spd_rate = ((rate - 1.0) * 100.0).round().clamp(-100.0, 100.0) as i32;
            let _ = (f.spd_set_voice_rate)(self.conn, spd_rate);
            let Ok(ctext) = CString::new(text) else {
                return false;
            };
            // Flush anything in flight, like the web driver's cancel-then-speak.
            let _ = (f.spd_cancel)(self.conn);
            let msg = (f.spd_say)(self.conn, SPD_TEXT, ctext.as_ptr());
            if msg < 0 {
                return false;
            }
            // Recorded before the next poll drains FINISHED, so an END that
            // lands before spd_say returns still matches.
            self.current = utterance;
            self.current_msg = msg as usize;
        }
        true
    }

    fn stop(&mut self) {
        self.current.clear();
        if !self.conn.is_null() {
            if let Some(f) = fns() {
                // CANCEL, not STOP: STOP leaves a message that is still queued
                // (behind another client's speech) to play later.
                unsafe { (f.spd_cancel)(self.conn) };
            }
        }
    }

    fn poll(&mut self) -> Vec<TtsEvent> {
        let finished = std::mem::take(&mut *FINISHED.lock().unwrap());
        // A replaced or stopped message's END/CANCEL is dropped here. CANCEL
        // of the current one (another client's speech pre-empted it) ends it,
        // like the web driver's 'interrupted' error: skip, don't stall.
        if self.current.is_empty() || !finished.contains(&self.current_msg) {
            return Vec::new();
        }
        vec![TtsEvent::End {
            utterance: std::mem::take(&mut self.current),
        }]
    }
}
