package com.yilab.civics.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.yilab.civics.R
import com.yilab.civics.data.Categories
import com.yilab.civics.data.SpeechLanguage
import com.yilab.civics.settings.StudySettings
import java.util.Locale
import kotlin.math.round

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun SettingsScreen(
    settings: StudySettings,
    onChange: ((StudySettings) -> StudySettings) -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        SettingsSection(R.string.settings_language) {
            Text(
                stringResource(R.string.settings_ui_language),
                style = MaterialTheme.typography.bodyLarge,
            )
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                FilterChip(
                    selected = settings.language == null,
                    onClick = { onChange { it.copy(language = null) } },
                    label = { Text(stringResource(R.string.ui_system)) },
                )
                SpeechLanguage.entries.forEach { lang ->
                    FilterChip(
                        selected = settings.language == lang,
                        onClick = { onChange { it.copy(language = lang) } },
                        label = { Text(lang.displayName) },
                    )
                }
            }
        }

        SettingsSection(R.string.settings_voice) {
            Text(
                stringResource(
                    R.string.settings_speech_rate,
                    String.format(Locale.US, "%.2f", settings.speechRate),
                ),
                style = MaterialTheme.typography.bodyLarge,
            )
            Slider(
                value = settings.speechRate,
                onValueChange = { v -> onChange { it.copy(speechRate = round(v * 20) / 20f) } },
                valueRange = 0.75f..1.5f,
            )
            SwitchRow(
                label = stringResource(R.string.settings_announce_meta),
                checked = settings.announceMeta,
                onCheckedChange = { v -> onChange { it.copy(announceMeta = v) } },
            )
        }

        SettingsSection(R.string.settings_playback) {
            Text(stringResource(R.string.settings_think_pause), style = MaterialTheme.typography.bodyLarge)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf(
                    StudySettings.THINK_WAIT_FOR_PRESS to stringResource(R.string.think_wait),
                    0 to stringResource(R.string.think_none),
                    3 to stringResource(R.string.think_seconds, 3),
                    5 to stringResource(R.string.think_seconds, 5),
                    10 to stringResource(R.string.think_seconds, 10),
                ).forEach { (seconds, label) ->
                    FilterChip(
                        selected = settings.thinkSeconds == seconds,
                        onClick = { onChange { it.copy(thinkSeconds = seconds) } },
                        label = { Text(label) },
                    )
                }
            }
            SwitchRow(
                label = stringResource(R.string.settings_auto_advance),
                checked = settings.autoAdvance,
                onCheckedChange = { v -> onChange { it.copy(autoAdvance = v) } },
            )
        }

        SettingsSection(R.string.settings_deck) {
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Categories.values.forEach { cat ->
                    FilterChip(
                        selected = settings.category == cat,
                        onClick = { onChange { it.copy(category = cat) } },
                        label = { Text(categoryLabel(cat)) },
                    )
                }
            }
            SwitchRow(
                label = stringResource(R.string.settings_shuffle),
                checked = settings.shuffle,
                onCheckedChange = { v -> onChange { it.copy(shuffle = v) } },
            )
        }

        SettingsSection(R.string.settings_progress) {
            Text(
                stringResource(R.string.settings_known_progress, settings.known.size),
                style = MaterialTheme.typography.bodyLarge,
            )
            TextButton(onClick = { onChange { it.copy(known = emptySet()) } }) {
                Text(stringResource(R.string.settings_clear_known))
            }
        }
    }
}

@Composable
private fun SettingsSection(titleRes: Int, content: @Composable () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text(
            stringResource(titleRes).uppercase(),
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.primary,
        )
        content()
    }
}

@Composable
private fun SwitchRow(label: String, checked: Boolean, onCheckedChange: (Boolean) -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(label, style = MaterialTheme.typography.bodyLarge)
        Switch(checked = checked, onCheckedChange = onCheckedChange)
    }
}
