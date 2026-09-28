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
/// This is the single language list shared by speech and the UI.
enum SpeechLanguage: CaseIterable {
    case english
    case chineseSimplified
    case chineseTraditional
    case spanish
    case vietnamese
    case tagalog
    case korean
    case arabic
    case hindi
    case portuguese
    case russian

    /// Key into `Question.translations`; English has no entry (it is the canonical text).
    var translationKey: String {
        switch self {
        case .english: "en"
        case .chineseSimplified: "zh-Hans"
        case .chineseTraditional: "zh-Hant"
        case .spanish: "es"
        case .vietnamese: "vi"
        case .tagalog: "tl"
        case .korean: "ko"
        case .arabic: "ar"
        case .hindi: "hi"
        case .portuguese: "pt"
        case .russian: "ru"
        }
    }

    /// TTS locale identifier (AVSpeechSynthesisVoice language code / BCP-47 tag).
    var localeCode: String {
        switch self {
        case .english: "en-US"
        case .chineseSimplified: "zh-CN"
        case .chineseTraditional: "zh-TW"
        case .spanish: "es-US"
        case .vietnamese: "vi-VN"
        case .tagalog: "fil-PH"
        case .korean: "ko-KR"
        case .arabic: "ar-SA"
        case .hindi: "hi-IN"
        case .portuguese: "pt-BR"
        case .russian: "ru-RU"
        }
    }

    /// The "Question N." announcement prefix in this language.
    func questionPrefix(_ n: Int) -> String {
        switch self {
        case .english: "Question \(n)."
        case .chineseSimplified: "第 \(n) 题。"
        case .chineseTraditional: "第 \(n) 題。"
        case .spanish: "Pregunta \(n)."
        case .vietnamese: "Câu \(n)."
        case .tagalog: "Tanong \(n)."
        case .korean: "질문 \(n)."
        case .arabic: "السؤال \(n)."
        case .hindi: "प्रश्न \(n)."
        case .portuguese: "Pergunta \(n)."
        case .russian: "Вопрос \(n)."
        }
    }

    /// Self-name shown in the language picker (autonym).
    var displayName: String {
        switch self {
        case .english: "English"
        case .chineseSimplified: "简体中文"
        case .chineseTraditional: "繁體中文"
        case .spanish: "Español"
        case .vietnamese: "Tiếng Việt"
        case .tagalog: "Tagalog"
        case .korean: "한국어"
        case .arabic: "العربية"
        case .hindi: "हिन्दी"
        case .portuguese: "Português"
        case .russian: "Русский"
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

    /// Case/diacritic-insensitive match for the Questions-tab search. Matches
    /// the English question text, every translated question text, the question
    /// number ("12" or "Q12"), and the given (localized) category label.
    func matches(query: String, categoryName: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return true }
        var digits = trimmed.lowercased()
        if digits.hasPrefix("q") { digits.removeFirst() }
        if digits == String(n) { return true }
        if categoryName.localizedStandardContains(trimmed) { return true }
        if question.localizedStandardContains(trimmed) { return true }
        return translations.values.contains { $0.question.localizedStandardContains(trimmed) }
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

/// Filters a deck by whether questions are marked known.
enum KnownFilter: CaseIterable {
    case all
    case known
    case notKnown
}
