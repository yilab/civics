// Windows SAPI backend. One ISpVoice lives on the worker thread (MTA COM).
// Word boundaries arrive as queued SPEI_WORD_BOUNDARY events, drained with
// GetEvents — no notify-sink plumbing. Positions are UTF-16 code-unit offsets
// into the text passed to Speak, which is exactly what the JS karaoke
// highlighting expects (JS strings are UTF-16).
use windows::core::{HSTRING, PCWSTR, PWSTR};
use windows::Win32::Globalization::LCIDToLocaleName;
use windows::Win32::Media::Speech::{
    ISpObjectToken, ISpObjectTokenCategory, ISpVoice, SpObjectTokenCategory, SpVoice, SPCAT_VOICES,
    SPEI_END_INPUT_STREAM, SPEI_WORD_BOUNDARY, SPEVENT, SPF_ASYNC, SPF_PURGEBEFORESPEAK,
};
use windows::Win32::System::Com::{
    CoCreateInstance, CoInitializeEx, CoTaskMemFree, CLSCTX_ALL, COINIT_MULTITHREADED,
};

use super::{SpeechBackend, TtsEvent, VoiceInfo};

pub struct Sapi {
    voice: Option<ISpVoice>,
    tokens: Vec<(String, ISpObjectToken)>,
    /// Utterance id and text of the in-flight Speak; empty when idle.
    current: String,
    current_text: String,
}

// The COM pointers are created and used on the speech worker thread only; the
// struct is moved into that thread before any COM call is made.
unsafe impl Send for Sapi {}

impl Sapi {
    fn ensure(&mut self) -> Option<&ISpVoice> {
        if self.voice.is_none() {
            unsafe {
                let hr = CoInitializeEx(None, COINIT_MULTITHREADED);
                if hr.ok().is_err() {
                    if cfg!(test) {
                        eprintln!("diag: CoInitializeEx: {hr:?}");
                    }
                    return None;
                }
                let voice: ISpVoice = match CoCreateInstance(&SpVoice, None, CLSCTX_ALL) {
                    Ok(v) => v,
                    Err(e) => {
                        if cfg!(test) {
                            eprintln!("diag: cocreate SpVoice failed: {e}");
                        }
                        return None;
                    }
                };
                // Queue exactly the events the karaoke + chaining logic needs;
                // poll() drains them. Interest is a bitmask like the C SPFEI()
                // macro: the event bit PLUS the mandatory SPFEI_FLAGCHECK bits
                // (SPEI_RESERVED1=30 | SPEI_RESERVED2=33), without which
                // SetInterest returns E_INVALIDARG.
                let mask = (1u64 << 30)
                    | (1u64 << 33)
                    | (1u64 << SPEI_WORD_BOUNDARY.0)
                    | (1u64 << SPEI_END_INPUT_STREAM.0);
                if let Err(e) = voice.SetInterest(mask, mask) {
                    if cfg!(test) {
                        eprintln!("diag: SetInterest failed: {e}");
                    }
                    return None;
                }
                self.voice = Some(voice);
            }
        }
        self.voice.as_ref()
    }
}

impl SpeechBackend for Sapi {
    fn new() -> Self {
        Sapi {
            voice: None,
            tokens: Vec::new(),
            current: String::new(),
            current_text: String::new(),
        }
    }

