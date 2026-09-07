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
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.yilab.civics.R
import com.yilab.civics.audio.Phase
import com.yilab.civics.audio.StudyState
import com.yilab.civics.data.Question
import com.yilab.civics.data.SpeechLanguage

@Composable
fun ListenScreen(
    state: StudyState,
    ttsAvailable: Boolean,
    /** The spoken language whose translation is shown alongside the English text. */
    language: SpeechLanguage,
    /** True when the translation takes visual precedence (UI language matches it). */
    translationPrimary: Boolean,
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
                    stringResource(R.string.listen_no_tts),
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
                text = if (state.deckSize > 0) {
                    stringResource(R.string.listen_question_of, state.position + 1, state.deckSize)
                } else {
                    stringResource(R.string.listen_no_questions)
                },
                style = MaterialTheme.typography.labelLarge,
            )
            Text(
                text = stringResource(R.string.listen_known_count, state.known.size),
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
                        stringResource(R.string.listen_app_title),
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.SemiBold,
                    )
                    Spacer(Modifier.height(8.dp))
                    Text(
                        stringResource(R.string.listen_onboarding),
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
                            categoryLabel(q.category).uppercase(),
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    Spacer(Modifier.height(12.dp))
                    QuestionAnswerText(
                        english = q.question,
                        translated = q.translation(language)?.question,
                        translationPrimary = translationPrimary,
                        style = MaterialTheme.typography.headlineSmall,
                    )
                    if (state.answerRevealed) {
                        HorizontalDivider(Modifier.padding(vertical = 16.dp))
                        Text(
                            stringResource(R.string.listen_acceptable_answer),
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.tertiary,
                        )
                        Spacer(Modifier.height(6.dp))
                        QuestionAnswerText(
                            english = q.answer,
                            translated = q.translation(language)?.answer,
                            translationPrimary = translationPrimary,
                            style = MaterialTheme.typography.titleLarge,
                        )
                        val note = if (translationPrimary) q.translation(language)?.note ?: q.note else q.note
                        note?.let {
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
                Phase.SPEAKING_QUESTION -> stringResource(R.string.phase_speaking_question)
                Phase.THINKING -> stringResource(R.string.phase_thinking)
                Phase.SPEAKING_ANSWER -> stringResource(R.string.phase_speaking_answer)
                Phase.AWAITING_ADVANCE -> stringResource(R.string.phase_awaiting_advance)
                Phase.AWAITING_GRADE -> stringResource(R.string.phase_awaiting_grade)
                Phase.FINISHED -> ""
            },
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(bottom = 16.dp),
        )

        Button(onClick = onPrimary, modifier = Modifier.fillMaxWidth().height(56.dp)) {
            Text(
                when (state.phase) {
                    Phase.IDLE -> stringResource(R.string.button_start)
                    Phase.SPEAKING_QUESTION, Phase.THINKING -> stringResource(R.string.button_hear_answer)
                    Phase.SPEAKING_ANSWER, Phase.AWAITING_ADVANCE -> stringResource(R.string.button_next_question)
                    Phase.AWAITING_GRADE -> stringResource(R.string.button_got_it)
                    Phase.FINISHED -> stringResource(R.string.button_start)
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
                Icon(Icons.Filled.SkipPrevious, contentDescription = stringResource(R.string.listen_previous_question))
            }
            IconButton(onClick = onPause) {
                Icon(Icons.Filled.Stop, contentDescription = stringResource(R.string.listen_stop))
            }
            IconButton(onClick = onNext) {
                Icon(Icons.Filled.SkipNext, contentDescription = stringResource(R.string.button_next_question))
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
                Text(stringResource(if (isKnown) R.string.listen_known else R.string.listen_mark_known))
            }
        }
    }
}

/** Both languages are always shown; emphasis follows the UI language. */
@Composable
private fun QuestionAnswerText(
    english: String,
    translated: String?,
    translationPrimary: Boolean,
    style: androidx.compose.ui.text.TextStyle,
) {
    val secondary = MaterialTheme.typography.bodySmall.copy(color = MaterialTheme.colorScheme.onSurfaceVariant)
    if (translationPrimary && translated != null) {
        Column {
            Text(translated, style = style)
            Spacer(Modifier.height(4.dp))
            Text(english, style = secondary)
        }
    } else {
        Column {
            Text(english, style = style)
            translated?.let {
                Spacer(Modifier.height(4.dp))
                Text(it, style = secondary)
            }
        }
    }
}

/** Display name for a canonical (English) category string. */
@Composable
fun categoryLabel(category: String): String = when (category) {
    com.yilab.civics.data.Categories.ALL -> stringResource(R.string.category_all)
    "American Government" -> stringResource(R.string.category_american_government)
    "American History" -> stringResource(R.string.category_american_history)
    "Symbols & Holidays" -> stringResource(R.string.category_symbols_holidays)
    else -> category
}
