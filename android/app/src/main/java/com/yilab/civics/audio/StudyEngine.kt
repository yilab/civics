package com.yilab.civics.audio

import com.yilab.civics.data.Categories
import com.yilab.civics.data.Question
import com.yilab.civics.data.QuestionRepository
import com.yilab.civics.data.SpeechLanguage
import com.yilab.civics.settings.StudySettings
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

enum class Phase {
    IDLE, SPEAKING_QUESTION, THINKING, SPEAKING_ANSWER, AWAITING_ADVANCE,
    /** Test mode: answer revealed, waiting for a got-it/missed-it grade. */
    AWAITING_GRADE,
    /** Test mode: pass (12 correct) or fail (9 wrong) reached. */
    FINISHED,
}

/** What the engine is doing: free-form study, or a scored practice test. */
enum class EngineMode { STUDY, TEST }

/** The outcome of a finished practice test. */
enum class TestOutcome { NONE, PASSED, FAILED }

/** One recorded practice test, kept for history. */
data class TestRecord(
    val correct: Int,
    val wrong: Int,
    val passed: Boolean,
    val epochMillis: Long,
) {
    fun encode(): String = "$correct,$wrong,${if (passed) 1 else 0},$epochMillis"

    companion object {
        fun parse(s: String): TestRecord? {
            val p = s.split(',')
            if (p.size != 4) return null
            return TestRecord(
                correct = p[0].toIntOrNull() ?: return null,
                wrong = p[1].toIntOrNull() ?: return null,
                passed = p[2] == "1",
                epochMillis = p[3].toLongOrNull() ?: return null,
            )
        }
    }
}

data class StudyState(
    val phase: Phase = Phase.IDLE,
    val deck: List<Question> = emptyList(),
    val position: Int = 0,
    val current: Question? = null,
    val answerRevealed: Boolean = false,
    val known: Set<Int> = emptySet(),
    // Practice-test fields; inert in study mode.
    val mode: EngineMode = EngineMode.STUDY,
    val testIndex: Int = 0,
    val testCorrect: Int = 0,
    val testWrong: Int = 0,
    val testOutcome: TestOutcome = TestOutcome.NONE,
) {
    val deckSize: Int get() = deck.size
    val playing: Boolean get() = phase != Phase.IDLE

    companion object {
        const val TEST_TOTAL = 20
        const val TEST_PASS_AT = 12
        const val TEST_FAIL_AT = 9
    }
}

/**
 * Drives the hands-free study loop: speak question -> think pause -> speak answer -> next.
 * All public methods must be called on the main thread (or the test scope thread).
 */
