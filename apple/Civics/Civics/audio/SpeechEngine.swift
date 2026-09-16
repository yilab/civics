import Foundation

@MainActor
protocol SpeechEngineCallback: AnyObject {
    func onDone(utteranceID: String)
    func onError(utteranceID: String)
    /// Delivers the UTF-16 range of each word just before it is spoken,
    /// for karaoke-style highlighting.
    func onRange(utteranceID: String, range: NSRange)
}

extension SpeechEngineCallback {
    /// Optional: callbacks without on-screen highlighting can ignore word ranges.
    func onRange(utteranceID: String, range: NSRange) {}
}

@MainActor
protocol SpeechEngine: AnyObject {
    var callback: (any SpeechEngineCallback)? { get set }
    var speechRate: Float { get set }
    /// Speaks `text`, replacing anything queued or playing. When no voice exists
    /// for `language`, nothing is spoken and the utterance is reported done.
    func speak(utteranceID: String, text: String, language: SpeechLanguage)
    /// Stops speech; callbacks may still fire for the interrupted utterance.
    func stop()
    func shutdown()
}
