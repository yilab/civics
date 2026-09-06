package com.yilab.civics.audio

/**
 * Minimal text-to-speech abstraction so the study engine can be unit-tested.
 * All methods and callbacks are expected on the main thread.
 */
interface SpeechEngine {

    interface Callback {
        fun onDone(utteranceId: String)
        fun onError(utteranceId: String)
    }

    var callback: Callback?
    var speechRate: Float

    /** Speaks [text], replacing anything currently queued or playing. */
    fun speak(utteranceId: String, text: String)

    /** Stops any in-flight speech. May still trigger callbacks for interrupted utterances. */
    fun stop()

    fun shutdown()
}
