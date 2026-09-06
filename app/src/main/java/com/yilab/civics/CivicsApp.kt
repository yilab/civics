package com.yilab.civics

import android.app.Application
import com.yilab.civics.audio.AndroidSpeechEngine
import com.yilab.civics.audio.StudyEngine
import com.yilab.civics.data.QuestionRepository
import com.yilab.civics.settings.SettingsRepository
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.launch

class CivicsApp : Application() {

    val appScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    lateinit var questionRepo: QuestionRepository
        private set
    lateinit var settingsRepo: SettingsRepository
        private set
    lateinit var studyEngine: StudyEngine
        private set

    /** False when no usable TTS engine/voice is installed; the UI surfaces a warning. */
    val ttsAvailable = MutableStateFlow(true)

    override fun onCreate() {
        super.onCreate()
        questionRepo = QuestionRepository.fromAssets(this)
        settingsRepo = SettingsRepository(this, appScope)
        val speech = AndroidSpeechEngine(this) { available -> ttsAvailable.value = available }
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
