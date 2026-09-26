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
    /// Which questions the study deck includes by known status.
    var knownFilter: KnownFilter = .all
    /// The single language choice: spoken language and app UI language.
    /// `nil` = system UI + English speech.
    var language: SpeechLanguage? = nil
    /// Two-letter place code (50 states, DC, 5 territories) personalizing Q23/29/61/62.
    var jurisdiction: String? = nil
    /// Congressional district for Q29; nil = not chosen (only needed in multi-seat states).
    var district: Int? = nil

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
        knownFilter: KnownFilter? = nil,
        language: SpeechLanguage?? = nil,
        jurisdiction: String?? = nil,
        district: Int?? = nil
    ) -> StudySettings {
        StudySettings(
            speechRate: speechRate ?? self.speechRate,
            thinkSeconds: thinkSeconds ?? self.thinkSeconds,
            autoAdvance: autoAdvance ?? self.autoAdvance,
            category: category ?? self.category,
            shuffle: shuffle ?? self.shuffle,
            announceMeta: announceMeta ?? self.announceMeta,
            known: known ?? self.known,
            knownFilter: knownFilter ?? self.knownFilter,
            language: language ?? self.language,
            jurisdiction: jurisdiction ?? self.jurisdiction,
            district: district ?? self.district
        )
    }
}
