import Foundation

/// One language drives both the spoken loop and the app chrome.
/// `nil` (system) means: follow the device language for the UI, and speak English.
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
    /// The single language choice: spoken language and app UI language.
    /// `nil` = system UI + English speech.
    var language: SpeechLanguage? = nil

    static let thinkWaitForPress = -1

    /// The language actually spoken (English when following the system).
    var spokenLanguage: SpeechLanguage { language ?? .english }

    /// English is always spoken first; the translation follows when a
    /// non-English language is selected. This replaces the old bilingual toggle.
    var bilingual: Bool { spokenLanguage != .english }

    /// True when the translation takes visual precedence over English.
    var translationPrimary: Bool { bilingual }

    /// Kotlin-style copy so call sites read like the Android app.
    func copy(
        speechRate: Float? = nil,
        thinkSeconds: Int? = nil,
        autoAdvance: Bool? = nil,
        category: String? = nil,
        shuffle: Bool? = nil,
        announceMeta: Bool? = nil,
        known: Set<Int>? = nil,
        language: SpeechLanguage?? = nil
    ) -> StudySettings {
        StudySettings(
            speechRate: speechRate ?? self.speechRate,
            thinkSeconds: thinkSeconds ?? self.thinkSeconds,
            autoAdvance: autoAdvance ?? self.autoAdvance,
            category: category ?? self.category,
            shuffle: shuffle ?? self.shuffle,
            announceMeta: announceMeta ?? self.announceMeta,
            known: known ?? self.known,
            language: language ?? self.language
        )
    }
}