    fn voices(&mut self) -> Vec<VoiceInfo> {
        let mut out = Vec::new();
        let mut tokens = Vec::new();
        let Some(voice) = self.ensure() else {
            return out;
        };
        let _ = voice; // the voice instance exists; enumeration goes via the category
        unsafe {
            // SAPI voice tokens live under the "Voices" registry category —
            // ISpVoice itself has no enumerator (that's the automation API).
            let category: ISpObjectTokenCategory =
                match CoCreateInstance(&SpObjectTokenCategory, None, CLSCTX_ALL) {
                    Ok(c) => c,
                    Err(e) => {
                        if cfg!(test) {
                            eprintln!("diag: cocreate category failed: {e}");
                        }
                        return out;
                    }
                };
            if let Err(e) = category.SetId(SPCAT_VOICES, false) {
                if cfg!(test) {
                    eprintln!("diag: SetId failed: {e}");
                }
                return out;
            }
            let list = match category.EnumTokens(PCWSTR::null(), PCWSTR::null()) {
                Ok(l) => l,
                Err(e) => {
                    if cfg!(test) {
                        eprintln!("diag: EnumTokens failed: {e}");
                    }
                    return out;
                }
            };
            let mut count = 0u32;
            if let Err(e) = list.GetCount(&mut count) {
                if cfg!(test) {
                    eprintln!("diag: GetCount failed: {e}");
                }
                return out;
            }
            if cfg!(test) {
                eprintln!("diag: {count} tokens");
            }
            for i in 0..count {
                let Ok(token) = list.Item(i) else { continue };
                let id = token.GetId().map(|p| take_pwstr(p)).unwrap_or_default();
                if id.is_empty() {
                    continue;
                }
                // The token key's default value is the friendly name
                // ("Microsoft David Desktop"); fall back to the key's last segment.
                let name = token
                    .GetStringValue(PCWSTR::null())
                    .map(|p| take_pwstr(p))
                    .unwrap_or_else(|_| last_segment(&id));
                let lang = token
                    .OpenKey(&HSTRING::from("Attributes"))
                    .and_then(|attrs| attrs.GetStringValue(&HSTRING::from("Language")))
                    .map(|p| take_pwstr(p))
                    .map(|codes| {
                        // "409;804" hex LCIDs -> first convertible BCP-47 tag.
                        codes.split(';').find_map(lcid_to_tag).unwrap_or_default()
                    })
                    .unwrap_or_default();
                out.push(VoiceInfo {
                    id: id.clone(),
                    name,
                    lang: lang.to_lowercase(),
                });
                tokens.push((id, token));
            }
        }
        self.tokens = tokens;
        out
    }

    fn speak(&mut self, utterance: String, text: String, voice_id: String, rate: f64) -> bool {
        // Voice list can change (language packs installed); refresh on a miss.
        if !self.tokens.iter().any(|(id, _)| *id == voice_id) {
            self.voices();
        }
        let token = self
            .tokens
            .iter()
            .find(|(id, _)| *id == voice_id)
            .map(|(_, t)| t.clone());
        let Some(voice) = self.ensure() else {
            return false;
        };
        unsafe {
            if let Some(token) = token {
                let _ = voice.SetVoice(&token);
            }
            // SAPI rate is -10..10; the app's 0.75x..1.5x multiplier maps
            // linearly (1.0 -> 0, 1.5 -> 5, 0.75 -> -3).
            let sapi_rate = ((rate - 1.0) * 10.0).round().clamp(-10.0, 10.0) as i32;
            let _ = voice.SetRate(sapi_rate);
            // ASYNC + PURGEBEFORESPEAK = the web driver's cancel-then-speak.
            let text16 = HSTRING::from(&text);
            let flags = (SPF_ASYNC.0 | SPF_PURGEBEFORESPEAK.0) as u32;
            if voice
                .Speak(PCWSTR::from_raw(text16.as_ptr()), flags, None)
                .is_err()
            {
                return false;
            }
        }
        self.current = utterance;
        self.current_text = text;
        true
    }

    fn stop(&mut self) {
        if let Some(voice) = &self.voice {
            // SAPI has no Stop(); speaking NULL with PURGE flushes the queue.
            unsafe {
                let flags = SPF_PURGEBEFORESPEAK.0 as u32;
                let _ = voice.Speak(PCWSTR::null(), flags, None);
            }
        }
        self.current.clear();
        self.current_text.clear();
    }

    fn poll(&mut self) -> Vec<TtsEvent> {
        let mut out = Vec::new();
        let Some(voice) = &self.voice else { return out };
        let idle = self.current.is_empty();
        let text16len = self.current_text.encode_utf16().count() as u32;
        loop {
            let mut evt: SPEVENT = unsafe { std::mem::zeroed() };
            let mut fetched: u32 = 0;
            let hr = unsafe { voice.GetEvents(1, &mut evt, &mut fetched) };
            if hr.is_err() || fetched == 0 {
                break;
            }
            // SPEVENT packs { eEventId, elParamType } into the first 4 bytes;
            // the event id is the low word.
            let event_id = (evt._bitfield as u32) & 0xFFFF;
            if idle {
                continue; // discard events for an already-stopped utterance
            }
            if event_id == SPEI_WORD_BOUNDARY.0 as u32 {
                // Empirically verified against sapi.h semantics: wParam is
                // the word's LENGTH and lParam its char position. ("one two
                // three" -> (3,0) (3,4) (5,8).) Skip degenerate events.
                let start = evt.lParam.0.max(0) as u32;
                let len = evt.wParam.0 as u32;
                if len == 0 || start >= text16len {
                    continue;
                }
                let end = (start + len).min(text16len);
                out.push(TtsEvent::Word {
                    utterance: self.current.clone(),
                    start,
                    end,
                });
            } else if event_id == SPEI_END_INPUT_STREAM.0 as u32 {
                out.push(TtsEvent::End {
                    utterance: self.current.clone(),
                });
                self.current.clear();
                self.current_text.clear();
            }
        }
        out
    }
}

