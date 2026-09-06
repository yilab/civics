package com.yilab.civics

import android.Manifest
import android.content.ComponentName
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Icon
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.adaptive.navigationsuite.NavigationSuiteScaffold
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.core.content.ContextCompat
import androidx.media3.common.util.UnstableApi
import androidx.media3.session.MediaController
import androidx.media3.session.SessionToken
import com.yilab.civics.audio.CivicsAudioService
import com.yilab.civics.ui.ListenScreen
import com.yilab.civics.ui.QuestionsScreen
import com.yilab.civics.ui.SettingsScreen
import com.yilab.civics.ui.theme.CivicsTheme
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            CivicsTheme {
                CivicsRoot()
            }
        }
    }
}

enum class AppDestinations(val label: String, val icon: Int) {
    LISTEN("Listen", R.drawable.ic_headset),
    QUESTIONS("Questions", R.drawable.ic_list),
    SETTINGS("Settings", R.drawable.ic_settings),
}

@androidx.annotation.OptIn(UnstableApi::class)
@Composable
fun CivicsRoot() {
    val context = LocalContext.current
    val app = context.applicationContext as CivicsApp
    val engine = app.studyEngine

    // Connecting a controller starts/binds the media session service, which keeps
    // playback alive with the screen off and receives AirPods media buttons.
    var controller by remember { mutableStateOf<MediaController?>(null) }
    DisposableEffect(Unit) {
        var connected: MediaController? = null
        val token = SessionToken(context, ComponentName(context, CivicsAudioService::class.java))
        val future = MediaController.Builder(context, token).buildAsync()
        future.addListener(
            {
                runCatching { future.get() }.onSuccess {
                    connected = it
                    controller = it
                }
            },
            ContextCompat.getMainExecutor(context),
        )
        onDispose { connected?.release() }
    }

    RequestNotificationPermission()

    val state by engine.state.collectAsState()
    val settings by app.settingsRepo.settings.collectAsState()
    val ttsAvailable by app.ttsAvailable.collectAsState()
    var currentDestination by rememberSaveable { mutableStateOf(AppDestinations.LISTEN) }

    // Route transport through the session so on-screen and AirPod presses behave identically.
    val primary = { controller?.play() ?: engine.primaryAction() }
    val pause = { controller?.pause() ?: engine.pause() }
    val next = { controller?.seekToNext() ?: engine.next() }
    val previous = { controller?.seekToPrevious() ?: engine.previous() }

    NavigationSuiteScaffold(
        navigationSuiteItems = {
            AppDestinations.entries.forEach { destination ->
                item(
                    icon = {
                        Icon(painterResource(destination.icon), contentDescription = destination.label)
                    },
                    label = { Text(destination.label) },
                    selected = destination == currentDestination,
                    onClick = { currentDestination = destination },
                )
            }
        }
    ) {
        Scaffold(modifier = Modifier.fillMaxSize()) { innerPadding ->
            when (currentDestination) {
                AppDestinations.LISTEN -> ListenScreen(
                    state = state,
                    ttsAvailable = ttsAvailable,
                    onPrimary = primary,
                    onPause = pause,
                    onNext = next,
                    onPrevious = previous,
                    onToggleKnown = engine::toggleKnown,
                    modifier = Modifier.padding(innerPadding),
                )

                AppDestinations.QUESTIONS -> QuestionsScreen(
                    questions = app.questionRepo.questions,
                    known = state.known,
                    currentNumber = state.current?.n,
                    onJump = engine::jumpTo,
                    modifier = Modifier.padding(innerPadding),
                )

                AppDestinations.SETTINGS -> SettingsScreen(
                    settings = settings,
                    onChange = { transform -> app.appScope.launch { app.settingsRepo.update(transform) } },
                    modifier = Modifier.padding(innerPadding),
                )
            }
        }
    }
}

@Composable
private fun RequestNotificationPermission() {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
    val context = LocalContext.current
    val launcher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { }
    LaunchedEffect(Unit) {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            launcher.launch(Manifest.permission.POST_NOTIFICATIONS)
        }
    }
}
