package com.yilab.civics.audio

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.PowerManager
import android.support.v4.media.session.MediaSessionCompat
import android.util.Log
import android.view.KeyEvent
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import androidx.media3.common.util.UnstableApi
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService
import com.yilab.civics.CivicsApp
import com.yilab.civics.MainActivity
import com.yilab.civics.R
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/**
 * Keeps TTS playback alive with the screen off and routes Bluetooth/headset media
 * buttons (AirPods stem presses) into the study engine via [CivicsPlayer].
 *
 * The media notification is managed by this service itself (Media3's automatic
 * notification only follows player timelines that ExoPlayer-style players produce,
 * which this TTS-driven player does not fully emulate).
 */
@OptIn(UnstableApi::class)
class CivicsAudioService : MediaSessionService() {

    private val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    private lateinit var engine: StudyEngine
    private lateinit var player: CivicsPlayer
    private lateinit var session: MediaSession
    private lateinit var audioManager: AudioManager

    private var wakeLock: PowerManager.WakeLock? = null
    private var focusRequest: AudioFocusRequest? = null
    private var noisyReceiverRegistered = false
    private var inForeground = false
    private var wasPlaying = false

    private val noisyReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action == AudioManager.ACTION_AUDIO_BECOMING_NOISY) engine.pause()
        }
    }

    override fun onCreate() {
        super.onCreate()
        val app = application as CivicsApp
        engine = app.studyEngine
        audioManager = getSystemService(AUDIO_SERVICE) as AudioManager
        player = CivicsPlayer(engine, mainLooper)
        session = MediaSession.Builder(this, player)
            .setCallback(object : MediaSession.Callback {
                override fun onMediaButtonEvent(
                    session: MediaSession,
                    controllerInfo: MediaSession.ControllerInfo,
                    intent: Intent,
                ): Boolean {
                    Log.d(TAG, "onMediaButtonEvent: ${intent.action} ${intent.getParcelableExtra<KeyEvent>(Intent.EXTRA_KEY_EVENT)}")
                    return super.onMediaButtonEvent(session, controllerInfo, intent)
                }
            })
            .build()
        createNotificationChannel()
        serviceScope.launch {
            // Word-range highlight updates arrive several times per second; the media
            // session, notification, and playback resources only care about the rest.
            var lastNotified: StudyState? = null
            engine.state.collect { st ->
                if (lastNotified?.copy(highlight = null) != st.copy(highlight = null)) {
                    player.refresh()
                    updatePlaybackResources(st.playing)
                    updateNotification(st)
                    lastNotified = st
                }
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_PLAY_PAUSE -> {
                if (engine.state.value.playing) engine.pause() else engine.primaryAction()
                return START_STICKY
            }
            ACTION_NEXT -> {
                engine.next()
                return START_STICKY
            }
            ACTION_PREVIOUS -> {
                engine.previous()
                return START_STICKY
            }
        }
        return super.onStartCommand(intent, flags, startId)
    }

    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaSession = session

    /** Suppresses Media3's automatic notification; [updateNotification] handles it. */
    override fun onUpdateNotification(session: MediaSession, startInForegroundRequired: Boolean) = Unit

    override fun onDestroy() {
        serviceScope.cancel()
        updatePlaybackResources(false)
        if (inForeground) {
            ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
            inForeground = false
        }
        NotificationManagerCompat.from(this).cancel(NOTIFICATION_ID)
        session.release()
        super.onDestroy()
    }

    // ------------------------------------------------------------- notification

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            NOTIFICATION_CHANNEL_ID,
            getString(R.string.app_name),
            NotificationManager.IMPORTANCE_LOW,
        ).apply { description = "Ongoing civics study playback" }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    private fun updateNotification(state: StudyState) {
        if (state.playing) wasPlaying = true
        // After pausing mid-session, keep a dismissible notification so playback can be
        // resumed from the lock screen or notification shade.
        if (!state.playing && !wasPlaying) {
            NotificationManagerCompat.from(this).cancel(NOTIFICATION_ID)
            return
        }
        val notification = buildNotification(state)
        try {
            if (state.playing) {
                if (!inForeground) {
                    ServiceCompat.startForeground(
                        this,
                        NOTIFICATION_ID,
                        notification,
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK,
                    )
                    inForeground = true
                } else {
                    NotificationManagerCompat.from(this).notify(NOTIFICATION_ID, notification)
                }
            } else {
                if (inForeground) {
                    ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_DETACH)
                    inForeground = false
                }
                NotificationManagerCompat.from(this).notify(NOTIFICATION_ID, notification)
            }
        } catch (t: Throwable) {
            Log.e(TAG, "could not update playback notification", t)
        }
    }

    private fun buildNotification(state: StudyState): Notification {
        val q = state.current
        val contentIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val playing = state.playing
        val builder = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_headset)
            .setContentTitle(q?.let { "Question ${it.n}" } ?: getString(R.string.app_name))
            .setContentText(
                when {
                    q == null -> ""
                    state.answerRevealed -> "${q.question} — ${q.answer}"
                    else -> q.question
                }
            )
            .setSubText(q?.category)
            .setContentIntent(contentIntent)
            .setOngoing(playing)
            .setShowWhen(false)
            .setCategory(NotificationCompat.CATEGORY_TRANSPORT)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .addAction(android.R.drawable.ic_media_previous, "Previous", actionIntent(ACTION_PREVIOUS))
            .addAction(
                if (playing) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play,
                if (playing) "Pause" else "Play",
                actionIntent(ACTION_PLAY_PAUSE),
            )
            .addAction(android.R.drawable.ic_media_next, "Next", actionIntent(ACTION_NEXT))

        runCatching {
            val token = MediaSessionCompat.Token.fromToken(session.platformToken)
            androidx.media.app.NotificationCompat.MediaStyle()
                .setMediaSession(token)
                .setShowActionsInCompactView(0, 1, 2)
                .also { mediaStyle -> builder.setStyle(mediaStyle) }
        }.onFailure { Log.e(TAG, "media style unavailable", it) }

        return builder.build()
    }

    private fun actionIntent(action: String): PendingIntent = PendingIntent.getService(
        this,
        action.hashCode(),
        Intent(this, CivicsAudioService::class.java).setAction(action),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )

    // -------------------------------------------------- wake lock / audio focus

    // Keeps the CPU awake for TTS, ducks other audio, and pauses when headphones unplug.
    private fun updatePlaybackResources(playing: Boolean) {
        if (playing) {
            if (wakeLock == null) {
                wakeLock = (getSystemService(POWER_SERVICE) as PowerManager)
                    .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "civics:speech")
                    .apply { setReferenceCounted(false) }
            }
            wakeLock?.acquire(WAKE_LOCK_TIMEOUT_MS)

            if (focusRequest == null) {
                focusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                    .setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_MEDIA)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                            .build()
                    )
                    .setOnAudioFocusChangeListener { change ->
                        if (change == AudioManager.AUDIOFOCUS_LOSS ||
                            change == AudioManager.AUDIOFOCUS_LOSS_TRANSIENT
                        ) {
                            engine.pause()
                        }
                    }
                    .build()
            }
            focusRequest?.let { audioManager.requestAudioFocus(it) }

            if (!noisyReceiverRegistered) {
                ContextCompat.registerReceiver(
                    this,
                    noisyReceiver,
                    IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY),
                    ContextCompat.RECEIVER_NOT_EXPORTED,
                )
                noisyReceiverRegistered = true
            }
        } else {
            wakeLock?.let { if (it.isHeld) it.release() }
            focusRequest?.let { audioManager.abandonAudioFocusRequest(it) }
            if (noisyReceiverRegistered) {
                unregisterReceiver(noisyReceiver)
                noisyReceiverRegistered = false
            }
        }
    }

    companion object {
        // Safety net so a stuck engine can never hold the CPU forever.
        private const val WAKE_LOCK_TIMEOUT_MS = 30 * 60 * 1000L
        private const val TAG = "Civics"
        private const val NOTIFICATION_ID = 1
        private const val NOTIFICATION_CHANNEL_ID = "playback"
        private const val ACTION_PLAY_PAUSE = "com.yilab.civics.action.PLAY_PAUSE"
        private const val ACTION_NEXT = "com.yilab.civics.action.NEXT"
        private const val ACTION_PREVIOUS = "com.yilab.civics.action.PREVIOUS"
    }
}
