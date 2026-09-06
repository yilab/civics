package com.yilab.civics.settings

import com.yilab.civics.data.Categories

data class StudySettings(
    val speechRate: Float = 1.0f,
    /** Seconds to pause between question and answer. [THINK_WAIT_FOR_PRESS] = wait for a button press. */
    val thinkSeconds: Int = THINK_WAIT_FOR_PRESS,
    /** Automatically move to the next question after the answer has been spoken. */
    val autoAdvance: Boolean = false,
    val category: String = Categories.ALL,
    val shuffle: Boolean = false,
    /** Speak "Question N" before the question text. */
    val announceMeta: Boolean = true,
    val known: Set<Int> = emptySet(),
) {
    companion object {
        const val THINK_WAIT_FOR_PRESS = -1
    }
}
