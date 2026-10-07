package com.yilab.civics.data

import android.content.Context
import org.json.JSONObject

class QuestionRepository(private val jsonSource: () -> String) {

    val questions: List<Question> by lazy { parse(jsonSource()) }

    fun deck(
        category: String,
        shuffle: Boolean,
        knownFilter: KnownFilter = KnownFilter.ALL,
        known: Set<Int> = emptySet(),
    ): List<Question> {
        var filtered = when (category) {
            Categories.ALL -> questions
            Categories.VARIES -> questions.filter { it.dynamic }
            else -> questions.filter { it.category == category }
        }
        filtered = when (knownFilter) {
            KnownFilter.ALL -> filtered
            KnownFilter.KNOWN -> filtered.filter { it.n in known }
            KnownFilter.NOT_KNOWN -> filtered.filter { it.n !in known }
        }
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
                    translations = parseTranslations(o.optJSONObject("translations")),
                )
            }
        }

        private fun parseTranslations(node: JSONObject?): Map<String, Translation> {
            node ?: return emptyMap()
            val out = LinkedHashMap<String, Translation>()
            for (key in node.keys()) {
                val t = node.optJSONObject(key) ?: continue
                out[key] = Translation(
                    question = t.optString("question"),
                    answer = t.optString("answer"),
                    spoken = t.optString("spoken"),
                    note = if (t.isNull("note")) null else t.optString("note"),
                )
            }
            return out
        }
    }
}
