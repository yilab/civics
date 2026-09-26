package com.yilab.civics

import android.app.Application
import com.yilab.civics.audio.AndroidSpeechEngine
import com.yilab.civics.audio.StudyEngine
import com.yilab.civics.data.QuestionRepository
import com.yilab.civics.data.SpeechLanguage
import com.yilab.civics.settings.SettingsRepository
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
    lateinit var officialsRepo: com.yilab.civics.data.OfficialsRepository
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
        officialsRepo = com.yilab.civics.data.OfficialsRepository.fromAssets(this)
        settingsRepo = SettingsRepository(this, appScope)
        speech = AndroidSpeechEngine(this) { ready -> speechReady.value = ready }
        ttsAvailable = combine(settingsRepo.settings, speechReady) { s, _ ->
            val lang = s.spokenLanguage
            when {
                lang == SpeechLanguage.ENGLISH -> speech.isAvailable(SpeechLanguage.ENGLISH)
                s.bilingual -> speech.isAvailable(SpeechLanguage.ENGLISH) && speech.isAvailable(lang)
                else -> speech.isAvailable(lang)
            }
        }.stateIn(appScope, SharingStarted.Eagerly, true)
        studyEngine = StudyEngine(
            speech = speech,
            repo = questionRepo,
            officials = officialsRepo.data,
            settingsFlow = settingsRepo.settings,
            scope = appScope,
            onKnownChanged = { n, known ->
                appScope.launch {
                    settingsRepo.update { s -> s.copy(known = if (known) s.known + n else s.known - n) }
                }
            },
            onTestFinished = { record ->
                appScope.launch { settingsRepo.recordTest(record) }
            },
        )
    }
}
