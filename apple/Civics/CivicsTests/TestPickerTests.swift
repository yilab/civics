import Foundation
import Testing
@testable import Civics

struct TestPickerTests {

    private func q(_ n: Int) -> Question {
        Question(n: n, category: "American Government", question: "Q\(n)?",
                 answer: "A\(n)", spoken: "A\(n) spoken", dynamic: false, note: nil)
    }

    private func pool(_ ns: [Int]) -> [Question] { ns.map(q) }

    private func missedStat(_ wrong: Int, _ lastWrong: Int) -> QuestionStat {
        QuestionStat(right: 0, wrong: wrong, lastWrongMillis: lastWrong)
    }

    // MARK: - Thresholds

    @Test func thresholdsKeepTheSixtyPercentBarAndMatchTheConstantsAtTwenty() {
        #expect(TestPicker.thresholds(20).passAt == StudyState.testPassAt)
        #expect(TestPicker.thresholds(20).failAt == StudyState.testFailAt)
        #expect(TestPicker.thresholds(20) == (passAt: 12, failAt: 9))
        #expect(TestPicker.thresholds(1) == (passAt: 1, failAt: 1))
        #expect(TestPicker.thresholds(3) == (passAt: 2, failAt: 2))
        #expect(TestPicker.thresholds(2) == (passAt: 2, failAt: 1))
        #expect(TestPicker.thresholds(10) == (passAt: 6, failAt: 5))
    }

    // MARK: - pickDeck

    @Test func pickDeckWithoutMissedQuestionsIsAPlainSampleOfThePool() {
        let pool = pool(Array(1...30))
        let deck = TestPicker.pickDeck(pool, [:], focus: true)
        #expect(deck.count == StudyState.testTotal)
        let allInPool = deck.allSatisfy { (1...30).contains($0.n) }
        #expect(allInPool)
        #expect(Set(deck.map(\.n)).count == deck.count) // no repeats
    }

    @Test func pickDeckWithFocusOffIgnoresTheMissedQuestions() {
        let pool = pool(Array(1...30))
        let stats = [1: missedStat(2, 10), 2: missedStat(1, 20)]
        let deck = TestPicker.pickDeck(pool, stats, focus: false)
        #expect(deck.count == StudyState.testTotal)
        // Uniform sampling: the missed pair may or may not appear — only the shape is guaranteed.
    }

    @Test func pickDeckPullsEveryMissedQuestionWhenFewAreMissed() {
        let pool = pool(Array(1...30))
        let stats = [1: missedStat(2, 10), 5: missedStat(1, 20), 9: missedStat(3, 30)]
        let deck = TestPicker.pickDeck(pool, stats, focus: true)
        #expect(deck.count == StudyState.testTotal)
        let allMissedPresent = [1, 5, 9].allSatisfy { n in deck.contains { $0.n == n } }
        #expect(allMissedPresent)
    }

    @Test func pickDeckCapsTheMissedSliceAtHalfTheDeck() {
        let pool = pool(Array(1...30))
        let stats = Dictionary(uniqueKeysWithValues: (1...15).map { ($0, missedStat(3, 10)) })
        let deck = TestPicker.pickDeck(pool, stats, focus: true)
        #expect(deck.count == StudyState.testTotal)
        #expect(deck.filter { (1...15).contains($0.n) }.count == 10)
        #expect(deck.filter { (16...30).contains($0.n) }.count == 10)
    }

    @Test func pickDeckOverASmallPoolReturnsTheWholePool() {
        let deck = TestPicker.pickDeck(pool([1, 2, 3]), [1: missedStat(1, 5)], focus: true)
        #expect(Set(deck.map(\.n)) == [1, 2, 3])
    }

    @Test func pickDeckOverAnEmptyPoolIsEmpty() {
        #expect(TestPicker.pickDeck([], [:], focus: true).isEmpty)
    }

    // MARK: - reviewRanking

    @Test func reviewRankingOrdersByMissesThenRecencyAndSkipsUnmissed() {
        let stats: [Int: QuestionStat] = [
            1: QuestionStat(right: 2, wrong: 1, lastWrongMillis: 500), // last wrong
            2: QuestionStat(right: 0, wrong: 3, lastWrongMillis: 100), // most misses
            3: QuestionStat(right: 5, wrong: 0, lastWrongMillis: 0),   // never missed
            4: QuestionStat(right: 0, wrong: 3, lastWrongMillis: 900), // ties Q2, more recent
            5: QuestionStat(right: 0, wrong: 2, lastWrongMillis: 0),   // dominates, oldest
        ]
        let ranked = TestPicker.reviewRanking(pool([1, 2, 3, 4, 5]), stats)
        #expect(ranked.map(\.n) == [4, 2, 5, 1])
    }

    @Test func reviewRankingIgnoresStatsForQuestionsOutsideThePool() {
        let ranked = TestPicker.reviewRanking(pool([1, 2]), [1: missedStat(1, 10), 99: missedStat(9, 99)])
        #expect(ranked.map(\.n) == [1])
    }

    @Test func reviewRankingWithNothingMissedIsEmpty() {
        #expect(TestPicker.reviewRanking(pool([1, 2, 3]), [:]).isEmpty)
    }

    // MARK: - TestRecord Codable compatibility

    @Test func legacyRecordsDecodeWithDefaults() throws {
        // The pre-review shape: no review/answers keys.
        let json = """
        [{"correct":12,"wrong":7,"passed":true,"date":700000000.0}]
        """.data(using: .utf8)!
        let records = try JSONDecoder().decode([TestRecord].self, from: json)
        #expect(records.count == 1)
        #expect(records[0].correct == 12)
        #expect(records[0].wrong == 7)
        #expect(records[0].passed)
        #expect(records[0].review == false)
        #expect(records[0].answers.isEmpty)
    }

    @Test func recordsRoundTripWithReviewFlagAndAnswers() throws {
        let record = TestRecord(
            correct: 6,
            wrong: 4,
            passed: false,
            date: Date(timeIntervalSince1970: 700000000),
            review: true,
            answers: [GradedAnswer(n: 3, correct: false), GradedAnswer(n: 9, correct: true)]
        )
        let data = try JSONEncoder().encode([record])
        let decoded = try JSONDecoder().decode([TestRecord].self, from: data)
        #expect(decoded == [record])
    }
}
