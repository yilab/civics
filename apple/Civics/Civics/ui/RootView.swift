import SwiftUI

enum AppDestination: Hashable {
    case listen, questions, settings

    var labelKey: String {
        switch self {
        case .listen: "tab.listen"
        case .questions: "tab.questions"
        case .settings: "tab.settings"
        }
    }

    var icon: String {
        switch self {
        case .listen: "headphones"
        case .questions: "list.bullet"
        case .settings: "gearshape"
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let zhPrimary = model.settingsRepo.settings.uiLanguage == .chinese
        TabView {
            Tab(L10n.t(AppDestination.listen.labelKey), systemImage: AppDestination.listen.icon) {
                // Transport is routed through the playback coordinator so on-screen
                // and AirPod presses behave identically.
                ListenScreen(
                    state: model.engine.state,
                    ttsAvailable: model.ttsAvailable,
                    zhPrimary: zhPrimary,
                    onPrimary: { model.playback.play() },
                    onPause: { model.playback.pause() },
                    onNext: { model.playback.next() },
                    onPrevious: { model.playback.previous() },
                    onToggleKnown: { model.engine.toggleKnown($0) }
                )
            }
            Tab(L10n.t(AppDestination.questions.labelKey), systemImage: AppDestination.questions.icon) {
                QuestionsScreen(
                    questions: model.questionRepo.questions,
                    known: model.engine.state.known,
                    currentNumber: model.engine.state.current?.n,
                    zhPrimary: zhPrimary,
                    onJump: { model.engine.jumpTo($0) }
                )
            }
            Tab(L10n.t(AppDestination.settings.labelKey), systemImage: AppDestination.settings.icon) {
                SettingsScreen(
                    settings: model.settingsRepo.settings,
                    onChange: { transform in model.settingsRepo.update(transform) }
                )
            }
        }
        // Rebuild the whole tree when the in-app language changes so every
        // string re-resolves against the new bundle.
        .id(model.settingsRepo.settings.uiLanguage)
    }
}
