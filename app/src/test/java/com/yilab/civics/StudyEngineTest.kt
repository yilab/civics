package com.yilab.civics

import com.yilab.civics.audio.Phase
import com.yilab.civics.audio.SpeechEngine
import com.yilab.civics.audio.StudyEngine
import com.yilab.civics.data.QuestionRepository
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
    val spoken = mutableListOf<Pair<String, String>>()
    var stopCount = 0

    override fun speak(utteranceId: String, text: String) {
        spoken += utteranceId to text
    }

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
}
