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
        val SPOKEN_LANGUAGE = stringPreferencesKey("spoken_language")
        val BILINGUAL = booleanPreferencesKey("bilingual")
        val UI_LANGUAGE = stringPreferencesKey("ui_language")
        /** Pre-N-language key, read once for migration and never written. */
        val LEGACY_SPEECH_MODE = stringPreferencesKey("speech_mode")
        val TEST_HISTORY = stringPreferencesKey("test_history")
    }

    val settings: StateFlow<StudySettings> = store.data
        .map { prefs ->
            // Migrate the old speech_mode (english/chinese/bilingual) into
            // spoken_language + bilingual when the new key has never been written.
            val legacyMode = prefs[Keys.LEGACY_SPEECH_MODE]
            val hasSpokenLanguage = prefs[Keys.SPOKEN_LANGUAGE] != null
            StudySettings(
                speechRate = prefs[Keys.SPEECH_RATE] ?: 1.0f,
                thinkSeconds = prefs[Keys.THINK_SECONDS] ?: 3,
                autoAdvance = prefs[Keys.AUTO_ADVANCE] ?: false,
                category = prefs[Keys.CATEGORY] ?: com.yilab.civics.data.Categories.ALL,
                shuffle = prefs[Keys.SHUFFLE] ?: false,
                announceMeta = prefs[Keys.ANNOUNCE_META] ?: true,
                known = prefs[Keys.KNOWN].orEmpty().mapNotNull { it.toIntOrNull() }.toSet(),
                spokenLanguage = when (prefs[Keys.SPOKEN_LANGUAGE]) {
                    "zh-Hans" -> SpeechLanguage.CHINESE_SIMPLIFIED
                    "zh-Hant" -> SpeechLanguage.CHINESE_TRADITIONAL
                    "es" -> SpeechLanguage.SPANISH
                    "english" -> SpeechLanguage.ENGLISH
                    else -> when (legacyMode) {
                        "bilingual", "chinese" -> SpeechLanguage.CHINESE_SIMPLIFIED
                        else -> SpeechLanguage.ENGLISH
                    }
                },
                bilingual = prefs[Keys.BILINGUAL] ?: (!hasSpokenLanguage && legacyMode == "bilingual"),
                uiLanguage = when (prefs[Keys.UI_LANGUAGE]) {
                    "english" -> UiLanguage.ENGLISH
                    "zh-Hans", "chinese" -> UiLanguage.CHINESE_SIMPLIFIED // "chinese" is the pre-N-language value
                    "zh-Hant" -> UiLanguage.CHINESE_TRADITIONAL
                    "es" -> UiLanguage.SPANISH
                    else -> UiLanguage.SYSTEM
                },
            )
        }
        .stateIn(scope, SharingStarted.Eagerly, StudySettings())

    suspend fun update(transform: (StudySettings) -> StudySettings) {
        store.edit { prefs ->
            val s = transform(settings.value)
            prefs[Keys.SPEECH_RATE] = s.speechRate
            prefs[Keys.THINK_SECONDS] = s.thinkSeconds
            prefs[Keys.AUTO_ADVANCE] = s.autoAdvance
            prefs[Keys.CATEGORY] = s.category
            prefs[Keys.SHUFFLE] = s.shuffle
            prefs[Keys.ANNOUNCE_META] = s.announceMeta
            prefs[Keys.KNOWN] = s.known.map { it.toString() }.toSet()
            prefs[Keys.SPOKEN_LANGUAGE] = when (s.spokenLanguage) {
                SpeechLanguage.ENGLISH -> "english"
                SpeechLanguage.CHINESE_SIMPLIFIED -> "zh-Hans"
                SpeechLanguage.CHINESE_TRADITIONAL -> "zh-Hant"
                SpeechLanguage.SPANISH -> "es"
            }
            prefs[Keys.BILINGUAL] = s.bilingual
            prefs[Keys.UI_LANGUAGE] = when (s.uiLanguage) {
                UiLanguage.SYSTEM -> "system"
                UiLanguage.ENGLISH -> "english"
                UiLanguage.CHINESE_SIMPLIFIED -> "zh-Hans"
                UiLanguage.CHINESE_TRADITIONAL -> "zh-Hant"
                UiLanguage.SPANISH -> "es"
            }
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
}
