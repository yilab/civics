package com.yilab.civics.settings

import com.yilab.civics.data.Categories
import com.yilab.civics.data.SpeechLanguage

/** The app chrome language, independent of the system language. */
enum class UiLanguage {
    SYSTEM, ENGLISH, CHINESE_SIMPLIFIED, CHINESE_TRADITIONAL, SPANISH;

    /** The spoken language this UI language corresponds to, if any. */
    val speechLanguage: SpeechLanguage?
        get() = when (this) {
            SYSTEM -> null
            ENGLISH -> SpeechLanguage.ENGLISH
            CHINESE_SIMPLIFIED -> SpeechLanguage.CHINESE_SIMPLIFIED
            CHINESE_TRADITIONAL -> SpeechLanguage.CHINESE_TRADITIONAL
            SPANISH -> SpeechLanguage.SPANISH
        }
}

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
    /** The language the study loop speaks. */
    val spokenLanguage: SpeechLanguage = SpeechLanguage.ENGLISH,
    /** Also speak the English original before the translation. */
    val bilingual: Boolean = false,
    /** App chrome language (menus, buttons, labels). */
    val uiLanguage: UiLanguage = UiLanguage.SYSTEM,
) {
    companion object {
        const val THINK_WAIT_FOR_PRESS = -1
    }
}
