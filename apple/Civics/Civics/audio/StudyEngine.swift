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

/// One graded answer inside a practice test, in ask order.
struct GradedAnswer: Equatable, Codable {
    let n: Int
    let correct: Bool
}

/// One recorded practice test, kept for history.
struct TestRecord: Equatable, Codable {
    let correct: Int
    let wrong: Int
    let passed: Bool
    let date: Date
    /// True for a shortened review session over missed questions.
    var review: Bool = false
    /// The graded answers in ask order (empty on records from older versions).
    var answers: [GradedAnswer] = []

    init(correct: Int, wrong: Int, passed: Bool, date: Date,
         review: Bool = false, answers: [GradedAnswer] = []) {
        self.correct = correct
        self.wrong = wrong
        self.passed = passed
        self.date = date
        self.review = review
        self.answers = answers
    }

    private enum CodingKeys: String, CodingKey {
        case correct, wrong, passed, date, review, answers
    }

    /// Older records lack the review/answers keys — decode them with defaults
    /// instead of failing (which would wipe the whole history).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        correct = try c.decode(Int.self, forKey: .correct)
        wrong = try c.decode(Int.self, forKey: .wrong)
        passed = try c.decode(Bool.self, forKey: .passed)
        date = try c.decode(Date.self, forKey: .date)
        review = try c.decodeIfPresent(Bool.self, forKey: .review) ?? false
        answers = try c.decodeIfPresent([GradedAnswer].self, forKey: .answers) ?? []
    }
}

/// The word currently being spoken, for karaoke-style highlighting in the UI.
struct SpokenHighlight: Equatable {
    /// Which on-screen text block the utterance belongs to.
    enum Block: Equatable {
        case question, answer
    }
    let block: Block
    /// True for translated (`z`-prefixed) utterances, false for English.
    let isTranslation: Bool
    /// The exact text handed to the speech engine.
    let text: String
    /// UTF-16 offsets of the word being spoken; nil until the first range event.
    var range: Range<Int>?

    /// Derives the highlight target from the utterance id; nil for unknown ids.
    init?(utteranceID: String, text: String) {
        // z-prefixed ids must be checked before their English counterparts.
        if utteranceID.hasPrefix("zq-") {
            block = .question; isTranslation = true
        } else if utteranceID.hasPrefix("za-") {
            block = .answer; isTranslation = true
        } else if utteranceID.hasPrefix("q-") {
            block = .question; isTranslation = false
        } else if utteranceID.hasPrefix("a-") {
            block = .answer; isTranslation = false
        } else {
            return nil
        }
        self.text = text
        range = nil
    }
}

struct StudyState: Equatable {
    var phase: Phase = .idle
    var deck: [Question] = []
    var position: Int = 0
    var current: Question?
    var answerRevealed = false
    /// Karaoke highlight for the utterance in flight; nil when nothing is spoken.
    var highlight: SpokenHighlight?
    var known: Set<Int> = []
    // Practice-test fields; inert in study mode.
    var mode: EngineMode = .study
    var testIndex = 0
    var testCorrect = 0
    var testWrong = 0
    var testOutcome: TestOutcome = .none
    /// The graded answers so far, in ask order.
    var answers: [GradedAnswer] = []
    /// True when this test is a review session over missed questions.
    var review = false
    /// Pass/fail marks scaled to the deck size (12/9 for the standard 20).
    var testPassAt = StudyState.testPassAt
    var testFailAt = StudyState.testFailAt

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
        testOutcome: TestOutcome? = nil,
        answers: [GradedAnswer]? = nil,
        review: Bool? = nil,
        testPassAt: Int? = nil,
        testFailAt: Int? = nil
    ) -> StudyState {
        StudyState(
            phase: phase ?? self.phase,
            deck: deck ?? self.deck,
            position: position ?? self.position,
            current: current ?? self.current,
            answerRevealed: answerRevealed ?? self.answerRevealed,
            // Always carried over; emit() clears it when the phase leaves speech.
            highlight: self.highlight,
            known: known ?? self.known,
            mode: mode ?? self.mode,
            testIndex: testIndex ?? self.testIndex,
            testCorrect: testCorrect ?? self.testCorrect,
            testWrong: testWrong ?? self.testWrong,
            testOutcome: testOutcome ?? self.testOutcome,
            answers: answers ?? self.answers,
            review: review ?? self.review,
            testPassAt: testPassAt ?? self.testPassAt,
            testFailAt: testFailAt ?? self.testFailAt
        )
    }
}

