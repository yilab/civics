import Foundation

/// Right/wrong history for one question, updated by every graded test answer.
struct QuestionStat: Equatable, Codable {
    var right: Int = 0
    var wrong: Int = 0
    /// Epoch milliseconds of the most recent wrong answer; 0 when the last answer was right.
    var lastWrongMillis: Int = 0
}

/// Encodes the per-question stats store and defines the missed-question rule.
enum QuestionStats {

    /// Missed = the last answer was wrong, or misses dominate the history.
    static func isMissed(_ stat: QuestionStat?) -> Bool {
        guard let stat else { return false }
        return stat.lastWrongMillis > 0 || (stat.wrong >= 2 && stat.wrong >= stat.right)
    }

    static func missed(_ stats: [Int: QuestionStat]) -> Set<Int> {
        Set(stats.filter { isMissed($0.value) }.keys)
    }

    /// Applies one graded answer, returning the updated map.
    static func record(_ stats: [Int: QuestionStat], _ n: Int, correct: Bool, now: Int) -> [Int: QuestionStat] {
        var stats = stats
        var s = stats[n] ?? QuestionStat()
        if correct {
            s.right += 1
            s.lastWrongMillis = 0
        } else {
            s.wrong += 1
            s.lastWrongMillis = now
        }
        stats[n] = s
        return stats
    }

    /// Drops the given questions' entries (their answers changed with the location).
    static func drop(_ stats: [Int: QuestionStat], _ ns: Set<Int>) -> [Int: QuestionStat] {
        stats.filter { !ns.contains($0.key) }
    }
}
