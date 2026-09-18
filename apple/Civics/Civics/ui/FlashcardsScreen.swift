import SwiftUI

/// The Flashcards tab: flip through a category-filtered deck, mark cards known,
/// reshuffle on demand. Filter, position, order, and flip are view-local like the
/// web tab (nothing persisted); the known set is the shared one from Listen/Questions.
struct FlashcardsScreen: View {
    let questions: [Question]
    let known: Set<Int>
    /// The spoken language whose translation is shown alongside the English text.
    var language: SpeechLanguage = .english
    /// True when the translation takes visual precedence over English.
    var translationPrimary: Bool = false
    let onToggleKnown: (Int) -> Void

    /// Category chip selection — view-local, defaults to All.
    @State private var filter: String = Categories.all
    @State private var deck: [Question]
    @State private var position: Int = 0
    @State private var flipped: Bool = false

    init(questions: [Question], known: Set<Int>, language: SpeechLanguage = .english,
         translationPrimary: Bool = false, onToggleKnown: @escaping (Int) -> Void) {
        self.questions = questions
        self.known = known
        self.language = language
        self.translationPrimary = translationPrimary
        self.onToggleKnown = onToggleKnown
        _deck = State(initialValue: questions)
    }

    private var current: Question? {
        deck.indices.contains(position) ? deck[position] : nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Changing the category rebuilds the deck back at the first card.
                FlowRow(spacing: 8) {
                    ForEach(Categories.values, id: \.self) { category in
                        Chip(
                            label: CategoriesL10n.name(category),
                            selected: filter == category,
                            action: {
                                filter = category
                                rebuildDeck(shuffle: false)
                            }
                        )
                    }
                }
                .padding(.bottom, 12)

                HStack {
                    Text(deck.isEmpty
                         ? L10n.t("listen.noQuestions")
                         : L10n.t("listen.questionOf", position + 1, deck.count))
                    Spacer()
                    Text(L10n.t("listen.knownCount", known.count))
                        .foregroundStyle(.secondary)
                }
                .font(.footnote.weight(.semibold))
                .padding(.bottom, 12)

                card
                    .padding(.bottom, 16)

                HStack(spacing: 10) {
                    navButton(systemImage: "chevron.left",
                              label: L10n.t("listen.previousQuestion"),
                              enabled: position > 0) {
                        position -= 1
                        flipped = false
                    }

                    knownButton

                    Button(action: { rebuildDeck(shuffle: true) }) {
                        Label(L10n.t("flashcards.shuffle"), systemImage: "shuffle")
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .buttonStyle(.bordered)
                    .disabled(deck.count < 2)

                    navButton(systemImage: "chevron.right",
                              label: L10n.t("button.nextQuestion"),
                              enabled: position < deck.count - 1) {
                        position += 1
                        flipped = false
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    // MARK: - Pieces

    /// Rebuilds the deck for the current filter and resets to the first card,
    /// unflipped. Shuffle is one-shot — it never touches the persisted setting.
    private func rebuildDeck(shuffle: Bool) {
        var filtered = filter == Categories.all ? questions : questions.filter { $0.category == filter }
        if shuffle { filtered.shuffle() }
        deck = filtered
        position = 0
        flipped = false
    }

    /// Both faces share one ZStack so the card keeps the taller face's height;
    /// the hidden face is faded out while the container rotates around Y.
    private var card: some View {
        ZStack {
            if let q = current {
                cardFace(q, front: true)
                    .opacity(flipped ? 0 : 1)
                    .accessibilityHidden(flipped)
                cardFace(q, front: false)
                    .opacity(flipped ? 1 : 0)
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                    .accessibilityHidden(!flipped)
            } else {
                Text(L10n.t("listen.noQuestions"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 280)
        .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
        .animation(.spring(duration: 0.4), value: flipped)
        .onTapGesture {
            if current != nil { flipped.toggle() }
        }
    }

    @ViewBuilder
    private func cardFace(_ q: Question, front: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
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

            if front {
                primaryText(q.question, q.translation(language)?.question)
                    .font(.title3.weight(.medium))
            } else {
                Text(L10n.t("listen.acceptableAnswer"))
                    .font(.caption2)
                    .foregroundStyle(.tint)
                    .padding(.bottom, 6)
                primaryText(q.answer, q.translation(language)?.answer)
                    .font(.title3.weight(.medium))
                let note = translationPrimary ? (q.translation(language)?.note ?? q.note) : q.note
                if let note {
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.top, 10)
                }
            }

            Spacer(minLength: 16)

            HStack {
                Spacer()
                Text(front ? L10n.t("flashcards.tapToReveal") : L10n.t("flashcards.tapForQuestion"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12))
    }

    /// Primary language in the emphasis style, the other as a muted secondary line.
    @ViewBuilder
    private func primaryText(_ english: String, _ translated: String?) -> some View {
        if translationPrimary, let translated {
            VStack(alignment: .leading, spacing: 8) {
                Text(translated)
                // No font override: the secondary line inherits the primary font.
                Text(english)
                    .foregroundStyle(.secondary)
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text(english)
                if let translated {
                    Text(translated)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    /// Large bordered previous/next chevron, like Listen's transport buttons.
    private func navButton(systemImage: String, label: String, enabled: Bool,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
        }
        .font(.title2)
        .buttonStyle(.bordered)
        .controlSize(.large)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    private var knownButton: some View {
        let q = current
        let isKnown = q.map { known.contains($0.n) } == true
        return Button {
            if let q { onToggleKnown(q.n) }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isKnown ? "checkmark.circle.fill" : "circle")
                Text(isKnown ? L10n.t("listen.known") : L10n.t("questions.mark"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .disabled(q == nil)
    }
}
