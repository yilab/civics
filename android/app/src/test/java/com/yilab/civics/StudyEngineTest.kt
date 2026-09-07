package com.yilab.civics

import com.yilab.civics.audio.Phase
import com.yilab.civics.audio.SpeechEngine
import com.yilab.civics.audio.SpeechLanguage
import com.yilab.civics.audio.StudyEngine
import com.yilab.civics.data.QuestionRepository
import com.yilab.civics.settings.SpeechMode
import com.yilab.civics.settings.StudySettings
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

private class FakeSpeechEngine : SpeechEngine {
    override var callback: SpeechEngine.Callback? = null
    override var speechRate: Float = 1f
    val spoken = mutableListOf<Triple<String, String, SpeechLanguage>>()
    var stopCount = 0

    override fun speak(utteranceId: String, text: String, language: SpeechLanguage) {
        spoken += Triple(utteranceId, text, language)
    }

    override fun isAvailable(language: SpeechLanguage) = true

    override fun stop() {
        stopCount++
    }

    override fun shutdown() {}

    /** Simulates the TTS finishing the most recent utterance. */
    fun finishLast() {
        callback?.onDone(spoken.last().first)
    }
}

@OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
class StudyEngineTest {

    private val repo = QuestionRepository { File("src/main/assets/questions.json").readText() }

    private fun TestScope.engine(
        settings: MutableStateFlow<StudySettings>,
        onKnownChanged: (Int, Boolean) -> Unit = { _, _ -> },
    ): Pair<StudyEngine, FakeSpeechEngine> {
        val speech = FakeSpeechEngine()
        // backgroundScope: the engine's settings-collection coroutine never completes by design
        val engine = StudyEngine(speech, repo, settings, backgroundScope, onKnownChanged)
        return engine to speech
    }

    @Test
    fun `starts idle with the full deck`() = runTest {
        val (engine) = engine(MutableStateFlow(StudySettings()))
        assertEquals(Phase.IDLE, engine.state.value.phase)
        assertEquals(128, engine.state.value.deckSize)
    }

    @Test
    fun `primary action speaks the first question with its number`() = runTest {
        val (engine, speech) = engine(MutableStateFlow(StudySettings()))
        engine.primaryAction()
        assertEquals(Phase.SPEAKING_QUESTION, engine.state.value.phase)
        assertEquals("q-1", speech.spoken.last().first)
        assertTrue(speech.spoken.last().second.startsWith("Question 1."))
        assertFalse(engine.state.value.answerRevealed)
    }

    @Test
    fun `waits for press, then speaks the TTS-cleaned answer`() = runTest {
        val (engine, speech) = engine(MutableStateFlow(StudySettings()))
        engine.primaryAction()
        speech.finishLast() // question finished
        assertEquals(Phase.THINKING, engine.state.value.phase)

        engine.primaryAction() // user press -> reveal
        assertEquals(Phase.SPEAKING_ANSWER, engine.state.value.phase)
        assertTrue(engine.state.value.answerRevealed)
        assertEquals("a-1", speech.spoken.last().first)

        speech.finishLast() // answer finished
        assertEquals(Phase.AWAITING_ADVANCE, engine.state.value.phase)

        engine.primaryAction() // user press -> next
        assertEquals(Phase.SPEAKING_QUESTION, engine.state.value.phase)
        assertEquals("q-2", speech.spoken.last().first)
        assertEquals(1, engine.state.value.position)
    }

    @Test
    fun `press during the question skips straight to the answer`() = runTest {
        val (engine, speech) = engine(MutableStateFlow(StudySettings()))
        engine.primaryAction()
        engine.primaryAction()
        assertEquals(Phase.SPEAKING_ANSWER, engine.state.value.phase)
        assertEquals("a-1", speech.spoken.last().first)
    }

