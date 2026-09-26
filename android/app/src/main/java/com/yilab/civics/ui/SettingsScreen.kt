package com.yilab.civics.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Slider
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.yilab.civics.R
import com.yilab.civics.data.Categories
import com.yilab.civics.data.OfficialsData
import com.yilab.civics.data.SpeechLanguage
import com.yilab.civics.settings.StudySettings
import java.time.LocalDate
import java.util.Locale
import kotlin.math.round

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun SettingsScreen(
    settings: StudySettings,
    officials: OfficialsData,
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

        LocationSection(settings, officials, onChange)

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
private fun LocationSection(
    settings: StudySettings,
    officials: OfficialsData,
    onChange: ((StudySettings) -> StudySettings) -> Unit,
) {
    var showPlacePicker by remember { mutableStateOf(false) }
    var showDistrictPicker by remember { mutableStateOf(false) }
    val uriHandler = LocalUriHandler.current
    val place = officials.places.firstOrNull { it.code == settings.jurisdiction }
    val districts = remember(place?.code) {
        place?.let { officials.districtOptions(it.code, LocalDate.now().toString()) } ?: emptyList()
    }

    SettingsSection(R.string.settings_location) {
        Text(stringResource(R.string.settings_your_state), style = MaterialTheme.typography.bodyLarge)
        OutlinedButton(onClick = { showPlacePicker = true }) {
            Text(place?.name(settings.spokenLanguage) ?: stringResource(R.string.settings_not_set))
        }
        if (place != null && place.seats > 1) {
            Text(stringResource(R.string.settings_district), style = MaterialTheme.typography.bodyLarge)
            OutlinedButton(onClick = { showDistrictPicker = true }) {
                Text(
                    settings.district?.let { d ->
                        val name = districts.firstOrNull { it.first == d }?.second
                        stringResource(R.string.settings_district) + " " + d + (name?.let { " · $it" } ?: "")
                    } ?: stringResource(R.string.settings_not_set),
                )
            }
            TextButton(onClick = {
                uriHandler.openUri("https://www.house.gov/representatives/find-your-representative")
            }) {
                Text(stringResource(R.string.settings_find_district))
            }
        }
        Text(
            stringResource(R.string.settings_location_hint),
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }

    if (showPlacePicker) {
        AlertDialog(
            onDismissRequest = { showPlacePicker = false },
            confirmButton = {},
            text = {
                LazyColumn(modifier = Modifier.heightIn(max = 480.dp)) {
                    item {
                        PickerRow(stringResource(R.string.settings_not_set)) {
                            showPlacePicker = false
                            onChange { it.copy(jurisdiction = null, district = null) }
                        }
                    }
                    items(officials.places) { p ->
                        PickerRow(p.name(settings.spokenLanguage)) {
                            showPlacePicker = false
                            onChange { it.copy(jurisdiction = p.code, district = null) }
                        }
                    }
                }
            },
        )
    }
    if (showDistrictPicker) {
        AlertDialog(
            onDismissRequest = { showDistrictPicker = false },
            confirmButton = {},
            text = {
                LazyColumn(modifier = Modifier.heightIn(max = 480.dp)) {
                    item {
                        PickerRow(stringResource(R.string.settings_not_set)) {
                            showDistrictPicker = false
                            onChange { it.copy(district = null) }
                        }
                    }
                    items(districts) { (d, name) ->
                        PickerRow(
                            stringResource(R.string.settings_district) + " " + d + (name?.let { " · $it" } ?: ""),
                        ) {
                            showDistrictPicker = false
                            onChange { it.copy(district = d) }
                        }
                    }
                }
            },
        )
    }
}

@Composable
private fun PickerRow(label: String, onClick: () -> Unit) {
    TextButton(onClick = onClick, modifier = Modifier.fillMaxWidth()) {
        Text(label, modifier = Modifier.fillMaxWidth())
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
