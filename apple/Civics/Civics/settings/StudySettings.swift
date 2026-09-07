import Foundation

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

    static let thinkWaitForPress = -1

    /// Kotlin-style copy so call sites read like the Android app.
    func copy(
        speechRate: Float? = nil,
        thinkSeconds: Int? = nil,
        autoAdvance: Bool? = nil,
        category: String? = nil,
        shuffle: Bool? = nil,
        announceMeta: Bool? = nil,
        known: Set<Int>? = nil
    ) -> StudySettings {
        StudySettings(
            speechRate: speechRate ?? self.speechRate,
            thinkSeconds: thinkSeconds ?? self.thinkSeconds,
            autoAdvance: autoAdvance ?? self.autoAdvance,
            category: category ?? self.category,
            shuffle: shuffle ?? self.shuffle,
            announceMeta: announceMeta ?? self.announceMeta,
            known: known ?? self.known
        )
    }
}
