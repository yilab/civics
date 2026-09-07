package com.yilab.civics.settings

import android.content.Context
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.floatPreferencesKey
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.core.stringSetPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn

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
        val SPEECH_MODE = stringPreferencesKey("speech_mode")
        val UI_LANGUAGE = stringPreferencesKey("ui_language")
    }

    val settings: StateFlow<StudySettings> = store.data
        .map { prefs ->
            StudySettings(
                speechRate = prefs[Keys.SPEECH_RATE] ?: 1.0f,
                thinkSeconds = prefs[Keys.THINK_SECONDS] ?: StudySettings.THINK_WAIT_FOR_PRESS,
                autoAdvance = prefs[Keys.AUTO_ADVANCE] ?: false,
                category = prefs[Keys.CATEGORY] ?: com.yilab.civics.data.Categories.ALL,
                shuffle = prefs[Keys.SHUFFLE] ?: false,
                announceMeta = prefs[Keys.ANNOUNCE_META] ?: true,
                known = prefs[Keys.KNOWN].orEmpty().mapNotNull { it.toIntOrNull() }.toSet(),
                speechMode = when (prefs[Keys.SPEECH_MODE]) {
                    "bilingual" -> SpeechMode.BILINGUAL
                    "chinese" -> SpeechMode.CHINESE
                    else -> SpeechMode.ENGLISH
                },
                uiLanguage = when (prefs[Keys.UI_LANGUAGE]) {
                    "english" -> UiLanguage.ENGLISH
                    "chinese" -> UiLanguage.CHINESE
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
            prefs[Keys.SPEECH_MODE] = when (s.speechMode) {
                SpeechMode.BILINGUAL -> "bilingual"
                SpeechMode.CHINESE -> "chinese"
                SpeechMode.ENGLISH -> "english"
            }
            prefs[Keys.UI_LANGUAGE] = when (s.uiLanguage) {
                UiLanguage.ENGLISH -> "english"
                UiLanguage.CHINESE -> "chinese"
                UiLanguage.SYSTEM -> "system"
            }
        }
    }
}
