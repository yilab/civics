package com.yilab.civics.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.fillMaxSize
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
import com.yilab.civics.data.Question

@Composable
fun QuestionsScreen(
    questions: List<Question>,
    known: Set<Int>,
    currentNumber: Int?,
    onJump: (Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    LazyColumn(modifier = modifier.fillMaxSize()) {
        items(questions, key = { it.n }) { q ->
            ListItem(
                modifier = Modifier.clickable { onJump(q.n) },
                overlineContent = {
                    Text(
                        "Q${q.n} · ${q.category}" + if (q.n == currentNumber) " · playing" else "",
                        color = if (q.n == currentNumber) MaterialTheme.colorScheme.primary
                        else MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                },
                headlineContent = { Text(q.question) },
                trailingContent = {
                    if (q.n in known) {
                        Icon(
                            Icons.Filled.CheckCircle,
                            contentDescription = "Known",
                            tint = MaterialTheme.colorScheme.primary,
                        )
                    }
                },
            )
            HorizontalDivider()
        }
    }
}
