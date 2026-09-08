import SwiftUI

enum AppDestination: Hashable {
    case listen, questions, test, settings

    var labelKey: String {
        switch self {
        case .listen: "tab.listen"
        case .questions: "tab.questions"
        case .test: "tab.test"
        case .settings: "tab.settings"
        }
    }

    var icon: String {
        switch self {
        case .listen: "headphones"
        case .questions: "list.bullet"
        case .test: "checkmark.circle"
        case .settings: "gearshape"
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @State private var selected: AppDestination = .listen

    var body: some View {
        let settings = model.settingsRepo.settings
        let spoken = settings.spokenLanguage
        // The translation takes visual precedence when a non-English language is chosen.
        let translationPrimary = settings.translationPrimary
        TabView(selection: $selected) {
            Tab(L10n.t(AppDestination.listen.labelKey), systemImage: AppDestination.listen.icon, value: .listen) {
                // Transport is routed through the playback coordinator so on-screen
                // and AirPod presses behave identically.
                ListenScreen(
                    state: model.engine.state,
                    ttsAvailable: model.ttsAvailable,
                    language: spoken,
                    translationPrimary: translationPrimary,
                    onPrimary: { model.playback.play() },
                    onPause: { model.playback.pause() },
                    onNext: { model.playback.next() },
                    onPrevious: { model.playback.previous() },
                    onToggleKnown: { model.engine.toggleKnown($0) }
                )
            }
            Tab(L10n.t(AppDestination.questions.labelKey), systemImage: AppDestination.questions.icon, value: .questions) {
                QuestionsScreen(
                    questions: model.questionRepo.questions,
                    known: model.engine.state.known,
                    currentNumber: model.engine.state.current?.n,
                    language: spoken,
                    translationPrimary: translationPrimary,
                    onJump: { model.engine.jumpTo($0) },
                    onToggleKnown: { model.engine.toggleKnown($0) }
                )
            }
            Tab(L10n.t(AppDestination.test.labelKey), systemImage: AppDestination.test.icon, value: .test) {
                TestScreen(
                    state: model.engine.state,
                    history: model.settingsRepo.testHistory,
                    language: spoken,
                    translationPrimary: translationPrimary,
                    onStart: { model.engine.startTest() },
                    onReveal: { model.playback.play() },
                    onGrade: { model.engine.grade(correct: $0) },
                    onBackToStudy: { model.engine.startStudy() }
                )
            }
            Tab(L10n.t(AppDestination.settings.labelKey), systemImage: AppDestination.settings.icon, value: .settings) {
                SettingsScreen(
                    settings: model.settingsRepo.settings,
                    onChange: { transform in model.settingsRepo.update(transform) }
                )
            }
        }
        // Rebuild the whole tree when the in-app language changes so every
        // string re-resolves against the new bundle. Selection is preserved.
        .id(model.settingsRepo.settings.language)
    }
}
