package com.yilab.civics

import com.yilab.civics.data.Categories
import com.yilab.civics.data.QuestionRepository
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

        val ordered = repo.deck(Categories.ALL, shuffle = false).map { it.n }
        val shuffled = repo.deck(Categories.ALL, shuffle = true).map { it.n }
        assertEquals(ordered.toSet(), shuffled.toSet())
        assertNotEquals(ordered, shuffled)
    }
}
