// Linux speech-dispatcher backend, dlopen'ed so the app still runs (without
// speech) when libspeechd isn't installed. Word notifications require
// speech-dispatcher >= 0.10; callbacks arrive on speech-dispatcher's event
// thread and translate SSIP byte offsets to UTF-16 indices against the spoken
// text before the worker polls them out.
//
// NOTE: written against the libspeechd 0.10/0.11 headers (the SPDConnection
// layout below only touches fields up to the callbacks, which precede the
// private tail). Verify on a Linux box before shipping — if word callbacks
// misbehave, speech still works, only karaoke highlighting degrades.
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

#[repr(C)]
struct SpdConnection {
    socket: c_int,
    connection_name: *mut c_char,
    client_name: *mut c_char,
    component_name: *mut c_char,
    mode: c_int,
    pipe0: [c_int; 2],
    pipe1: [c_int; 2],
    events_thread: usize, // pthread_t
    callback_begin: Option<SpdCallback>,
    callback_end: Option<SpdCallback>,
    callback_cancel: Option<SpdCallback>,
    callback_pause: Option<SpdCallback>,
    callback_resume: Option<SpdCallback>,
    callback_im: Option<SpdCallback>,
    callback_word: Option<SpdCallback>,
    callback_sentence: Option<SpdCallback>,
}

type SpdCallback = unsafe extern "C" fn(msg_id: c_int, start: c_int, end: c_int);

const SPD_MODE_THREADED: c_int = 1;
const SPD_TEXT: c_int = 3; // priority
                           // SPDNotification enum values (libspeechd.h)
const SPD_END: c_int = 2;
const SPD_WORD: c_int = 7;

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
    spd_stop: unsafe extern "C" fn(conn: *mut SpdConnection) -> c_int,
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
            spd_stop: *lib.get(b"spd_stop\0").ok()?,
            spd_set_voice_rate: *lib.get(b"spd_set_voice_rate\0").ok()?,
            spd_set_language: *lib.get(b"spd_set_language\0").ok()?,
            spd_set_synthesis_voice: *lib.get(b"spd_set_synthesis_voice\0").ok()?,
            spd_list_synthesis_voices: *lib.get(b"spd_list_synthesis_voices\0").ok()?,
            spd_set_notification_on: *lib.get(b"spd_set_notification_on\0").ok()?,
        })
    })
    .as_ref()
}

/* ---------- callback context (single connection per process) ---------- */
struct CallbackCtx {
    queue: Vec<TtsEvent>,
    utterance: String,
    /// The exact UTF-8 text spoken, for byte-offset -> UTF-16 conversion.
    text: String,
}
static CALLBACK_CTX: Mutex<CallbackCtx> = Mutex::new(CallbackCtx {
    queue: Vec::new(),
    utterance: String::new(),
    text: String::new(),
});

unsafe extern "C" fn on_word(_msg: c_int, start: c_int, end: c_int) {
    let mut g = CALLBACK_CTX.lock().unwrap();
    if g.utterance.is_empty() {
        return; // stale
    }
    let (start, end) = byte_range_to_utf16(&g.text, start.max(0) as usize, end.max(0) as usize);
    let utterance = g.utterance.clone();
    g.queue.push(TtsEvent::Word {
        utterance,
        start,
        end,
    });
}

unsafe extern "C" fn on_end(_msg: c_int, _start: c_int, _end: c_int) {
    let mut g = CALLBACK_CTX.lock().unwrap();
    if g.utterance.is_empty() {
        return;
    }
    let utterance = g.utterance.clone();
    g.utterance.clear();
    g.text.clear();
    g.queue.push(TtsEvent::End { utterance });
}

unsafe extern "C" fn on_cancel(_msg: c_int, _start: c_int, _end: c_int) {
    let mut g = CALLBACK_CTX.lock().unwrap();
    if g.utterance.is_empty() {
        return;
    }
    let utterance = g.utterance.clone();
    g.utterance.clear();
    g.text.clear();
    g.queue.push(TtsEvent::End { utterance }); // JS drops it via its stale-id check
}

/// SSIP reports byte offsets; JS highlights UTF-16 indices. When no end offset
/// arrives, extend to the next whitespace — same fallback as the web driver.
fn byte_range_to_utf16(text: &str, bstart: usize, bend: usize) -> (u32, u32) {
    let snap = |mut i: usize| {
        i = i.min(text.len());
        while i > 0 && !text.is_char_boundary(i) {
            i -= 1;
        }
        i
    };
    let mut s = snap(bstart);
    let mut e = snap(bend);
    if e <= s {
        e = s;
        while e < text.len() {
            let ch = text[e..].chars().next().unwrap();
            if ch.is_whitespace() {
                break;
            }
            e += ch.len_utf8();
        }
    }
    let start = text[..s].encode_utf16().count() as u32;
    let end = text[..e].encode_utf16().count() as u32;
    (start, end)
}

pub struct Speechd {
    conn: *mut SpdConnection,
    voices: Vec<VoiceInfo>,
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
            (*conn).callback_end = Some(on_end);
            (*conn).callback_cancel = Some(on_cancel);
            (*conn).callback_word = Some(on_word);
            let _ = (f.spd_set_notification_on)(conn, SPD_END);
            let _ = (f.spd_set_notification_on)(conn, SPD_WORD);
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
            let Ok(ctext) = CString::new(text.as_str()) else {
                return false;
            };
            // Flush anything in flight, like the web driver's cancel-then-speak.
            let _ = (f.spd_stop)(self.conn);
            {
                let mut g = CALLBACK_CTX.lock().unwrap();
                g.utterance = utterance;
                g.text = text;
            }
            (f.spd_say)(self.conn, SPD_TEXT, ctext.as_ptr()) >= 0
        }
    }

    fn stop(&mut self) {
        if !self.conn.is_null() {
            if let Some(f) = fns() {
                unsafe { (f.spd_stop)(self.conn) };
            }
        }
        let mut g = CALLBACK_CTX.lock().unwrap();
        g.utterance.clear();
        g.text.clear();
    }

    fn poll(&mut self) -> Vec<TtsEvent> {
        let mut g = CALLBACK_CTX.lock().unwrap();
        std::mem::take(&mut g.queue)
    }
}
