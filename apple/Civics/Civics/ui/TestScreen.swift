import SwiftUI

struct TestScreen: View {
    let state: StudyState
    let history: [TestRecord]
    /// The spoken language whose translation is shown alongside the English text.
    var language: SpeechLanguage = .english
    /// True when the translation takes visual precedence (UI language matches it).
    var translationPrimary: Bool = false
    let onStart: () -> Void
    let onReveal: () -> Void
    let onGrade: (Bool) -> Void
    let onBackToStudy: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch state.phase {
                case .finished: finished
                case .idle: start
                default: running
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    // MARK: - Start

    private var start: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.t("test.title"))
                .font(.title2.weight(.semibold))
            VStack(alignment: .leading, spacing: 8) {
                Text("• " + L10n.t("test.rules1"))
                Text("• " + L10n.t("test.rules2"))
                Text("• " + L10n.t("test.rules3"))
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Button(action: onStart) {
                Text(L10n.t("test.start"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 24)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("startTest")

            if !history.isEmpty {
                Text(L10n.t("test.history").uppercased())
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.tint)
                    .padding(.top, 8)
                ForEach(history.prefix(5).indices, id: \.self) { i in
                    let r = history[i]
                    HStack {
                        Image(systemName: r.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(r.passed ? .green : .red)
                        Text(L10n.t("test.score", r.correct, r.correct + r.wrong))
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(r.date, style: .date)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Running

    private var running: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(L10n.t("test.progress", state.testIndex + 1, StudyState.testTotal))
                Spacer()
                Label("\(state.testCorrect)", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Label("\(state.testWrong)", systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }
            .font(.footnote.weight(.semibold))

            ProgressView(value: Double(state.testIndex) / Double(StudyState.testTotal))
                .padding(.vertical, 8)

            card
                .padding(.vertical, 12)

            Text(caption)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 16)

            if state.phase == .awaitingGrade {
                HStack(spacing: 12) {
                    Button { onGrade(false) } label: {
                        Label(L10n.t("button.missedIt"), systemImage: "xmark")
                            .frame(maxWidth: .infinity).frame(height: 24)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .accessibilityIdentifier("gradeMissed")
                    Button { onGrade(true) } label: {
                        Label(L10n.t("button.gotIt"), systemImage: "checkmark")
                            .frame(maxWidth: .infinity).frame(height: 24)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .accessibilityIdentifier("gradeCorrect")
                }
                .controlSize(.large)
            } else {
                Button(action: onReveal) {
                    Text(revealLabel)
                        .frame(maxWidth: .infinity)
                        .frame(height: 24)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("revealAnswer")
            }
        }
    }

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

                bilingualText(q.question, q.translation(language)?.question, block: .question)
                    .font(.title3.weight(.medium))

                if state.answerRevealed {
                    Divider().padding(.vertical, 16)
                    Text(L10n.t("listen.acceptableAnswer"))
                        .font(.caption2)
                        .foregroundStyle(.tint)
                        .padding(.bottom, 6)
                    bilingualText(q.answer, q.translation(language)?.answer, block: .answer)
                        .font(.title2)
                    let note = translationPrimary ? (q.translation(language)?.note ?? q.note) : q.note
                    if let note {
                        Text(note)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .padding(.top, 10)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func bilingualText(_ english: String, _ translated: String?, block: SpokenHighlight.Block) -> some View {
        if translationPrimary, let translated {
            VStack(alignment: .leading, spacing: 8) {
                karaokeLine(translated, block: block, isTranslation: true)
                karaokeLine(english, block: block, isTranslation: false)
                    .foregroundStyle(.secondary)
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                karaokeLine(english, block: block, isTranslation: false)
                if let translated {
                    karaokeLine(translated, block: block, isTranslation: true)
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

    private var caption: String {
        switch state.phase {
        case .speakingQuestion: L10n.t("phase.speakingQuestion")
        case .thinking: L10n.t("phase.thinking")
        case .speakingAnswer: L10n.t("phase.speakingAnswer")
        case .awaitingGrade: L10n.t("phase.awaitingGrade")
        default: ""
        }
    }

    private var revealLabel: String {
        L10n.t("button.hearAnswer")
    }

    // MARK: - Finished

    private var finished: some View {
        let passed = state.testOutcome == .passed
        return VStack(spacing: 16) {
            Text(passed ? L10n.t("test.passed") : L10n.t("test.failed"))
                .font(.title.weight(.bold))
                .foregroundStyle(passed ? .green : .red)
                .padding(.top, 24)
            Text(L10n.t("test.score", state.testCorrect, state.testCorrect + state.testWrong))
                .font(.system(size: 48, weight: .semibold, design: .rounded))
            Text(passed ? L10n.t("test.verdictPass") : L10n.t("test.verdictFail"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(action: onStart) {
                Text(L10n.t("test.again")).frame(maxWidth: .infinity).frame(height: 24)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Button(action: onBackToStudy) {
                Text(L10n.t("test.backToStudy")).frame(maxWidth: .infinity).frame(height: 24)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity)
    }
}
