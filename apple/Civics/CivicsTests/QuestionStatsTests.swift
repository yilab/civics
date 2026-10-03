import Foundation
import Testing
@testable import Civics

struct QuestionStatsTests {

    @Test func recordIncrementsTheMatchingCounterAndTimestampsOnlyMisses() {
        let start = [7: QuestionStat(right: 1, wrong: 1, lastWrongMillis: 0)]
        let now = 1_700_000_000_000
        let right = QuestionStats.record(start, 7, correct: true, now: now)
        #expect(right[7] == QuestionStat(right: 2, wrong: 1, lastWrongMillis: 0))
        let wrong = QuestionStats.record(start, 7, correct: false, now: now)
        #expect(wrong[7] == QuestionStat(right: 1, wrong: 2, lastWrongMillis: now))
    }

    @Test func recordCreatesAnEntryForAnUnseenQuestion() {
        let stats = QuestionStats.record([:], 12, correct: false, now: 5)
        #expect(stats[12] == QuestionStat(right: 0, wrong: 1, lastWrongMillis: 5))
    }

    @Test func aRightAnswerClearsTheLastWrongTimestamp() {
        let start = [3: QuestionStat(right: 0, wrong: 3, lastWrongMillis: 99)]
        let stats = QuestionStats.record(start, 3, correct: true, now: 100)
        #expect(stats[3]?.lastWrongMillis == 0)
    }

    @Test func isMissedMatchesTheRule() {
        // Never seen.
        #expect(!QuestionStats.isMissed(nil))
        // Last answer wrong.
        #expect(QuestionStats.isMissed(QuestionStat(right: 5, wrong: 1, lastWrongMillis: 1)))
        // Last answer right, misses dominate with at least two.
        #expect(QuestionStats.isMissed(QuestionStat(right: 0, wrong: 2, lastWrongMillis: 0)))
        // Last answer right, misses don't dominate.
        #expect(!QuestionStats.isMissed(QuestionStat(right: 3, wrong: 2, lastWrongMillis: 0)))
        // A single miss righted later is not missed.
        #expect(!QuestionStats.isMissed(QuestionStat(right: 1, wrong: 1, lastWrongMillis: 0)))
    }

    @Test func missedCollectsExactlyTheMissedEntries() {
        let stats: [Int: QuestionStat] = [
            1: QuestionStat(right: 1, wrong: 0, lastWrongMillis: 0),
            2: QuestionStat(right: 0, wrong: 1, lastWrongMillis: 1),
            3: QuestionStat(right: 0, wrong: 3, lastWrongMillis: 0),
            4: QuestionStat(right: 5, wrong: 4, lastWrongMillis: 0),
        ]
        #expect(QuestionStats.missed(stats) == [2, 3])
    }

    @Test func dropRemovesTheGivenQuestions() {
        let stats: [Int: QuestionStat] = [
            23: QuestionStat(right: 1, wrong: 0, lastWrongMillis: 0),
            24: QuestionStat(right: 0, wrong: 1, lastWrongMillis: 1),
        ]
        let dropped = QuestionStats.drop(stats, [23, 61])
        #expect(dropped.count == 1)
        #expect(dropped[24] == QuestionStat(right: 0, wrong: 1, lastWrongMillis: 1))
    }

    @Test func statsRoundTripThroughJSON() throws {
        let stats: [Int: QuestionStat] = [
            1: QuestionStat(right: 3, wrong: 1, lastWrongMillis: 0),
            57: QuestionStat(right: 0, wrong: 2, lastWrongMillis: 1_700_000_000_000),
        ]
        let data = try JSONEncoder().encode(stats)
        let decoded = try JSONDecoder().decode([Int: QuestionStat].self, from: data)
        #expect(decoded == stats)
    }
}