    @Test
    fun `timed think pause reveals the answer automatically`() = runTest {
        val (engine, speech) = engine(MutableStateFlow(StudySettings(thinkSeconds = 5)))
        engine.primaryAction()
        speech.finishLast()
        assertEquals(Phase.THINKING, engine.state.value.phase)
        advanceTimeBy(5_000)
        runCurrent()
        assertEquals(Phase.SPEAKING_ANSWER, engine.state.value.phase)
        assertEquals("a-1", speech.spoken.last().first)
    }

    @Test
    fun `auto advance moves to the next question after the answer`() = runTest {
        val (engine, speech) =
            engine(MutableStateFlow(StudySettings(thinkSeconds = 0, autoAdvance = true)))
        engine.primaryAction()
        speech.finishLast() // question done -> think 0 -> answer immediately
        assertEquals(Phase.SPEAKING_ANSWER, engine.state.value.phase)
        speech.finishLast() // answer done
        assertEquals(Phase.AWAITING_ADVANCE, engine.state.value.phase)
        advanceTimeBy(StudyEngine.AUTO_ADVANCE_DELAY_MS)
        runCurrent()
        assertEquals("q-2", speech.spoken.last().first)
    }

    @Test
    fun `next wraps around the deck`() = runTest {
        val (engine, speech) = engine(MutableStateFlow(StudySettings()))
        engine.jumpTo(128)
        assertEquals("q-128", speech.spoken.last().first)
        engine.next()
        assertEquals("q-1", speech.spoken.last().first)
        assertEquals(0, engine.state.value.position)
    }

    @Test
    fun `previous repeats the question while the answer is playing, goes back otherwise`() = runTest {
        val (engine, speech) = engine(MutableStateFlow(StudySettings()))
        engine.primaryAction() // Q1
        engine.next() // Q2
        speech.finishLast() // Q2 question done -> thinking
        engine.primaryAction() // reveal answer
        assertEquals("a-2", speech.spoken.last().first)
        engine.previous() // repeat Q2
        assertEquals("q-2", speech.spoken.last().first)
        assertEquals(1, engine.state.value.position)
        engine.previous() // back to Q1
        assertEquals("q-1", speech.spoken.last().first)
    }

    @Test
    fun `pause silences speech and ignores stale utterance callbacks`() = runTest {
        val (engine, speech) = engine(MutableStateFlow(StudySettings()))
        engine.primaryAction()
        engine.pause()
        assertEquals(Phase.IDLE, engine.state.value.phase)
        assertEquals(1, speech.stopCount)
        speech.finishLast() // stale callback after pause
        assertEquals(Phase.IDLE, engine.state.value.phase)
    }

    @Test
    fun `jumping to a question outside the filtered deck uses the full deck`() = runTest {
        val settings = MutableStateFlow(StudySettings(category = "Symbols & Holidays"))
        val (engine, speech) = engine(settings)
        runCurrent()
        assertEquals(10, engine.state.value.deckSize)
        engine.jumpTo(5) // American Government question
        assertEquals("q-5", speech.spoken.last().first)
        assertEquals(128, engine.state.value.deckSize)
    }

    @Test
    fun `category change rebuilds the deck`() = runTest {
        val settings = MutableStateFlow(StudySettings())
        val (engine) = engine(settings)
        settings.value = settings.value.copy(category = "American History", shuffle = false)
        runCurrent()
        assertEquals(46, engine.state.value.deckSize)
        assertEquals(0, engine.state.value.position)
    }

    @Test
    fun `speech rate changes are applied to the speech engine`() = runTest {
        val settings = MutableStateFlow(StudySettings())
        val (_, speech) = engine(settings)
        settings.value = settings.value.copy(speechRate = 1.4f)
        runCurrent()
        assertEquals(1.4f, speech.speechRate)
    }

    @Test
    fun `toggle known reports through the callback`() = runTest {
        val events = mutableListOf<Pair<Int, Boolean>>()
        val settings = MutableStateFlow(StudySettings(known = setOf(3)))
        val (engine) = engine(settings, onKnownChanged = { n, known -> events += n to known })
        runCurrent()
        assertEquals(setOf(3), engine.state.value.known)
        engine.toggleKnown(3)
        engine.toggleKnown(7)
        assertEquals(listOf(3 to false, 7 to true), events)
    }

