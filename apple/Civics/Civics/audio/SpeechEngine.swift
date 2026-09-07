import Foundation

/// The language an utterance is spoken in.
enum SpeechLanguage {
    case english
    case chinese
}

@MainActor
protocol SpeechEngineCallback: AnyObject {
    func onDone(utteranceID: String)
    func onError(utteranceID: String)
}

@MainActor
protocol SpeechEngine: AnyObject {
    var callback: (any SpeechEngineCallback)? { get set }
    var speechRate: Float { get set }
    /// Speaks `text`, replacing anything queued or playing.
    func speak(utteranceID: String, text: String, language: SpeechLanguage)
    /// Stops speech; callbacks may still fire for the interrupted utterance.
    func stop()
    func shutdown()
}
