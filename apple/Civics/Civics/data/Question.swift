import Foundation

/// A question rendered in one non-English language.
struct Translation: Hashable, Decodable {
    let question: String
    let answer: String
    /// TTS-friendly rendering of `answer`.
    let spoken: String
    let note: String?
}

/// A language the study loop can speak, with its TTS locale and translation key.
enum SpeechLanguage: CaseIterable {
    case english
    case chineseSimplified
    case chineseTraditional
    case spanish

    /// Key into `Question.translations`; English has no entry (it is the canonical text).
    var translationKey: String {
        switch self {
        case .english: "en"
        case .chineseSimplified: "zh-Hans"
        case .chineseTraditional: "zh-Hant"
        case .spanish: "es"
        }
    }

    /// TTS locale identifier (AVSpeechSynthesisVoice language code / BCP-47 tag).
    var localeCode: String {
        switch self {
        case .english: "en-US"
        case .chineseSimplified: "zh-CN"
        case .chineseTraditional: "zh-TW"
        case .spanish: "es-US"
        }
    }

    /// The "Question N." announcement prefix in this language.
    func questionPrefix(_ n: Int) -> String {
        switch self {
        case .english: "Question \(n)."
        case .chineseSimplified: "第 \(n) 题。"
        case .chineseTraditional: "第 \(n) 題。"
        case .spanish: "Pregunta \(n)."
        }
    }
}

struct Question: Hashable, Decodable {
    let n: Int
    let category: String
    let question: String
    let answer: String
    /// TTS-friendly rendering of `answer`.
    let spoken: String
    /// True when the answer changes over time or depends on the user's state.
    let dynamic: Bool
    let note: String?
    /// Non-English renderings keyed by language code ("zh-Hans", "zh-Hant", "es");
    /// English is used as fallback when a language is absent.
    let translations: [String: Translation]

    private enum CodingKeys: String, CodingKey {
        case n, category, question, answer, spoken, dynamic, note, translations
    }

    init(n: Int, category: String, question: String, answer: String, spoken: String, dynamic: Bool, note: String?,
         translations: [String: Translation] = [:]) {
        self.n = n
        self.category = category
        self.question = question
        self.answer = answer
        self.spoken = spoken
        self.dynamic = dynamic
        self.note = note
        self.translations = translations
    }

    /// The translation for `language`, if this question has one.
    func translation(_ language: SpeechLanguage) -> Translation? {
        translations[language.translationKey]
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        n = try c.decode(Int.self, forKey: .n)
        category = try c.decode(String.self, forKey: .category)
        question = try c.decode(String.self, forKey: .question)
        answer = try c.decode(String.self, forKey: .answer)
        spoken = try c.decode(String.self, forKey: .spoken)
        // Absent key decodes as false, like Kotlin's optBoolean("dynamic", false).
        dynamic = try c.decodeIfPresent(Bool.self, forKey: .dynamic) ?? false
        note = try c.decodeIfPresent(String.self, forKey: .note)
        translations = try c.decodeIfPresent([String: Translation].self, forKey: .translations) ?? [:]
    }
}

enum Categories {
    static let all = "All"
    static let values = [all, "American Government", "American History", "Symbols & Holidays"]
}
