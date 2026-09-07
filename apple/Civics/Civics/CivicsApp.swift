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
    let settingsRepo: SettingsRepository
    let engine: StudyEngine
    let playback: PlaybackCoordinator
    let ttsAvailable: Bool

    init() {
        let questionRepo = QuestionRepository.fromBundle()
        let settingsRepo = SettingsRepository()
        let speech = SystemSpeechEngine()
        let engine = StudyEngine(
            speech: speech,
            repo: questionRepo,
            settings: settingsRepo,
            scheduler: MainTaskScheduler(),
            onKnownChanged: { n, known in
                settingsRepo.update { s in
                    s.copy(known: known ? s.known.union([n]) : s.known.subtracting([n]))
                }
            }
        )
        self.questionRepo = questionRepo
        self.settingsRepo = settingsRepo
        self.engine = engine
        self.playback = PlaybackCoordinator(engine: engine)
        self.ttsAvailable = speech.isAvailable

        // Wires remote commands, now-playing info, and the audio session.
        playback.start()
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
    }
}
