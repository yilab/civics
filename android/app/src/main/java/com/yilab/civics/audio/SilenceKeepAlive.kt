package com.yilab.civics.audio

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.util.Log

/**
 * Loops inaudible silence from this app's own process while a study session runs.
 *
 * Android delivers media buttons (AirPods presses) to the media session of the app
 * that most recently played audio. The questions are spoken by the TTS engine,
 * which plays from its own process, so without this the system would hand the
 * buttons to whichever media app played last instead of to [CivicsAudioService].
 */
class SilenceKeepAlive {

    private var track: AudioTrack? = null

    fun start() {
        if (track != null) return
        track = runCatching {
            AudioTrack.Builder()
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .build()
                )
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setSampleRate(SAMPLE_RATE)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                        .build()
                )
                .setTransferMode(AudioTrack.MODE_STATIC)
                .setBufferSizeInBytes(FRAMES * 2)
                .build()
                .apply {
                    write(ShortArray(FRAMES), 0, FRAMES)
                    setLoopPoints(0, FRAMES, -1)
                    play()
                }
        }.onFailure { Log.w(TAG, "silence keep-alive unavailable", it) }.getOrNull()
    }

    fun stop() {
        track?.run {
            runCatching { stop() }
            release()
        }
        track = null
    }

    private companion object {
        const val TAG = "Civics"
        const val SAMPLE_RATE = 8_000
        const val FRAMES = SAMPLE_RATE / 2 // half a second, looped forever
    }
}
