import SwiftUI

enum AppDestination: Hashable {
    case listen, flashcards, questions, test, settings

    var labelKey: String {
        switch self {
        case .listen: "tab.listen"
        case .flashcards: "tab.flashcards"
        case .questions: "tab.questions"
        case .test: "tab.test"
        case .settings: "tab.settings"
        }
    }

    var icon: String {
        switch self {
        case .listen: "headphones"
        case .flashcards: "rectangle.portrait.on.rectangle.portrait"
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
                    knownFilter: model.settingsRepo.settings.knownFilter,
                    onPrimary: { model.playback.play() },
                    onPause: { model.playback.pause() },
                    onNext: { model.playback.next() },
                    onPrevious: { model.playback.previous() },
                    onToggleKnown: { model.engine.toggleKnown($0) },
                    onFilterChange: { filter in model.settingsRepo.update { $0.copy(knownFilter: filter) } }
                )
            }
            Tab(L10n.t(AppDestination.flashcards.labelKey), systemImage: AppDestination.flashcards.icon, value: .flashcards) {
                // Deck state is view-local; only the shared known set persists.
                FlashcardsScreen(
                    questions: model.questionRepo.questions,
                    known: model.engine.state.known,
                    language: spoken,
                    translationPrimary: translationPrimary,
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
        // Persistent brand mark in the upper left. The .bar background keeps the
        // logo legible over scrolling content without navigation-bar chrome.
        .safeAreaInset(edge: .top, spacing: 0) {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(height: 25)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 16)
                .padding(.vertical, 7)
                .opacity(0.9)
                .accessibilityHidden(true)
                .background(.bar)
        }
        // Rebuild the whole tree when the in-app language changes so every
        // string re-resolves against the new bundle. Selection is preserved.
        .id(model.settingsRepo.settings.language)
    }
}
