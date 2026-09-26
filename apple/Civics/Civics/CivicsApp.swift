//
//  CivicsApp.swift
//  Civics
//
//  Created by Yi Wang on 9/6/26.
//

import SwiftUI

/// The DI container — the CivicsApp.onCreate analog.
@MainActor @Observable
final class AppModel {
    let questionRepo: QuestionRepository
    let officialsRepo: OfficialsRepository
    let settingsRepo: SettingsRepository
    let engine: StudyEngine
    let playback: PlaybackCoordinator
    private let speech: SystemSpeechEngine

    /// Mode-aware TTS availability for the Listen warning card.
    var ttsAvailable: Bool {
        let s = settingsRepo.settings
        let lang = s.spokenLanguage
        if lang == .english { return speech.isAvailable(.english) }
        return s.bilingual
            ? speech.isAvailable(.english) && speech.isAvailable(lang)
            : speech.isAvailable(lang)
    }

    init() {
        let questionRepo = QuestionRepository.fromBundle()
        let officialsRepo = OfficialsRepository.fromBundle()
        let settingsRepo = SettingsRepository()
        let speech = SystemSpeechEngine()
        let engine = StudyEngine(
            speech: speech,
            repo: questionRepo,
            officials: officialsRepo.data,
            settings: settingsRepo,
            scheduler: MainTaskScheduler(),
            onKnownChanged: { n, known in
                settingsRepo.update { s in
                    s.copy(known: known ? s.known.union([n]) : s.known.subtracting([n]))
                }
            },
            onTestFinished: { record in
                settingsRepo.recordTest(record)
            }
        )
        self.questionRepo = questionRepo
        self.officialsRepo = officialsRepo
        self.settingsRepo = settingsRepo
        self.engine = engine
        self.playback = PlaybackCoordinator(engine: engine)
        self.speech = speech

        // Point the string resolver at the chosen language before the first
        // render, and keep it current as the setting changes.
        L10n.apply(settingsRepo.settings.language)
        settingsRepo.observe { s in
            L10n.apply(s.language)
        }

        // Wires remote commands, now-playing info, and the audio session.
        playback.start()

        #if DEBUG && os(macOS)
        // Mac App Store screenshots: renders and returns immediately unless
        // -renderScreenshots <dir> was passed (see ScreenshotRenderer).
        ScreenshotRenderer.renderIfRequested(model: self)
        #endif
    }
}

@main
struct CivicsApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
        }
        #if os(macOS)
        // 16:10 default window — also the Mac App Store screenshot content size
        // (1280 × 800 pt → 2560 × 1600 px on Retina).
        .defaultSize(CGSize(width: 1280, height: 800))
        #endif
    }
}
