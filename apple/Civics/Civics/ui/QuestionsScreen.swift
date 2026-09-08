import SwiftUI

struct QuestionsScreen: View {
    let questions: [Question]
    let known: Set<Int>
    let currentNumber: Int?
    /// The spoken language whose translation is shown alongside the English text.
    var language: SpeechLanguage = .english
    /// True when the translation takes visual precedence over English.
    var translationPrimary: Bool = false
    let onJump: (Int) -> Void
    let onToggleKnown: (Int) -> Void

    /// When on, only the questions marked known are listed, for review.
    @State private var showKnownOnly = false

    private var shown: [Question] {
        showKnownOnly ? questions.filter { known.contains($0.n) } : questions
    }

    var body: some View {
        VStack(spacing: 0) {
            Toggle(isOn: $showKnownOnly) {
                Text(L10n.t("questions.knownOnly"))
                    .font(.subheadline)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)

            List {
                ForEach(shown, id: \.n) { q in
                    let isKnown = known.contains(q.n)
                    Button {
                        onJump(q.n) // hear this question
                    } label: {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Q\(q.n) · \(CategoriesL10n.name(q.category))"
                                    + (q.n == currentNumber ? L10n.t("questions.playingSuffix") : ""))
                                    .font(.footnote)
                                    .foregroundStyle(q.n == currentNumber ? Color.accentColor : .secondary)
                                let translated = q.translation(language)?.question
                                if translationPrimary, let translated {
                                    Text(translated)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                        .multilineTextAlignment(.leading)
                                    Text(q.question)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.leading)
                                } else {
                                    Text(q.question)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                        .multilineTextAlignment(.leading)
                                    if let translated {
                                        Text(translated)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                            .multilineTextAlignment(.leading)
                                    }
                                }
                            }
                            Spacer(minLength: 8)
                            // Tap the check to unmark a known question (or mark one).
                            Button {
                                onToggleKnown(q.n)
                            } label: {
                                Image(systemName: isKnown ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(isKnown ? Color.accentColor : .secondary)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel(isKnown ? L10n.t("questions.unmark") : L10n.t("questions.mark"))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.plain)
        }
    }
}
