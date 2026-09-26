package com.yilab.civics.data

import android.content.Context
import org.json.JSONObject

/** One entry in an official's service timeline; [until] null = no end marker.
 * Dates are ISO yyyy-MM-dd strings, comparable lexicographically. */
data class OfficialEntry(
    val name: String,
    val from: String,
    val until: String?,
)

/** A state, D.C., or territory the user can pick as their place. */
data class Place(
    val code: String,
    /** "state" | "dc" | "territory" */
    val kind: String,
    /** U.S. House seats; 1 for at-large states, D.C., and the territories. */
    val seats: Int,
    val capital: String?,
    /** Localized place names keyed by study language ("english", "zh-Hans", ...). */
    val names: Map<String, String>,
) {
    fun name(language: SpeechLanguage): String =
        names[if (language == SpeechLanguage.ENGLISH) "english" else language.translationKey]
            ?: names.getValue("english")
}

/**
 * State-specific answers for the four "depends on your state" questions
 * (Q23 senators, Q29 representative, Q61 governor, Q62 capital) — mirrors
 * web/src/officials.js. Officials' names stay in English in every language
 * (the interview is in English); only the surrounding sentence comes from
 * the translated templates.
 */
class OfficialsData(root: JSONObject) {

    val places: List<Place>
    private val placeByCode: Map<String, Place>
    private val governors: Map<String, List<OfficialEntry>>
    private val senators: Map<String, Map<Int, List<OfficialEntry>>>
    private val representatives: Map<String, Map<String, List<OfficialEntry>>>
    private val templates: Map<String, Map<String, String>>

    init {
        val placesArr = root.getJSONArray("places")
        val parsed = List(placesArr.length()) { i ->
            val o = placesArr.getJSONObject(i)
            val nameObj = o.getJSONObject("name")
            val names = mutableMapOf<String, String>()
            for (lang in nameObj.keys()) names[lang] = nameObj.getString(lang)
            Place(
                code = o.getString("code"),
                kind = o.getString("kind"),
                seats = o.getInt("seats"),
                capital = if (o.isNull("capital")) null else o.getString("capital"),
                names = names,
            )
        }
        places = parsed
        placeByCode = parsed.associateBy { it.code }
        governors = parseTimelines(root.getJSONObject("governors"))

        val senObj = root.getJSONObject("senators")
        val sm = LinkedHashMap<String, Map<Int, List<OfficialEntry>>>()
        for (code in senObj.keys()) {
            val arr = senObj.getJSONArray(code)
            val bySeat = LinkedHashMap<Int, MutableList<OfficialEntry>>()
            for (i in 0 until arr.length()) {
                val e = arr.getJSONObject(i)
                bySeat.getOrPut(e.getInt("seat")) { mutableListOf() }.add(entry(e))
            }
            sm[code] = bySeat
        }
        senators = sm

        val repObj = root.getJSONObject("representatives")
        val rm = LinkedHashMap<String, Map<String, List<OfficialEntry>>>()
        for (code in repObj.keys()) {
            val dObj = repObj.getJSONObject(code)
            val dm = LinkedHashMap<String, List<OfficialEntry>>()
            for (d in dObj.keys()) {
                val arr = dObj.getJSONArray(d)
                dm[d] = List(arr.length()) { i -> entry(arr.getJSONObject(i)) }
            }
            rm[code] = dm
        }
        representatives = rm

        val tObj = root.getJSONObject("templates")
        val tm = LinkedHashMap<String, Map<String, String>>()
        for (lang in tObj.keys()) {
            val l = tObj.getJSONObject(lang)
            val m = LinkedHashMap<String, String>()
            for (k in l.keys()) m[k] = l.getString(k)
            tm[lang] = m
        }
        templates = tm
    }

    /** The 128 questions with the four state questions personalized for the
     * chosen place/district/date. Untouched questions pass through by reference. */
    fun personalize(
        questions: List<Question>,
        placeCode: String?,
        district: Int?,
        today: String,
    ): List<Question> {
        val place = placeByCode[placeCode]
        val dist = districtFor(place, district)
        return questions.map { q ->
            if (q.n in STATE_QUESTIONS) personalizeQuestion(q, place, dist, today) else q
        }
    }

    /** State questions that cannot be answered for these settings — excluded
     * from the practice test, since the user cannot be graded on them. */
    fun unresolvedStateQuestions(placeCode: String?, district: Int?): Set<Int> {
        val place = placeByCode[placeCode] ?: return STATE_QUESTIONS
        return if (place.seats > 1 && districtFor(place, district) == null) setOf(29) else emptySet()
    }

    /** Options for the district picker: district number to the current
     * member's name (null = vacant). Empty for single-seat places. */
    fun districtOptions(placeCode: String?, today: String): List<Pair<Int, String?>> {
        val place = placeByCode[placeCode] ?: return emptyList()
        if (place.seats <= 1) return emptyList()
        val reps = representatives[place.code].orEmpty()
        return (1..place.seats).map { d -> d to pickName(reps[d.toString()], today)?.name }
    }

