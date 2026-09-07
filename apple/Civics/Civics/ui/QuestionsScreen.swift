import SwiftUI

struct QuestionsScreen: View {
    let questions: [Question]
    let known: Set<Int>
    let currentNumber: Int?
    let onJump: (Int) -> Void

    var body: some View {
        List {
            ForEach(questions, id: \.n) { q in
                Button {
                    onJump(q.n)
                } label: {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Q\(q.n) · \(q.category)" + (q.n == currentNumber ? " · playing" : ""))
                                .font(.footnote)
                                .foregroundStyle(q.n == currentNumber ? Color.accentColor : .secondary)
                            Text(q.question)
                                .font(.body)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 8)
                        if known.contains(q.n) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.accentColor)
                                .accessibilityLabel("Known")
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.plain)
    }
}
