import SwiftUI

struct QuestionsScreen: View {
    let questions: [Question]
    let known: Set<Int>
    let currentNumber: Int?
    /// True when Chinese text takes visual precedence (UI language = 中文).
    var zhPrimary: Bool = false
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
                            if zhPrimary, let qZh = q.questionZh {
                                Text(qZh)
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
                                if let qZh = q.questionZh {
                                    Text(qZh)
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
