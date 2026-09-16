import AVFoundation

/// `SpeechEngine` backed by on-device AVSpeechSynthesizer.
///
/// Unlike Android's TextToSpeech there is no async initialization step: voice
/// availability is known synchronously at construction, so no pending-utterance
/// slot is needed. There is no error delegate callback either — `didCancel`
/// stands in for it (user stops are filtered out by StudyEngine's
/// expectedUtterance guard, so only flaky system-side cancels reach it).
@MainActor
final class SystemSpeechEngine: NSObject, SpeechEngine {

    var callback: (any SpeechEngineCallback)?
    var speechRate: Float = 1.0

    private let voices: [SpeechLanguage: AVSpeechSynthesisVoice]

    private let synthesizer = AVSpeechSynthesizer()

    /// Carries the utterance id through the delegate callbacks.
    private final class TaggedUtterance: AVSpeechUtterance {
        let utteranceID: String

        init(utteranceID: String, text: String) {
            self.utteranceID = utteranceID
            super.init(string: text)
        }

        required init?(coder: NSCoder) {
            nil
        }
    }

    override init() {
        // Probe every spoken language; a missing voice just drops out of the map.
        var found: [SpeechLanguage: AVSpeechSynthesisVoice] = [:]
        for language in SpeechLanguage.allCases {
            if let voice = AVSpeechSynthesisVoice(language: language.localeCode) {
                found[language] = voice
            }
        }
        voices = found
        super.init()
        synthesizer.delegate = self
    }

    /// True when a voice for `language` exists on this device.
    func isAvailable(_ language: SpeechLanguage) -> Bool {
        voices[language] != nil
    }

    func speak(utteranceID: String, text: String, language: SpeechLanguage) {
        // No voice for this language: don't attempt the utterance — a default
        // voice would read it as gibberish. Report it done instead (async, like
        // a natural finish) so the study loop advances as if it had been spoken.
        guard let voice = voices[language] else {
            Task { @MainActor in
                self.callback?.onDone(utteranceID: utteranceID)
            }
            return
        }
        let u = TaggedUtterance(utteranceID: utteranceID, text: text)
        u.voice = voice
        // Linear scaling around the default rate, mirroring Android's speech-rate multiplier.
        u.rate = AVSpeechUtteranceDefaultSpeechRate * speechRate
        // AVSpeechSynthesizer enqueues by default; flush first for QUEUE_FLUSH parity.
        synthesizer.stopSpeaking(at: .immediate)
        synthesizer.speak(u)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    func shutdown() {
        stop()
    }
}

extension SystemSpeechEngine: AVSpeechSynthesizerDelegate {

    // The delegate callbacks arrive off the main actor; hop back for delivery,
    // like Android's mainHandler.post.
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        guard let tagged = utterance as? TaggedUtterance else { return }
        let id = tagged.utteranceID
        Task { @MainActor in
            self.callback?.onDone(utteranceID: id)
        }
    }

    // Word-level progress, delivered just before each word is spoken; the range
    // holds UTF-16 offsets into the utterance string.
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        guard let tagged = utterance as? TaggedUtterance else { return }
        let id = tagged.utteranceID
        Task { @MainActor in
            self.callback?.onRange(utteranceID: id, range: characterRange)
        }
    }

    // Reached for user stops (pause/skip/flush — those ids are stale by delivery
    // time and ignored by StudyEngine) and for system-side cancellations. Reported
    // as an error so a flaky cancel skips the utterance instead of wedging the deck.
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        guard let tagged = utterance as? TaggedUtterance else { return }
        let id = tagged.utteranceID
        Task { @MainActor in
            self.callback?.onError(utteranceID: id)
        }
    }
}
