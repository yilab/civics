package com.yilab.civics.data

data class Question(
    val n: Int,
    val category: String,
    val question: String,
    val answer: String,
    /** TTS-friendly rendering of [answer]. */
    val spoken: String,
    /** True when the answer changes over time or depends on the user's state. */
    val dynamic: Boolean,
    val note: String?,
    /** Simplified-Chinese translations; English is used as fallback when null. */
    val questionZh: String? = null,
    val answerZh: String? = null,
    val spokenZh: String? = null,
    val noteZh: String? = null,
)

object Categories {
    const val ALL = "All"
    val values = listOf(ALL, "American Government", "American History", "Symbols & Holidays")
}
