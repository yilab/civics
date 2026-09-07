package com.yilab.civics.data

import android.content.Context
import org.json.JSONObject

class QuestionRepository(private val jsonSource: () -> String) {

    val questions: List<Question> by lazy { parse(jsonSource()) }

    fun deck(category: String, shuffle: Boolean): List<Question> {
        val filtered =
            if (category == Categories.ALL) questions else questions.filter { it.category == category }
        return if (shuffle) filtered.shuffled() else filtered
    }

    fun byNumber(n: Int): Question? = questions.firstOrNull { it.n == n }

    companion object {
        fun fromAssets(context: Context) = QuestionRepository {
            context.assets.open("questions.json").bufferedReader().use { it.readText() }
        }

        fun parse(json: String): List<Question> {
            val root = JSONObject(json)
            val arr = root.getJSONArray("questions")
            return List(arr.length()) { i ->
                val o = arr.getJSONObject(i)
                Question(
                    n = o.getInt("n"),
                    category = o.getString("category"),
                    question = o.getString("question"),
                    answer = o.getString("answer"),
                    spoken = o.getString("spoken"),
                    dynamic = o.optBoolean("dynamic", false),
                    note = if (o.isNull("note")) null else o.getString("note"),
                    questionZh = o.optString("questionZh").ifBlank { null },
                    answerZh = o.optString("answerZh").ifBlank { null },
                    spokenZh = o.optString("spokenZh").ifBlank { null },
                    noteZh = o.optString("noteZh").ifBlank { null },
                )
            }
        }
    }
}
