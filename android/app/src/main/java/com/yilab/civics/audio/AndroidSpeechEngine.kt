package com.yilab.civics.audio

import android.content.Context
import android.media.AudioAttributes
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.util.Log
import com.yilab.civics.data.SpeechLanguage
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
    private var pending: Triple<String, String, SpeechLanguage>? = null
    private val available = mutableSetOf<SpeechLanguage>()

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
                available.clear()
                // Probe every spoken language; a missing voice just stays out of the set.
                SpeechLanguage.entries.forEach { lang ->
                    if (engine.languageSupported(lang.locale)) available += lang
                }
                ready = SpeechLanguage.ENGLISH in available
                engine.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                    override fun onStart(utteranceId: String?) = Unit

                    override fun onDone(utteranceId: String?) {
                        utteranceId ?: return
                        mainHandler.post { callback?.onDone(utteranceId) }
                    }

                    @Deprecated("deprecated in framework")
                    override fun onError(utteranceId: String?) {
                        utteranceId ?: return
                        Log.w(TAG, "TTS error on $utteranceId")
                        mainHandler.post { callback?.onError(utteranceId) }
                    }

                    override fun onError(utteranceId: String?, errorCode: Int) {
                        utteranceId ?: return
                        Log.w(TAG, "TTS error $errorCode on $utteranceId")
                        mainHandler.post { callback?.onError(utteranceId) }
                    }

                    override fun onStop(utteranceId: String?, interrupted: Boolean) {
                        // interrupted speech is expected (pause/skip); StudyEngine ignores stale ids
                    }
                })
            }
            onAvailabilityChanged(ready)
            pending?.let { (id, text, language) ->
                pending = null
                // Routed through speak() so the per-language gate also applies here.
                if (ready) speak(id, text, language)
            }
        }.also { tts = it }
    }

    override fun isAvailable(language: SpeechLanguage): Boolean = language in available

    override fun speak(utteranceId: String, text: String, language: SpeechLanguage) {
        if (!ready) {
            pending = Triple(utteranceId, text, language)
            return
        }
        if (language !in available) {
            // No voice installed for this language: skip the audio but report the
            // utterance as done (posted, exactly like a natural completion) so the
            // study flow advances instead of stalling or garbling through a
            // fallback voice.
            Log.w(TAG, "no TTS voice for $language; skipping $utteranceId")
            mainHandler.post { callback?.onDone(utteranceId) }
            return
        }
        speakNow(utteranceId, text, language)
    }

    private fun speakNow(utteranceId: String, text: String, language: SpeechLanguage) {
        val engine = tts ?: return
        engine.language = language.locale
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

    private fun TextToSpeech.languageSupported(locale: Locale): Boolean {
        val result = setLanguage(locale)
        return result != TextToSpeech.LANG_MISSING_DATA && result != TextToSpeech.LANG_NOT_SUPPORTED
    }

    private companion object {
        const val TAG = "Civics"
    }
}
