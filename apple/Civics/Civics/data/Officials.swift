import Foundation

/// One entry in an official's service timeline; `until` nil = no end marker.
/// Dates are ISO yyyy-MM-dd strings, comparable lexicographically.
struct OfficialEntry: Decodable {
    let name: String
    let from: String
    let until: String?
}

private struct SenatorEntry: Decodable {
    let name: String
    let from: String
    let until: String?
    let seat: Int
}

/// A state, D.C., or territory the user can pick as their place.
struct Place: Decodable, Hashable {
    let code: String
    /// "state" | "dc" | "territory"
    let kind: String
    /// U.S. House seats; 1 for at-large states, D.C., and the territories.
    let seats: Int
    let capital: String?
    /// Localized place names keyed by study language ("english", "zh-Hans", ...).
    let name: [String: String]

    func name(language: SpeechLanguage) -> String {
        name[language == .english ? "english" : language.translationKey] ?? name["english"] ?? code
    }
}

private struct OfficialsFile: Decodable {
    let places: [Place]
    let governors: [String: [OfficialEntry]]
    let senators: [String: [SenatorEntry]]
    let representatives: [String: [String: [OfficialEntry]]]
    let templates: [String: [String: String]]
}

/// State-specific answers for the four "depends on your state" questions
/// (Q23 senators, Q29 representative, Q61 governor, Q62 capital) — mirrors
/// web/src/officials.js. Officials' names stay in English in every language
/// (the interview is in English); only the surrounding sentence comes from
/// the translated templates.
final class OfficialsData {

    let places: [Place]
    private let placeByCode: [String: Place]
    private let governors: [String: [OfficialEntry]]
    private let senators: [String: [Int: [OfficialEntry]]]
    private let representatives: [String: [String: [OfficialEntry]]]
    private let templates: [String: [String: String]]

    static let stateQuestions: Set<Int> = [23, 29, 61, 62]

    init(data jsonData: Data) {
        // Same fatal-on-missing posture as QuestionRepository: the asset ships
        // with the app, so a decode failure is a build bug, not a runtime case.
        let file = try! JSONDecoder().decode(OfficialsFile.self, from: jsonData)
        places = file.places
        placeByCode = Dictionary(uniqueKeysWithValues: file.places.map { ($0.code, $0) })
        governors = file.governors
        var sen: [String: [Int: [OfficialEntry]]] = [:]
        for (code, entries) in file.senators {
            var bySeat: [Int: [OfficialEntry]] = [:]
            for e in entries {
                bySeat[e.seat, default: []].append(OfficialEntry(name: e.name, from: e.from, until: e.until))
            }
            sen[code] = bySeat
        }
        senators = sen
        representatives = file.representatives
        templates = file.templates
    }

    /// Local date in the data's yyyy-MM-dd format.
    static func today(_ date: Date = Date()) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// The 128 questions with the four state questions personalized for the
    /// chosen place/district/date. Untouched questions pass through by reference.
    func personalize(_ questions: [Question], placeCode: String?, district: Int?, today: String) -> [Question] {
        let place = placeCode.flatMap { placeByCode[$0] }
        let dist = districtFor(place, district)
        return questions.map { q in
            Self.stateQuestions.contains(q.n) ? personalizeQuestion(q, place, dist, today) : q
        }
    }

    /// State questions that cannot be answered for these settings — excluded
    /// from the practice test, since the user cannot be graded on them.
    func unresolvedStateQuestions(placeCode: String?, district: Int?) -> Set<Int> {
        guard let place = placeCode.flatMap({ placeByCode[$0] }) else { return Self.stateQuestions }
        return place.seats > 1 && districtFor(place, district) == nil ? [29] : []
    }

    /// Options for the district picker: district number to the current
    /// member's name (nil = vacant). Empty for single-seat places.
    func districtOptions(placeCode: String?, today: String) -> [(district: Int, name: String?)] {
        guard let place = placeCode.flatMap({ placeByCode[$0] }), place.seats > 1 else { return [] }
        let reps = representatives[place.code] ?? [:]
        return (1...place.seats).map { d in
            (district: d, name: pickName(reps[String(d)], today: today)?.name)
        }
    }

    // MARK: - internals

    private func districtFor(_ place: Place?, _ district: Int?) -> Int? {
        guard let place else { return nil }
        if place.seats > 1, district == nil || !(1...place.seats).contains(district!) { return nil }
        return district
    }