/// Drives the hands-free study loop: speak question -> think pause -> speak answer -> next.
@MainActor @Observable
final class StudyEngine {

    static let autoAdvanceDelaySeconds: TimeInterval = 2

    private let speech: any SpeechEngine
    private let repo: QuestionRepository
    private let officials: OfficialsData
    private let settings: any SettingsSource
    private let scheduler: any StudyScheduler
    private let onKnownChanged: (Int, Bool) -> Void
    private let stats: () -> [Int: QuestionStat]
    private let onGraded: (Int, Bool) -> Void
    private let onTestFinished: (TestRecord) -> Void

    private(set) var state = StudyState()
    private var deck: [Question] = []
    private var timer: (any ScheduledTask)?
    private var expectedUtterance: String?
    private var stateObservers: [(StudyState) -> Void] = []

    init(
        speech: any SpeechEngine,
        repo: QuestionRepository,
        officials: OfficialsData,
        settings: any SettingsSource,
        scheduler: any StudyScheduler,
        onKnownChanged: @escaping (Int, Bool) -> Void = { _, _ in },
        stats: @escaping () -> [Int: QuestionStat] = { [:] },
        onGraded: @escaping (Int, Bool) -> Void = { _, _ in },
        onTestFinished: @escaping (TestRecord) -> Void = { _ in }
    ) {
        self.speech = speech
        self.repo = repo
        self.officials = officials
        self.settings = settings
        self.scheduler = scheduler
        self.onKnownChanged = onKnownChanged
        self.stats = stats
        self.onGraded = onGraded
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
    /// Missed questions are pulled into up to half the deck when review focus is on.
    func startTest() {
        beginTest(TestPicker.pickDeck(testPool(), stats(), focus: settings.value.reviewFocus), review: false)
    }

    /// Starts a graded review session over the missed questions; a no-op when
    /// nothing is missed (the button is disabled, but the engine stays safe).
    func startReview() {
        let ranked = TestPicker.reviewRanking(testPool(), stats())
        guard !ranked.isEmpty else { return }
        beginTest(Array(ranked.prefix(StudyState.testTotal).shuffled()), review: true)
    }

    /// The questions eligible for tests: personalized, minus state questions the
    /// user can't answer yet (no place/district set) — they can't be graded on
    /// "choose your state in Settings".
    private func testPool() -> [Question] {
        let s = settings.value
        let unresolved = officials.unresolvedStateQuestions(placeCode: s.jurisdiction, district: s.district)
        return personalized(repo.questions, s).filter { !unresolved.contains($0.n) }
    }

    private func beginTest(_ questions: [Question], review: Bool) {
        cancelTimer()
        expectedUtterance = nil
        speech.stop()
        guard !questions.isEmpty else { return }
        deck = questions
        let marks = TestPicker.thresholds(deck.count)
        emit(state.copy(
            deck: deck,
            position: 0,
            mode: .test,
            testIndex: 0,
            testCorrect: 0,
            testWrong: 0,
            testOutcome: .none,
            answers: [],
            review: review,
            testPassAt: marks.passAt,
            testFailAt: marks.failAt
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
        onGraded(q.n, correct)
        let answersNow = state.answers + [GradedAnswer(n: q.n, correct: correct)]
        if correctNow >= state.testPassAt {
            finishTest(passed: true, correct: correctNow, wrong: wrongNow, answers: answersNow)
        } else if wrongNow >= state.testFailAt {
            finishTest(passed: false, correct: correctNow, wrong: wrongNow, answers: answersNow)
        } else if state.testIndex + 1 >= deck.count {
            // Ran out of questions (deck shorter than the terminal counts).
            finishTest(passed: correctNow >= state.testPassAt, correct: correctNow, wrong: wrongNow, answers: answersNow)
        } else {
            emit(state.copy(testIndex: state.testIndex + 1, testCorrect: correctNow, testWrong: wrongNow, answers: answersNow))
            speakQuestionAt(state.testIndex)
        }
    }

    /// Returns to free-form study, discarding any unfinished test.
    func startStudy() {
        cancelTimer()
        expectedUtterance = nil
        speech.stop()
        deck = personalized(repo.deck(
            category: settings.value.category,
            shuffle: settings.value.shuffle,
            knownFilter: settings.value.knownFilter,
            known: settings.value.known
        ), settings.value)
        emit(state.copy(phase: .idle, deck: deck, position: 0, mode: .study, testOutcome: .none, answers: [], review: false))
    }

    private func finishTest(passed: Bool, correct: Int, wrong: Int, answers: [GradedAnswer]) {
        cancelTimer()
        expectedUtterance = nil
        let record = TestRecord(
            correct: correct,
            wrong: wrong,
            passed: passed,
            date: Date(),
            review: state.review,
            answers: answers
        )
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
            deck = personalized(repo.deck(category: Categories.all, shuffle: false), settings.value)
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
        // While a test is in flight the deck is fixed: a settings emission (e.g. a
        // wrong answer unmarking a known question) must not swap in the study deck.
        if state.mode != .test {
            let newDeck = personalized(repo.deck(category: s.category, shuffle: s.shuffle, knownFilter: s.knownFilter, known: s.known), s)
            if deck.map(\.n) != newDeck.map(\.n) {
                deck = newDeck
                let pos = state.current.flatMap { c in deck.firstIndex { $0.n == c.n } } ?? 0
                emit(state.copy(deck: deck, position: pos))
            }
        }
        if state.known != s.known {
            emit(state.copy(known: s.known))
        }
    }

    // ------------------------------------------------------------------ helpers

    /// The question list with the four state questions filled in for the chosen
    /// place/district on today's date.
    private func personalized(_ questions: [Question], _ s: StudySettings) -> [Question] {
        officials.personalize(questions, placeCode: s.jurisdiction, district: s.district, today: OfficialsData.today())
    }

    private func speak(_ utteranceID: String, text: String, language: SpeechLanguage) {
        expectedUtterance = utteranceID
        state.highlight = SpokenHighlight(utteranceID: utteranceID, text: text)
        speech.speak(utteranceID: utteranceID, text: text, language: language)
    }

    private func cancelTimer() {
        timer?.cancel()
        timer = nil
    }

    private func emit(_ s: StudyState) {
        var s = s
        // The karaoke highlight only lives while speech is in flight; a new
        // speak() installs the next one before the speaking phase is emitted.
        if s.phase != .speakingQuestion && s.phase != .speakingAnswer {
            s.highlight = nil
        }
        state = s
        stateObservers.forEach { $0(s) }
    }
}

extension StudyEngine: SpeechEngineCallback {
    func onDone(utteranceID: String) { onUtteranceDone(utteranceID) }
    func onError(utteranceID: String) { onUtteranceError(utteranceID) }

    func onRange(utteranceID: String, range: NSRange) {
        // Stale ids (paused/replaced utterances) and cleared highlights are ignored.
        guard utteranceID == expectedUtterance, state.highlight != nil,
              let word = Range(range) else { return }
        state.highlight?.range = word
        stateObservers.forEach { $0(state) }
    }
}
