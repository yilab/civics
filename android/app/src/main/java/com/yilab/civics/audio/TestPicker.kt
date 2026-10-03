package com.yilab.civics.audio

import com.yilab.civics.data.Question
import com.yilab.civics.settings.QuestionStat
import com.yilab.civics.settings.QuestionStats
import kotlin.math.ceil
import kotlin.random.Random

/**
 * Pure deck-selection strategies for practice tests and review sessions.
 * Kept free of engine state so the sampling rules are unit-testable.
 */
object TestPicker {

    /**
     * The standard test deck: a random 20, with up to half drawn from missed
     * questions when [focus] is on. With nothing missed (or focus off) this is
     * a plain uniform shuffle of the pool — the historical behavior.
     */
    fun pickDeck(
        pool: List<Question>,
        stats: Map<Int, QuestionStat>,
        focus: Boolean,
        random: Random = Random.Default,
    ): List<Question> {
        if (!focus) return pool.shuffled(random).take(StudyState.TEST_TOTAL)
        val missedNumbers = pool.map { it.n }.filter { QuestionStats.isMissed(stats[it]) }.toSet()
        if (missedNumbers.isEmpty()) return pool.shuffled(random).take(StudyState.TEST_TOTAL)
        val missedPool = pool.filter { it.n in missedNumbers }
        val restPool = pool.filter { it.n !in missedNumbers }
        val missedCount = minOf(StudyState.TEST_TOTAL / 2, missedPool.size)
        val restCount = minOf(StudyState.TEST_TOTAL - missedCount, restPool.size)
        return (missedPool.shuffled(random).take(missedCount) +
            restPool.shuffled(random).take(restCount))
            .shuffled(random)
    }

    /** Missed questions ranked for review: most misses first, ties by most recent miss.
     * Deterministic — callers shuffle the cut they take. */
    fun reviewRanking(pool: List<Question>, stats: Map<Int, QuestionStat>): List<Question> =
        pool.filter { QuestionStats.isMissed(stats[it.n]) }
            .sortedWith(
                compareByDescending<Question> { stats[it.n]?.wrong ?: 0 }
                    .thenByDescending { stats[it.n]?.lastWrongMillis ?: 0 }
            )

    /**
     * Pass/fail marks scaled to the deck size, keeping the real interview's 60%
     * bar: 20 questions -> 12/9. (n=2 -> 2/1: a single miss fails a pair.)
     */
    fun thresholds(n: Int): Pair<Int, Int> {
        val passAt = ceil(n * 0.6).toInt()
        return passAt to (n - passAt + 1)
    }
}
