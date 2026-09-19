# Civics Audio Prep — Desktop (Windows & Linux)

Tauri 2 shell around the **shared web app** (`../web/src`). Everything except
the speech engine and OS media session is byte-identical to the web build:
engine, settings, i18n, and all UI modules are bundled straight from
`web/src`, so behavioral parity with Android/iOS/web is structural, not
maintained.

## Commands

```bash
npm install        # once
npm run build      # web/src -> desktop/dist/index.html (single file, no network)
npm run dev        # build + tauri dev (hot-reloads the Rust side)
npm run app        # build + tauri build (release installers: .msi/.nsis, .deb/AppImage)
cargo test         # in src-tauri/ — includes live SAPI voice + karaoke tests
```

## How the pieces fit

- **`build.mjs`** — esbuild bundle of `web/src/main.js`, with one substitution:
  every import of `web/src/speech.js` resolves to `src/native-speech.js`
  instead. Google Fonts links are stripped (system font fallbacks; the desktop
  app makes no network requests at all).
- **`src/native-speech.js`** — drop-in replacement for the Web Speech driver:
  speaks through Tauri commands (`tts_speak` / `tts_stop` / `tts_voices`),
  receives `tts:boundary` / `tts:end` events for karaoke highlighting and
  utterance chaining, and maps `media:action` events to the same
  play/pause/next/previous engine calls the web app wires to
  `navigator.mediaSession`.
- **`src-tauri/src/speech/`** — one worker thread owns the OS speech engine:
  - `sapi.rs` (Windows): `ISpVoice` via the `windows` crate; word-boundary
    karaoke via queued `SPEI_WORD_BOUNDARY` events (UTF-16 ranges, matching JS
    strings). Voice enumeration via `ISpObjectTokenCategory` + the `Language`
    attribute (hex LCIDs → BCP-47).
  - `speechd.rs` (Linux): speech-dispatcher via `dlopen`ed `libspeechd`
    (app still runs without it, speech simply disabled). Byte-offset word
    callbacks are converted to UTF-16 indices. Needs speech-dispatcher ≥ 0.10
    for word events — verify on a Linux box before shipping.
- **`src-tauri/src/media.rs`** — headset/lock-screen buttons via `souvlaki`
  (SMTC on Windows, MPRIS on Linux), plus OS media-session metadata.

## Notes

- Windows language coverage depends on installed voice packs (Settings →
  Speech); the app shows the shared no-TTS warning when a language is missing.
- `SPEVENT` packing and `SPFEI_FLAGCHECK` bits are handled in `sapi.rs` —
  SAPI's `SetInterest` rejects masks without bits 30|33, and word-boundary
  events carry length in `wParam`, position in `lParam` (verified by tests).
