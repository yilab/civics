import SwiftUI

struct ListenScreen: View {
    let state: StudyState
    let ttsAvailable: Bool
    /// The spoken language whose translation is shown alongside the English text.
    var language: SpeechLanguage = .english
    /// True when the translation takes visual precedence (UI language matches it).
    var translationPrimary: Bool = false
    let onPrimary: () -> Void
    let onPause: () -> Void
    let onNext: () -> Void
    let onPrevious: () -> Void
    let onToggleKnown: (Int) -> Void

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

                HStack(spacing: 8) {
                    Button(action: onPrevious) {
                        Image(systemName: "backward.end.fill")
                    }
                    .accessibilityLabel(L10n.t("listen.previousQuestion"))

                    Button(action: onPause) {
                        Image(systemName: "stop.fill")
                    }
                    .accessibilityLabel(L10n.t("listen.stop"))

                    Button(action: onNext) {
                        Image(systemName: "forward.end.fill")
                    }
                    .accessibilityLabel(L10n.t("button.nextQuestion"))

                    Spacer()

                    knownButton
                }
                .buttonStyle(.borderless)
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

                primaryText(q.question, q.translation(language)?.question)
                    .font(.title3.weight(.medium))

                if state.answerRevealed {
                    Divider()
                        .padding(.vertical, 16)
                    Text(L10n.t("listen.acceptableAnswer"))
                        .font(.caption2)
                        .foregroundStyle(.tint)
                        .padding(.bottom, 6)
                    primaryText(q.answer, q.translation(language)?.answer)
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
    private func primaryText(_ english: String, _ translated: String?) -> some View {
        if translationPrimary, let translated {
            VStack(alignment: .leading, spacing: 8) {
                Text(translated)
                Text(english)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text(english)
                if let translated {
                    Text(translated)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
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
