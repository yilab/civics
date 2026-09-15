package com.yilab.civics.audio

import com.yilab.civics.data.SpeechLanguage

/**
 * Minimal text-to-speech abstraction so the study engine can be unit-tested.
 * All methods and callbacks are expected on the main thread.
 */
interface SpeechEngine {

    interface Callback {
        fun onDone(utteranceId: String)

        /** A speech failure on an in-flight utterance; the study engine treats it as completion. */
        fun onError(utteranceId: String)
    }

    var callback: Callback?
    var speechRate: Float

    /**
     * Speaks [text], replacing anything currently queued or playing.
     * When no voice is installed for [language] (see [isAvailable]), nothing is
     * spoken and the utterance is reported done immediately, so the caller's flow
     * advances exactly as if it had played.
     */
    fun speak(utteranceId: String, text: String, language: SpeechLanguage)

    /** True when a voice for [language] is installed. */
    fun isAvailable(language: SpeechLanguage): Boolean

    /** Stops any in-flight speech. May still trigger callbacks for interrupted utterances. */
    fun stop()

    fun shutdown()
}
