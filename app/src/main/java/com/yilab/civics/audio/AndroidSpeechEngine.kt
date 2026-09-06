package com.yilab.civics.audio

import android.content.Context
import android.media.AudioAttributes
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import java.util.Locale

/**
 * [SpeechEngine] backed by Android's on-device [TextToSpeech].
 * Speech requested before the engine finishes initializing is queued and flushed once ready.
 */
class AndroidSpeechEngine(
    context: Context,
    private val onAvailabilityChanged: (Boolean) -> Unit = {},
) : SpeechEngine {

    override var callback: SpeechEngine.Callback? = null
    override var speechRate: Float = 1f

    private val mainHandler = Handler(Looper.getMainLooper())
    private var tts: TextToSpeech? = null
    private var ready = false
    private var pending: Pair<String, String>? = null

    init {
        TextToSpeech(context.applicationContext) { status ->
            if (status != TextToSpeech.SUCCESS) {
                onAvailabilityChanged(false)
                return@TextToSpeech
            }
            tts?.let { engine ->
                engine.setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .build()
                )
                val lang = engine.setLanguage(Locale.US)
                ready = lang != TextToSpeech.LANG_MISSING_DATA && lang != TextToSpeech.LANG_NOT_SUPPORTED
                engine.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                    override fun onStart(utteranceId: String?) = Unit

                    override fun onDone(utteranceId: String?) {
                        utteranceId ?: return
                        mainHandler.post { callback?.onDone(utteranceId) }
                    }

                    @Deprecated("deprecated in framework")
                    override fun onError(utteranceId: String?) {
                        utteranceId ?: return
                        mainHandler.post { callback?.onError(utteranceId) }
                    }

                    override fun onError(utteranceId: String?, errorCode: Int) {
                        utteranceId ?: return
                        mainHandler.post { callback?.onError(utteranceId) }
                    }

                    override fun onStop(utteranceId: String?, interrupted: Boolean) {
                        // interrupted speech is expected (pause/skip); StudyEngine ignores stale ids
                    }
                })
            }
            onAvailabilityChanged(ready)
            pending?.let { (id, text) ->
                pending = null
                if (ready) speakNow(id, text)
            }
        }.also { tts = it }
    }

    override fun speak(utteranceId: String, text: String) {
        if (ready) {
            speakNow(utteranceId, text)
        } else {
            pending = utteranceId to text
        }
    }

    private fun speakNow(utteranceId: String, text: String) {
        val engine = tts ?: return
        engine.setSpeechRate(speechRate)
        engine.speak(text, TextToSpeech.QUEUE_FLUSH, Bundle(), utteranceId)
    }

    override fun stop() {
        pending = null
        tts?.stop()
    }

    override fun shutdown() {
        tts?.stop()
        tts?.shutdown()
    }
}
