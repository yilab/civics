package com.yilab.civics

import com.yilab.civics.data.Categories
import com.yilab.civics.data.KnownFilter
import com.yilab.civics.data.QuestionRepository
import com.yilab.civics.data.SpeechLanguage
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class QuestionRepositoryTest {

    private val repo = QuestionRepository {
        File("src/main/assets/questions.json").readText()
    }

    @Test
    fun `parses all 128 questions numbered 1 to 128`() {
        assertEquals(128, repo.questions.size)
        assertEquals((1..128).toList(), repo.questions.map { it.n })
    }

    @Test
    fun `every question has content and a valid category`() {
        val valid = Categories.values.toSet()
        repo.questions.forEach { q ->
            assertTrue("bad category for Q${q.n}", q.category in valid)
            assertTrue("blank question for Q${q.n}", q.question.isNotBlank())
            assertTrue("blank answer for Q${q.n}", q.answer.isNotBlank())
            assertTrue("blank spoken for Q${q.n}", q.spoken.isNotBlank())
            assertTrue("spoken has parens for Q${q.n}", !q.spoken.contains('(') && !q.spoken.contains(')'))
        }
    }

    @Test
    fun `dynamic questions are the eight time-sensitive ones`() {
        val dynamic = repo.questions.filter { it.dynamic }.map { it.n }
        assertEquals(listOf(23, 29, 30, 38, 39, 57, 61, 62), dynamic)
        dynamic.forEach { n ->
            assertTrue("dynamic Q$n should carry a note", repo.byNumber(n)?.note != null)
        }
    }

    @Test
    fun `deck filters by category and shuffle keeps the same items`() {
        assertEquals(128, repo.deck(Categories.ALL, shuffle = false).size)
        assertEquals(72, repo.deck("American Government", shuffle = false).size)
        assertEquals(46, repo.deck("American History", shuffle = false).size)
        assertEquals(10, repo.deck("Symbols & Holidays", shuffle = false).size)
        // The virtual category collects the eight dynamic questions.
        assertEquals(
            listOf(23, 29, 30, 38, 39, 57, 61, 62),
            repo.deck(Categories.VARIES, shuffle = false).map { it.n },
        )

        val ordered = repo.deck(Categories.ALL, shuffle = false).map { it.n }
        val shuffled = repo.deck(Categories.ALL, shuffle = true).map { it.n }
        assertEquals(ordered.toSet(), shuffled.toSet())
        assertNotEquals(ordered, shuffled)
    }

    @Test
    fun `deck filters by known status`() {
        val known = setOf(1, 2, 3)
        assertEquals(listOf(1, 2, 3), repo.deck(Categories.ALL, shuffle = false, knownFilter = KnownFilter.KNOWN, known = known).map { it.n })
        val notKnown = repo.deck(Categories.ALL, shuffle = false, knownFilter = KnownFilter.NOT_KNOWN, known = known)
        assertEquals(125, notKnown.size)
        assertTrue(notKnown.all { it.n !in known })
    }

    @Test
    fun `every question has a simplified chinese translation`() {
        repo.questions.forEach { q ->
            val t = q.translation(SpeechLanguage.CHINESE_SIMPLIFIED)
            assertTrue("missing zh-Hans translation for Q${q.n}", t != null)
            t ?: return@forEach
            assertTrue("blank zh-Hans question for Q${q.n}", t.question.isNotBlank())
            assertTrue("blank zh-Hans answer for Q${q.n}", t.answer.isNotBlank())
            assertTrue("blank zh-Hans spoken for Q${q.n}", t.spoken.isNotBlank())
            // TTS-clean: no ASCII or full-width parentheses, like the English spoken field.
            val spoken = t.spoken
            assertTrue(
                "zh-Hans spoken has parens for Q${q.n}",
                '(' !in spoken && ')' !in spoken && '（' !in spoken && '）' !in spoken,
            )
            if (q.dynamic) assertTrue("dynamic Q${q.n} should carry a zh-Hans note", t.note != null)
        }
    }

    @Test
    fun `translations map parses multiple languages and tolerates absent ones`() {
        val json = """{"questions":[
            {"n":1,"category":"American Government","question":"Q1?","answer":"A1","spoken":"A1 spoken","dynamic":false,"note":null,
             "translations":{"es":{"question":"¿P1?","answer":"R1","spoken":"R1 hablada"},
                             "zh-Hant":{"question":"題目一","answer":"答案一","spoken":"答案一","note":"附註一"}}},
            {"n":2,"category":"American History","question":"Q2?","answer":"A2","spoken":"A2 spoken"}
        ]}"""
        val repo = QuestionRepository { json }
        val q1 = repo.byNumber(1)!!
        assertEquals(2, q1.translations.size)
        assertEquals("¿P1?", q1.translation(SpeechLanguage.SPANISH)?.question)
        assertEquals(null, q1.translation(SpeechLanguage.SPANISH)?.note) // note is optional
        assertEquals("附註一", q1.translation(SpeechLanguage.CHINESE_TRADITIONAL)?.note)
        assertEquals(null, q1.translation(SpeechLanguage.CHINESE_SIMPLIFIED)) // a language may be absent
        val q2 = repo.byNumber(2)!!
        assertTrue(q2.translations.isEmpty())
        assertEquals(null, q2.translation(SpeechLanguage.SPANISH))
        assertEquals(false, q2.dynamic) // absent dynamic decodes as false
    }
}
