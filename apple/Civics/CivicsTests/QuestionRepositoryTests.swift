import Foundation
import Testing
@testable import Civics

struct QuestionRepositoryTests {

    private let repo = QuestionRepository.fromBundle()

    @Test func parsesAll128QuestionsNumbered1To128() {
        #expect(repo.questions.count == 128)
        #expect(repo.questions.map(\.n) == Array(1...128))
    }

    @Test func everyQuestionHasContentAndAValidCategory() {
        let valid = Set(Categories.values)
        for q in repo.questions {
            #expect(valid.contains(q.category), "bad category for Q\(q.n)")
            #expect(!q.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "blank question for Q\(q.n)")
            #expect(!q.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "blank answer for Q\(q.n)")
            #expect(!q.spoken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "blank spoken for Q\(q.n)")
            #expect(!q.spoken.contains("(") && !q.spoken.contains(")"), "spoken has parens for Q\(q.n)")
        }
    }

    @Test func dynamicQuestionsAreTheEightTimeSensitiveOnes() {
        let dynamic = repo.questions.filter(\.dynamic).map(\.n)
        #expect(dynamic == [23, 29, 30, 38, 39, 57, 61, 62])
        for n in dynamic {
            #expect(repo.byNumber(n)?.note != nil, "dynamic Q\(n) should carry a note")
        }
    }

    @Test func deckFiltersByCategoryAndShuffleKeepsTheSameItems() {
        #expect(repo.deck(category: Categories.all, shuffle: false).count == 128)
        #expect(repo.deck(category: "American Government", shuffle: false).count == 72)
        #expect(repo.deck(category: "American History", shuffle: false).count == 46)
        #expect(repo.deck(category: "Symbols & Holidays", shuffle: false).count == 10)

        let ordered = repo.deck(category: Categories.all, shuffle: false).map(\.n)
        let shuffled = repo.deck(category: Categories.all, shuffle: true).map(\.n)
        #expect(Set(ordered) == Set(shuffled))
        #expect(ordered != shuffled)
    }

    @Test func everyQuestionHasAChineseVersion() {
        for q in repo.questions {
            #expect(!(q.questionZh ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "blank questionZh for Q\(q.n)")
            #expect(!(q.answerZh ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "blank answerZh for Q\(q.n)")
            #expect(!(q.spokenZh ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "blank spokenZh for Q\(q.n)")
            // TTS-clean: no ASCII or full-width parentheses, like the English spoken field.
            let spoken = q.spokenZh ?? ""
            #expect(!spoken.contains("(") && !spoken.contains(")") && !spoken.contains("（") && !spoken.contains("）"),
                    "spokenZh has parens for Q\(q.n)")
            if q.dynamic {
                #expect(q.noteZh != nil, "dynamic Q\(q.n) should carry a noteZh")
            }
        }
    }
}
