import AVFoundation

/// `SpeechEngine` backed by on-device AVSpeechSynthesizer.
///
/// Unlike Android's TextToSpeech there is no async initialization step: voice
/// availability is known synchronously at construction, so no pending-utterance
/// slot is needed. There is also no error delegate callback — `onError` exists
/// on the protocol purely for engine-logic parity and tests.
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
        let u = TaggedUtterance(utteranceID: utteranceID, text: text)
        u.voice = voices[language]
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

    // Interrupted speech (pause/skip/flush) is expected; StudyEngine's expectedUtterance
    // guard ignores stale ids — the analog of Android's ignored onStop.
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {}
}
