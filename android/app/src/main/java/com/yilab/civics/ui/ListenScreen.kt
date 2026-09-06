package com.yilab.civics.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.SkipNext
import androidx.compose.material.icons.filled.SkipPrevious
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material.icons.outlined.StarOutline
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.yilab.civics.audio.Phase
import com.yilab.civics.audio.StudyState

@Composable
fun ListenScreen(
    state: StudyState,
    ttsAvailable: Boolean,
    onPrimary: () -> Unit,
    onPause: () -> Unit,
    onNext: () -> Unit,
    onPrevious: () -> Unit,
    onToggleKnown: (Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp, vertical = 16.dp),
    ) {
        if (!ttsAvailable) {
            Card(modifier = Modifier.fillMaxWidth().padding(bottom = 16.dp)) {
                Text(
                    "No text-to-speech voice is available. Install or enable Google Speech Services " +
                        "in system settings to hear questions.",
                    modifier = Modifier.padding(16.dp),
                    color = MaterialTheme.colorScheme.error,
                )
            }
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = if (state.deckSize > 0) "Question ${state.position + 1} of ${state.deckSize}" else "No questions",
                style = MaterialTheme.typography.labelLarge,
            )
            Text(
                text = "${state.known.size} known",
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        LinearProgressIndicator(
            progress = { if (state.deckSize == 0) 0f else (state.position + 1) / state.deckSize.toFloat() },
            modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp),
        )

        Card(modifier = Modifier.fillMaxWidth().padding(vertical = 12.dp)) {
            Column(modifier = Modifier.padding(20.dp)) {
                val q = state.current
                if (q == null) {
                    Text(
                        "Civics Audio Prep",
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.SemiBold,
                    )
                    Spacer(Modifier.height(8.dp))
                    Text(
                        "Press Start, put your phone away, and answer each question out loud. " +
                            "On AirPods: one press to hear the answer or continue, two presses for the next question, three to repeat.",
                        style = MaterialTheme.typography.bodyMedium,
                    )
                } else {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                    ) {
                        Text(
                            "Q${q.n}",
                            style = MaterialTheme.typography.titleMedium,
                            color = MaterialTheme.colorScheme.primary,
                            fontWeight = FontWeight.SemiBold,
                        )
                        Text(
                            q.category.uppercase(),
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    Spacer(Modifier.height(12.dp))
                    Text(q.question, style = MaterialTheme.typography.headlineSmall)
                    if (state.answerRevealed) {
                        HorizontalDivider(Modifier.padding(vertical = 16.dp))
                        Text(
                            "ACCEPTABLE ANSWER",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.tertiary,
                        )
                        Spacer(Modifier.height(6.dp))
                        Text(q.answer, style = MaterialTheme.typography.titleLarge)
                        q.note?.let {
                            Spacer(Modifier.height(10.dp))
                            Text(
                                it,
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.error,
                            )
                        }
                    }
                }
            }
        }

        Text(
            text = when (state.phase) {
                Phase.IDLE -> ""
                Phase.SPEAKING_QUESTION -> "Speaking the question — press to hear the answer"
                Phase.THINKING -> "Your turn — answer out loud, then press"
                Phase.SPEAKING_ANSWER -> "Speaking the answer"
                Phase.AWAITING_ADVANCE -> "Press for the next question"
            },
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(bottom = 16.dp),
        )

        Button(onClick = onPrimary, modifier = Modifier.fillMaxWidth().height(56.dp)) {
            Text(
                when (state.phase) {
                    Phase.IDLE -> "Start listening"
                    Phase.SPEAKING_QUESTION, Phase.THINKING -> "Hear the answer"
                    Phase.SPEAKING_ANSWER, Phase.AWAITING_ADVANCE -> "Next question"
                }
            )
        }
        Spacer(Modifier.height(12.dp))
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            IconButton(onClick = onPrevious) {
                Icon(Icons.Filled.SkipPrevious, contentDescription = "Previous question")
            }
            IconButton(onClick = onPause) {
                Icon(Icons.Filled.Stop, contentDescription = "Stop")
            }
            IconButton(onClick = onNext) {
                Icon(Icons.Filled.SkipNext, contentDescription = "Next question")
            }
            Spacer(Modifier.weight(1f))
            val q = state.current
            val isKnown = q != null && q.n in state.known
            FilledTonalButton(
                onClick = { q?.let { onToggleKnown(it.n) } },
                enabled = q != null,
            ) {
                Icon(
                    if (isKnown) Icons.Filled.Star else Icons.Outlined.StarOutline,
                    contentDescription = null,
                    modifier = Modifier.padding(end = 6.dp),
                )
                Text(if (isKnown) "Known" else "Mark known")
            }
        }
    }
}
