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
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.yilab.civics.R
import com.yilab.civics.audio.Phase
import com.yilab.civics.audio.StudyState
import com.yilab.civics.audio.TestOutcome
import com.yilab.civics.audio.TestRecord

@Composable
fun TestScreen(
    state: StudyState,
    history: List<TestRecord>,
    zhPrimary: Boolean,
    onStart: () -> Unit,
    onReveal: () -> Unit,
    onGrade: (Boolean) -> Unit,
    onBackToStudy: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp, vertical = 16.dp),
    ) {
        when (state.phase) {
            Phase.FINISHED -> Finished(state, onStart, onBackToStudy)
            Phase.IDLE -> Start(history, onStart)
            else -> Running(state, zhPrimary, onReveal, onGrade)
        }
    }
}

@Composable
private fun Start(history: List<TestRecord>, onStart: () -> Unit) {
    Text(stringResource(R.string.test_title), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
    Spacer(Modifier.height(12.dp))
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text("• " + stringResource(R.string.test_rules1), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text("• " + stringResource(R.string.test_rules2), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text("• " + stringResource(R.string.test_rules3), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
    Spacer(Modifier.height(16.dp))
    Button(onClick = onStart, modifier = Modifier.fillMaxWidth().height(56.dp)) {
        Text(stringResource(R.string.test_start))
    }
    if (history.isNotEmpty()) {
        Spacer(Modifier.height(20.dp))
        Text(
            stringResource(R.string.test_history).uppercase(),
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.primary,
        )
        Spacer(Modifier.height(8.dp))
        history.take(5).forEach { r ->
            Row(
                modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    (if (r.passed) "✓ " else "✗ ") + stringResource(R.string.test_score, r.correct, r.correct + r.wrong),
                    style = MaterialTheme.typography.bodyMedium,
                    color = if (r.passed) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.error,
                )
                Text(
                    java.text.DateFormat.getDateInstance().format(java.util.Date(r.epochMillis)),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

@Composable
private fun Running(state: StudyState, zhPrimary: Boolean, onReveal: () -> Unit, onGrade: (Boolean) -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            stringResource(R.string.test_progress, state.testIndex + 1, StudyState.TEST_TOTAL),
            style = MaterialTheme.typography.labelLarge,
        )
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Text("✓ ${state.testCorrect}", color = MaterialTheme.colorScheme.primary, style = MaterialTheme.typography.labelLarge)
            Text("✗ ${state.testWrong}", color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.labelLarge)
        }
    }
    LinearProgressIndicator(
        progress = { state.testIndex / StudyState.TEST_TOTAL.toFloat() },
        modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp),
    )

    Card(modifier = Modifier.fillMaxWidth().padding(vertical = 12.dp)) {
        Column(modifier = Modifier.padding(20.dp)) {
            val q = state.current
            if (q != null) {
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text("Q${q.n}", style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.SemiBold)
                    Text(categoryLabel(q.category).uppercase(), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                Spacer(Modifier.height(12.dp))
                BilingualText(q.question, q.questionZh, zhPrimary, MaterialTheme.typography.headlineSmall)
                if (state.answerRevealed) {
                    HorizontalDivider(Modifier.padding(vertical = 16.dp))
                    Text(stringResource(R.string.listen_acceptable_answer), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.tertiary)
                    Spacer(Modifier.height(6.dp))
                    BilingualText(q.answer, q.answerZh, zhPrimary, MaterialTheme.typography.titleLarge)
                    val note = if (zhPrimary) q.noteZh ?: q.note else q.note
                    note?.let {
                        Spacer(Modifier.height(10.dp))
                        Text(it, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.error)
                    }
                }
            }
        }
    }

    Text(
        text = when (state.phase) {
            Phase.SPEAKING_QUESTION -> stringResource(R.string.phase_speaking_question)
            Phase.THINKING -> stringResource(R.string.phase_thinking)
            Phase.SPEAKING_ANSWER -> stringResource(R.string.phase_speaking_answer)
            Phase.AWAITING_GRADE -> stringResource(R.string.phase_awaiting_grade)
            else -> ""
        },
        style = MaterialTheme.typography.bodyMedium,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier.padding(bottom = 16.dp),
    )

    if (state.phase == Phase.AWAITING_GRADE) {
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.fillMaxWidth()) {
            TextButton(onClick = { onGrade(false) }, modifier = Modifier.weight(1f).height(56.dp)) {
                Text("✗ " + stringResource(R.string.button_missed_it), color = MaterialTheme.colorScheme.error)
            }
            Button(onClick = { onGrade(true) }, modifier = Modifier.weight(1f).height(56.dp)) {
                Text("✓ " + stringResource(R.string.button_got_it))
            }
        }
    } else {
        Button(onClick = onReveal, modifier = Modifier.fillMaxWidth().height(56.dp)) {
            Text(stringResource(R.string.button_hear_answer))
        }
    }
}

@Composable
private fun Finished(state: StudyState, onStart: () -> Unit, onBackToStudy: () -> Unit) {
    val passed = state.testOutcome == TestOutcome.PASSED
    Column(modifier = Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
        Spacer(Modifier.height(24.dp))
        Text(
            stringResource(if (passed) R.string.test_passed else R.string.test_failed),
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold,
            color = if (passed) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.error,
        )
        Spacer(Modifier.height(12.dp))
        Text(
            stringResource(R.string.test_score, state.testCorrect, state.testCorrect + state.testWrong),
            style = MaterialTheme.typography.displayMedium,
        )
        Spacer(Modifier.height(12.dp))
        Text(
            stringResource(if (passed) R.string.test_verdict_pass else R.string.test_verdict_fail),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(Modifier.height(24.dp))
        Button(onClick = onStart, modifier = Modifier.fillMaxWidth().height(56.dp)) {
            Text(stringResource(R.string.test_again))
        }
        Spacer(Modifier.height(8.dp))
        TextButton(onClick = onBackToStudy, modifier = Modifier.fillMaxWidth()) {
            Text(stringResource(R.string.test_back_to_study))
        }
    }
}

@Composable
private fun BilingualText(english: String, chinese: String?, zhPrimary: Boolean, style: androidx.compose.ui.text.TextStyle) {
    val secondary = MaterialTheme.typography.bodySmall.copy(color = MaterialTheme.colorScheme.onSurfaceVariant)
    if (zhPrimary && chinese != null) {
        Column {
            Text(chinese, style = style)
            Spacer(Modifier.height(4.dp))
            Text(english, style = secondary)
        }
    } else {
        Column {
            Text(english, style = style)
            chinese?.let {
                Spacer(Modifier.height(4.dp))
                Text(it, style = secondary)
            }
        }
    }
}
