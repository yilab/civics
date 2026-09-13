package com.yilab.civics.ui

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
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
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Shuffle
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.outlined.StarOutline
import androidx.compose.material3.Card
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.FilledTonalIconButton
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.yilab.civics.R
import com.yilab.civics.data.Categories
import com.yilab.civics.data.Question
import com.yilab.civics.data.SpeechLanguage
import kotlin.random.Random

/**
 * Self-contained flip cards. The category filter, one-shot shuffle, position, and
 * flip are view-local; only the known marks are shared (persisted) state.
 */
@Composable
fun FlashcardsScreen(
    questions: List<Question>,
    known: Set<Int>,
    /** The spoken language whose translation is shown alongside the English text. */
    language: SpeechLanguage,
    /** True when the translation takes visual precedence (UI language matches it). */
    translationPrimary: Boolean,
    onToggleKnown: (Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    var category by rememberSaveable { mutableStateOf(Categories.ALL) }
    // A seed (rather than a shuffled list) keeps the one-shot shuffle saveable.
    var shuffleSeed by rememberSaveable { mutableStateOf<Int?>(null) }
    var position by rememberSaveable { mutableStateOf(0) }
    var flipped by rememberSaveable { mutableStateOf(false) }

    val deck = remember(questions, category, shuffleSeed) {
        val filtered =
            if (category == Categories.ALL) questions else questions.filter { it.category == category }
        shuffleSeed?.let { filtered.shuffled(Random(it)) } ?: filtered
    }
    val q = deck.getOrNull(position)

    Column(modifier = modifier.fillMaxSize().padding(horizontal = 20.dp, vertical = 16.dp)) {
        Row(
            modifier = Modifier.horizontalScroll(rememberScrollState()),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Categories.values.forEach { cat ->
                FilterChip(
                    selected = category == cat,
                    onClick = {
                        category = cat
                        shuffleSeed = null
                        position = 0
                        flipped = false
                    },
                    label = { Text(categoryLabel(cat)) },
                )
            }
        }
        Spacer(Modifier.height(8.dp))
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = if (deck.isEmpty()) {
                    stringResource(R.string.listen_no_questions)
                } else {
                    stringResource(R.string.listen_question_of, position + 1, deck.size)
                },
                style = MaterialTheme.typography.labelLarge,
            )
            Text(
                text = stringResource(R.string.listen_known_count, known.size),
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }

        val rotation by animateFloatAsState(
            targetValue = if (flipped) 180f else 0f,
            animationSpec = tween(350),
            label = "flip",
        )
        Card(
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f)
                .padding(vertical = 12.dp)
                .graphicsLayer {
                    rotationY = rotation
                    cameraDistance = 12f * density
                }
                .clickable(enabled = q != null) { flipped = !flipped },
        ) {
            when {
                q == null -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Text(stringResource(R.string.listen_no_questions))
                }
                rotation <= 90f -> CardFace(q, language, translationPrimary, front = true)
                // Counter-rotate the back face so it reads straight past 90°.
                else -> Box(Modifier.graphicsLayer { rotationY = 180f }) {
                    CardFace(q, language, translationPrimary, front = false)
                }
            }
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            FilledTonalIconButton(
                onClick = { position--; flipped = false },
                enabled = position > 0,
            ) {
                Icon(
                    Icons.AutoMirrored.Filled.KeyboardArrowLeft,
                    contentDescription = stringResource(R.string.listen_previous_question),
                )
            }
            val isKnown = q != null && q.n in known
            FilledTonalButton(
                onClick = { q?.let { onToggleKnown(it.n) } },
                enabled = q != null,
                modifier = Modifier.weight(1f),
            ) {
                Icon(
                    if (isKnown) Icons.Filled.Star else Icons.Outlined.StarOutline,
                    contentDescription = null,
                    modifier = Modifier.padding(end = 6.dp),
                )
                Text(stringResource(if (isKnown) R.string.listen_known else R.string.questions_mark))
            }
            FilledTonalIconButton(
                onClick = {
                    shuffleSeed = Random.nextInt()
                    position = 0
                    flipped = false
                },
                enabled = deck.isNotEmpty(),
            ) {
                Icon(Icons.Filled.Shuffle, contentDescription = stringResource(R.string.flashcards_shuffle))
            }
            FilledTonalIconButton(
                onClick = { position++; flipped = false },
                enabled = position < deck.size - 1,
            ) {
                Icon(
                    Icons.AutoMirrored.Filled.KeyboardArrowRight,
                    contentDescription = stringResource(R.string.button_next_question),
                )
            }
        }
    }
}

/** One side of the card: the question in front, the acceptable answer on the back. */
@Composable
private fun CardFace(
    q: Question,
    language: SpeechLanguage,
    translationPrimary: Boolean,
    front: Boolean,
) {
    Box(Modifier.fillMaxSize().padding(20.dp)) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .align(Alignment.TopStart)
                .verticalScroll(rememberScrollState())
                .padding(bottom = 18.dp),
        ) {
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
            if (front) {
                QuestionAnswerText(
                    english = q.question,
                    translated = q.translation(language)?.question,
                    translationPrimary = translationPrimary,
                    style = MaterialTheme.typography.headlineSmall,
                )
            } else {
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
        Text(
            stringResource(if (front) R.string.flashcards_tap_to_reveal else R.string.flashcards_tap_for_question),
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.align(Alignment.BottomEnd),
        )
    }
}
