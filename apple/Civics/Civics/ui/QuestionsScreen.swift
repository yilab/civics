import SwiftUI

struct QuestionsScreen: View {
    let questions: [Question]
    let known: Set<Int>
    let currentNumber: Int?
    /// The spoken language whose translation is shown alongside the English text.
    var language: SpeechLanguage = .english
    /// True when the translation takes visual precedence (UI language matches it).
    var translationPrimary: Bool = false
    let onJump: (Int) -> Void

    var body: some View {
        List {
            ForEach(questions, id: \.n) { q in
                Button {
                    onJump(q.n)
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
                        if known.contains(q.n) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.accentColor)
                                .accessibilityLabel(L10n.t("questions.known"))
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.plain)
    }
}