class StudyEngine(
    private val speech: SpeechEngine,
    private val repo: QuestionRepository,
    private val settingsFlow: StateFlow<StudySettings>,
    private val scope: CoroutineScope,
    private val onKnownChanged: (Int, Boolean) -> Unit = { _, _ -> },
    private val onTestFinished: (TestRecord) -> Unit = {},
) {

    private val _state = MutableStateFlow(StudyState())
    val state: StateFlow<StudyState> = _state.asStateFlow()

    private var deck: List<Question> = emptyList()
    private var timerJob: Job? = null
    private var expectedUtterance: String? = null

    init {
        speech.callback = object : SpeechEngine.Callback {
            override fun onDone(utteranceId: String) = onUtteranceDone(utteranceId)
            override fun onError(utteranceId: String) = onUtteranceError(utteranceId)
        }
        scope.launch {
            settingsFlow.collect { applySettings(it) }
        }
        applySettings(settingsFlow.value)
    }

    // ------------------------------------------------------------------ actions

    /** The single AirPod press: meaning depends on the current phase. */
    fun primaryAction() {
        when (state.value.phase) {
            Phase.IDLE -> startDeck()
            Phase.SPEAKING_QUESTION -> revealAnswer()
            Phase.THINKING -> revealAnswer()
            Phase.SPEAKING_ANSWER -> next()
            Phase.AWAITING_ADVANCE -> next()
            Phase.AWAITING_GRADE -> grade(correct = true)
            Phase.FINISHED -> Unit
        }
    }

    fun pause() {
        cancelTimer()
        expectedUtterance = null
        speech.stop()
        emit(state.value.copy(phase = Phase.IDLE))
    }

    /** Starts a scored practice test: 20 random questions, pass at 12, fail at 9. */
    fun startTest() {
        cancelTimer()
        expectedUtterance = null
        speech.stop()
        deck = repo.questions.shuffled().take(StudyState.TEST_TOTAL)
        emit(
            state.value.copy(
                deck = deck,
                position = 0,
                mode = EngineMode.TEST,
                testIndex = 0,
                testCorrect = 0,
                testWrong = 0,
                testOutcome = TestOutcome.NONE,
            )
        )
        speakQuestionAt(0)
    }

    /** Records the user's self-grade for the current test question. */
    fun grade(correct: Boolean) {
        if (state.value.phase != Phase.AWAITING_GRADE) return
        val q = state.value.current ?: return
        val correctNow = state.value.testCorrect + if (correct) 1 else 0
        val wrongNow = state.value.testWrong + if (correct) 0 else 1
        // Mistakes resurface in study mode: a wrong answer unmarks a known question.
        if (!correct && q.n in state.value.known) {
            onKnownChanged(q.n, false)
        }
        when {
            correctNow >= StudyState.TEST_PASS_AT -> finishTest(true, correctNow, wrongNow)
            wrongNow >= StudyState.TEST_FAIL_AT -> finishTest(false, correctNow, wrongNow)
            state.value.testIndex + 1 >= deck.size ->
                finishTest(correctNow >= StudyState.TEST_PASS_AT, correctNow, wrongNow)
            else -> {
                emit(
                    state.value.copy(
                        testIndex = state.value.testIndex + 1,
                        testCorrect = correctNow,
                        testWrong = wrongNow,
                    )
                )
                speakQuestionAt(state.value.testIndex)
            }
        }
    }

    /** Returns to free-form study, discarding any unfinished test. */
    fun startStudy() {
        cancelTimer()
        expectedUtterance = null
        speech.stop()
        deck = repo.deck(
            settingsFlow.value.category,
            settingsFlow.value.shuffle,
            settingsFlow.value.knownFilter,
            settingsFlow.value.known,
        )
        emit(
            state.value.copy(
                phase = Phase.IDLE,
                deck = deck,
                position = 0,
                mode = EngineMode.STUDY,
                testOutcome = TestOutcome.NONE,
            )
        )
    }

    private fun finishTest(passed: Boolean, correct: Int, wrong: Int) {
        cancelTimer()
        val record = TestRecord(correct, wrong, passed, System.currentTimeMillis())
        emit(
            state.value.copy(
                phase = Phase.FINISHED,
                answerRevealed = true,
                testCorrect = correct,
                testWrong = wrong,
                testOutcome = if (passed) TestOutcome.PASSED else TestOutcome.FAILED,
            )
        )
        speech.stop()
        onTestFinished(record)
    }

    fun next() {
        if (state.value.mode == EngineMode.TEST) return // no skipping during a test
        if (deck.isEmpty()) return
        val pos = (state.value.position + 1) % deck.size
        speakQuestionAt(pos)
    }

    /** Music-player style: while hearing the answer, repeat this question; otherwise go back one. */
    fun previous() {
        if (state.value.mode == EngineMode.TEST) return // no skipping during a test
        if (deck.isEmpty()) return
        when (state.value.phase) {
            Phase.SPEAKING_ANSWER, Phase.AWAITING_ADVANCE -> speakQuestionAt(state.value.position)
            else -> {
                val pos = (state.value.position - 1 + deck.size) % deck.size
                speakQuestionAt(pos)
            }
        }
    }

    fun jumpTo(questionNumber: Int) {
        var idx = deck.indexOfFirst { it.n == questionNumber }
        if (idx < 0) {
            deck = repo.deck(Categories.ALL, shuffle = false)
            emit(state.value.copy(deck = deck))
            idx = deck.indexOfFirst { it.n == questionNumber }
        }
        if (idx >= 0) speakQuestionAt(idx)
    }

    fun toggleKnown(n: Int) {
        val known = state.value.known
        onKnownChanged(n, n !in known)
    }

    // ------------------------------------------------------------- state machine

    private fun startDeck() {
        if (deck.isEmpty()) return
        val pos = state.value.position.coerceIn(0, deck.size - 1)
        speakQuestionAt(pos)
    }

    private fun speakQuestionAt(position: Int) {
        cancelTimer()
        val q = deck[position]
        val settings = settingsFlow.value
        val lang = settings.spokenLanguage
        // english/bilingual start with the English question; a single non-English
        // language goes straight to the translation (falling back to English when
        // no translation exists).
        if (!settings.bilingual && lang != SpeechLanguage.ENGLISH && q.translation(lang) != null) {
            speak("zq-${q.n}", translationQuestionText(q, lang), lang)
        } else {
            val text = buildString {
                if (settings.announceMeta) append("Question ${q.n}. ")
                append(q.question)
            }
            speak("q-${q.n}", text, SpeechLanguage.ENGLISH)
        }
        emit(
            state.value.copy(
                phase = Phase.SPEAKING_QUESTION,
                position = position,
                current = q,
                answerRevealed = false,
            )
        )
    }

    private fun revealAnswer() {
        cancelTimer()
        val q = state.value.current ?: return
        val settings = settingsFlow.value
        val lang = settings.spokenLanguage
        val translation = q.translation(lang)
        if (!settings.bilingual && lang != SpeechLanguage.ENGLISH && translation != null) {
            speak("za-${q.n}", translation.spoken, lang)
        } else {
            speak("a-${q.n}", q.spoken, SpeechLanguage.ENGLISH)
        }
        emit(state.value.copy(phase = Phase.SPEAKING_ANSWER, answerRevealed = true))
    }

    /** After the answer is spoken: study mode awaits advance; test mode awaits a grade. */
    private fun afterAnswerSpoken() {
        if (state.value.mode == EngineMode.TEST) {
            emit(state.value.copy(phase = Phase.AWAITING_GRADE))
        } else {
            beginAwaitingAdvance()
        }
    }

    private fun onUtteranceDone(utteranceId: String) {
        if (utteranceId != expectedUtterance) return
        val settings = settingsFlow.value
        val lang = settings.spokenLanguage
        // z-prefixed ids must be checked before their English counterparts.
        when {
            utteranceId.startsWith("zq-") -> beginThinkPause()
            utteranceId.startsWith("za-") -> afterAnswerSpoken()
            utteranceId.startsWith("q-") -> {
                val q = state.value.current
                if (settings.bilingual && q?.translation(lang) != null) {
                    speak("zq-${q.n}", translationQuestionText(q, lang), lang)
                } else {
                    beginThinkPause()
                }
            }
            utteranceId.startsWith("a-") -> {
                val q = state.value.current
                val t = q?.translation(lang)
                if (settings.bilingual && q != null && t != null) {
                    speak("za-${q.n}", t.spoken, lang)
                } else {
                    afterAnswerSpoken()
                }
            }
        }
    }

    private fun translationQuestionText(q: Question, language: SpeechLanguage): String {
        val t = q.translation(language) ?: return q.question
        return if (settingsFlow.value.announceMeta) "${language.questionPrefix(q.n)} ${t.question}" else t.question
    }

    private fun onUtteranceError(utteranceId: String) {
        if (utteranceId != expectedUtterance) return
        // A flaky speech failure must not stall the deck: skip the utterance,
        // advancing exactly as if it had been spoken to completion. Intentional
        // stops (pause/skip) never reach here — they clear expectedUtterance first.
        onUtteranceDone(utteranceId)
    }

    private fun beginThinkPause() {
        val think = settingsFlow.value.thinkSeconds
        when {
            think == 0 -> revealAnswer()
            think > 0 -> {
                emit(state.value.copy(phase = Phase.THINKING))
                timerJob = scope.launch {
                    delay(think * 1000L)
                    revealAnswer()
                }
            }
            else -> emit(state.value.copy(phase = Phase.THINKING)) // wait for press
        }
    }

    private fun beginAwaitingAdvance() {
        emit(state.value.copy(phase = Phase.AWAITING_ADVANCE))
        if (settingsFlow.value.autoAdvance) {
            timerJob = scope.launch {
                delay(AUTO_ADVANCE_DELAY_MS)
                next()
            }
        }
    }

    // ------------------------------------------------------------------ settings

    private fun applySettings(s: StudySettings) {
        speech.speechRate = s.speechRate
        val newDeck = repo.deck(s.category, s.shuffle, s.knownFilter, s.known)
        if (deck.map { it.n } != newDeck.map { it.n }) {
            deck = newDeck
            val pos = state.value.current?.let { c -> deck.indexOfFirst { it.n == c.n } }
                ?.takeIf { it >= 0 } ?: 0
            emit(state.value.copy(deck = deck, position = pos))
        }
        if (state.value.known != s.known) {
            emit(state.value.copy(known = s.known))
        }
    }

    // ------------------------------------------------------------------ helpers

    private fun speak(utteranceId: String, text: String, language: SpeechLanguage) {
        expectedUtterance = utteranceId
        speech.speak(utteranceId, text, language)
    }

    private fun cancelTimer() {
        timerJob?.cancel()
        timerJob = null
    }

    private fun emit(s: StudyState) {
        _state.value = s
    }

    companion object {
        const val AUTO_ADVANCE_DELAY_MS = 2_000L
    }
}