/// Copies a SAPI-allocated string and frees it (caller-owned via CoTaskMem).
unsafe fn take_pwstr(p: PWSTR) -> String {
    if p.is_null() {
        return String::new();
    }
    let mut len = 0usize;
    while *p.0.add(len) != 0 {
        len += 1;
    }
    let s = String::from_utf16_lossy(std::slice::from_raw_parts(p.0, len));
    CoTaskMemFree(Some(p.0 as *const core::ffi::c_void));
    s
}

fn last_segment(id: &str) -> String {
    id.rsplit(['\\', '/']).next().unwrap_or(id).to_string()
}

/// LCID ("409") -> BCP-47 ("en-US"); empty when the LCID is unknown.
fn lcid_to_tag(code: &str) -> Option<String> {
    let lcid = u32::from_str_radix(code.trim(), 16).ok()?;
    let mut buf = [0u16; 85]; // LOCALE_NAME_MAX_LENGTH
    let n = unsafe { LCIDToLocaleName(lcid, Some(&mut buf), 0) };
    if n > 0 {
        // The return value includes the NUL terminator.
        let end = (n as usize).min(buf.len());
        let s = &buf[..end];
        let trim = if s.last() == Some(&0) { end - 1 } else { end };
        Some(String::from_utf16_lossy(&s[..trim]))
    } else {
        None
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn lcid_parsing() {
        assert_eq!(lcid_to_tag("409").unwrap().to_lowercase(), "en-us");
        assert_eq!(lcid_to_tag("804").unwrap().to_lowercase(), "zh-cn");
        assert_eq!(lcid_to_tag("404").unwrap().to_lowercase(), "zh-tw");
        assert!(lcid_to_tag("zz").is_none());
    }

    #[test]
    fn enumerates_voices_with_tags() {
        let mut sapi = Sapi::new();
        let voices = sapi.voices();
        assert!(!voices.is_empty(), "SAPI returned no voices");
        assert!(voices
            .iter()
            .all(|v| !v.id.is_empty() && !v.name.is_empty()));
        // Windows ships English voices; the Language attribute must come out
        // as a BCP-47 tag the JS voice matcher understands.
        assert!(
            voices.iter().any(|v| v.lang.starts_with("en")),
            "no en-* voice in {:?}",
            voices.iter().map(|v| v.lang.as_str()).collect::<Vec<_>>()
        );
    }

    #[test]
    fn speaks_and_reports_word_boundaries() {
        // End-to-end through the backend the worker drives: async Speak, then
        // poll() must surface word-boundary events with UTF-16 [start, end)
        // ranges that land on non-whitespace, and finally an End event.
        let mut sapi = Sapi::new();
        let voices = sapi.voices();
        let en = voices
            .iter()
            .find(|v| v.lang.starts_with("en"))
            .expect("en voice")
            .id
            .clone();
        let text = "one two three";
        assert!(sapi.speak("t-1".into(), text.into(), en, 1.0));

        let mut words: Vec<(u32, u32)> = Vec::new();
        let mut ended = false;
        let deadline = std::time::Instant::now() + std::time::Duration::from_secs(10);
        while !ended && std::time::Instant::now() < deadline {
            for ev in sapi.poll() {
                match ev {
                    TtsEvent::Word { start, end, .. } => words.push((start, end)),
                    TtsEvent::End { .. } => ended = true,
                }
            }
            std::thread::sleep(std::time::Duration::from_millis(20));
        }
        assert!(ended, "no end-of-stream event; words so far: {words:?}");
        assert!(
            words.len() >= 3,
            "expected >=3 word boundaries, got {words:?}"
        );
        for (start, end) in words {
            assert!(end > start, "empty range {start}..{end}");
            let slice = &text[start as usize..end as usize];
            assert!(
                !slice.trim().is_empty(),
                "boundary on whitespace: {slice:?}"
            );
        }
    }
}
