package com.yilab.civics.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.outlined.Circle
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.yilab.civics.R
import com.yilab.civics.data.Question
import com.yilab.civics.data.SpeechLanguage

@Composable
fun QuestionsScreen(
    questions: List<Question>,
    known: Set<Int>,
    currentNumber: Int?,
    /** The spoken language whose translation is shown alongside the English text. */
    language: SpeechLanguage,
    /** True when the translation takes visual precedence (UI language matches it). */
    translationPrimary: Boolean,
    onJump: (Int) -> Unit,
    onToggleKnown: (Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    val playingSuffix = stringResource(R.string.questions_playing_suffix)
    // When on, only the questions marked known are listed, for review.
    var showKnownOnly by remember { mutableStateOf(false) }
    val shown = if (showKnownOnly) questions.filter { it.n in known } else questions

    Column(modifier = modifier.fillMaxSize()) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                stringResource(R.string.questions_known_only),
                style = MaterialTheme.typography.bodyMedium,
                modifier = Modifier.weight(1f),
            )
            Switch(checked = showKnownOnly, onCheckedChange = { showKnownOnly = it })
        }
        LazyColumn {
            items(shown, key = { it.n }) { q ->
                val isKnown = q.n in known
                ListItem(
                    modifier = Modifier.clickable { onJump(q.n) }, // hear this question
                    overlineContent = {
                        Text(
                            "Q${q.n} · ${categoryLabel(q.category)}" + if (q.n == currentNumber) playingSuffix else "",
                            color = if (q.n == currentNumber) MaterialTheme.colorScheme.primary
                            else MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    },
                    headlineContent = {
                        Column {
                            val translated = q.translation(language)?.question
                            if (translationPrimary && translated != null) {
                                Text(translated)
                                Spacer(Modifier.height(2.dp))
                                Text(
                                    q.question,
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            } else {
                                Text(q.question)
                                translated?.let {
                                    Spacer(Modifier.height(2.dp))
                                    Text(
                                        it,
                                        style = MaterialTheme.typography.bodySmall,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    )
                                }
                            }
                        }
                    },
                    trailingContent = {
                        // Tap to unmark a known question (or mark one).
                        IconButton(onClick = { onToggleKnown(q.n) }) {
                            Icon(
                                if (isKnown) Icons.Filled.CheckCircle else Icons.Outlined.Circle,
                                contentDescription = stringResource(
                                    if (isKnown) R.string.questions_unmark else R.string.questions_mark,
                                ),
                                tint = if (isKnown) MaterialTheme.colorScheme.primary
                                else MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    },
                )
                HorizontalDivider()
            }
        }
    }
}
