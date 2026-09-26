package com.yilab.civics

import android.Manifest
import android.content.ComponentName
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.appcompat.app.AppCompatDelegate
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.core.os.LocaleListCompat
import androidx.media3.common.util.UnstableApi
import androidx.media3.session.MediaController
import androidx.media3.session.SessionToken
import com.yilab.civics.audio.CivicsAudioService
import com.yilab.civics.ui.FlashcardsScreen
import com.yilab.civics.ui.ListenScreen
import com.yilab.civics.ui.QuestionsScreen
import com.yilab.civics.ui.SettingsScreen
import com.yilab.civics.ui.theme.CivicsTheme
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MainActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Apply the persisted in-app language before the first composition.
        applyUiLanguage((applicationContext as CivicsApp).settingsRepo.settings.value.language)
        enableEdgeToEdge()
        setContent {
            CivicsTheme {
                CivicsRoot()
            }
        }
    }
}

/** Applies the in-app language; recreates the activity when it actually changes. */
fun applyUiLanguage(language: com.yilab.civics.data.SpeechLanguage?) {
    val locales = when (language) {
        null, com.yilab.civics.data.SpeechLanguage.ENGLISH -> LocaleListCompat.getEmptyLocaleList()
        else -> LocaleListCompat.forLanguageTags(language.translationKey)
    }
    if (AppCompatDelegate.getApplicationLocales() != locales) {
        AppCompatDelegate.setApplicationLocales(locales)
    }
}

enum class AppDestinations(val labelRes: Int, val icon: Int) {
    LISTEN(R.string.tab_listen, R.drawable.ic_headset),
    FLASHCARDS(R.string.tab_flashcards, R.drawable.ic_cards),
    QUESTIONS(R.string.tab_questions, R.drawable.ic_list),
    TEST(R.string.tab_test, R.drawable.ic_list),
    SETTINGS(R.string.tab_settings, R.drawable.ic_settings),
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

    // Keep the activity locale in sync with the uiLanguage setting.
    LaunchedEffect(Unit) {
        app.settingsRepo.settings.collect { applyUiLanguage(it.language) }
    }

    val spoken = settings.spokenLanguage
    // The translation takes visual precedence when the UI language matches it.
    val translationPrimary = settings.translationPrimary

    // The four state questions show the officials for the chosen place/district.
    val personalizedQuestions = remember(settings.jurisdiction, settings.district) {
        app.officialsRepo.data.personalize(
            app.questionRepo.questions,
            settings.jurisdiction,
            settings.district,
            java.time.LocalDate.now().toString(),
        )
    }

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
                        Icon(painterResource(destination.icon), contentDescription = stringResource(destination.labelRes))
                    },
                    label = { Text(stringResource(destination.labelRes)) },
                    selected = destination == currentDestination,
                    onClick = { currentDestination = destination },
                )
            }
        }
    ) {
        Scaffold(
            modifier = Modifier.fillMaxSize(),
            topBar = { BrandingTopBar() },
        ) { innerPadding ->
            when (currentDestination) {
                AppDestinations.LISTEN -> ListenScreen(
                    state = state,
                    ttsAvailable = ttsAvailable,
                    language = spoken,
                    translationPrimary = translationPrimary,
                    onPrimary = primary,
                    onPause = pause,
                    onNext = next,
                    onPrevious = previous,
                    onToggleKnown = engine::toggleKnown,
                    knownFilter = settings.knownFilter,
                    onFilterChange = { filter ->
                        app.appScope.launch { app.settingsRepo.update { it.copy(knownFilter = filter) } }
                    },
                    modifier = Modifier.padding(innerPadding),
                )

                AppDestinations.FLASHCARDS -> FlashcardsScreen(
                    questions = personalizedQuestions,
                    known = state.known,
                    language = spoken,
                    translationPrimary = translationPrimary,
                    onToggleKnown = engine::toggleKnown,
                    modifier = Modifier.padding(innerPadding),
                )

                AppDestinations.QUESTIONS -> QuestionsScreen(
                    questions = personalizedQuestions,
                    known = state.known,
                    currentNumber = state.current?.n,
                    language = spoken,
                    translationPrimary = translationPrimary,
                    onJump = engine::jumpTo,
                    onToggleKnown = engine::toggleKnown,
                    modifier = Modifier.padding(innerPadding),
                )

                AppDestinations.SETTINGS -> SettingsScreen(
                    settings = settings,
                    officials = app.officialsRepo.data,
                    onChange = { transform -> app.appScope.launch { app.settingsRepo.update(transform) } },
                    modifier = Modifier.padding(innerPadding),
                )

                AppDestinations.TEST -> {
                    var history by remember { mutableStateOf<List<com.yilab.civics.audio.TestRecord>>(emptyList()) }
                    LaunchedEffect(state.phase) {
                        history = withContext(kotlinx.coroutines.Dispatchers.IO) { app.settingsRepo.testHistory() }
                    }
                    com.yilab.civics.ui.TestScreen(
                        state = state,
                        history = history,
                        language = spoken,
                        translationPrimary = translationPrimary,
                        onStart = { engine.startTest() },
                        onReveal = primary,
                        onGrade = { engine.grade(it) },
                        onBackToStudy = { engine.startStudy() },
                        modifier = Modifier.padding(innerPadding),
                    )
                }
            }
        }
    }
}

/** Persistent brand mark: a small Starwave logo pinned to the upper left of every tab. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun BrandingTopBar() {
    TopAppBar(
        title = {},
        navigationIcon = {
            Image(
                painter = painterResource(R.drawable.ic_logo),
                contentDescription = null,
                alpha = 0.9f,
                modifier = Modifier
                    .padding(start = 12.dp)
                    .size(26.dp),
            )
        },
        colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
    )
}

@Composable
private fun RequestNotificationPermission() {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
    val context = LocalContext.current
    val launcher = androidx.activity.compose.rememberLauncherForActivityResult(
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
