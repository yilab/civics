import Foundation

/// Pure deck-selection strategies for practice tests and review sessions.
/// Kept free of engine state so the sampling rules are unit-testable.
enum TestPicker {

    /// The standard test deck: a random 20, with up to half drawn from missed
    /// questions when `focus` is on. With nothing missed (or focus off) this is
    /// a plain uniform shuffle of the pool — the historical behavior.
    static func pickDeck(_ pool: [Question], _ stats: [Int: QuestionStat], focus: Bool) -> [Question] {
        guard focus else { return Array(pool.shuffled().prefix(StudyState.testTotal)) }
        let missedNumbers = Set(pool.map(\.n).filter { QuestionStats.isMissed(stats[$0]) })
        guard !missedNumbers.isEmpty else { return Array(pool.shuffled().prefix(StudyState.testTotal)) }
        let missedPool = pool.filter { missedNumbers.contains($0.n) }
        let restPool = pool.filter { !missedNumbers.contains($0.n) }
        let missedCount = min(StudyState.testTotal / 2, missedPool.count)
        let restCount = min(StudyState.testTotal - missedCount, restPool.count)
        return (Array(missedPool.shuffled().prefix(missedCount))
            + Array(restPool.shuffled().prefix(restCount))).shuffled()
    }

    /// Missed questions ranked for review: most misses first, ties by most
    /// recent miss. Deterministic — callers shuffle the cut they take.
    static func reviewRanking(_ pool: [Question], _ stats: [Int: QuestionStat]) -> [Question] {
        pool.filter { QuestionStats.isMissed(stats[$0.n]) }
            .sorted {
                let a = stats[$0.n] ?? QuestionStat()
                let b = stats[$1.n] ?? QuestionStat()
                return (b.wrong, b.lastWrongMillis) < (a.wrong, a.lastWrongMillis)
            }
    }

    /// Pass/fail marks scaled to the deck size, keeping the real interview's
    /// 60% bar: 20 questions -> 12/9. (n=2 -> 2/1: a single miss fails a pair.)
    static func thresholds(_ n: Int) -> (passAt: Int, failAt: Int) {
        let passAt = Int(ceil(Double(n) * 0.6))
        return (passAt, n - passAt + 1)
    }
}
