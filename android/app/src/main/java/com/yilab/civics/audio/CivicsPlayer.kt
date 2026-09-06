package com.yilab.civics.audio

import android.os.Looper
import android.util.Log
import androidx.media3.common.C
import androidx.media3.common.MediaMetadata
import androidx.media3.common.Player
import androidx.media3.common.SimpleBasePlayer
import androidx.media3.common.SimpleBasePlayer.MediaItemData
import androidx.media3.common.util.UnstableApi
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture
import com.yilab.civics.data.Question

/**
 * Bridges media-session commands (AirPods presses, notification, lock screen, UI)
 * into [StudyEngine] actions. The engine is the single source of truth; this player
 * only reflects its state.
 */
@OptIn(UnstableApi::class)
class CivicsPlayer(
    private val engine: StudyEngine,
    looper: Looper,
) : SimpleBasePlayer(looper) {

    /**
     * The player only leaves STATE_IDLE once the user starts a session, so no
     * notification is posted for an app that was merely opened.
     */
    private var hasStarted = false

    /** Called by the service whenever the engine state changes. */
    fun refresh() = invalidateState()

    override fun getState(): State {
        val st = engine.state.value
        val builder = State.Builder()
            .setAvailableCommands(
                Player.Commands.Builder()
                    .addAll(
                        Player.COMMAND_PLAY_PAUSE,
                        Player.COMMAND_STOP,
                        Player.COMMAND_SEEK_TO_NEXT,
                        Player.COMMAND_SEEK_TO_PREVIOUS,
                    )
                    .build()
            )
            .setContentPositionMs(C.TIME_UNSET)
        if (st.deck.isEmpty() || !hasStarted) {
            // Empty playlist is only valid in STATE_IDLE/STATE_ENDED.
            builder.setPlaybackState(Player.STATE_IDLE)
            builder.setPlayWhenReady(false, Player.PLAY_WHEN_READY_CHANGE_REASON_USER_REQUEST)
        } else {
            builder.setPlaybackState(Player.STATE_READY)
            builder.setPlayWhenReady(st.playing, Player.PLAY_WHEN_READY_CHANGE_REASON_USER_REQUEST)
            builder.setPlaylist(st.deck.map { it.toMediaItemData() })
            builder.setCurrentMediaItemIndex(st.position.coerceIn(0, st.deck.size - 1))
        }
        return builder.build()
    }

    /** Play/pause (single AirPod press, notification button, lock screen). */
    override fun handleSetPlayWhenReady(playWhenReady: Boolean): ListenableFuture<*> {
        Log.d(TAG, "handleSetPlayWhenReady($playWhenReady)")
        if (playWhenReady) {
            hasStarted = true
            engine.primaryAction()
        } else {
            engine.pause()
        }
        return Futures.immediateVoidFuture()
    }

    override fun handleStop(): ListenableFuture<*> {
        Log.d(TAG, "handleStop")
        engine.pause()
        return Futures.immediateVoidFuture()
    }

    override fun handleSeek(
        mediaItemIndex: Int,
        positionMs: Long,
        seekCommand: Int,
    ): ListenableFuture<*> {
        Log.d(TAG, "handleSeek(command=$seekCommand)")
        hasStarted = true
        when (seekCommand) {
            Player.COMMAND_SEEK_TO_NEXT, Player.COMMAND_SEEK_TO_NEXT_MEDIA_ITEM -> engine.next()
            Player.COMMAND_SEEK_TO_PREVIOUS, Player.COMMAND_SEEK_TO_PREVIOUS_MEDIA_ITEM -> engine.previous()
        }
        return Futures.immediateVoidFuture()
    }

    private companion object {
        const val TAG = "Civics"

        fun Question.toMediaItemData(): MediaItemData =
            MediaItemData.Builder("q$n")
                .setMediaMetadata(
                    MediaMetadata.Builder()
                        .setDisplayTitle("Question $n")
                        .setTitle(question)
                        .setArtist(category)
                        .build()
                )
                .build()
    }
}
