# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Civics Audio Prep — a hands-free audio study tool for the US naturalization civics test (128 questions, 2025 version), branded "Starwave". One app, three parallel implementations kept in behavioral parity:

- **android/** — Kotlin + Jetpack Compose (`com.yilab.civics`), minSdk 30 / targetSdk 36. Reference implementation.
- **apple/Civics/** — SwiftUI (Xcode project, scheme `Civics`), iOS/iPadOS (deployment target 26.5), also builds/runs on macOS Apple Silicon.
- **web/** — vanilla JS ES modules bundled by esbuild into a single-file HTML, deployed as static assets on Cloudflare Workers.

The app speaks each question, pauses for you to answer aloud, then speaks the answer (karaoke-highlighting the spoken word). Tabs: Listen, Flashcards, Questions, Test (hands-free practice test), Settings. 11 study languages.

**Android is the behavioral reference**: `web/src/engine.js` is a stated port of `StudyEngine.kt`, `web/src/i18n.js` mirrors `SpeechLanguage.kt`. Engine/settings/i18n behavior changes must land on all three platforms — check the other two whenever you touch one.

## Commands

```bash
# Android (from android/)
./gradlew test                                        # all unit tests
./gradlew test --tests "com.yilab.civics.StudyEngineTest"   # single test class
./gradlew installDebug                                # build + install to device/emulator

# Apple (from apple/Civics/)
xcodebuild -project Civics.xcodeproj -scheme Civics \
  -destination 'platform=iOS Simulator,name=<installed iPhone sim>' test

# Web (from web/, npm install once)
npm run sync      # regenerate question bank from sources + rebuild artifact
npm run build     # rebuild web/civics-test-study-tool.html from web/src/
npm run dev       # build + wrangler dev (local Cloudflare Workers)
npm run deploy    # build + wrangler deploy
```

Web has no test suite — a clean `npm run build` is its smoke test. Android unit tests use JUnit + `kotlinx-coroutines-test` (`StudyEngineTest` drives the engine via a `FakeSpeechEngine` with virtual time). Apple unit tests are in `CivicsTests` (StudyEngine, KaraokeText, QuestionRepository).

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

The web app renders only from `BANK`, never from `questions-source.js`.

## Architecture (shared across platforms)

Same file layout on each platform — `audio/`, `data/`, `settings/`, `ui/` (Kotlin), or same-named `.swift` files, or `web/src/{engine,speech,i18n,settings}.js` + `web/src/ui/*.js`:

- **StudyEngine** (`audio/StudyEngine.kt` | `.swift` | `src/engine.js`) — the core state machine: speak question → think pause (default 3 s) → speak answer → advance. `Phase`: IDLE, SPEAKING_QUESTION, THINKING, SPEAKING_ANSWER, AWAITING_ADVANCE, AWAITING_GRADE, FINISHED. `Mode`: STUDY vs TEST — the practice test asks 20 questions and stops the moment you reach 12 correct (pass) or 9 wrong (fail), like the real interview. The engine never touches the UI; screens observe state (Compose state flows / observable `AppModel` / `onEngineUpdate` callback).
- **SpeechEngine** abstraction per platform — Android `TextToSpeech` (run by `CivicsAudioService`, a foreground service with media3/MediaSession lock-screen controls), Apple `AVSpeechSynthesizer`, web `SpeechSynthesis`. All skip utterances whose language has no installed voice rather than garbling.
- **Karaoke** (`ui/Karaoke.kt` | `ui/KaraokeText.swift` | `ui/listen.js`) — TTS boundary/range events set a character range on the in-flight utterance; the UI highlights that word. When the same text appears twice (original + translation), highlight the copy actually being spoken, not the first match.
- **QuestionRepository** (`data/`) — loads the generated bank, categories, known-question set, three-way known filter.
- **Settings** — Android DataStore Preferences / Apple UserDefaults / web `localStorage` with `civics.*` keys; identical shapes.

### Web build specifics

`web/build.mjs` esbuild-bundles `src/main.js` + styles + icons and inlines everything (JS, CSS, icons as data URIs) into the checked-in single-file artifact `web/civics-test-study-tool.html` — no runtime fetches, openable from `file://`. Deploy copies it to `dist/index.html` for wrangler static assets. Edit `web/src/`, never the artifact.

### Icons and brand marks

`python3 assets/generate_icons.py` regenerates every platform's launcher icons and logo marks (Android drawables/mipmaps, iOS asset catalog, `web/icons/`) from vector geometry — needs Pillow. `npm run build` fails with a pointer to it if web icons are missing.

## Conventions

- Conventional commits (`feat:`, `fix:`, `chore:`, `refactor:`); no Co-Author lines.
- Generated files carry "do not edit by hand" banners: the two `questions.json`s, `bank.generated.js`, `civics-test-study-tool.html`.
