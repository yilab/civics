package com.yilab.civics.settings

/** Right/wrong history for one question, updated by every graded test answer. */
data class QuestionStat(
    val right: Int = 0,
    val wrong: Int = 0,
    /** Epoch millis of the most recent wrong answer; 0 when the last answer was right. */
    val lastWrongMillis: Long = 0,
)

/** Encodes the per-question stats store and defines the missed-question rule. */
object QuestionStats {

    /** Missed = the last answer was wrong, or misses dominate the history. */
    fun isMissed(stat: QuestionStat?): Boolean =
        stat != null && (stat.lastWrongMillis > 0 || (stat.wrong >= 2 && stat.wrong >= stat.right))

    fun missed(stats: Map<Int, QuestionStat>): Set<Int> = stats.filterValues { isMissed(it) }.keys

    /** Applies one graded answer, returning the updated map. */
    fun record(stats: Map<Int, QuestionStat>, n: Int, correct: Boolean, now: Long): Map<Int, QuestionStat> {
        val s = stats[n] ?: QuestionStat()
        val updated = if (correct) {
            s.copy(right = s.right + 1, lastWrongMillis = 0)
        } else {
            s.copy(wrong = s.wrong + 1, lastWrongMillis = now)
        }
        return stats + (n to updated)
    }

    /** Drops the given questions' entries (their answers changed with the location). */
    fun drop(stats: Map<Int, QuestionStat>, ns: Set<Int>): Map<Int, QuestionStat> =
        stats - ns

    // Encoding mirrors TestRecord: compact CSV records joined by ';'.

    fun encode(stats: Map<Int, QuestionStat>): String =
        stats.entries.sortedBy { it.key }.joinToString(";") { (n, s) -> "$n:${s.right},${s.wrong},${s.lastWrongMillis}" }

    fun parse(raw: String?): Map<Int, QuestionStat> {
        if (raw.isNullOrBlank()) return emptyMap()
        val out = mutableMapOf<Int, QuestionStat>()
        for (record in raw.split(';')) {
            if (record.isBlank()) continue
            val head = record.split(':')
            if (head.size != 2) continue
            val n = head[0].toIntOrNull() ?: continue
            val f = head[1].split(',')
            if (f.size != 3) continue
            val right = f[0].toIntOrNull() ?: continue
            val wrong = f[1].toIntOrNull() ?: continue
            val lastWrongMillis = f[2].toLongOrNull() ?: continue
            out[n] = QuestionStat(right, wrong, lastWrongMillis)
        }
        return out
    }
}
