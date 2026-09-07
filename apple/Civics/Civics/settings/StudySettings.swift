import Foundation

/// Which languages the study loop speaks.
enum SpeechMode: Equatable, CaseIterable {
    /// English only — the interview language.
    case english
    /// English first, then the Chinese translation.
    case bilingual
    /// Chinese only (for comprehension).
    case chinese
}

/// The app chrome language, independent of the system language.
enum UiLanguage: Equatable, CaseIterable {
    case system
    case english
    case chinese
}

struct StudySettings: Equatable {
    var speechRate: Float = 1.0
    /// Seconds to pause between question and answer. `thinkWaitForPress` = wait for a button press.
    var thinkSeconds: Int = StudySettings.thinkWaitForPress
    /// Automatically move to the next question after the answer has been spoken.
    var autoAdvance: Bool = false
    var category: String = Categories.all
    var shuffle: Bool = false
    /// Speak "Question N" before the question text.
    var announceMeta: Bool = true
    var known: Set<Int> = []
    /// Which languages the study loop speaks.
    var speechMode: SpeechMode = .english
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
        speechMode: SpeechMode? = nil,
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
            speechMode: speechMode ?? self.speechMode,
            uiLanguage: uiLanguage ?? self.uiLanguage
        )
    }
}