    // ------------------------------------------------------------------ internals

    private fun districtFor(place: Place?, district: Int?): Int? {
        if (place == null) return null
        return if (place.seats > 1 && (district == null || district !in 1..place.seats)) null else district
    }

    private fun personalizeQuestion(q: Question, place: Place?, district: Int?, today: String): Question {
        if (place == null) return withSpokenPrompt(q, "chooseState")
        if (q.n == 29 && place.seats > 1 && district == null) return withSpokenPrompt(q, "chooseDistrict")
        val en = resolveTexts(q.n, place, district, today, "english") ?: return q
        val translations = q.translations.mapValues { (lang, tr) ->
            val t = resolveTexts(q.n, place, district, today, lang)
            if (t == null) tr else tr.copy(answer = t.answer, spoken = t.answer, note = t.note)
        }
        return q.copy(answer = en.answer, spoken = en.answer, note = en.note, translations = translations)
    }

    /** Replaces only the spoken text (all languages) with a "set this up" prompt;
     * the bank's display answer and note stay. */
    private fun withSpokenPrompt(q: Question, key: String): Question {
        val translations = q.translations.mapValues { (lang, tr) ->
            tr.copy(spoken = templates.getValue(lang).getValue(key))
        }
        return q.copy(spoken = templates.getValue("english").getValue(key), translations = translations)
    }

    private class Texts(val answer: String, val note: String?)

    private class Pick(val name: String, val stale: Boolean)

    /** Latest entry seated on or before [today]; stale when its `until` date has
     * passed and no successor entry exists yet (data awaiting an election refresh). */
    private fun pickName(timeline: List<OfficialEntry>?, today: String): Pick? {
        var cur: OfficialEntry? = null
        for (e in timeline.orEmpty()) if (e.from <= today) cur = e
        val c = cur ?: return null
        return Pick(c.name, c.until != null && today > c.until)
    }

    private fun fill(tpl: String, values: Map<String, String>): String {
        var s = tpl
        for ((k, v) in values) s = s.replace("{$k}", v)
        return s
    }

    /** Texts for one state question in one language. */
    private fun resolveTexts(n: Int, place: Place, district: Int?, today: String, lang: String): Texts? {
        val tpl = templates.getValue(lang)
        val placeName = place.names.getValue(lang)
        val verifyNote = fill(tpl.getValue("noteVerify"), mapOf("place" to placeName))
        fun dated(text: String, stale: Boolean) =
            if (stale) fill(tpl.getValue("outOfDate"), mapOf("text" to text)) else text
        return when (n) {
            23 -> {
                if (place.kind != "state") {
                    return Texts(fill(tpl.getValue("senatorsNone"), mapOf("place" to placeName)), null)
                }
                val picks = senators[place.code].orEmpty().values.mapNotNull { pickName(it, today) }
                if (picks.isEmpty()) return Texts(tpl.getValue("vacant"), verifyNote)
                val stale = picks.any { it.stale }
                val text = if (picks.size == 1) {
                    picks[0].name + "."
                } else {
                    fill(tpl.getValue("senators"), mapOf("a" to picks[0].name, "b" to picks[1].name))
                }
                Texts(dated(text, stale), verifyNote)
            }
            29 -> {
                val districts = representatives[place.code].orEmpty()
                val key = if (place.seats == 1) districts.keys.firstOrNull() else district?.toString()
                val pick = pickName(districts[key], today)
                    ?: return Texts(tpl.getValue("vacant"), verifyNote)
                Texts(dated(pick.name + ".", pick.stale), verifyNote)
            }
            61 -> {
                if (place.kind == "dc") return Texts(tpl.getValue("governorNoneDc"), null)
                val pick = pickName(governors[place.code], today)
                    ?: return Texts(tpl.getValue("vacant"), verifyNote)
                Texts(dated(pick.name + ".", pick.stale), verifyNote)
            }
            62 -> if (place.kind == "dc") {
                Texts(tpl.getValue("capitalNoneDc"), null)
            } else {
                Texts(place.capital + ".", null)
            }
            else -> null
        }
    }

    companion object {
        /** Questions whose answers depend on the user's place. */
        val STATE_QUESTIONS = setOf(23, 29, 61, 62)

        private fun entry(o: JSONObject) = OfficialEntry(
            name = o.getString("name"),
            from = o.getString("from"),
            until = if (o.isNull("until")) null else o.getString("until"),
        )

        private fun parseTimelines(o: JSONObject): Map<String, List<OfficialEntry>> {
            val m = LinkedHashMap<String, List<OfficialEntry>>()
            for (code in o.keys()) {
                val arr = o.getJSONArray(code)
                m[code] = List(arr.length()) { i -> entry(arr.getJSONObject(i)) }
            }
            return m
        }
    }
}

class OfficialsRepository(private val jsonSource: () -> String) {

    val data: OfficialsData by lazy { OfficialsData(JSONObject(jsonSource())) }

    companion object {
        fun fromAssets(context: Context) = OfficialsRepository {
            context.assets.open("officials.json").bufferedReader().use { it.readText() }
        }
    }
}
