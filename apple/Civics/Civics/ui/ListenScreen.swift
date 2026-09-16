import SwiftUI

struct ListenScreen: View {
    let state: StudyState
    let ttsAvailable: Bool
    /// The spoken language whose translation is shown alongside the English text.
    var language: SpeechLanguage = .english
    /// True when the translation takes visual precedence (UI language matches it).
    var translationPrimary: Bool = false
    /// Which questions the study deck includes by known status.
    var knownFilter: KnownFilter = .all
    let onPrimary: () -> Void
    let onPause: () -> Void
    let onNext: () -> Void
    let onPrevious: () -> Void
    let onToggleKnown: (Int) -> Void
    let onFilterChange: (KnownFilter) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if !ttsAvailable {
                    Text(L10n.t("listen.noTts"))
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12))
                        .padding(.bottom, 16)
                }

                HStack {
                    Text(headerText)
                    Spacer()
                    Text(L10n.t("listen.knownCount", state.known.count))
                        .foregroundStyle(.secondary)
                }
                .font(.footnote.weight(.semibold))

                ProgressView(value: progress)
                    .padding(.vertical, 8)

                // Which questions to listen to: all, only known, only not known.
                HStack(spacing: 8) {
                    ForEach(KnownFilter.allCases, id: \.self) { filter in
                        Chip(
                            label: filterLabel(filter),
                            selected: knownFilter == filter,
                            action: { onFilterChange(filter) }
                        )
                    }
                }
                .padding(.bottom, 4)

                card
                    .padding(.vertical, 12)

                Text(phaseCaption)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 16)

                Button(action: onPrimary) {
                    Text(primaryLabel)
                        .frame(maxWidth: .infinity)
                        .frame(height: 24)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("primaryAction")

                HStack(spacing: 12) {
                    transportButton(action: onPrevious, systemImage: "backward.end.fill",
                                    label: L10n.t("listen.previousQuestion"))
                    transportButton(action: onPause, systemImage: "stop.fill",
                                    label: L10n.t("listen.stop"))
                    transportButton(action: onNext, systemImage: "forward.end.fill",
                                    label: L10n.t("button.nextQuestion"))

                    Spacer()

                    knownButton
                }
                .padding(.top, 12)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    // MARK: - Pieces

    private var headerText: String {
        state.deckSize > 0
            ? L10n.t("listen.questionOf", state.position + 1, state.deckSize)
            : L10n.t("listen.noQuestions")
    }

    private var progress: Double {
        state.deckSize == 0 ? 0 : Double(state.position + 1) / Double(state.deckSize)
    }

    /// Both languages are always shown; emphasis follows the UI language.
    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let q = state.current {
                HStack(alignment: .firstTextBaseline) {
                    Text("Q\(q.n)")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.tint)
                    Spacer()
                    Text(CategoriesL10n.name(q.category).uppercased())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 12)

                primaryText(q.question, q.translation(language)?.question, block: .question)
                    .font(.title3.weight(.medium))

                if state.answerRevealed {
                    Divider()
                        .padding(.vertical, 16)
                    Text(L10n.t("listen.acceptableAnswer"))
                        .font(.caption2)
                        .foregroundStyle(.tint)
                        .padding(.bottom, 6)
                    primaryText(q.answer, q.translation(language)?.answer, block: .answer)
                        .font(.title2)
                    let note = translationPrimary ? (q.translation(language)?.note ?? q.note) : q.note
                    if let note {
                        Text(note)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .padding(.top, 10)
                    }
                }
            } else {
                Text(L10n.t("listen.appTitle"))
                    .font(.title2.weight(.semibold))
                    .padding(.bottom, 8)
                Text(L10n.t("listen.onboarding"))
                    .font(.subheadline)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12))
    }

    /// Primary language in the emphasis style, the other as a muted secondary line.
    @ViewBuilder
    private func primaryText(_ english: String, _ translated: String?, block: SpokenHighlight.Block) -> some View {
        if translationPrimary, let translated {
            VStack(alignment: .leading, spacing: 8) {
                karaokeLine(translated, block: block, isTranslation: true)
                karaokeLine(english, block: block, isTranslation: false)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                karaokeLine(english, block: block, isTranslation: false)
                if let translated {
                    karaokeLine(translated, block: block, isTranslation: true)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    /// One text line, karaoke-highlighted while it is the line being spoken.
    private func karaokeLine(_ display: String, block: SpokenHighlight.Block, isTranslation: Bool) -> Text {
        let speaking = state.phase == .speakingQuestion || state.phase == .speakingAnswer
        return KaraokeText.text(display: display, highlight: state.highlight, block: block,
                                isTranslation: isTranslation, speaking: speaking)
    }

    private var phaseCaption: String {
        switch state.phase {
        case .idle: ""
        case .speakingQuestion: L10n.t("phase.speakingQuestion")
        case .thinking: L10n.t("phase.thinking")
        case .speakingAnswer: L10n.t("phase.speakingAnswer")
        case .awaitingAdvance: L10n.t("phase.awaitingAdvance")
        case .awaitingGrade: L10n.t("phase.awaitingGrade")
        case .finished: ""
        }
    }

    private var primaryLabel: String {
        switch state.phase {
        case .idle: L10n.t("button.start")
        case .speakingQuestion, .thinking: L10n.t("button.hearAnswer")
        case .speakingAnswer, .awaitingAdvance: L10n.t("button.nextQuestion")
        case .awaitingGrade: L10n.t("button.gotIt")
        case .finished: L10n.t("button.start")
        }
    }

    private func filterLabel(_ filter: KnownFilter) -> String {
        switch filter {
        case .all: L10n.t("filter.all")
        case .known: L10n.t("filter.known")
        case .notKnown: L10n.t("filter.notKnown")
        }
    }

    /// Large bordered transport button for previous/stop/next.
    private func transportButton(action: @escaping () -> Void, systemImage: String, label: String) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
        }
        .font(.title2)
        .buttonStyle(.bordered)
        .controlSize(.large)
        .accessibilityLabel(label)
    }

    private var knownButton: some View {
        let q = state.current
        let isKnown = q.map { state.known.contains($0.n) } == true
        return Button {
            if let q { onToggleKnown(q.n) }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isKnown ? "star.fill" : "star")
                Text(isKnown ? L10n.t("listen.known") : L10n.t("listen.markKnown"))
            }
        }
        .buttonStyle(.bordered)
        .disabled(q == nil)
    }
}
