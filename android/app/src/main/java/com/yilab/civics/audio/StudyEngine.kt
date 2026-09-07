package com.yilab.civics.audio

import com.yilab.civics.data.Categories
import com.yilab.civics.data.Question
import com.yilab.civics.data.QuestionRepository
import com.yilab.civics.settings.SpeechMode
import com.yilab.civics.settings.StudySettings
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

enum class Phase { IDLE, SPEAKING_QUESTION, THINKING, SPEAKING_ANSWER, AWAITING_ADVANCE }

data class StudyState(
    val phase: Phase = Phase.IDLE,
    val deck: List<Question> = emptyList(),
    val position: Int = 0,
    val current: Question? = null,
    val answerRevealed: Boolean = false,
    val known: Set<Int> = emptySet(),
) {
    val deckSize: Int get() = deck.size
    val playing: Boolean get() = phase != Phase.IDLE
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
        }
    }

    fun pause() {
        cancelTimer()
        expectedUtterance = null
        speech.stop()
        emit(state.value.copy(phase = Phase.IDLE))
    }

    fun next() {
        if (deck.isEmpty()) return
        val pos = (state.value.position + 1) % deck.size
        speakQuestionAt(pos)
    }

    /** Music-player style: while hearing the answer, repeat this question; otherwise go back one. */
    fun previous() {
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
        // english/bilingual start with the English question; chinese goes straight to zh
        // (falling back to English when no translation exists).
        if (settings.speechMode == SpeechMode.CHINESE && q.questionZh != null) {
            speak("zq-${q.n}", zhQuestionText(q), SpeechLanguage.CHINESE)
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
        if (settingsFlow.value.speechMode == SpeechMode.CHINESE && q.spokenZh != null) {
            speak("za-${q.n}", q.spokenZh, SpeechLanguage.CHINESE)
        } else {
            speak("a-${q.n}", q.spoken, SpeechLanguage.ENGLISH)
        }
        emit(state.value.copy(phase = Phase.SPEAKING_ANSWER, answerRevealed = true))
    }

    private fun onUtteranceDone(utteranceId: String) {
        if (utteranceId != expectedUtterance) return
        val mode = settingsFlow.value.speechMode
        // z-prefixed ids must be checked before their English counterparts.
        when {
            utteranceId.startsWith("zq-") -> beginThinkPause()
            utteranceId.startsWith("za-") -> beginAwaitingAdvance()
            utteranceId.startsWith("q-") -> {
                val q = state.value.current
                if (mode == SpeechMode.BILINGUAL && q?.questionZh != null) {
                    speak("zq-${q.n}", zhQuestionText(q), SpeechLanguage.CHINESE)
                } else {
                    beginThinkPause()
                }
            }
            utteranceId.startsWith("a-") -> {
                val q = state.value.current
                if (mode == SpeechMode.BILINGUAL && q?.spokenZh != null) {
                    speak("za-${q.n}", q.spokenZh, SpeechLanguage.CHINESE)
                } else {
                    beginAwaitingAdvance()
                }
            }
        }
    }

    private fun zhQuestionText(q: Question): String {
        val qZh = q.questionZh ?: return q.question
        return if (settingsFlow.value.announceMeta) "第 ${q.n} 题。 $qZh" else qZh
    }

    private fun onUtteranceError(utteranceId: String) {
        if (utteranceId != expectedUtterance) return
        // A speech failure should not cascade through the deck; stop where we are.
        pause()
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
        val newDeck = repo.deck(s.category, s.shuffle)
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
