package com.yilab.civics.settings

import com.yilab.civics.data.Categories
import com.yilab.civics.data.KnownFilter
import com.yilab.civics.data.SpeechLanguage

data class StudySettings(
    val speechRate: Float = 1.0f,
    /** Seconds to pause between question and answer. [THINK_WAIT_FOR_PRESS] = wait for a button press. */
    val thinkSeconds: Int = 3,
    /** Automatically move to the next question after the answer has been spoken. */
    val autoAdvance: Boolean = false,
    val category: String = Categories.ALL,
    val shuffle: Boolean = false,
    /** Speak "Question N" before the question text. */
    val announceMeta: Boolean = true,
    val known: Set<Int> = emptySet(),
    /** Which questions the study deck includes by known status. */
    val knownFilter: KnownFilter = KnownFilter.ALL,
    /** The single language choice: spoken language and app UI language.
     * `null` = system UI + English speech. */
    val language: SpeechLanguage? = null,
) {
    /** The language actually spoken (English when following the system). */
    val spokenLanguage: SpeechLanguage get() = language ?: SpeechLanguage.ENGLISH

    /** English is always spoken first; the translation follows when a
     * non-English language is selected. This replaces the old bilingual toggle. */
    val bilingual: Boolean get() = spokenLanguage != SpeechLanguage.ENGLISH

    /** True when the translation takes visual precedence over English. */
    val translationPrimary: Boolean get() = bilingual

    companion object {
        const val THINK_WAIT_FOR_PRESS = -1
    }
}
