import Foundation

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
    func speak(utteranceID: String, text: String)
    /// Stops speech; callbacks may still fire for the interrupted utterance.
    func stop()
    func shutdown()
}
