package com.yilab.civics.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
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
import androidx.compose.ui.unit.dp
import com.yilab.civics.data.Categories
import com.yilab.civics.settings.StudySettings
import java.util.Locale
import kotlin.math.round

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
        SettingsSection("Voice") {
            Text(
                "Speech rate: ${String.format(Locale.US, "%.2f", settings.speechRate)}×",
                style = MaterialTheme.typography.bodyLarge,
            )
            Slider(
                value = settings.speechRate,
                onValueChange = { v -> onChange { it.copy(speechRate = round(v * 20) / 20f) } },
                valueRange = 0.75f..1.5f,
            )
            SwitchRow(
                label = "Announce question number",
                checked = settings.announceMeta,
                onCheckedChange = { v -> onChange { it.copy(announceMeta = v) } },
            )
        }

        SettingsSection("Playback") {
            Text("Pause before revealing the answer", style = MaterialTheme.typography.bodyLarge)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf(
                    StudySettings.THINK_WAIT_FOR_PRESS to "Wait",
                    0 to "None",
                    3 to "3s",
                    5 to "5s",
                    10 to "10s",
                ).forEach { (seconds, label) ->
                    FilterChip(
                        selected = settings.thinkSeconds == seconds,
                        onClick = { onChange { it.copy(thinkSeconds = seconds) } },
                        label = { Text(label) },
                    )
                }
            }
            SwitchRow(
                label = "Auto-advance after the answer",
                checked = settings.autoAdvance,
                onCheckedChange = { v -> onChange { it.copy(autoAdvance = v) } },
            )
        }

        SettingsSection("Deck") {
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Categories.values.forEach { cat ->
                    FilterChip(
                        selected = settings.category == cat,
                        onClick = { onChange { it.copy(category = cat) } },
                        label = { Text(if (cat == Categories.ALL) "All 128 questions" else cat) },
                    )
                }
            }
            SwitchRow(
                label = "Shuffle",
                checked = settings.shuffle,
                onCheckedChange = { v -> onChange { it.copy(shuffle = v) } },
            )
        }

        SettingsSection("Progress") {
            Text(
                "${settings.known.size} of 128 marked as known",
                style = MaterialTheme.typography.bodyLarge,
            )
            TextButton(onClick = { onChange { it.copy(known = emptySet()) } }) {
                Text("Clear known marks")
            }
        }
    }
}

@Composable
private fun SettingsSection(title: String, content: @Composable () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text(
            title.uppercase(),
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
