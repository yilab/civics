package com.yilab.civics

import com.yilab.civics.data.OfficialsData
import com.yilab.civics.data.QuestionRepository
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/** Drives the generated officials.json through the same edge cases as the web
 * personalizer smoke test (web/src/officials.js), which it mirrors. */
class OfficialsDataTest {

    private val questions = QuestionRepository {
        File("src/main/assets/questions.json").readText()
    }.questions
    private val officials = OfficialsData(
        JSONObject(File("src/main/assets/officials.json").readText()),
    )

    private fun byN(list: List<com.yilab.civics.data.Question>, n: Int) = list.first { it.n == n }

    @Test
    fun `parses 56 places in picker order`() {
        assertEquals(56, officials.places.size)
        assertEquals("AL", officials.places.first().code)
        assertEquals("DC", officials.places[50].code)
        assertEquals(5, officials.places.count { it.kind == "territory" })
    }

    @Test
    fun `unset place keeps bank text and prompts via spoken text`() {
        val p = officials.personalize(questions, null, null, TODAY)
        val q23 = byN(p, 23)
        assertEquals("Depends on your state.", q23.answer)
        assertTrue(q23.spoken.contains("Choose your state in Settings"))
        assertTrue(q23.translations.getValue("zh-Hans").spoken.contains("设置"))
        // untouched questions pass through by reference
        assertTrue(byN(p, 1) === byN(questions, 1))
    }

    @Test
    fun `state fills senators governor and capital in every language`() {
        val p = officials.personalize(questions, "CA", null, TODAY)
        val q23 = byN(p, 23)
        assertTrue(q23.answer.startsWith("Either one: "))
        assertEquals(2, q23.answer.split(',').size) // two names
        assertEquals(q23.answer, q23.spoken)
        assertEquals("Gavin Newsom.", byN(p, 61).answer)
        assertEquals("Sacramento.", byN(p, 62).answer)
        assertNull(byN(p, 62).note)
        // names stay English in the translations; the sentence is localized
        val zh = q23.translations.getValue("zh-Hans")
        assertTrue(zh.answer.startsWith("两位中的任意一位"))
        assertTrue(zh.answer.contains("Alex Padilla"))
        assertTrue(q23.note!!.contains("California"))
    }

    @Test
    fun `multi-seat state without district prompts for Q29 only`() {
        val p = officials.personalize(questions, "CA", null, TODAY)
        val q29 = byN(p, 29)
        assertEquals("Depends on where you live.", q29.answer)
        assertTrue(q29.spoken.contains("congressional district"))
        assertEquals(setOf(29), officials.unresolvedStateQuestions("CA", null))
        assertEquals(emptySet<Int>(), officials.unresolvedStateQuestions("CA", 5))
        assertEquals(OfficialsData.STATE_QUESTIONS, officials.unresolvedStateQuestions(null, null))
        assertEquals(emptySet<Int>(), officials.unresolvedStateQuestions("WY", null))
    }

    @Test
    fun `district resolves the representative`() {
        val p = officials.personalize(questions, "CA", 12, TODAY)
        assertEquals("Lateefah Simon.", byN(p, 29).answer)
        assertTrue(byN(p, 29).note!!.contains("Verify"))
    }

    @Test
    fun `vacant seat says so instead of guessing a name`() {
        val p = officials.personalize(questions, "FL", 20, TODAY)
        assertTrue(byN(p, 29).answer.contains("vacant"))
        assertTrue(byN(p, 29).answer.contains("house.gov"))
    }

    @Test
    fun `district of columbia gets its own wording`() {
        val p = officials.personalize(questions, "DC", null, TODAY)
        assertEquals("There are no U.S. senators for District of Columbia.", byN(p, 23).answer)
        assertEquals("Eleanor Holmes Norton.", byN(p, 29).answer)
        assertEquals("D.C. does not have a governor.", byN(p, 61).answer)
        assertEquals("D.C. is not a state and does not have a capital.", byN(p, 62).answer)
    }

    @Test
    fun `territory names its delegate governor and capital`() {
        val p = officials.personalize(questions, "PR", null, TODAY)
        assertEquals("Pablo José Hernández.", byN(p, 29).answer)
        assertEquals("Jenniffer González-Colón.", byN(p, 61).answer)
        assertEquals("San Juan.", byN(p, 62).answer)
        assertTrue(byN(p, 23).translations.getValue("es").answer.contains("Puerto Rico"))
    }

    @Test
    fun `expired term keeps the name flagged as possibly out of date`() {
        // Alaska's governor has a staleness marker in December 2026; by January 2027
        // no successor is in the data, so the answer stays but carries the warning.
        val p = officials.personalize(questions, "AK", null, "2027-01-05")
        val answer = byN(p, 61).answer
        assertTrue(answer.startsWith("Mike Dunleavy."))
        assertTrue(answer.contains("out of date"))
    }

    @Test
    fun `future entries take over on their start date`() {
        val before = officials.personalize(questions, "OH", null, "2025-01-20")
        val after = officials.personalize(questions, "OH", null, "2025-01-21")
        assertFalse(byN(before, 23).answer.contains("Jon Husted"))
        assertTrue(byN(after, 23).answer.contains("Jon Husted"))
    }

    @Test
    fun `district options carry current member names`() {
        val options = officials.districtOptions("CA", TODAY)
        assertEquals(52, options.size)
        assertEquals(12 to "Lateefah Simon", options.first { it.first == 12 })
        assertTrue(officials.districtOptions("WY", TODAY).isEmpty())
    }

    companion object {
        private const val TODAY = "2026-09-26"
    }
}
