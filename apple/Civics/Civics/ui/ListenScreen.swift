import SwiftUI

struct ListenScreen: View {
    let state: StudyState
    let ttsAvailable: Bool
    let onPrimary: () -> Void
    let onPause: () -> Void
    let onNext: () -> Void
    let onPrevious: () -> Void
    let onToggleKnown: (Int) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if !ttsAvailable {
                    Text(
                        "No text-to-speech voice is available. Enable a voice in Settings › Accessibility › "
                            + "Spoken Content › Voices to hear questions."
                    )
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
                    Text("\(state.known.count) known")
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
                    .accessibilityLabel("Previous question")

                    Button(action: onPause) {
                        Image(systemName: "stop.fill")
                    }
                    .accessibilityLabel("Stop")

                    Button(action: onNext) {
                        Image(systemName: "forward.end.fill")
                    }
                    .accessibilityLabel("Next question")

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
        state.deckSize > 0 ? "Question \(state.position + 1) of \(state.deckSize)" : "No questions"
    }

    private var progress: Double {
        state.deckSize == 0 ? 0 : Double(state.position + 1) / Double(state.deckSize)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let q = state.current {
                HStack(alignment: .firstTextBaseline) {
                    Text("Q\(q.n)")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.tint)
                    Spacer()
                    Text(q.category.uppercased())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 12)

                Text(q.question)
                    .font(.title3.weight(.medium))

                if state.answerRevealed {
                    Divider()
                        .padding(.vertical, 16)
                    Text("ACCEPTABLE ANSWER")
                        .font(.caption2)
                        .foregroundStyle(.tint)
                        .padding(.bottom, 6)
                    Text(q.answer)
                        .font(.title2)
                    if let note = q.note {
                        Text(note)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .padding(.top, 10)
                    }
                }
            } else {
                Text("Civics Audio Prep")
                    .font(.title2.weight(.semibold))
                    .padding(.bottom, 8)
                Text(
                    "Press Start, put your phone away, and answer each question out loud. "
                        + "On AirPods: one press to hear the answer or continue, two presses for the "
                        + "next question, three to repeat."
                )
                .font(.subheadline)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12))
    }

    private var phaseCaption: String {
        switch state.phase {
        case .idle: ""
        case .speakingQuestion: "Speaking the question — press to hear the answer"
        case .thinking: "Your turn — answer out loud, then press"
        case .speakingAnswer: "Speaking the answer"
        case .awaitingAdvance: "Press for the next question"
        }
    }

    private var primaryLabel: String {
        switch state.phase {
        case .idle: "Start listening"
        case .speakingQuestion, .thinking: "Hear the answer"
        case .speakingAnswer, .awaitingAdvance: "Next question"
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
                Text(isKnown ? "Known" : "Mark known")
            }
        }
        .buttonStyle(.bordered)
        .disabled(q == nil)
    }
}
