package com.yilab.civics

import android.app.Application
import com.yilab.civics.audio.AndroidSpeechEngine
import com.yilab.civics.audio.SpeechLanguage
import com.yilab.civics.audio.StudyEngine
import com.yilab.civics.data.QuestionRepository
import com.yilab.civics.settings.SettingsRepository
import com.yilab.civics.settings.SpeechMode
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

class CivicsApp : Application() {

    val appScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    lateinit var questionRepo: QuestionRepository
        private set
    lateinit var settingsRepo: SettingsRepository
        private set
    lateinit var studyEngine: StudyEngine
        private set
    private lateinit var speech: AndroidSpeechEngine

    private val speechReady = MutableStateFlow(false)

    /** False when a voice required by the current speech mode is missing; the UI surfaces a warning. */
    var ttsAvailable: StateFlow<Boolean> = MutableStateFlow(true)
        private set

    override fun onCreate() {
        super.onCreate()
        questionRepo = QuestionRepository.fromAssets(this)
        settingsRepo = SettingsRepository(this, appScope)
        speech = AndroidSpeechEngine(this) { ready -> speechReady.value = ready }
        ttsAvailable = combine(settingsRepo.settings, speechReady) { s, _ ->
            when (s.speechMode) {
                SpeechMode.ENGLISH -> speech.isAvailable(SpeechLanguage.ENGLISH)
                SpeechMode.CHINESE -> speech.isAvailable(SpeechLanguage.CHINESE)
                SpeechMode.BILINGUAL ->
                    speech.isAvailable(SpeechLanguage.ENGLISH) && speech.isAvailable(SpeechLanguage.CHINESE)
            }
        }.stateIn(appScope, SharingStarted.Eagerly, true)
        studyEngine = StudyEngine(
            speech = speech,
            repo = questionRepo,
            settingsFlow = settingsRepo.settings,
            scope = appScope,
            onKnownChanged = { n, known ->
                appScope.launch {
                    settingsRepo.update { s -> s.copy(known = if (known) s.known + n else s.known - n) }
                }
            },
        )
    }
}
