import Foundation
import Observation

enum Phase: Equatable {
    case idle, speakingQuestion, thinking, speakingAnswer, awaitingAdvance
    /// Test mode: answer revealed, waiting for a got-it/missed-it grade.
    case awaitingGrade
    /// Test mode: pass (12 correct) or fail (9 wrong) reached.
    case finished
}

/// What the engine is doing: free-form study, or a scored practice test.
enum EngineMode: Equatable {
    case study, test
}

/// The outcome of a finished practice test.
enum TestOutcome: Equatable {
    case none, passed, failed
}

/// One recorded practice test, kept for history.
struct TestRecord: Equatable, Codable {
    let correct: Int
    let wrong: Int
    let passed: Bool
    let date: Date
}

struct StudyState: Equatable {
    var phase: Phase = .idle
    var deck: [Question] = []
    var position: Int = 0
    var current: Question?
    var answerRevealed = false
    var known: Set<Int> = []
    // Practice-test fields; inert in study mode.
    var mode: EngineMode = .study
    var testIndex = 0
    var testCorrect = 0
    var testWrong = 0
    var testOutcome: TestOutcome = .none

    var deckSize: Int { deck.count }
    var playing: Bool { phase != .idle }

    static let testTotal = 20
    static let testPassAt = 12
    static let testFailAt = 9

