package com.yilab.civics

import com.yilab.civics.audio.StudyState
import com.yilab.civics.audio.TestPicker
import com.yilab.civics.data.Question
import com.yilab.civics.settings.QuestionStat
import kotlin.random.Random
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class TestPickerTest {

    private fun q(n: Int) = Question(n, "American Government", "Q$n?", "A$n", "A$n spoken", dynamic = false, note = null)

    private fun pool(vararg ns: Int) = ns.map(::q)

    private fun missedStat(wrong: Int, lastWrong: Long) =
        QuestionStat(right = 0, wrong = wrong, lastWrongMillis = lastWrong)

    // ------------------------------------------------------------------ thresholds

    @Test
    fun `thresholds keep the sixty percent bar and match the constants at twenty`() {
        assertEquals(StudyState.TEST_PASS_AT to StudyState.TEST_FAIL_AT, TestPicker.thresholds(20))
        assertEquals(12 to 9, TestPicker.thresholds(20))
        assertEquals(1 to 1, TestPicker.thresholds(1))
        assertEquals(2 to 2, TestPicker.thresholds(3))
        assertEquals(2 to 1, TestPicker.thresholds(2))
        assertEquals(6 to 5, TestPicker.thresholds(10))
    }

    // -------------------------------------------------------------------- pickDeck

    @Test
    fun `pickDeck without missed questions is a plain sample of the pool`() {
        val pool = pool(*(1..30).toList().toIntArray())
        val deck = TestPicker.pickDeck(pool, emptyMap(), focus = true, random = Random(42))
        assertEquals(StudyState.TEST_TOTAL, deck.size)
        assertTrue(deck.all { q -> q.n in 1..30 })
        assertEquals(deck.size, deck.map { it.n }.toSet().size) // no repeats
    }

    @Test
    fun `pickDeck with focus off ignores the missed questions`() {
        val pool = pool(*(1..30).toList().toIntArray())
        val stats = mapOf(1 to missedStat(2, 10), 2 to missedStat(1, 20))
        val deck = TestPicker.pickDeck(pool, stats, focus = false, random = Random(7))
        assertEquals(StudyState.TEST_TOTAL, deck.size)
        // Uniform sampling: the missed pair may or may not appear — only the shape is guaranteed.
    }

    @Test
    fun `pickDeck pulls every missed question when few are missed`() {
        val pool = pool(*(1..30).toList().toIntArray())
        val stats = mapOf(1 to missedStat(2, 10), 5 to missedStat(1, 20), 9 to missedStat(3, 30))
        val deck = TestPicker.pickDeck(pool, stats, focus = true, random = Random(3))
        assertEquals(StudyState.TEST_TOTAL, deck.size)
        assertTrue(listOf(1, 5, 9).all { it in deck.map { q -> q.n } })
    }

    @Test
    fun `pickDeck caps the missed slice at half the deck`() {
        val pool = pool(*(1..30).toList().toIntArray())
        val stats = (1..15).associateWith { missedStat(3, 10) }
        val deck = TestPicker.pickDeck(pool, stats, focus = true, random = Random(5))
        assertEquals(StudyState.TEST_TOTAL, deck.size)
        val missedInDeck = deck.count { it.n in 1..15 }
        val restInDeck = deck.count { it.n in 16..30 }
        assertEquals(10, missedInDeck)
        assertEquals(10, restInDeck)
    }

    @Test
    fun `pickDeck over a small pool returns the whole pool`() {
        val pool = pool(1, 2, 3)
        val deck = TestPicker.pickDeck(pool, mapOf(1 to missedStat(1, 5)), focus = true, random = Random(1))
        assertEquals(3, deck.size)
        assertEquals(setOf(1, 2, 3), deck.map { it.n }.toSet())
    }

    @Test
    fun `pickDeck over an empty pool is empty`() {
        assertTrue(TestPicker.pickDeck(emptyList(), emptyMap(), focus = true).isEmpty())
    }

    // ---------------------------------------------------------------- reviewRanking

    @Test
    fun `reviewRanking orders by misses then recency and skips unmissed`() {
        val pool = pool(1, 2, 3, 4, 5)
        val stats = mapOf(
            1 to QuestionStat(right = 2, wrong = 1, lastWrongMillis = 500), // last wrong
            2 to QuestionStat(right = 0, wrong = 3, lastWrongMillis = 100), // most misses
            3 to QuestionStat(right = 5, wrong = 0, lastWrongMillis = 0),   // never missed
            4 to QuestionStat(right = 0, wrong = 3, lastWrongMillis = 900), // ties Q2, more recent
            5 to QuestionStat(right = 0, wrong = 2, lastWrongMillis = 0),   // dominates, oldest
        )
        val ranked = TestPicker.reviewRanking(pool, stats)
        assertEquals(listOf(4, 2, 5, 1), ranked.map { it.n })
    }

    @Test
    fun `reviewRanking ignores stats for questions outside the pool`() {
        val pool = pool(1, 2)
        val stats = mapOf(1 to missedStat(1, 10), 99 to missedStat(9, 99))
        val ranked = TestPicker.reviewRanking(pool, stats)
        assertEquals(listOf(1), ranked.map { it.n })
    }

    @Test
    fun `reviewRanking with nothing missed is empty`() {
        assertTrue(TestPicker.reviewRanking(pool(1, 2, 3), emptyMap()).isEmpty())
    }

    // ------------------------------------------------------------------ TestRecord

    @Test
    fun `legacy four-field records parse with defaults`() {
        val r = com.yilab.civics.audio.TestRecord.parse("12,7,1,1690000000000")!!
        assertEquals(12, r.correct)
        assertEquals(7, r.wrong)
        assertEquals(true, r.passed)
        assertEquals(1_690_000_000_000L, r.epochMillis)
        assertEquals(false, r.review)
        assertTrue(r.answers.isEmpty())
    }

    @Test
    fun `records round-trip with review flag and answers`() {
        val r = com.yilab.civics.audio.TestRecord(
            correct = 6,
            wrong = 4,
            passed = false,
            epochMillis = 1_690_000_000_000L,
            review = true,
            answers = listOf(
                com.yilab.civics.audio.GradedAnswer(3, correct = false),
                com.yilab.civics.audio.GradedAnswer(9, correct = true),
            ),
        )
        assertEquals(r, com.yilab.civics.audio.TestRecord.parse(r.encode()))
    }

    @Test
    fun `records with no answers round-trip`() {
        val r = com.yilab.civics.audio.TestRecord(12, 0, true, 1_690_000_000_000L)
        assertEquals(r, com.yilab.civics.audio.TestRecord.parse(r.encode()))
    }

    @Test
    fun `malformed records parse to null`() {
        assertNull(com.yilab.civics.audio.TestRecord.parse("1,2"))
        assertNull(com.yilab.civics.audio.TestRecord.parse("a,b,c,d"))
        assertNull(com.yilab.civics.audio.TestRecord.parse("1,2,0,notanumber"))
    }
}
