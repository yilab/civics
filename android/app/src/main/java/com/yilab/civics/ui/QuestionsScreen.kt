package com.yilab.civics.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
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
    modifier: Modifier = Modifier,
) {
    val playingSuffix = stringResource(R.string.questions_playing_suffix)
    LazyColumn(modifier = modifier.fillMaxSize()) {
        items(questions, key = { it.n }) { q ->
            ListItem(
                modifier = Modifier.clickable { onJump(q.n) },
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
                    if (q.n in known) {
                        Icon(
                            Icons.Filled.CheckCircle,
                            contentDescription = stringResource(R.string.questions_known),
                            tint = MaterialTheme.colorScheme.primary,
                        )
                    }
                },
            )
            HorizontalDivider()
        }
    }
}