    /// Kotlin-style copy so the engine reads like the Android original.
    func copy(
        phase: Phase? = nil,
        deck: [Question]? = nil,
        position: Int? = nil,
        current: Question? = nil,
        answerRevealed: Bool? = nil,
        known: Set<Int>? = nil,
        mode: EngineMode? = nil,
        testIndex: Int? = nil,
        testCorrect: Int? = nil,
        testWrong: Int? = nil,
        testOutcome: TestOutcome? = nil
    ) -> StudyState {
        StudyState(
            phase: phase ?? self.phase,
            deck: deck ?? self.deck,
            position: position ?? self.position,
            current: current ?? self.current,
            answerRevealed: answerRevealed ?? self.answerRevealed,
            known: known ?? self.known,
            mode: mode ?? self.mode,
            testIndex: testIndex ?? self.testIndex,
            testCorrect: testCorrect ?? self.testCorrect,
            testWrong: testWrong ?? self.testWrong,
            testOutcome: testOutcome ?? self.testOutcome
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
    private let onTestFinished: (TestRecord) -> Void

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
        onKnownChanged: @escaping (Int, Bool) -> Void = { _, _ in },
        onTestFinished: @escaping (TestRecord) -> Void = { _ in }
    ) {
        self.speech = speech
        self.repo = repo
        self.settings = settings
        self.scheduler = scheduler
        self.onKnownChanged = onKnownChanged
        self.onTestFinished = onTestFinished

        speech.callback = self
        settings.observe { [weak self] s in self?.applySettings(s) }
        applySettings(settings.value)
    }

    // ------------------------------------------------------------------ actions

    /// The single AirPod press: meaning depends on the current phase.
    /// In test mode, a press while awaiting a grade counts as "got it".
    func primaryAction() {
        switch state.phase {
        case .idle: startDeck()
        case .speakingQuestion, .thinking: revealAnswer()
        case .speakingAnswer: next()
        case .awaitingAdvance: next()
        case .awaitingGrade: grade(correct: true)
        case .finished: break
        }
    }

    func pause() {
        cancelTimer()
        expectedUtterance = nil
        speech.stop()
        emit(state.copy(phase: .idle))
    }

    /// Starts a scored practice test: 20 random questions, pass at 12, fail at 9.
    func startTest() {
        cancelTimer()
        expectedUtterance = nil
        speech.stop()
        deck = Array(repo.questions.shuffled().prefix(StudyState.testTotal))
        emit(state.copy(
            deck: deck,
            position: 0,
            mode: .test,
            testIndex: 0,
            testCorrect: 0,
            testWrong: 0,
            testOutcome: .none
        ))
        speakQuestionAt(0)
    }

    /// Records the user's self-grade for the current test question.
    func grade(correct: Bool) {
        guard state.phase == .awaitingGrade, let q = state.current else { return }
        let correctNow = state.testCorrect + (correct ? 1 : 0)
        let wrongNow = state.testWrong + (correct ? 0 : 1)
        // Mistakes resurface in study mode: a wrong answer unmarks a known question.
        if !correct && state.known.contains(q.n) {
            onKnownChanged(q.n, false)
        }
        if correctNow >= StudyState.testPassAt {
            finishTest(passed: true, correct: correctNow, wrong: wrongNow)
        } else if wrongNow >= StudyState.testFailAt {
            finishTest(passed: false, correct: correctNow, wrong: wrongNow)
        } else if state.testIndex + 1 >= deck.count {
            // Ran out of questions (deck shorter than the terminal counts).
            finishTest(passed: correctNow >= StudyState.testPassAt, correct: correctNow, wrong: wrongNow)
        } else {
            emit(state.copy(testIndex: state.testIndex + 1, testCorrect: correctNow, testWrong: wrongNow))
            speakQuestionAt(state.testIndex)
        }
    }

    /// Returns to free-form study, discarding any unfinished test.
    func startStudy() {
        cancelTimer()
        expectedUtterance = nil
        speech.stop()
        deck = repo.deck(
            category: settings.value.category,
            shuffle: settings.value.shuffle,
            knownFilter: settings.value.knownFilter,
            known: settings.value.known
        )
        emit(state.copy(phase: .idle, deck: deck, position: 0, mode: .study, testOutcome: .none))
    }

    private func finishTest(passed: Bool, correct: Int, wrong: Int) {
        cancelTimer()
        expectedUtterance = nil
        let record = TestRecord(correct: correct, wrong: wrong, passed: passed, date: Date())
        emit(state.copy(
            phase: .finished,
            answerRevealed: true,
            testCorrect: correct,
            testWrong: wrong,
            testOutcome: passed ? .passed : .failed
        ))
        speech.stop()
        onTestFinished(record)
    }

    func next() {
        guard state.mode == .study else { return } // no skipping during a test
        guard !deck.isEmpty else { return }
        let pos = (state.position + 1) % deck.count
        speakQuestionAt(pos)
    }

    /// Music-player style: while hearing the answer, repeat this question; otherwise go back one.
    func previous() {
        guard state.mode == .study else { return } // no skipping during a test
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
        let s = settings.value
        let lang = s.spokenLanguage
        // english/bilingual start with the English question; a single non-English
        // language goes straight to the translation (falling back to English when
        // no translation exists).
        if !s.bilingual, lang != .english, q.translation(lang) != nil {
            speak("zq-\(q.n)", text: translationQuestionText(q, lang), language: lang)
        } else {
            let text = s.announceMeta ? "Question \(q.n). \(q.question)" : q.question
            speak("q-\(q.n)", text: text, language: .english)
        }
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
        let s = settings.value
        let lang = s.spokenLanguage
        if !s.bilingual, lang != .english, let t = q.translation(lang) {
            speak("za-\(q.n)", text: t.spoken, language: lang)
        } else {
            speak("a-\(q.n)", text: q.spoken, language: .english)
        }
        emit(state.copy(phase: .speakingAnswer, answerRevealed: true))
    }

    /// After the answer is spoken: study mode awaits advance; test mode awaits a grade.
    private func afterAnswerSpoken() {
        if state.mode == .test {
            emit(state.copy(phase: .awaitingGrade))
        } else {
            beginAwaitingAdvance()
        }
    }

    private func onUtteranceDone(_ utteranceID: String) {
        guard utteranceID == expectedUtterance else { return }
        let s = settings.value
        let lang = s.spokenLanguage
        // z-prefixed ids must be checked before their English counterparts.
        if utteranceID.hasPrefix("zq-") {
            beginThinkPause()
        } else if utteranceID.hasPrefix("za-") {
            afterAnswerSpoken()
        } else if utteranceID.hasPrefix("q-") {
            if s.bilingual, let q = state.current, q.translation(lang) != nil {
                speak("zq-\(q.n)", text: translationQuestionText(q, lang), language: lang)
            } else {
                beginThinkPause()
            }
        } else if utteranceID.hasPrefix("a-") {
            if s.bilingual, let q = state.current, let t = q.translation(lang) {
                speak("za-\(q.n)", text: t.spoken, language: lang)
            } else {
                afterAnswerSpoken()
            }
        }
    }

    private func translationQuestionText(_ q: Question, _ language: SpeechLanguage) -> String {
        guard let t = q.translation(language) else { return q.question }
        return settings.value.announceMeta ? "\(language.questionPrefix(q.n)) \(t.question)" : t.question
    }

    private func onUtteranceError(_ utteranceID: String) {
        guard utteranceID == expectedUtterance else { return }
        // A flaky speech failure must not stall the deck: skip the utterance as
        // if it had finished.
        onUtteranceDone(utteranceID)
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
        let newDeck = repo.deck(category: s.category, shuffle: s.shuffle, knownFilter: s.knownFilter, known: s.known)
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

    private func speak(_ utteranceID: String, text: String, language: SpeechLanguage) {
        expectedUtterance = utteranceID
        speech.speak(utteranceID: utteranceID, text: text, language: language)
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
