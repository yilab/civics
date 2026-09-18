# Civics Audio Prep

A hands-free audio study tool for the **US naturalization civics test** (128 questions,
2025 version). It speaks each question, pauses while you answer out loud, then speaks
the answer — highlighting each word as it is read. Study with the phone in your pocket,
while cooking, or on the drive to your interview.

Branded **Starwave**. No ads, no tracking, no accounts, no network calls.

## Features

- **All 128 official civics questions**, in 11 study languages: English, Spanish,
  Simplified & Traditional Chinese, Vietnamese, Tagalog, Korean, Arabic, Hindi,
  Portuguese, Russian.
- **Bilingual read-along** — each question and answer is spoken in English and your
  study language; the copy actually being spoken is the one that lights up.
- **Karaoke word highlight** — TTS boundary events light up the current word so you
  can read along.
- **Hands-free practice test** — asks 20 questions and stops the moment you reach
  12 correct (pass) or 9 wrong (fail), just like the real interview.
- **Flashcards** and a **three-way known filter** (known / unknown / all) on the
  Listen and Questions tabs.
- Configurable think pause (default 3 s), speech rate, and voice.

Tabs: **Listen** (continuous audio study) · **Flashcards** · **Questions** (browse
& mark known) · **Test** (hands-free practice test) · **Settings**.

## Platforms

One app, three implementations kept in behavioral parity:

| Platform | Stack | Notes |
|---|---|---|
| **Android** | Kotlin + Jetpack Compose | `com.yilab.civics`, minSdk 30 / targetSdk 36. Foreground service with lock-screen media controls. Behavioral reference for the other two. |
| **Apple** | SwiftUI | iOS/iPadOS (deployment target 26.5); also builds and runs on Apple-silicon Macs. |
| **Web** | Vanilla JS ES modules + esbuild | Bundled into a single self-contained HTML file — openable from `file://`, zero runtime fetches. Deployed as static assets on Cloudflare Workers. |

## Build & run

### Android (`android/`)

```bash
./gradlew installDebug        # build + install to a device/emulator
./gradlew test                # unit tests (JUnit + kotlinx-coroutines-test)
```

### Apple (`apple/Civics/`)

Open `Civics.xcodeproj` in Xcode and run scheme **Civics**, or from the command line:

```bash
xcodebuild -project Civics.xcodeproj -scheme Civics \
  -destination 'platform=iOS Simulator,name=<installed iPhone sim>' test
```

### Web (`web/`)

```bash
npm install       # once
npm run build     # rebuild civics-test-study-tool.html from web/src/
npm run dev       # build + wrangler dev (local Cloudflare Workers)
npm run deploy    # build + wrangler deploy
npm run sync      # regenerate the question bank from sources + rebuild
```

`npm run build` inlines everything — JS, CSS, icons as data URIs — into the checked-in
artifact `web/civics-test-study-tool.html`, then copies it to `dist/index.html` for
wrangler. Edit `web/src/`, never the artifact.

The web app has no test suite; a clean build is its smoke test. Android and Apple
have unit tests for the engine, karaoke highlighting, and question repository.

## Question bank pipeline

Never edit a generated file by hand. The chain:

1. **Sources of truth**
   - `web/data/questions-source.js` — English (`Q`, 128 questions) + Simplified Chinese (`QZ`)
   - `android/tools/translations-extra.json` — the other 9 languages
2. **Generator** — `node android/tools/extract-questions.mjs` adds the TTS-friendly
   `spoken` field (hand-tuned overrides + heuristics that strip parentheticals) and
   **fails** if any language is missing a translation or spoken text still contains
   parentheses/double spaces.
3. **Generated, checked in**
   - `android/app/src/main/assets/questions.json`
   - `apple/Civics/Civics/Resources/questions.json`
   - `web/data/bank.generated.js` (ESM module the web app imports; the web app renders
     only from this bank)

The official questions come from USCIS (US federal government content — public domain);
the translations and spoken-text tuning are part of this project.

## Architecture

All three platforms share the same design, with same-named modules:

- **StudyEngine** (`audio/StudyEngine.kt` · `.swift` · `src/engine.js`) — the core
  state machine: speak question → think pause → speak answer → advance.
  Phases: IDLE, SPEAKING_QUESTION, THINKING, SPEAKING_ANSWER, AWAITING_ADVANCE,
  AWAITING_GRADE, FINISHED. Modes: STUDY vs TEST (the early-stop practice test).
  The engine never touches the UI; screens observe engine state.
- **SpeechEngine** — per-platform TTS (Android `TextToSpeech`, Apple
  `AVSpeechSynthesizer`, web `SpeechSynthesis`). All skip utterances whose language
  has no installed voice rather than garbling them.
- **Karaoke** (`ui/Karaoke.kt` · `ui/KaraokeText.swift` · `ui/listen.js`) — TTS
  boundary/range events set a character range; the UI highlights that word, on the
  copy actually being spoken.
- **QuestionRepository** (`data/`) — loads the generated bank, categories, and the
  known-question set.
- **Settings** — DataStore Preferences (Android) / UserDefaults (Apple) /
  `localStorage` with `civics.*` keys (web); identical shapes everywhere.

Engine, settings, and i18n behavior changes must land on all three platforms — keep
them in parity.

Launcher icons and logo marks are regenerated from vector geometry:
`python3 assets/generate_icons.py` (needs Pillow).

## License

Code and content in this repository are licensed under the
[Apache License 2.0](LICENSE) — the same permissive license used across this
project family. You are free to use, study, modify, and redistribute it, including
commercially, with attribution.

The **Starwave** name and logo are project trademarks and are not licensed for
redistribution under the Apache-2.0 terms; forks should pick their own name.

This project is not affiliated with or endorsed by USCIS or any government agency.
It is an independent study aid; always check the
[official USCIS 2025 civics test page](https://www.uscis.gov/citizenship-resource-center/naturalization-test-and-study-resources/2025-civics-test)
for the current test.