    private func personalizeQuestion(_ q: Question, _ place: Place?, _ district: Int?, _ today: String) -> Question {
        guard let place else { return withSpokenPrompt(q, "chooseState") }
        if q.n == 29, place.seats > 1, district == nil { return withSpokenPrompt(q, "chooseDistrict") }
        guard let en = resolveTexts(q.n, place, district, today, "english") else { return q }
        var translations = q.translations
        for (lang, tr) in translations {
            if let t = resolveTexts(q.n, place, district, today, lang) {
                translations[lang] = Translation(question: tr.question, answer: t.answer, spoken: t.answer, note: t.note)
            }
        }
        return Question(
            n: q.n, category: q.category, question: q.question,
            answer: en.answer, spoken: en.answer, dynamic: q.dynamic, note: en.note,
            translations: translations
        )
    }

    /// Replaces only the spoken text (all languages) with a "set this up" prompt;
    /// the bank's display answer and note stay.
    private func withSpokenPrompt(_ q: Question, _ key: String) -> Question {
        var translations = q.translations
        for (lang, tr) in translations {
            translations[lang] = Translation(
                question: tr.question, answer: tr.answer,
                spoken: templates[lang]?[key] ?? tr.spoken, note: tr.note
            )
        }
        return Question(
            n: q.n, category: q.category, question: q.question,
            answer: q.answer, spoken: templates["english"]?[key] ?? q.spoken,
            dynamic: q.dynamic, note: q.note, translations: translations
        )
    }

    private struct Texts {
        let answer: String
        let note: String?
    }

    private struct Pick {
        let name: String
        let stale: Bool
    }

    /// Latest entry seated on or before `today`; stale when its `until` date has
    /// passed and no successor entry exists yet (data awaiting an election refresh).
    private func pickName(_ timeline: [OfficialEntry]?, today: String) -> Pick? {
        var cur: OfficialEntry? = nil
        for e in timeline ?? [] where e.from <= today { cur = e }
        guard let c = cur else { return nil }
        return Pick(name: c.name, stale: c.until.map { today > $0 } ?? false)
    }

    private func fill(_ tpl: String, _ values: [String: String]) -> String {
        var s = tpl
        for (k, v) in values { s = s.replacingOccurrences(of: "{\(k)}", with: v) }
        return s
    }

    /// Texts for one state question in one language.
    private func resolveTexts(_ n: Int, _ place: Place, _ district: Int?, _ today: String, _ lang: String) -> Texts? {
        guard let tpl = templates[lang], let placeName = place.name[lang] else { return nil }
        let verifyNote = fill(tpl["noteVerify"] ?? "", ["place": placeName])
        func dated(_ text: String, _ stale: Bool) -> String {
            stale ? fill(tpl["outOfDate"] ?? "", ["text": text]) : text
        }
        switch n {
        case 23:
            if place.kind != "state" {
                return Texts(answer: fill(tpl["senatorsNone"] ?? "", ["place": placeName]), note: nil)
            }
            let picks = (senators[place.code] ?? [:]).sorted { $0.key < $1.key }
                .compactMap { pickName($0.value, today: today) }
            if picks.isEmpty { return Texts(answer: tpl["vacant"] ?? "", note: verifyNote) }
            let stale = picks.contains { $0.stale }
            let text = picks.count == 1
                ? picks[0].name + "."
                : fill(tpl["senators"] ?? "", ["a": picks[0].name, "b": picks[1].name])
            return Texts(answer: dated(text, stale), note: verifyNote)
        case 29:
            let districts = representatives[place.code] ?? [:]
            let key = place.seats == 1 ? districts.keys.first : district.map(String.init)
            guard let pick = pickName(districts[key ?? ""], today: today) else {
                return Texts(answer: tpl["vacant"] ?? "", note: verifyNote)
            }
            return Texts(answer: dated(pick.name + ".", pick.stale), note: verifyNote)
        case 61:
            if place.kind == "dc" { return Texts(answer: tpl["governorNoneDc"] ?? "", note: nil) }
            guard let pick = pickName(governors[place.code], today: today) else {
                return Texts(answer: tpl["vacant"] ?? "", note: verifyNote)
            }
            return Texts(answer: dated(pick.name + ".", pick.stale), note: verifyNote)
        case 62:
            if place.kind == "dc" { return Texts(answer: tpl["capitalNoneDc"] ?? "", note: nil) }
            return Texts(answer: (place.capital ?? "") + ".", note: nil)
        default:
            return nil
        }
    }
}

final class OfficialsRepository {
    private let jsonSource: () -> Data

    init(jsonSource: @escaping () -> Data) {
        self.jsonSource = jsonSource
    }

    /// Parsed once on first access, then cached.
    private(set) lazy var data: OfficialsData = OfficialsData(data: jsonSource())

    static func fromBundle() -> OfficialsRepository {
        OfficialsRepository {
            guard let url = Bundle.main.url(forResource: "officials", withExtension: "json") else {
                fatalError("officials.json is missing from the bundle")
            }
            return try! Data(contentsOf: url)
        }
    }
}
