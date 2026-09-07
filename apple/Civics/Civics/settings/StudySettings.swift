import Foundation

/// The app chrome language, independent of the system language.
enum UiLanguage: Equatable, CaseIterable {
    case system
    case english
    case chineseSimplified
    case chineseTraditional
    case spanish

    /// The spoken language this UI language corresponds to, if any.
    var speechLanguage: SpeechLanguage? {
        switch self {
        case .system: nil
        case .english: .english
        case .chineseSimplified: .chineseSimplified
        case .chineseTraditional: .chineseTraditional
        case .spanish: .spanish
        }
    }
}

struct StudySettings: Equatable {
    var speechRate: Float = 1.0
    /// Seconds to pause between question and answer. `thinkWaitForPress` = wait for a button press.
    var thinkSeconds: Int = 3
    /// Automatically move to the next question after the answer has been spoken.
    var autoAdvance: Bool = false
    var category: String = Categories.all
    var shuffle: Bool = false
    /// Speak "Question N" before the question text.
    var announceMeta: Bool = true
    var known: Set<Int> = []
    /// The language the study loop speaks.
    var spokenLanguage: SpeechLanguage = .english
    /// Also speak the English original before the translation.
    var bilingual: Bool = false
    /// App chrome language (menus, buttons, labels).
    var uiLanguage: UiLanguage = .system

    static let thinkWaitForPress = -1

    /// Kotlin-style copy so call sites read like the Android app.
    func copy(
        speechRate: Float? = nil,
        thinkSeconds: Int? = nil,
        autoAdvance: Bool? = nil,
        category: String? = nil,
        shuffle: Bool? = nil,
        announceMeta: Bool? = nil,
        known: Set<Int>? = nil,
        spokenLanguage: SpeechLanguage? = nil,
        bilingual: Bool? = nil,
        uiLanguage: UiLanguage? = nil
    ) -> StudySettings {
        StudySettings(
            speechRate: speechRate ?? self.speechRate,
            thinkSeconds: thinkSeconds ?? self.thinkSeconds,
            autoAdvance: autoAdvance ?? self.autoAdvance,
            category: category ?? self.category,
            shuffle: shuffle ?? self.shuffle,
            announceMeta: announceMeta ?? self.announceMeta,
            known: known ?? self.known,
            spokenLanguage: spokenLanguage ?? self.spokenLanguage,
            bilingual: bilingual ?? self.bilingual,
            uiLanguage: uiLanguage ?? self.uiLanguage
        )
    }
}
