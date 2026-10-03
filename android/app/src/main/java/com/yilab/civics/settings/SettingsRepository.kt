package com.yilab.civics.settings

import android.content.Context
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.floatPreferencesKey
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.core.stringSetPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.yilab.civics.audio.TestRecord
import com.yilab.civics.data.KnownFilter
import com.yilab.civics.data.SpeechLanguage
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.runBlocking

private val Context.settingsDataStore by preferencesDataStore(name = "study_settings")

class SettingsRepository(context: Context, scope: CoroutineScope) {

    private val store = context.settingsDataStore

    private object Keys {
        val SPEECH_RATE = floatPreferencesKey("speech_rate")
        val THINK_SECONDS = intPreferencesKey("think_seconds")
        val AUTO_ADVANCE = booleanPreferencesKey("auto_advance")
        val CATEGORY = stringPreferencesKey("category")
        val SHUFFLE = booleanPreferencesKey("shuffle")
        val ANNOUNCE_META = booleanPreferencesKey("announce_meta")
        val KNOWN = stringSetPreferencesKey("known")
        val KNOWN_FILTER = stringPreferencesKey("known_filter")
        /** The single merged language setting. */
        val LANGUAGE = stringPreferencesKey("language")
        /** Legacy keys read once for migration, never written. */
        val SPOKEN_LANGUAGE = stringPreferencesKey("spoken_language")
        val BILINGUAL = booleanPreferencesKey("bilingual")
        val UI_LANGUAGE = stringPreferencesKey("ui_language")
        val LEGACY_SPEECH_MODE = stringPreferencesKey("speech_mode")
        val TEST_HISTORY = stringPreferencesKey("test_history")
        val JURISDICTION = stringPreferencesKey("jurisdiction")
        val DISTRICT = intPreferencesKey("district")
        /** Per-question right/wrong history, encoded by [QuestionStats]. */
        val QUESTION_STATS = stringPreferencesKey("question_stats")
        val REVIEW_FOCUS = booleanPreferencesKey("review_focus")
    }

    private fun languageFor(raw: String?): SpeechLanguage? = when (raw) {
        "english" -> SpeechLanguage.ENGLISH
        "zh-Hans", "chinese" -> SpeechLanguage.CHINESE_SIMPLIFIED
        "zh-Hant" -> SpeechLanguage.CHINESE_TRADITIONAL
        "es" -> SpeechLanguage.SPANISH
        "vi" -> SpeechLanguage.VIETNAMESE
        "tl" -> SpeechLanguage.TAGALOG
        "ko" -> SpeechLanguage.KOREAN
        "ar" -> SpeechLanguage.ARABIC
        "hi" -> SpeechLanguage.HINDI
        "pt" -> SpeechLanguage.PORTUGUESE
        "ru" -> SpeechLanguage.RUSSIAN
        else -> null
    }

    private fun languageName(language: SpeechLanguage?): String? =
        language?.let { if (it.translationKey == "en") "english" else it.translationKey }

    val settings: StateFlow<StudySettings> = store.data
        .map { prefs ->
            // Resolve the merged language, migrating from the older split keys:
            // language, then ui_language, then spoken_language, then speech_mode.
            val resolvedLanguage = languageFor(prefs[Keys.LANGUAGE])
                ?: languageFor(prefs[Keys.UI_LANGUAGE])
                ?: languageFor(prefs[Keys.SPOKEN_LANGUAGE])
                ?: prefs[Keys.LEGACY_SPEECH_MODE]
                    ?.let { languageFor(if (it == "english") "english" else "zh-Hans") }
            StudySettings(
                speechRate = prefs[Keys.SPEECH_RATE] ?: 1.0f,
                thinkSeconds = prefs[Keys.THINK_SECONDS] ?: 3,
                autoAdvance = prefs[Keys.AUTO_ADVANCE] ?: false,
                reviewFocus = prefs[Keys.REVIEW_FOCUS] ?: true,
                category = prefs[Keys.CATEGORY] ?: com.yilab.civics.data.Categories.ALL,
                shuffle = prefs[Keys.SHUFFLE] ?: false,
                announceMeta = prefs[Keys.ANNOUNCE_META] ?: true,
                known = prefs[Keys.KNOWN].orEmpty().mapNotNull { it.toIntOrNull() }.toSet(),
                knownFilter = when (prefs[Keys.KNOWN_FILTER]) {
                    "known" -> KnownFilter.KNOWN
                    "notKnown" -> KnownFilter.NOT_KNOWN
                    else -> KnownFilter.ALL
                },
                language = resolvedLanguage,
                jurisdiction = prefs[Keys.JURISDICTION]?.takeIf { it.matches(Regex("[A-Z]{2}")) },
                district = prefs[Keys.DISTRICT]?.takeIf { it >= 1 },
            )
        }
        .stateIn(scope, SharingStarted.Eagerly, StudySettings())

