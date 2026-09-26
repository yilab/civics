# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Civics Audio Prep — a hands-free audio study tool for the US naturalization civics test (128 questions, 2025 version), branded "Starwave". One app, four parallel implementations kept in behavioral parity:

- **android/** — Kotlin + Jetpack Compose (`com.yilab.civics`), minSdk 30 / targetSdk 36. Reference implementation.
- **apple/Civics/** — SwiftUI (Xcode project, scheme `Civics`), iOS/iPadOS (deployment target 26.5), also builds/runs on macOS Apple Silicon.
- **web/** — vanilla JS ES modules bundled by esbuild into a single-file HTML, deployed as static assets on Cloudflare Workers.
- **desktop/** — Tauri 2 (Windows + Linux) wrapping the shared web sources: `build.mjs` bundles `web/src` with `web/src/speech.js` swapped for `desktop/src/native-speech.js`, which drives OS TTS (Windows SAPI, Linux speech-dispatcher) and OS media keys (SMTC/MPRIS) from `src-tauri/`.

The app speaks each question, pauses for you to answer aloud, then speaks the answer (karaoke-highlighting the spoken word). Tabs: Listen, Flashcards, Questions, Test (hands-free practice test), Settings. 11 study languages.

**Android is the behavioral reference**: `web/src/engine.js` is a stated port of `StudyEngine.kt`, `web/src/i18n.js` mirrors `SpeechLanguage.kt`. Engine/settings/i18n behavior changes must land on all platforms — the desktop build shares the web engine by construction, but check android/apple whenever you touch one.

## Commands

```bash
# Android (from android/)
./gradlew test                                        # all unit tests
./gradlew test --tests "com.yilab.civics.StudyEngineTest"   # single test class
./gradlew installDebug                                # build + install to device/emulator

# Apple (from apple/Civics/)
xcodebuild -project Civics.xcodeproj -scheme Civics \
  -destination 'platform=iOS Simulator,name=<installed iPhone sim>' test

# Apple App Store screenshots (from repo root) — captures en + zh-Hans UI sets
# on the given simulator into assets/screenshots/apple/<size>/{en,zh-Hans}/
apple/tools/capture-screenshots.sh "iPhone 17 Pro Max" assets/screenshots/apple/iphone-6.9
apple/tools/capture-screenshots.sh "iPad Air 13-inch (M4)" assets/screenshots/apple/ipad-13
# Note: the iPad Pro 13-inch (M5) sim renders a blank screen in the iOS 26.5
# runtime on this machine — use the iPad Air 13-inch (M4) sim instead.

# Mac App Store screenshots (from repo root) — builds the macOS app and runs it
# with -renderScreenshots; ScreenshotRenderer (DEBUG-only, ui/ScreenshotRenderer.swift)
# snapshots the five screens in offscreen windows at 2560x1600 into
# assets/screenshots/apple/mac/{en,zh-Hans}/ — no Accessibility grant needed.
# The script temporarily re-signs the debug build without the sandbox so the
# shots can be written outside the app container (a rebuild restores it).
apple/tools/capture-screenshots-mac.sh assets/screenshots/apple/mac

# Google Play screenshots — boots the profile's emulator headless if needed and
# captures en + zh-Hans sets into assets/screenshots/android/<profile>/ —
# no test code, pure adb/uiautomator driving. phone = 1080x2160 (Play's max
# 2:1 aspect), tablet-10 = native 1600x2560, tablet-7 = native 1200x1920.
python3 android/tools/capture-screenshots.py            # phone (Pixel_10)
python3 android/tools/capture-screenshots.py tablet-10  # 10" tablet (HP_Tablet)
python3 android/tools/capture-screenshots.py tablet-7   # 7" tablet (Nexus_7)

# Web (from web/, npm install once)
npm run sync      # regenerate question bank from sources + rebuild artifact
npm run build     # rebuild web/civics-test-study-tool.html from web/src/
npm run dev       # build + wrangler dev (local Cloudflare Workers)
npm run deploy    # build + wrangler deploy

# Desktop (from desktop/, npm install once)
npm run dev       # rebuild web bundle + tauri dev
npm run app       # rebuild web bundle + tauri build (release installers)
(cd src-tauri && cargo test)   # SAPI voice/karaoke tests (Windows)
```

Web has no test suite — a clean `npm run build` is its smoke test. Android unit tests use JUnit + `kotlinx-coroutines-test` (`StudyEngineTest` drives the engine via a `FakeSpeechEngine` with virtual time). Apple unit tests are in `CivicsTests` (StudyEngine, KaraokeText, QuestionRepository). Desktop: `cargo test` in `desktop/src-tauri/` exercises the SAPI backend live (voice enumeration, word-boundary events).

## Question-Bank Data Pipeline

Never edit a generated file by hand. The chain:

1. **Sources of truth**:
   - `web/data/questions-source.js` — `Q` (128 English questions) + `QZ` (Simplified Chinese).
   - `android/tools/translations-extra.json` — the other 9 languages (es, zh-Hant, vi, tl, ko, ar, hi, pt, ru).
2. **Generator**: `node android/tools/extract-questions.mjs` (or `npm run sync` in web/, which also rebuilds). Adds the TTS-friendly `spoken` field (hand-tuned `SPOKEN_OVERRIDES` + heuristics that strip parentheticals) and **fails** if any language is missing a translation or spoken text still contains parens/double spaces.
3. **Generated, checked in**:
   - `android/app/src/main/assets/questions.json`
   - `apple/Civics/Civics/Resources/questions.json`
   - `web/data/bank.generated.js` (ESM module the web app imports)

The web app renders only from `BANK`, never from `questions-source.js`. The desktop app gets the bank the same way — `desktop/build.mjs` bundles `web/data/bank.generated.js`.

## Officials Data Pipeline (state-specific answers)

Q23/29/61/62 depend on where the applicant lives. Design and refresh cadence: `docs/state-answers.md`.

1. **Sources of truth**:
   - `web/data/officials-source.json` — hand-maintained: the 56 places (50 states, D.C., 5 territories) with capitals and localized names, governors with term dates, and the answer-sentence templates in all 11 study languages. Officials' names stay in English in every language; only the surrounding sentence is translated.
   - `web/data/officials-congress.json` — distilled from the CC0 unitedstates/congress-legislators roster by `node android/tools/fetch-officials.mjs` (checked in; re-run after elections or seat changes and review the diff).
2. **Generator**: `node android/tools/extract-officials.mjs` (runs as part of `npm run sync` in web/). Merges both into per-seat timelines with `from`/`until` dates and **fails** on any coverage, seat-count, or template gap.
3. **Generated, checked in**:
   - `android/app/src/main/assets/officials.json`
   - `apple/Civics/Civics/Resources/officials.json`
   - `web/data/officials.generated.js`

At runtime each platform's personalizer (`web/src/officials.js`, `data/Officials.kt`, `data/Officials.swift` — kept in parity) fills the four questions for the user's `jurisdiction`/`district` settings on today's date; the engines exclude state questions from the practice test until a state is set.

## Architecture (shared across platforms)

Same file layout on each platform — `audio/`, `data/`, `settings/`, `ui/` (Kotlin), or same-named `.swift` files, or `web/src/{engine,speech,i18n,settings}.js` + `web/src/ui/*.js`. **Desktop shares the web files wholesale** — only the speech engine and media-session integration live in `desktop/` (`src/native-speech.js` + `src-tauri/src/`).

- **StudyEngine** (`audio/StudyEngine.kt` | `.swift` | `src/engine.js`) — the core state machine: speak question → think pause (default 3 s) → speak answer → advance. `Phase`: IDLE, SPEAKING_QUESTION, THINKING, SPEAKING_ANSWER, AWAITING_ADVANCE, AWAITING_GRADE, FINISHED. `Mode`: STUDY vs TEST — the practice test asks 20 questions and stops the moment you reach 12 correct (pass) or 9 wrong (fail), like the real interview. The engine never touches the UI; screens observe state (Compose state flows / observable `AppModel` / `onEngineUpdate` callback).
- **SpeechEngine** abstraction per platform — Android `TextToSpeech` (run by `CivicsAudioService`, a foreground service with media3/MediaSession lock-screen controls), Apple `AVSpeechSynthesizer`, web `SpeechSynthesis`. All skip utterances whose language has no installed voice rather than garbling.
- **Karaoke** (`ui/Karaoke.kt` | `ui/KaraokeText.swift` | `ui/listen.js`) — TTS boundary/range events set a character range on the in-flight utterance; the UI highlights that word. When the same text appears twice (original + translation), highlight the copy actually being spoken, not the first match.
- **QuestionRepository** (`data/`) — loads the generated bank, categories, known-question set, three-way known filter.
- **Settings** — Android DataStore Preferences / Apple UserDefaults / web `localStorage` with `civics.*` keys; identical shapes.

### Web build specifics

`web/build.mjs` esbuild-bundles `src/main.js` + styles + icons and inlines everything (JS, CSS, icons as data URIs) into the checked-in single-file artifact `web/civics-test-study-tool.html` — no runtime fetches, openable from `file://`. The build also rewrites `dist/` (wrangler static assets): the artifact as `index.html`, plus `src/privacy.html` → `privacy.html`, served at `/privacy` as the App Store / Google Play privacy-policy URL. Edit `web/src/`, never the artifact. If an app starts storing, sending, or requesting anything new (network, permissions, SDKs), update `src/privacy.html` in the same change.

### Icons and brand marks

`python3 assets/generate_icons.py` regenerates every platform's launcher icons and logo marks (Android drawables/mipmaps, iOS asset catalog, `web/icons/`) from vector geometry — needs Pillow. `npm run build` fails with a pointer to it if web icons are missing.

## Conventions

- Conventional commits (`feat:`, `fix:`, `chore:`, `refactor:`); no Co-Author lines.
- Generated files carry "do not edit by hand" banners: the two `questions.json`s, `bank.generated.js`, `civics-test-study-tool.html`.