    @Test
    fun `a speech error stops the engine instead of cascading`() = runTest {
        val (engine, speech) = engine(MutableStateFlow(StudySettings(autoAdvance = true, thinkSeconds = 0)))
        engine.primaryAction()
        speech.callback?.onError("q-1")
        assertEquals(Phase.IDLE, engine.state.value.phase)
    }

    @Test
    fun `announce meta setting drops the question-number prefix`() = runTest {
        val (engine, speech) = engine(MutableStateFlow(StudySettings(announceMeta = false)))
        engine.primaryAction()
        assertEquals(repo.byNumber(1)?.question, speech.spoken.last().second)
    }

    // ------------------------------------------------------------- speech modes

    @Test
    fun `bilingual mode speaks english then chinese in each phase`() = runTest {
        val (engine, speech) = engine(MutableStateFlow(StudySettings(speechMode = SpeechMode.BILINGUAL)))
        engine.primaryAction()
        assertEquals("q-1", speech.spoken.last().first)
        speech.finishLast() // English question done -> Chinese question
        assertEquals(Phase.SPEAKING_QUESTION, engine.state.value.phase)
        assertEquals("zq-1", speech.spoken.last().first)
        assertEquals(SpeechLanguage.CHINESE, speech.spoken.last().third)
        assertTrue(speech.spoken.last().second.startsWith("第 1 题。"))
        speech.finishLast() // Chinese question done -> think pause
        assertEquals(Phase.THINKING, engine.state.value.phase)

        engine.primaryAction() // reveal
        assertEquals("a-1", speech.spoken.last().first)
        speech.finishLast() // English answer done -> Chinese answer
        assertEquals("za-1", speech.spoken.last().first)
        speech.finishLast() // Chinese answer done -> awaiting
        assertEquals(Phase.AWAITING_ADVANCE, engine.state.value.phase)

        engine.primaryAction() // next
        assertEquals("q-2", speech.spoken.last().first)
    }

    @Test
    fun `chinese mode speaks only chinese`() = runTest {
        val (engine, speech) = engine(MutableStateFlow(StudySettings(speechMode = SpeechMode.CHINESE)))
        engine.primaryAction()
        assertEquals("zq-1", speech.spoken.last().first)
        assertEquals(SpeechLanguage.CHINESE, speech.spoken.last().third)
        speech.finishLast()
        assertEquals(Phase.THINKING, engine.state.value.phase)
        engine.primaryAction()
        assertEquals("za-1", speech.spoken.last().first)
        assertEquals(repo.byNumber(1)?.spokenZh, speech.spoken.last().second)
        speech.finishLast()
        assertEquals(Phase.AWAITING_ADVANCE, engine.state.value.phase)
    }

    @Test
    fun `bilingual announce meta off drops the zh prefix`() = runTest {
        val (engine, speech) =
            engine(MutableStateFlow(StudySettings(announceMeta = false, speechMode = SpeechMode.BILINGUAL)))
        engine.primaryAction()
        speech.finishLast()
        assertEquals(repo.byNumber(1)?.questionZh, speech.spoken.last().second)
    }

    @Test
    fun `chinese mode without translation falls back to english`() = runTest {
        // A single-question repo without zh fields simulates untranslated data.
        val json = """{"questions":[{"n":1,"category":"American Government","question":"Q?","answer":"A","spoken":"A spoken","dynamic":false,"note":null}]}"""
        val single = QuestionRepository { json }
        val speech = FakeSpeechEngine()
        val engine = StudyEngine(speech, single, MutableStateFlow(StudySettings(speechMode = SpeechMode.CHINESE)), backgroundScope)
        engine.primaryAction()
        assertEquals("q-1", speech.spoken.last().first) // no questionZh -> English fallback
        assertEquals(SpeechLanguage.ENGLISH, speech.spoken.last().third)
    }
}
