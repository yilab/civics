import Foundation
import Observation

/// The `StateFlow<StudySettings>` analog consumed by the study engine.
@MainActor
protocol SettingsSource: AnyObject {
    var value: StudySettings { get }
    /// Registers an observer that fires immediately and on every change, like `StateFlow.collect`.
    func observe(_ onChange: @escaping (StudySettings) -> Void)
}

/// Persists study settings in UserDefaults — the DataStore Preferences analog.
@MainActor @Observable
final class SettingsRepository: SettingsSource {

    private enum Keys {
        static let speechRate = "speech_rate"
        static let thinkSeconds = "think_seconds"
        static let autoAdvance = "auto_advance"
        static let category = "category"
        static let shuffle = "shuffle"
        static let announceMeta = "announce_meta"
        static let known = "known"
        static let knownFilter = "known_filter"
        /// The single merged language setting.
        static let language = "language"
        /// Legacy keys read once for migration, never written.
        static let spokenLanguage = "spoken_language"
        static let bilingual = "bilingual"
        static let uiLanguage = "ui_language"
        static let legacySpeechMode = "speech_mode"
        static let testHistory = "test_history"
    }

    private static func language(_ raw: String?) -> SpeechLanguage? {
        switch raw {
        case "english": return .english
        case "zh-Hans", "chinese": return .chineseSimplified
        case "zh-Hant": return .chineseTraditional
        case "es": return .spanish
        case "vi": return .vietnamese
        case "tl": return .tagalog
        case "ko": return .korean
        case "ar": return .arabic
        case "hi": return .hindi
        case "pt": return .portuguese
        case "ru": return .russian
        default: return nil
        }
    }

    private static func languageName(_ language: SpeechLanguage?) -> String? {
        guard let language else { return nil }
        return language.translationKey == "en" ? "english" : language.translationKey
    }

    private static func knownFilter(_ raw: String?) -> KnownFilter {
        switch raw {
        case "known": return .known
        case "notKnown": return .notKnown
        default: return .all
        }
    }

    private let defaults: UserDefaults
    private var observers: [(StudySettings) -> Void] = []

    private(set) var settings: StudySettings

    var value: StudySettings { settings }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        func bool(_ key: String, _ fallback: Bool) -> Bool {
            defaults.object(forKey: key) == nil ? fallback : defaults.bool(forKey: key)
        }
        // UserDefaults returns zero-values for absent keys, so presence is checked explicitly
        // to keep the StudySettings defaults, like DataStore's null-means-default.

        // Resolve the merged language, migrating from the older split keys.
        // Priority: new `language` key, then ui_language, then spoken_language,
        // then the oldest speech_mode.
        let resolvedLanguage = Self.language(defaults.string(forKey: Keys.language))
            ?? Self.language(defaults.string(forKey: Keys.uiLanguage))
            ?? Self.language(defaults.string(forKey: Keys.spokenLanguage))
            ?? (defaults.string(forKey: Keys.legacySpeechMode).map { $0 == "english" ? "english" : "zh-Hans" }
                .flatMap(Self.language))

        settings = StudySettings(
            speechRate: defaults.object(forKey: Keys.speechRate) == nil
                ? 1.0 : Float(defaults.double(forKey: Keys.speechRate)),
            thinkSeconds: defaults.object(forKey: Keys.thinkSeconds) == nil
                ? 3 : defaults.integer(forKey: Keys.thinkSeconds),
            autoAdvance: bool(Keys.autoAdvance, false),
            category: defaults.string(forKey: Keys.category) ?? Categories.all,
            shuffle: bool(Keys.shuffle, false),
            announceMeta: bool(Keys.announceMeta, true),
            known: Set((defaults.stringArray(forKey: Keys.known) ?? []).compactMap(Int.init)),
            knownFilter: Self.knownFilter(defaults.string(forKey: Keys.knownFilter)),
            language: resolvedLanguage
        )
    }

    func observe(_ onChange: @escaping (StudySettings) -> Void) {
        observers.append(onChange)
        onChange(settings)
    }

    func update(_ transform: (StudySettings) -> StudySettings) {
        let s = transform(settings)
        // All keys written in one pass, like DataStore's atomic edit.
        defaults.set(Double(s.speechRate), forKey: Keys.speechRate)
        defaults.set(s.thinkSeconds, forKey: Keys.thinkSeconds)
        defaults.set(s.autoAdvance, forKey: Keys.autoAdvance)
        defaults.set(s.category, forKey: Keys.category)
        defaults.set(s.shuffle, forKey: Keys.shuffle)
        defaults.set(s.announceMeta, forKey: Keys.announceMeta)
        defaults.set(s.known.map(String.init), forKey: Keys.known)
        defaults.set(s.knownFilter == .known ? "known" : s.knownFilter == .notKnown ? "notKnown" : "all",
                     forKey: Keys.knownFilter)
        // The merged language is written under the single `language` key; nil clears it (system).
        defaults.set(Self.languageName(s.language), forKey: Keys.language)
        settings = s
        observers.forEach { $0(s) }
    }

    // MARK: - Test history

    /// Recorded practice tests, most recent first.
    var testHistory: [TestRecord] {
        get {
            guard let data = defaults.data(forKey: Keys.testHistory),
                  let records = try? JSONDecoder().decode([TestRecord].self, from: data)
            else { return [] }
            return records
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: Keys.testHistory)
            }
        }
    }

    /// Appends a finished test, keeping the 20 most recent.
    func recordTest(_ record: TestRecord) {
        testHistory = ([record] + testHistory).prefix(20).map { $0 }
    }
}