    suspend fun update(transform: (StudySettings) -> StudySettings) {
        store.edit { prefs ->
            val before = settings.value
            var s = transform(before)
            if (s.jurisdiction != before.jurisdiction || s.district != before.district) {
                // The four state answers changed — their known marks and stats must be re-earned.
                s = s.copy(known = s.known - com.yilab.civics.data.OfficialsData.STATE_QUESTIONS)
                if (s.jurisdiction == null) s = s.copy(district = null)
                val stats = QuestionStats.parse(prefs[Keys.QUESTION_STATS])
                prefs[Keys.QUESTION_STATS] = QuestionStats.encode(
                    QuestionStats.drop(stats, com.yilab.civics.data.OfficialsData.STATE_QUESTIONS)
                )
            }
            prefs[Keys.SPEECH_RATE] = s.speechRate
            prefs[Keys.THINK_SECONDS] = s.thinkSeconds
            prefs[Keys.AUTO_ADVANCE] = s.autoAdvance
            prefs[Keys.REVIEW_FOCUS] = s.reviewFocus
            prefs[Keys.CATEGORY] = s.category
            prefs[Keys.SHUFFLE] = s.shuffle
            prefs[Keys.ANNOUNCE_META] = s.announceMeta
            prefs[Keys.KNOWN] = s.known.map { it.toString() }.toSet()
            prefs[Keys.KNOWN_FILTER] = when (s.knownFilter) {
                KnownFilter.KNOWN -> "known"
                KnownFilter.NOT_KNOWN -> "notKnown"
                KnownFilter.ALL -> "all"
            }
            val name = languageName(s.language)
            if (name == null) prefs.remove(Keys.LANGUAGE) else prefs[Keys.LANGUAGE] = name
            if (s.jurisdiction == null) prefs.remove(Keys.JURISDICTION) else prefs[Keys.JURISDICTION] = s.jurisdiction
            if (s.district == null) prefs.remove(Keys.DISTRICT) else prefs[Keys.DISTRICT] = s.district
        }
    }

    // ------------------------------------------------------------- test history

    /** Recorded practice tests, most recent first. */
    fun testHistory(): List<TestRecord> = runBlocking {
        val raw = store.data.first()[Keys.TEST_HISTORY].orEmpty()
        raw.split(';').mapNotNull { TestRecord.parse(it) }
    }

    /** Appends a finished test, keeping the 20 most recent. */
    suspend fun recordTest(record: TestRecord) {
        store.edit { prefs ->
            val existing = prefs[Keys.TEST_HISTORY].orEmpty()
            val list = (listOf(record.encode()) + existing.split(';').filter { it.isNotBlank() })
                .take(20)
            prefs[Keys.TEST_HISTORY] = list.joinToString(";")
        }
    }

    // ------------------------------------------------------------ question stats

    /** Right/wrong history per question number; updates as answers are graded. */
    val stats: StateFlow<Map<Int, QuestionStat>> = store.data
        .map { prefs -> QuestionStats.parse(prefs[Keys.QUESTION_STATS]) }
        .stateIn(scope, SharingStarted.Eagerly, emptyMap())

    /** Applies one graded answer to the stats store (atomic read-modify-write). */
    suspend fun recordGraded(n: Int, correct: Boolean) {
        store.edit { prefs ->
            val updated = QuestionStats.record(
                QuestionStats.parse(prefs[Keys.QUESTION_STATS]),
                n,
                correct,
                System.currentTimeMillis(),
            )
            prefs[Keys.QUESTION_STATS] = QuestionStats.encode(updated)
        }
    }

    /** Clears all per-question stats. */
    suspend fun resetQuestionStats() {
        store.edit { prefs -> prefs.remove(Keys.QUESTION_STATS) }
    }
}
