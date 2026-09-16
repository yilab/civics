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

        /**
         * The engine reached a word or phrase: [start]..[end] are character offsets into
         * the text of [utteranceId]. Engines without range support simply never call this;
         * the study engine then leaves the text unhighlighted.
         */
        fun onRangeStart(utteranceId: String, start: Int, end: Int) {}
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
