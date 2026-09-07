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
        static let speechMode = "speech_mode"
        static let uiLanguage = "ui_language"
    }

    private static func speechMode(_ raw: String?) -> SpeechMode {
        switch raw {
        case "bilingual": return .bilingual
        case "chinese": return .chinese
        default: return .english
        }
    }

    private static func uiLanguage(_ raw: String?) -> UiLanguage {
        switch raw {
        case "english": return .english
        case "chinese": return .chinese
        default: return .system
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
        settings = StudySettings(
            speechRate: defaults.object(forKey: Keys.speechRate) == nil
                ? 1.0 : Float(defaults.double(forKey: Keys.speechRate)),
            thinkSeconds: defaults.object(forKey: Keys.thinkSeconds) == nil
                ? StudySettings.thinkWaitForPress : defaults.integer(forKey: Keys.thinkSeconds),
            autoAdvance: bool(Keys.autoAdvance, false),
            category: defaults.string(forKey: Keys.category) ?? Categories.all,
            shuffle: bool(Keys.shuffle, false),
            announceMeta: bool(Keys.announceMeta, true),
            known: Set((defaults.stringArray(forKey: Keys.known) ?? []).compactMap(Int.init)),
            speechMode: Self.speechMode(defaults.string(forKey: Keys.speechMode)),
            uiLanguage: Self.uiLanguage(defaults.string(forKey: Keys.uiLanguage))
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
        defaults.set(s.speechMode == .bilingual ? "bilingual" : s.speechMode == .chinese ? "chinese" : "english",
                     forKey: Keys.speechMode)
        defaults.set(s.uiLanguage == .english ? "english" : s.uiLanguage == .chinese ? "chinese" : "system",
                     forKey: Keys.uiLanguage)
        settings = s
        observers.forEach { $0(s) }
    }
}
