package com.yilab.civics.settings

import com.yilab.civics.data.Categories

/** Which languages the study loop speaks. */
enum class SpeechMode { ENGLISH, BILINGUAL, CHINESE }

/** The app chrome language, independent of the system language. */
enum class UiLanguage { SYSTEM, ENGLISH, CHINESE }

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
    /** Which languages the study loop speaks. */
    val speechMode: SpeechMode = SpeechMode.ENGLISH,
    /** App chrome language (menus, buttons, labels). */
    val uiLanguage: UiLanguage = UiLanguage.SYSTEM,
) {
    companion object {
        const val THINK_WAIT_FOR_PRESS = -1
    }
}
