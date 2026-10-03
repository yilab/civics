import SwiftUI

struct QuestionsScreen: View {
    let questions: [Question]
    let known: Set<Int>
    /// Right/wrong history per question, for the miss badges.
    var stats: [Int: QuestionStat] = [:]
    let currentNumber: Int?
    /// The spoken language whose translation is shown alongside the English text.
    var language: SpeechLanguage = .english
    /// True when the translation takes visual precedence over English.
    var translationPrimary: Bool = false
    let onJump: (Int) -> Void
    let onToggleKnown: (Int) -> Void

    /// View-local filter over the list: all / only known / only not known.
    @State private var filter: KnownFilter = .all
    /// View-local search text, applied on top of `filter`.
    @State private var query = ""

    private var shown: [Question] {
        let filtered: [Question] = switch filter {
        case .all: questions
        case .known: questions.filter { known.contains($0.n) }
        case .notKnown: questions.filter { !known.contains($0.n) }
        }
        guard !query.isEmpty else { return filtered }
        return filtered.filter { $0.matches(query: query, categoryName: CategoriesL10n.name($0.category)) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(L10n.t("questions.search"), text: $query)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.t("questions.search"))
                }
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.15)))
            .padding(.horizontal, 20)
            .padding(.top, 8)

            HStack(spacing: 8) {
                ForEach(KnownFilter.allCases, id: \.self) { f in
                    Chip(label: filterLabel(f), selected: filter == f, action: { filter = f })
                }
                Spacer()
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
                                        .font(.body)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.leading)
                                } else {
                                    Text(q.question)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                        .multilineTextAlignment(.leading)
                                    if let translated {
                                        Text(translated)
                                            .font(.body)
                                            .foregroundStyle(.secondary)
                                            .multilineTextAlignment(.leading)
                                    }
                                }
                            }
                            Spacer(minLength: 8)
                            // How many times this question was missed in tests, when any.
                            if let stat = stats[q.n], stat.wrong > 0 {
                                Text("×\(stat.wrong)")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.red)
                                    .accessibilityLabel(L10n.t("questions.missedTimes", stat.wrong))
                            }
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

    private func filterLabel(_ filter: KnownFilter) -> String {
        switch filter {
        case .all: L10n.t("filter.all")
        case .known: L10n.t("filter.known")
        case .notKnown: L10n.t("filter.notKnown")
        }
    }
}
