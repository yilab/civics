import Foundation
import Observation

enum Phase: Equatable {
    case idle, speakingQuestion, thinking, speakingAnswer, awaitingAdvance
}

struct StudyState: Equatable {
    var phase: Phase = .idle
    var deck: [Question] = []
    var position: Int = 0
    var current: Question?
    var answerRevealed = false
    var known: Set<Int> = []

    var deckSize: Int { deck.count }
    var playing: Bool { phase != .idle }

    /// Kotlin-style copy so the engine reads like the Android original.
    func copy(
        phase: Phase? = nil,
        deck: [Question]? = nil,
        position: Int? = nil,
        current: Question? = nil,
        answerRevealed: Bool? = nil,
        known: Set<Int>? = nil
    ) -> StudyState {
        StudyState(
            phase: phase ?? self.phase,
            deck: deck ?? self.deck,
            position: position ?? self.position,
            current: current ?? self.current,
            answerRevealed: answerRevealed ?? self.answerRevealed,
            known: known ?? self.known
        )
    }
}

/// Drives the hands-free study loop: speak question -> think pause -> speak answer -> next.
@MainActor @Observable
final class StudyEngine {

    static let autoAdvanceDelaySeconds: TimeInterval = 2

    private let speech: any SpeechEngine
    private let repo: QuestionRepository
    private let settings: any SettingsSource
    private let scheduler: any StudyScheduler
    private let onKnownChanged: (Int, Bool) -> Void

    private(set) var state = StudyState()
    private var deck: [Question] = []
    private var timer: (any ScheduledTask)?
    private var expectedUtterance: String?
    private var stateObservers: [(StudyState) -> Void] = []

    init(
        speech: any SpeechEngine,
        repo: QuestionRepository,
        settings: any SettingsSource,
        scheduler: any StudyScheduler,
        onKnownChanged: @escaping (Int, Bool) -> Void = { _, _ in }
    ) {
        self.speech = speech
        self.repo = repo
        self.settings = settings
        self.scheduler = scheduler
        self.onKnownChanged = onKnownChanged

        speech.callback = self
        settings.observe { [weak self] s in self?.applySettings(s) }
        applySettings(settings.value)
    }

    // ------------------------------------------------------------------ actions

    /// The single AirPod press: meaning depends on the current phase.
    func primaryAction() {
        switch state.phase {
        case .idle: startDeck()
        case .speakingQuestion, .thinking: revealAnswer()
        case .speakingAnswer, .awaitingAdvance: next()
        }
    }

    func pause() {
        cancelTimer()
        expectedUtterance = nil
        speech.stop()
        emit(state.copy(phase: .idle))
    }

    func next() {
        guard !deck.isEmpty else { return }
        let pos = (state.position + 1) % deck.count
        speakQuestionAt(pos)
    }

    /// Music-player style: while hearing the answer, repeat this question; otherwise go back one.
    func previous() {
        guard !deck.isEmpty else { return }
        switch state.phase {
        case .speakingAnswer, .awaitingAdvance:
            speakQuestionAt(state.position)
        default:
            let pos = (state.position - 1 + deck.count) % deck.count
            speakQuestionAt(pos)
        }
    }

    func jumpTo(_ questionNumber: Int) {
        var idx = deck.firstIndex { $0.n == questionNumber }
        if idx == nil {
            deck = repo.deck(category: Categories.all, shuffle: false)
            emit(state.copy(deck: deck))
            idx = deck.firstIndex { $0.n == questionNumber }
        }
        if let idx { speakQuestionAt(idx) }
    }

    func toggleKnown(_ n: Int) {
        onKnownChanged(n, !state.known.contains(n))
    }

    /// The `StateFlow.collect` analog for non-SwiftUI observers; fires immediately.
    func observeState(_ handler: @escaping (StudyState) -> Void) {
        stateObservers.append(handler)
        handler(state)
    }

    // ------------------------------------------------------------- state machine

    private func startDeck() {
        guard !deck.isEmpty else { return }
        let pos = min(max(state.position, 0), deck.count - 1)
        speakQuestionAt(pos)
    }

    private func speakQuestionAt(_ position: Int) {
        cancelTimer()
        let q = deck[position]
        let text = settings.value.announceMeta ? "Question \(q.n). \(q.question)" : q.question
        speak("q-\(q.n)", text: text)
        emit(state.copy(
            phase: .speakingQuestion,
            position: position,
            current: q,
            answerRevealed: false
        ))
    }

    private func revealAnswer() {
        cancelTimer()
        guard let q = state.current else { return }
        speak("a-\(q.n)", text: q.spoken)
        emit(state.copy(phase: .speakingAnswer, answerRevealed: true))
    }

    private func onUtteranceDone(_ utteranceID: String) {
        guard utteranceID == expectedUtterance else { return }
        switch utteranceID.prefix(2) {
        case "q-": beginThinkPause()
        case "a-": beginAwaitingAdvance()
        default: break
        }
    }

    private func onUtteranceError(_ utteranceID: String) {
        guard utteranceID == expectedUtterance else { return }
        // A speech failure should not cascade through the deck; stop where we are.
        pause()
    }

    private func beginThinkPause() {
        let think = settings.value.thinkSeconds
        switch think {
        case 0:
            revealAnswer()
        case 1...:
            emit(state.copy(phase: .thinking))
            timer = scheduler.run(after: TimeInterval(think)) { [weak self] in self?.revealAnswer() }
        default:
            emit(state.copy(phase: .thinking)) // wait for press
        }
    }

    private func beginAwaitingAdvance() {
        emit(state.copy(phase: .awaitingAdvance))
        if settings.value.autoAdvance {
            timer = scheduler.run(after: Self.autoAdvanceDelaySeconds) { [weak self] in self?.next() }
        }
    }

    // ------------------------------------------------------------------ settings

    private func applySettings(_ s: StudySettings) {
        speech.speechRate = s.speechRate
        let newDeck = repo.deck(category: s.category, shuffle: s.shuffle)
        if deck.map(\.n) != newDeck.map(\.n) {
            deck = newDeck
            let pos = state.current.flatMap { c in deck.firstIndex { $0.n == c.n } } ?? 0
            emit(state.copy(deck: deck, position: pos))
        }
        if state.known != s.known {
            emit(state.copy(known: s.known))
        }
    }

    // ------------------------------------------------------------------ helpers

    private func speak(_ utteranceID: String, text: String) {
        expectedUtterance = utteranceID
        speech.speak(utteranceID: utteranceID, text: text)
    }

    private func cancelTimer() {
        timer?.cancel()
        timer = nil
    }

    private func emit(_ s: StudyState) {
        state = s
        stateObservers.forEach { $0(s) }
    }
}

extension StudyEngine: SpeechEngineCallback {
    func onDone(utteranceID: String) { onUtteranceDone(utteranceID) }
    func onError(utteranceID: String) { onUtteranceError(utteranceID) }
}
