import SwiftUI

enum AppDestination: Hashable {
    case listen, questions, settings

    var label: String {
        switch self {
        case .listen: "Listen"
        case .questions: "Questions"
        case .settings: "Settings"
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
        TabView {
            Tab(AppDestination.listen.label, systemImage: AppDestination.listen.icon) {
                // Transport is routed through the playback coordinator so on-screen
                // and AirPod presses behave identically.
                ListenScreen(
                    state: model.engine.state,
                    ttsAvailable: model.ttsAvailable,
                    onPrimary: { model.playback.play() },
                    onPause: { model.playback.pause() },
                    onNext: { model.playback.next() },
                    onPrevious: { model.playback.previous() },
                    onToggleKnown: { model.engine.toggleKnown($0) }
                )
            }
            Tab(AppDestination.questions.label, systemImage: AppDestination.questions.icon) {
                QuestionsScreen(
                    questions: model.questionRepo.questions,
                    known: model.engine.state.known,
                    currentNumber: model.engine.state.current?.n,
                    onJump: { model.engine.jumpTo($0) }
                )
            }
            Tab(AppDestination.settings.label, systemImage: AppDestination.settings.icon) {
                SettingsScreen(
                    settings: model.settingsRepo.settings,
                    onChange: { transform in model.settingsRepo.update(transform) }
                )
            }
        }
    }
}
