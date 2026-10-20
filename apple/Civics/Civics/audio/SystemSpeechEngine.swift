import AVFoundation

/// `SpeechEngine` backed by on-device AVSpeechSynthesizer.
///
/// Unlike Android's TextToSpeech there is no async initialization step: voice
/// availability is known synchronously at construction, so no pending-utterance
/// slot is needed. There is no error delegate callback either — `didCancel`
/// stands in for it (user stops are dropped by the utterance serial check, so
/// only system-side cancels of the live utterance reach it).
@MainActor
final class SystemSpeechEngine: NSObject, SpeechEngine {

    var callback: (any SpeechEngineCallback)?
    var speechRate: Float = 1.0

    private let voices: [SpeechLanguage: AVSpeechSynthesisVoice]

    private let synthesizer = AVSpeechSynthesizer()

    /// Serial of the utterance this engine last started (0 after a stop). Callbacks
    /// for any other — a flushed or stopped utterance — are dropped: the id alone
    /// can't tell them apart when the question in flight is spoken again.
    private var currentSerial = 0
    private var lastSerial = 0

    /// Carries the utterance id and serial through the delegate callbacks.
    private final class TaggedUtterance: AVSpeechUtterance {
        let utteranceID: String
        let serial: Int

        init(utteranceID: String, text: String, serial: Int) {
            self.utteranceID = utteranceID
            self.serial = serial
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
        lastSerial += 1
        let u = TaggedUtterance(utteranceID: utteranceID, text: text, serial: lastSerial)
        u.voice = voice
        // Linear scaling around the default rate, mirroring Android's speech-rate multiplier.
        u.rate = AVSpeechUtteranceDefaultSpeechRate * speechRate
        // AVSpeechSynthesizer enqueues by default; flush first for QUEUE_FLUSH parity.
        synthesizer.stopSpeaking(at: .immediate)
        currentSerial = u.serial
        synthesizer.speak(u)
    }

    func stop() {
        currentSerial = 0
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
        let id = tagged.utteranceID, serial = tagged.serial
        Task { @MainActor in
            guard serial == self.currentSerial else { return }
            self.callback?.onDone(utteranceID: id)
        }
    }

    // Word-level progress, delivered just before each word is spoken; the range
    // holds UTF-16 offsets into the utterance string.
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        guard let tagged = utterance as? TaggedUtterance else { return }
        let id = tagged.utteranceID, serial = tagged.serial
        Task { @MainActor in
            guard serial == self.currentSerial else { return }
            self.callback?.onRange(utteranceID: id, range: characterRange)
        }
    }

    // User stops (pause/skip/flush) fail the serial check and are dropped; what
    // remains is a system-side cancel of the live utterance, reported as an error
    // so it skips the utterance instead of wedging the deck.
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        guard let tagged = utterance as? TaggedUtterance else { return }
        let id = tagged.utteranceID, serial = tagged.serial
        Task { @MainActor in
            guard serial == self.currentSerial else { return }
            self.callback?.onError(utteranceID: id)
        }
    }
}
