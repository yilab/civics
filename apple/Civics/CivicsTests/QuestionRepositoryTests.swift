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

    @Test func everyQuestionHasASimplifiedChineseTranslation() {
        for q in repo.questions {
            guard let t = q.translation(.chineseSimplified) else {
                Issue.record("missing zh-Hans translation for Q\(q.n)")
                continue
            }
            #expect(!t.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "blank zh-Hans question for Q\(q.n)")
            #expect(!t.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "blank zh-Hans answer for Q\(q.n)")
            #expect(!t.spoken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "blank zh-Hans spoken for Q\(q.n)")
            // TTS-clean: no ASCII or full-width parentheses, like the English spoken field.
            let spoken = t.spoken
            #expect(!spoken.contains("(") && !spoken.contains(")") && !spoken.contains("（") && !spoken.contains("）"),
                    "zh-Hans spoken has parens for Q\(q.n)")
            if q.dynamic {
                #expect(t.note != nil, "dynamic Q\(q.n) should carry a zh-Hans note")
            }
        }
    }

    @Test func translationsMapParsesMultipleLanguagesAndToleratesAbsentOnes() {
        let json = """
        {"questions":[
          {"n":1,"category":"American Government","question":"Q1?","answer":"A1","spoken":"A1 spoken","dynamic":false,"note":null,
           "translations":{"es":{"question":"¿P1?","answer":"R1","spoken":"R1 hablada"},
                           "zh-Hant":{"question":"題目一","answer":"答案一","spoken":"答案一","note":"附註一"}}},
          {"n":2,"category":"American History","question":"Q2?","answer":"A2","spoken":"A2 spoken"}
        ]}
        """
        let repo = QuestionRepository(jsonSource: { Data(json.utf8) })
        let q1 = repo.byNumber(1)
        #expect(q1?.translations.count == 2)
        #expect(q1?.translation(.spanish)?.question == "¿P1?")
        #expect(q1?.translation(.spanish)?.note == nil) // note is optional
        #expect(q1?.translation(.chineseTraditional)?.note == "附註一")
        #expect(q1?.translation(.chineseSimplified) == nil) // a language may be absent
        let q2 = repo.byNumber(2)
        #expect(q2?.translations.isEmpty == true)
        #expect(q2?.translation(.spanish) == nil)
        #expect(q2?.dynamic == false) // absent dynamic decodes as false
    }
}
