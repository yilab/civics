package com.yilab.civics.data

import java.util.Locale

/** A question rendered in one non-English language. */
data class Translation(
    val question: String,
    val answer: String,
    /** TTS-friendly rendering of [answer]. */
    val spoken: String,
    val note: String? = null,
)

/** A language the study loop can speak, with its TTS locale and translation key. */
enum class SpeechLanguage(
    /** Key into [Question.translations]; English has no entry (it is the canonical text). */
    val translationKey: String,
    /** The TTS locale probed for availability and set before speaking. */
    val locale: Locale,
) {
    ENGLISH("en", Locale.US),
    CHINESE_SIMPLIFIED("zh-Hans", Locale.SIMPLIFIED_CHINESE),
    CHINESE_TRADITIONAL("zh-Hant", Locale.TRADITIONAL_CHINESE),
    SPANISH("es", Locale("es", "US")),
    VIETNAMESE("vi", Locale("vi", "VN")),
    TAGALOG("tl", Locale("fil", "PH")),
    KOREAN("ko", Locale.KOREA),
    ARABIC("ar", Locale("ar", "SA")),
    HINDI("hi", Locale("hi", "IN")),
    PORTUGUESE("pt", Locale("pt", "BR")),
    RUSSIAN("ru", Locale("ru", "RU")),
    ;

    /** The "Question N." announcement prefix in this language. */
    fun questionPrefix(n: Int): String = when (this) {
        ENGLISH -> "Question $n."
        CHINESE_SIMPLIFIED -> "第 $n 题。"
        CHINESE_TRADITIONAL -> "第 $n 題。"
        SPANISH -> "Pregunta $n."
        VIETNAMESE -> "Câu $n."
        TAGALOG -> "Tanong $n."
        KOREAN -> "질문 $n."
        ARABIC -> "السؤال $n."
        HINDI -> "प्रश्न $n."
        PORTUGUESE -> "Pergunta $n."
        RUSSIAN -> "Вопрос $n."
    }

    /** Self-name shown in the language picker (autonym). */
    val displayName: String
        get() = when (this) {
            ENGLISH -> "English"
            CHINESE_SIMPLIFIED -> "简体中文"
            CHINESE_TRADITIONAL -> "繁體中文"
            SPANISH -> "Español"
            VIETNAMESE -> "Tiếng Việt"
            TAGALOG -> "Tagalog"
            KOREAN -> "한국어"
            ARABIC -> "العربية"
            HINDI -> "हिन्दी"
            PORTUGUESE -> "Português"
            RUSSIAN -> "Русский"
        }
}

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
    /** Non-English renderings keyed by language code ("zh-Hans", "zh-Hant", "es");
     * English is used as fallback when a language is absent. */
    val translations: Map<String, Translation> = emptyMap(),
) {
    /** The translation for [language], if this question has one. */
    fun translation(language: SpeechLanguage): Translation? = translations[language.translationKey]
}

object Categories {
    const val ALL = "All"
    val values = listOf(ALL, "American Government", "American History", "Symbols & Holidays")
}
