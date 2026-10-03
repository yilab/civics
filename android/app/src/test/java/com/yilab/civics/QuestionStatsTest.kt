package com.yilab.civics

import com.yilab.civics.settings.QuestionStat
import com.yilab.civics.settings.QuestionStats
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class QuestionStatsTest {

    @Test
    fun `null or blank raw parses to empty`() {
        assertEquals(emptyMap<Int, QuestionStat>(), QuestionStats.parse(null))
        assertEquals(emptyMap<Int, QuestionStat>(), QuestionStats.parse(""))
        assertEquals(emptyMap<Int, QuestionStat>(), QuestionStats.parse("  "))
    }

    @Test
    fun `encode and parse round-trip`() {
        val stats = mapOf(
            1 to QuestionStat(right = 3, wrong = 1, lastWrongMillis = 0),
            57 to QuestionStat(right = 0, wrong = 2, lastWrongMillis = 1_700_000_000_000),
        )
        assertEquals(stats, QuestionStats.parse(QuestionStats.encode(stats)))
    }

    @Test
    fun `malformed records are skipped without losing the rest`() {
        val parsed = QuestionStats.parse("1:2,0,0;junk;57:x,1,1;58:1,1;59:0,1,999")
        assertEquals(mapOf(1 to QuestionStat(2, 0, 0), 59 to QuestionStat(0, 1, 999)), parsed)
    }

    @Test
    fun `record increments the matching counter and timestamps only misses`() {
        val start = mapOf(7 to QuestionStat(right = 1, wrong = 1, lastWrongMillis = 0))
        val now = 1_700_000_000_000L
        val right = QuestionStats.record(start, 7, correct = true, now = now)
        assertEquals(QuestionStat(right = 2, wrong = 1, lastWrongMillis = 0), right[7])
        val wrong = QuestionStats.record(start, 7, correct = false, now = now)
        assertEquals(QuestionStat(right = 1, wrong = 2, lastWrongMillis = now), wrong[7])
    }

    @Test
    fun `record creates an entry for an unseen question`() {
        val stats = QuestionStats.record(emptyMap(), 12, correct = false, now = 5L)
        assertEquals(QuestionStat(right = 0, wrong = 1, lastWrongMillis = 5L), stats[12])
    }

    @Test
    fun `a right answer clears the last-wrong timestamp`() {
        val start = mapOf(3 to QuestionStat(right = 0, wrong = 3, lastWrongMillis = 99L))
        val stats = QuestionStats.record(start, 3, correct = true, now = 100L)
        assertEquals(0L, stats[3]?.lastWrongMillis)
    }

    @Test
    fun `isMissed matches the rule`() {
        // Never seen.
        assertFalse(QuestionStats.isMissed(null))
        // Last answer wrong.
        assertTrue(QuestionStats.isMissed(QuestionStat(right = 5, wrong = 1, lastWrongMillis = 1)))
        // Last answer right, misses dominate with at least two.
        assertTrue(QuestionStats.isMissed(QuestionStat(right = 0, wrong = 2, lastWrongMillis = 0)))
        // Last answer right, misses don't dominate.
        assertFalse(QuestionStats.isMissed(QuestionStat(right = 3, wrong = 2, lastWrongMillis = 0)))
        // A single miss righted later is not missed.
        assertFalse(QuestionStats.isMissed(QuestionStat(right = 1, wrong = 1, lastWrongMillis = 0)))
    }

    @Test
    fun `missed collects exactly the missed entries`() {
        val stats = mapOf(
            1 to QuestionStat(right = 1, wrong = 0, lastWrongMillis = 0),
            2 to QuestionStat(right = 0, wrong = 1, lastWrongMillis = 1),
            3 to QuestionStat(right = 0, wrong = 3, lastWrongMillis = 0),
            4 to QuestionStat(right = 5, wrong = 4, lastWrongMillis = 0),
        )
        assertEquals(setOf(2, 3), QuestionStats.missed(stats))
    }

    @Test
    fun `drop removes the given questions`() {
        val stats = mapOf(
            23 to QuestionStat(right = 1, wrong = 0, lastWrongMillis = 0),
            24 to QuestionStat(right = 0, wrong = 1, lastWrongMillis = 1),
        )
        val dropped = QuestionStats.drop(stats, setOf(23, 61))
        assertEquals(mapOf(24 to QuestionStat(0, 1, 1)), dropped)
    }
}
