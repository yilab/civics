import Foundation
import Testing
@testable import Civics

// MARK: - Fakes

private final class FakeSpeechEngine: SpeechEngine {
    var callback: (any SpeechEngineCallback)?
    var speechRate: Float = 1.0
    private(set) var spoken: [(utteranceID: String, text: String, language: SpeechLanguage)] = []
    private(set) var stopCount = 0

    /// Languages with no installed voice: their utterances are reported done via
    /// `skipScheduler` instead of playing, mirroring SystemSpeechEngine's skip.
    var unavailable: Set<SpeechLanguage> = []
    var skipScheduler: ManualScheduler?

    func speak(utteranceID: String, text: String, language: SpeechLanguage) {
        spoken.append((utteranceID, text, language))
        if unavailable.contains(language), let skipScheduler {
            skipScheduler.run(after: 0) { [weak self] in
                self?.callback?.onDone(utteranceID: utteranceID)
            }
        }
    }

    func stop() {
        stopCount += 1
    }

    func shutdown() {}

    /// Simulates the TTS finishing the most recent utterance.
    func finishLast() {
        callback?.onDone(utteranceID: spoken.last!.utteranceID)
    }
}

/// The MutableStateFlow analog: assignment notifies observers.
private final class SettingsBox: SettingsSource {
    var value: StudySettings {
        didSet { observers.forEach { $0(value) } }
    }
    private var observers: [(StudySettings) -> Void] = []

    init(_ value: StudySettings) {
        self.value = value
    }

    func observe(_ onChange: @escaping (StudySettings) -> Void) {
        observers.append(onChange)
        onChange(value)
    }
}

/// The runTest-virtual-time analog: `advance(by:)` fires due timers in
/// deadline order, including timers scheduled by fired actions.
private final class ManualScheduler: StudyScheduler {

    private final class PendingTimer {
        let deadline: TimeInterval
        let action: () -> Void
        var cancelled = false
        init(deadline: TimeInterval, action: @escaping () -> Void) {
            self.deadline = deadline
            self.action = action
        }
    }

    private final class TaskHandle: ScheduledTask {
        let timer: PendingTimer
        init(timer: PendingTimer) { self.timer = timer }
        func cancel() { timer.cancelled = true }
    }

    private var pending: [PendingTimer] = []
    private var now: TimeInterval = 0

    // Constructible from default-argument expressions, which evaluate nonisolated.
    nonisolated init() {}

    func run(after seconds: TimeInterval, _ action: @escaping () -> Void) -> any ScheduledTask {
        let timer = PendingTimer(deadline: now + seconds, action: action)
        pending.append(timer)
        return TaskHandle(timer: timer)
    }

    func advance(by seconds: TimeInterval) {
        let target = now + seconds
        while let next = pending.filter({ !$0.cancelled && $0.deadline <= target })
            .min(by: { $0.deadline < $1.deadline }) {
            now = max(now, next.deadline)
            pending.removeAll { $0 === next }
            next.action()
        }
        now = target
    }
}

// MARK: - Tests

@MainActor
struct StudyEngineTests {

    private let repo = QuestionRepository.fromBundle()
    private let officials = OfficialsRepository.fromBundle().data

    private func makeEngine(
        settings: SettingsBox,
        scheduler: ManualScheduler = ManualScheduler(),
        repo: QuestionRepository? = nil,
        onKnownChanged: @escaping (Int, Bool) -> Void = { _, _ in },
        stats: @escaping () -> [Int: QuestionStat] = { [:] },
        onGraded: @escaping (Int, Bool) -> Void = { _, _ in },
        onTestFinished: @escaping (TestRecord) -> Void = { _ in }
    ) -> (StudyEngine, FakeSpeechEngine) {
        let speech = FakeSpeechEngine()
        let engine = StudyEngine(
            speech: speech,
            repo: repo ?? self.repo,
            officials: officials,
            settings: settings,
            scheduler: scheduler,
            onKnownChanged: onKnownChanged,
            stats: stats,
            onGraded: onGraded,
            onTestFinished: onTestFinished
        )
        return (engine, speech)
    }

    @Test func startsIdleWithTheFullDeck() {
        let (engine, _) = makeEngine(settings: SettingsBox(StudySettings()))
        #expect(engine.state.phase == .idle)
        #expect(engine.state.deckSize == 128)
    }

    @Test func primaryActionSpeaksTheFirstQuestionWithItsNumber() {
        let (engine, speech) = makeEngine(settings: SettingsBox(StudySettings()))
        engine.primaryAction()
        #expect(engine.state.phase == .speakingQuestion)
        #expect(speech.spoken.last?.utteranceID == "q-1")
        #expect(speech.spoken.last?.text.hasPrefix("Question 1.") == true)
        #expect(!engine.state.answerRevealed)
    }

    @Test func waitsForPressThenSpeaksTheTTSCleanedAnswer() {
        let (engine, speech) = makeEngine(settings: SettingsBox(StudySettings()))
        engine.primaryAction()
        speech.finishLast() // question finished
        #expect(engine.state.phase == .thinking)

        engine.primaryAction() // user press -> reveal
        #expect(engine.state.phase == .speakingAnswer)
        #expect(engine.state.answerRevealed)
        #expect(speech.spoken.last?.utteranceID == "a-1")

        speech.finishLast() // answer finished
        #expect(engine.state.phase == .awaitingAdvance)

        engine.primaryAction() // user press -> next
        #expect(engine.state.phase == .speakingQuestion)
        #expect(speech.spoken.last?.utteranceID == "q-2")
        #expect(engine.state.position == 1)
    }

    @Test func pressDuringTheQuestionSkipsStraightToTheAnswer() {
        let (engine, speech) = makeEngine(settings: SettingsBox(StudySettings()))
        engine.primaryAction()
        engine.primaryAction()
        #expect(engine.state.phase == .speakingAnswer)
        #expect(speech.spoken.last?.utteranceID == "a-1")
    }

    @Test func timedThinkPauseRevealsTheAnswerAutomatically() {
        let scheduler = ManualScheduler()
        let box = SettingsBox(StudySettings(thinkSeconds: 5))
        let (engine, speech) = makeEngine(settings: box, scheduler: scheduler)
        engine.primaryAction()
        speech.finishLast()
        #expect(engine.state.phase == .thinking)
        scheduler.advance(by: 5)
        #expect(engine.state.phase == .speakingAnswer)
        #expect(speech.spoken.last?.utteranceID == "a-1")
    }

    @Test func autoAdvanceMovesToTheNextQuestionAfterTheAnswer() {
        let scheduler = ManualScheduler()
        let box = SettingsBox(StudySettings(thinkSeconds: 0, autoAdvance: true))
        let (engine, speech) = makeEngine(settings: box, scheduler: scheduler)
        engine.primaryAction()
        speech.finishLast() // question done -> think 0 -> answer immediately
        #expect(engine.state.phase == .speakingAnswer)
        speech.finishLast() // answer done
        #expect(engine.state.phase == .awaitingAdvance)
        scheduler.advance(by: StudyEngine.autoAdvanceDelaySeconds)
        #expect(speech.spoken.last?.utteranceID == "q-2")
    }

    @Test func nextWrapsAroundTheDeck() {
        let (engine, speech) = makeEngine(settings: SettingsBox(StudySettings()))
        engine.jumpTo(128)
        #expect(speech.spoken.last?.utteranceID == "q-128")
        engine.next()
        #expect(speech.spoken.last?.utteranceID == "q-1")
        #expect(engine.state.position == 0)
    }

    @Test func previousRepeatsTheQuestionWhileTheAnswerIsPlayingGoesBackOtherwise() {
        let (engine, speech) = makeEngine(settings: SettingsBox(StudySettings()))
        engine.primaryAction() // Q1
        engine.next() // Q2
        speech.finishLast() // Q2 question done -> thinking
        engine.primaryAction() // reveal answer
        #expect(speech.spoken.last?.utteranceID == "a-2")
        engine.previous() // repeat Q2
        #expect(speech.spoken.last?.utteranceID == "q-2")
        #expect(engine.state.position == 1)
        engine.previous() // back to Q1
        #expect(speech.spoken.last?.utteranceID == "q-1")
    }

    @Test func pauseSilencesSpeechAndIgnoresStaleUtteranceCallbacks() {
        let (engine, speech) = makeEngine(settings: SettingsBox(StudySettings()))
        engine.primaryAction()
        engine.pause()
        #expect(engine.state.phase == .idle)
        #expect(speech.stopCount == 1)
        speech.finishLast() // stale callback after pause
        #expect(engine.state.phase == .idle)
        speech.callback?.onError(utteranceID: "q-1") // stale cancel/error after pause
        #expect(engine.state.phase == .idle)
    }

    @Test func jumpingToAQuestionOutsideTheFilteredDeckUsesTheFullDeck() {
        let settings = SettingsBox(StudySettings(category: "Symbols & Holidays"))
        let (engine, speech) = makeEngine(settings: settings)
        #expect(engine.state.deckSize == 10)
        engine.jumpTo(5) // American Government question
        #expect(speech.spoken.last?.utteranceID == "q-5")
        #expect(engine.state.deckSize == 128)
    }

    @Test func categoryChangeRebuildsTheDeck() {
        let settings = SettingsBox(StudySettings())
        let (engine, _) = makeEngine(settings: settings)
        settings.value = settings.value.copy(category: "American History", shuffle: false)
        #expect(engine.state.deckSize == 46)
        #expect(engine.state.position == 0)
    }

    @Test func knownFilterLimitsTheDeck() {
        let settings = SettingsBox(StudySettings(known: [1, 2]))
        let (engine, _) = makeEngine(settings: settings)
        settings.value = settings.value.copy(knownFilter: .notKnown)
        #expect(engine.state.deckSize == 126)
        settings.value = settings.value.copy(knownFilter: .known)
        #expect(engine.state.deckSize == 2)
        // Marking a question known under the not-known filter shrinks the deck.
        settings.value = settings.value.copy(known: [1, 2, 5], knownFilter: .notKnown)
        #expect(engine.state.deckSize == 125)
    }

    @Test func emptyFilteredDeckIsSafe() {
        let settings = SettingsBox(StudySettings(knownFilter: .known)) // nothing known yet
        let (engine, speech) = makeEngine(settings: settings)
        #expect(engine.state.deckSize == 0)
        engine.primaryAction()
        engine.next()
        #expect(engine.state.phase == .idle)
        #expect(speech.spoken.isEmpty)
    }

    @Test func speechRateChangesAreAppliedToTheSpeechEngine() {
        let settings = SettingsBox(StudySettings())
        let (_, speech) = makeEngine(settings: settings)
        settings.value = settings.value.copy(speechRate: 1.4)
        #expect(speech.speechRate == 1.4)
    }

    @Test func toggleKnownReportsThroughTheCallback() {
        var events: [(Int, Bool)] = []
        let settings = SettingsBox(StudySettings(known: [3]))
        let (engine, _) = makeEngine(settings: settings) { n, known in events.append((n, known)) }
        #expect(engine.state.known == [3])
        engine.toggleKnown(3)
        engine.toggleKnown(7)
        #expect(events.count == 2)
        #expect(events[0].0 == 3 && events[0].1 == false)
        #expect(events[1].0 == 7 && events[1].1 == true)
    }

    @Test func aSpeechErrorSkipsTheUtteranceAndKeepsTheDeckMoving() {
        let (engine, speech) = makeEngine(settings: SettingsBox(StudySettings(thinkSeconds: 0, autoAdvance: true)))
        engine.primaryAction()
        speech.callback?.onError(utteranceID: "q-1")
        // The failed question counts as done: think 0 -> the answer is spoken.
        #expect(engine.state.phase == .speakingAnswer)
        #expect(speech.spoken.last?.utteranceID == "a-1")
        speech.callback?.onError(utteranceID: "a-1")
        #expect(engine.state.phase == .awaitingAdvance)
    }

    @Test func missingTranslationVoiceSkipsTranslatedUtterancesWithoutWedging() {
        // No zh voice on the device: the fake reports translated utterances done
        // immediately, like SystemSpeechEngine's missing-voice skip.
        let scheduler = ManualScheduler()
        let box = SettingsBox(StudySettings(thinkSeconds: 0, autoAdvance: true, language: .chineseSimplified))
        let speech = FakeSpeechEngine()
        speech.unavailable = [.chineseSimplified]
        speech.skipScheduler = scheduler
        let engine = StudyEngine(speech: speech, repo: repo, officials: officials, settings: box, scheduler: scheduler)

        engine.primaryAction()
        #expect(speech.spoken.last?.utteranceID == "q-1") // English question plays
        speech.finishLast() // English done -> zh question requested but skipped
        #expect(speech.spoken.last?.utteranceID == "zq-1")
        scheduler.advance(by: 0) // skip callback -> think 0 -> English answer
        #expect(engine.state.phase == .speakingAnswer)
        #expect(speech.spoken.last?.utteranceID == "a-1")
        speech.finishLast() // English done -> zh answer requested but skipped
        #expect(speech.spoken.last?.utteranceID == "za-1")
        scheduler.advance(by: 0)
        #expect(engine.state.phase == .awaitingAdvance)
        scheduler.advance(by: StudyEngine.autoAdvanceDelaySeconds)
        #expect(speech.spoken.last?.utteranceID == "q-2") // the deck kept moving
    }

    @Test func announceMetaSettingDropsTheQuestionNumberPrefix() {
        let (engine, speech) = makeEngine(settings: SettingsBox(StudySettings(announceMeta: false)))
        engine.primaryAction()
        #expect(speech.spoken.last?.text == repo.byNumber(1)?.question)
    }

    // MARK: - Karaoke highlighting

    @Test func speakSetsTheHighlightTargetWithoutARange() {
        let (engine, speech) = makeEngine(settings: SettingsBox(StudySettings()))
        engine.primaryAction()
        let h = engine.state.highlight
        #expect(h?.block == .question)
        #expect(h?.isTranslation == false)
        #expect(h?.text == speech.spoken.last?.text)
        #expect(h?.range == nil)
    }

    @Test func rangeEventsUpdateTheHighlightWhenTheIdMatches() {
        let (engine, speech) = makeEngine(settings: SettingsBox(StudySettings()))
        engine.primaryAction()
        speech.callback?.onRange(utteranceID: "q-1", range: NSRange(location: 10, length: 4))
        #expect(engine.state.highlight?.range == 10..<14)
        speech.callback?.onRange(utteranceID: "q-1", range: NSRange(location: 15, length: 2))
        #expect(engine.state.highlight?.range == 15..<17)
    }

    @Test func staleRangeEventsAreIgnored() {
        let (engine, speech) = makeEngine(settings: SettingsBox(StudySettings()))
        engine.primaryAction()
        speech.callback?.onRange(utteranceID: "q-2", range: NSRange(location: 0, length: 3))
        #expect(engine.state.highlight?.range == nil)
    }

    @Test func pauseClearsTheHighlight() {
        let (engine, speech) = makeEngine(settings: SettingsBox(StudySettings()))
        engine.primaryAction()
        speech.callback?.onRange(utteranceID: "q-1", range: NSRange(location: 0, length: 7))
        #expect(engine.state.highlight?.range != nil)
        engine.pause()
        #expect(engine.state.highlight == nil)
        // A late range event for the paused utterance is ignored too.
        speech.callback?.onRange(utteranceID: "q-1", range: NSRange(location: 8, length: 3))
        #expect(engine.state.highlight == nil)
    }

    @Test func theHighlightClearsWhenTheQuestionEndsWithoutAFollowUp() {
        let (engine, speech) = makeEngine(settings: SettingsBox(StudySettings()))
        engine.primaryAction()
        speech.callback?.onRange(utteranceID: "q-1", range: NSRange(location: 0, length: 7))
        speech.finishLast() // question done -> think pause: nothing being spoken
        #expect(engine.state.phase == .thinking)
        #expect(engine.state.highlight == nil)
    }

    @Test func followUpSpeechOverwritesTheHighlight() {
        let (engine, speech) = makeEngine(settings: SettingsBox(StudySettings(thinkSeconds: 0)))
        engine.primaryAction()
        speech.callback?.onRange(utteranceID: "q-1", range: NSRange(location: 0, length: 7))
        speech.finishLast() // question done -> think 0 -> the answer is spoken
        let h = engine.state.highlight
        #expect(h?.block == .answer)
        #expect(h?.isTranslation == false)
        #expect(h?.text == speech.spoken.last?.text)
        #expect(h?.range == nil)
        speech.callback?.onRange(utteranceID: "a-1", range: NSRange(location: 0, length: 2))
        #expect(engine.state.highlight?.range == 0..<2)
        speech.finishLast() // answer done -> awaiting advance: highlight cleared
        #expect(engine.state.phase == .awaitingAdvance)
        #expect(engine.state.highlight == nil)
    }

    @Test func translatedUtterancesTargetTheTranslation() {
        let (engine, speech) = makeEngine(settings: SettingsBox(StudySettings(language: .chineseSimplified)))
        engine.primaryAction()
        speech.finishLast() // English question done -> translated question
        var h = engine.state.highlight
        #expect(h?.block == .question)
        #expect(h?.isTranslation == true)
        speech.callback?.onRange(utteranceID: "zq-1", range: NSRange(location: 0, length: 2))
        #expect(engine.state.highlight?.range == 0..<2)
        speech.finishLast()
        engine.primaryAction() // reveal -> English answer
        speech.finishLast() // English answer done -> translated answer
        h = engine.state.highlight
        #expect(h?.block == .answer)
        #expect(h?.isTranslation == true)
        #expect(h?.text == repo.byNumber(1)?.translation(.chineseSimplified)?.spoken)
    }

    // MARK: - Spoken languages

    @Test func bilingualModeSpeaksEnglishThenTheTranslationInEachPhase() {
        let (engine, speech) = makeEngine(settings: SettingsBox(StudySettings(language: .chineseSimplified)))
        engine.primaryAction()
        #expect(speech.spoken.last?.utteranceID == "q-1")
        speech.finishLast() // English question done -> translated question
        #expect(engine.state.phase == .speakingQuestion)
        #expect(speech.spoken.last?.utteranceID == "zq-1")
        #expect(speech.spoken.last?.language == .chineseSimplified)
        #expect(speech.spoken.last?.text.hasPrefix("第 1 题。") == true)
        speech.finishLast() // translated question done -> think pause
        #expect(engine.state.phase == .thinking)

        engine.primaryAction() // reveal
        #expect(speech.spoken.last?.utteranceID == "a-1")
        speech.finishLast() // English answer done -> translated answer
        #expect(speech.spoken.last?.utteranceID == "za-1")
        #expect(speech.spoken.last?.language == .chineseSimplified)
        speech.finishLast() // translated answer done -> awaiting
        #expect(engine.state.phase == .awaitingAdvance)

        engine.primaryAction() // next
        #expect(speech.spoken.last?.utteranceID == "q-2")
    }

    @Test func chineseOnlyModeSpeaksOnlyChinese() {
        // In the merged model, choosing a language means English first, then the
        // translation — there is no Chinese-only mode.
        let (engine, speech) = makeEngine(settings: SettingsBox(StudySettings(language: .chineseSimplified)))
        engine.primaryAction()
        #expect(speech.spoken.last?.utteranceID == "q-1")
        #expect(speech.spoken.last?.language == .english)
        speech.finishLast() // English question -> zh question
        #expect(speech.spoken.last?.utteranceID == "zq-1")
        #expect(speech.spoken.last?.language == .chineseSimplified)
        speech.finishLast()
        #expect(engine.state.phase == .thinking)
        engine.primaryAction() // reveal
        #expect(speech.spoken.last?.utteranceID == "a-1")
        speech.finishLast() // English answer -> zh answer
        #expect(speech.spoken.last?.utteranceID == "za-1")
        #expect(speech.spoken.last?.text == repo.byNumber(1)?.translation(.chineseSimplified)?.spoken)
        speech.finishLast()
        #expect(engine.state.phase == .awaitingAdvance)
    }

    @Test func bilingualSpanishSpeaksEnglishThenSpanishInEachPhase() {
        let (engine, speech) = makeEngine(
            settings: SettingsBox(StudySettings(language: .spanish)),
            repo: QuestionRepository(jsonSource: { Data(Self.esAndZhHantJson.utf8) })
        )
        engine.primaryAction()
        #expect(speech.spoken.last?.utteranceID == "q-1")
        #expect(speech.spoken.last?.language == .english)
        speech.finishLast() // English question done -> Spanish question
        #expect(speech.spoken.last?.utteranceID == "zq-1")
        #expect(speech.spoken.last?.language == .spanish)
        #expect(speech.spoken.last?.text.hasPrefix("Pregunta 1.") == true)
        speech.finishLast()
        #expect(engine.state.phase == .thinking)

        engine.primaryAction() // reveal
        #expect(speech.spoken.last?.utteranceID == "a-1")
        speech.finishLast() // English answer done -> Spanish answer
        #expect(speech.spoken.last?.utteranceID == "za-1")
        #expect(speech.spoken.last?.language == .spanish)
        speech.finishLast()
        #expect(engine.state.phase == .awaitingAdvance)
    }

    @Test func traditionalChineseUsesTheHantAnnouncePrefix() {
        let (engine, speech) = makeEngine(
            settings: SettingsBox(StudySettings(language: .chineseTraditional)),
            repo: QuestionRepository(jsonSource: { Data(Self.esAndZhHantJson.utf8) })
        )
        engine.primaryAction()
        #expect(speech.spoken.last?.utteranceID == "q-1") // English first
        speech.finishLast() // English question -> zh-Hant question
        #expect(speech.spoken.last?.utteranceID == "zq-1")
        #expect(speech.spoken.last?.language == .chineseTraditional)
        #expect(speech.spoken.last?.text.hasPrefix("第 1 題。") == true)
        speech.finishLast()
        #expect(engine.state.phase == .thinking)
        engine.primaryAction()
        #expect(speech.spoken.last?.utteranceID == "a-1")
        speech.finishLast() // English answer -> zh-Hant answer
        #expect(speech.spoken.last?.utteranceID == "za-1")
        #expect(speech.spoken.last?.text == "繁體答案朗讀")
    }

    @Test func bilingualAnnounceMetaOffDropsTheTranslationPrefix() {
        let (engine, speech) = makeEngine(settings: SettingsBox(StudySettings(announceMeta: false, language: .chineseSimplified)))
        engine.primaryAction()
        speech.finishLast()
        #expect(speech.spoken.last?.text == repo.byNumber(1)?.translation(.chineseSimplified)?.question)
    }

    @Test func chineseModeWithoutTranslationFallsBackToEnglish() {
        // A single-question repo without any translations simulates untranslated data.
        let single = QuestionRepository(jsonSource: { Data(Self.noTranslationsJson.utf8) })
        let (engine, speech) = makeEngine(
            settings: SettingsBox(StudySettings(language: .chineseSimplified)),
            repo: single
        )
        engine.primaryAction()
        #expect(speech.spoken.last?.utteranceID == "q-1") // no translation -> English fallback
        #expect(speech.spoken.last?.language == .english)
        speech.finishLast() // no zh translation -> think pause, no z-leg
        #expect(engine.state.phase == .thinking)
        engine.primaryAction()
        #expect(speech.spoken.last?.utteranceID == "a-1")
        #expect(speech.spoken.last?.language == .english)
    }

    @Test func spanishWithoutASpanishTranslationFallsBackToEnglish() {
        // The repo has zh-Hans but not es: the selected language drives the fallback.
        let single = QuestionRepository(jsonSource: { Data(Self.zhHansOnlyJson.utf8) })
        let (engine, speech) = makeEngine(
            settings: SettingsBox(StudySettings(language: .spanish)),
            repo: single
        )
        engine.primaryAction()
        #expect(speech.spoken.last?.utteranceID == "q-1")
        #expect(speech.spoken.last?.language == .english)
        speech.finishLast() // no es translation -> think pause, no z-leg
        #expect(engine.state.phase == .thinking)
        engine.primaryAction() // reveal
        #expect(speech.spoken.last?.utteranceID == "a-1")
        #expect(speech.spoken.last?.language == .english)
        speech.finishLast()
        #expect(engine.state.phase == .awaitingAdvance)
    }

    // MARK: - Fixtures

    private static let noTranslationsJson = """
    {"questions":[{"n":1,"category":"American Government","question":"Q?","answer":"A","spoken":"A spoken","dynamic":false,"note":null}]}
    """

    private static let zhHansOnlyJson = """
    {"questions":[{"n":1,"category":"American Government","question":"Q?","answer":"A","spoken":"A spoken","dynamic":false,"note":null,"translations":{"zh-Hans":{"question":"简体题目","answer":"简体答案","spoken":"简体答案朗读"}}}]}
    """

    private static let esAndZhHantJson = """
    {"questions":[{"n":1,"category":"American Government","question":"Q?","answer":"A","spoken":"A spoken","dynamic":false,"note":null,"translations":{"es":{"question":"¿Pregunta de ejemplo?","answer":"Respuesta","spoken":"Respuesta hablada"},"zh-Hant":{"question":"繁體題目","answer":"繁體答案","spoken":"繁體答案朗讀"}}}]}
    """

    // MARK: - Practice test mode

    private func makeTestEngine(
        onKnownChanged: @escaping (Int, Bool) -> Void = { _, _ in },
        stats: @escaping () -> [Int: QuestionStat] = { [:] },
        onGraded: @escaping (Int, Bool) -> Void = { _, _ in },
        onTestFinished: @escaping (TestRecord) -> Void = { _ in }
    ) -> (StudyEngine, FakeSpeechEngine) {
        makeEngine(
            settings: SettingsBox(StudySettings()),
            onKnownChanged: onKnownChanged,
            stats: stats,
            onGraded: onGraded,
            onTestFinished: onTestFinished
        )
    }

    @Test func startTestSpeaksFirstOfATwentyQuestionDeck() {
        let (engine, speech) = makeTestEngine()
        engine.startTest()
        #expect(engine.state.mode == .test)
        #expect(engine.state.deckSize == StudyState.testTotal)
        #expect(engine.state.phase == .speakingQuestion)
        #expect(speech.spoken.last?.utteranceID.hasPrefix("q-") == true)
    }

    @Test func gradingAdvancesThroughTheTest() {
        let (engine, speech) = makeTestEngine()
        engine.startTest()
        speech.finishLast() // question -> think
        engine.primaryAction() // reveal answer
        speech.finishLast() // answer -> awaiting grade
        #expect(engine.state.phase == .awaitingGrade)
        engine.grade(correct: true)
        #expect(engine.state.testCorrect == 1)
        #expect(engine.state.testIndex == 1)
        #expect(engine.state.phase == .speakingQuestion)
    }

    @Test func testPassesAtTwelveCorrect() {
        var finished: TestRecord?
        let (engine, speech) = makeTestEngine(onTestFinished: { finished = $0 })
        engine.startTest()
        for _ in 0..<StudyState.testPassAt {
            speech.finishLast() // question done
            engine.primaryAction() // reveal
            speech.finishLast() // answer done -> awaiting grade
            engine.grade(correct: true)
        }
        #expect(engine.state.phase == .finished)
        #expect(engine.state.testOutcome == .passed)
        #expect(finished?.passed == true)
        #expect(finished?.correct == StudyState.testPassAt)
    }

    @Test func testFailsAtNineWrong() {
        var finished: TestRecord?
        let (engine, speech) = makeTestEngine(onTestFinished: { finished = $0 })
        engine.startTest()
        for _ in 0..<StudyState.testFailAt {
            speech.finishLast()
            engine.primaryAction()
            speech.finishLast()
            engine.grade(correct: false)
        }
        #expect(engine.state.phase == .finished)
        #expect(engine.state.testOutcome == .failed)
        #expect(finished?.passed == false)
        #expect(finished?.wrong == StudyState.testFailAt)
    }

    @Test func aWrongAnswerUnmarksAKnownQuestion() {
        // Single-question repo whose only question is already marked known.
        let json = """
        {"questions":[{"n":1,"category":"American Government","question":"Q?","answer":"A","spoken":"A spoken","dynamic":false,"note":null}]}
        """.data(using: .utf8)!
        let single = QuestionRepository(jsonSource: { json })
        var knownEvents: [(Int, Bool)] = []
        let speech = FakeSpeechEngine()
        let engine = StudyEngine(
            speech: speech, repo: single, officials: officials, settings: SettingsBox(StudySettings(known: [1])),
            scheduler: ManualScheduler(),
            onKnownChanged: { n, known in knownEvents.append((n, known)) }
        )
        engine.startTest()
        #expect(engine.state.current?.n == 1)
        #expect(engine.state.known.contains(1))
        speech.finishLast() // question done
        engine.primaryAction() // reveal
        speech.finishLast() // answer -> awaiting grade
        engine.grade(correct: false)
        // Known question answered wrong -> unmark it via the callback.
        #expect(knownEvents.count == 1)
        #expect(knownEvents[0].0 == 1 && knownEvents[0].1 == false)
    }

    @Test func nextAndPreviousAreDisabledDuringATest() {
        let (engine, speech) = makeTestEngine()
        engine.startTest()
        let before = speech.spoken.last?.utteranceID
        engine.next()
        engine.previous()
        // No skipping: the spoken utterance is unchanged.
        #expect(speech.spoken.last?.utteranceID == before)
        #expect(engine.state.phase == .speakingQuestion)
    }

    @Test func aSettingsChangeDuringATestDoesNotReplaceTheTestDeck() {
        let settings = SettingsBox(StudySettings())
        let (engine, _) = makeEngine(settings: settings)
        engine.startTest()
        let deckBefore = engine.state.deck.map(\.n)
        // A grade-time settings emission (e.g. a wrong answer unmarking a known
        // question) rebuilds the study deck — it must not touch the test deck.
        settings.value = settings.value.copy(category: "American History", shuffle: true)
        #expect(engine.state.deck.map(\.n) == deckBefore)
        #expect(engine.state.mode == .test)
    }

    @Test func gradingReportsThroughTheOnGradedCallback() {
        var graded: [(Int, Bool)] = []
        let (engine, speech) = makeTestEngine(onGraded: { n, correct in graded.append((n, correct)) })
        engine.startTest()
        for _ in 0..<2 {
            speech.finishLast() // question -> think
            engine.primaryAction() // reveal
            speech.finishLast() // answer -> awaiting grade
            engine.grade(correct: true)
        }
        #expect(graded.count == 2)
        let allCorrect = graded.allSatisfy { $0.1 }
        #expect(allCorrect)
        let distinctQuestions = Set(graded.map { $0.0 }).count
        #expect(distinctQuestions == 2) // one report per distinct question
    }

    @Test func aFinishedTestRecordCarriesItsAnswers() throws {
        var finished: TestRecord?
        let (engine, speech) = makeTestEngine(onTestFinished: { finished = $0 })
        engine.startTest()
        for _ in 0..<StudyState.testPassAt {
            speech.finishLast()
            engine.primaryAction()
            speech.finishLast()
            engine.grade(correct: true)
        }
        let record = try #require(finished)
        #expect(record.review == false)
        #expect(record.answers.count == StudyState.testPassAt)
        let allGradedCorrect = record.answers.allSatisfy { $0.correct }
        #expect(allGradedCorrect)
        #expect(record.answers.map(\.n) == Array(engine.state.deck.map(\.n).prefix(StudyState.testPassAt)))
    }

    @Test func startReviewDrillsTheMissedQuestionsWithScaledThresholds() throws {
        var finished: TestRecord?
        let stats: [Int: QuestionStat] = [
            1: QuestionStat(right: 0, wrong: 3, lastWrongMillis: 30),
            5: QuestionStat(right: 0, wrong: 2, lastWrongMillis: 20),
            9: QuestionStat(right: 0, wrong: 1, lastWrongMillis: 10),
        ]
        let (engine, speech) = makeEngine(
            settings: SettingsBox(StudySettings()),
            stats: { stats },
            onTestFinished: { finished = $0 }
        )
        engine.startReview()
        #expect(engine.state.mode == .test)
        #expect(engine.state.review)
        #expect(engine.state.deckSize == 3)
        #expect(engine.state.testPassAt == 2)
        #expect(engine.state.testFailAt == 2)
        // Two correct out of three clears the 60%-of-3 bar.
        for _ in 0..<2 {
            speech.finishLast()
            engine.primaryAction()
            speech.finishLast()
            engine.grade(correct: true)
        }
        #expect(engine.state.phase == .finished)
        #expect(engine.state.testOutcome == .passed)
        let record = try #require(finished)
        #expect(record.review)
        // passAt=2 ends the review after two answers; they must come from the missed set.
        #expect(record.answers.count == 2)
        let fromMissedSet = record.answers.allSatisfy { [1, 5, 9].contains($0.n) }
        #expect(fromMissedSet)
    }

    @Test func startReviewWithNothingMissedIsANoop() {
        let (engine, speech) = makeTestEngine()
        engine.startReview()
        #expect(engine.state.phase == .idle)
        #expect(speech.spoken.isEmpty)
    }

    @Test func reviewDeckExcludesUnresolvedStateQuestions() {
        let stats: [Int: QuestionStat] = [
            23: QuestionStat(right: 0, wrong: 1, lastWrongMillis: 10),
            5: QuestionStat(right: 0, wrong: 2, lastWrongMillis: 20),
        ]
        let (engine, _) = makeEngine(settings: SettingsBox(StudySettings()), stats: { stats })
        engine.startReview()
        #expect(engine.state.deck.map(\.n) == [5])
    }

    @Test func aRegularTestPullsEveryMissedQuestionWhenReviewFocusIsOn() {
        let stats: [Int: QuestionStat] = [
            1: QuestionStat(right: 0, wrong: 3, lastWrongMillis: 30),
            5: QuestionStat(right: 0, wrong: 2, lastWrongMillis: 20),
            9: QuestionStat(right: 0, wrong: 1, lastWrongMillis: 10),
            23: QuestionStat(right: 0, wrong: 9, lastWrongMillis: 99), // unresolved: not in the pool
        ]
        let (engine, _) = makeEngine(settings: SettingsBox(StudySettings()), stats: { stats })
        engine.startTest()
        let ns = Set(engine.state.deck.map(\.n))
        let allMissedPresent = [1, 5, 9].allSatisfy { ns.contains($0) }
        #expect(allMissedPresent)
        #expect(!ns.contains(23))
    }

    // MARK: - State answers

    @Test func testDeckExcludesStateQuestionsWhenNoPlaceIsSet() {
        let (engine, _) = makeTestEngine()
        engine.startTest()
        #expect(!engine.state.deck.contains { OfficialsData.stateQuestions.contains($0.n) })
        engine.startStudy()
        // The study deck keeps them, speaking the choose-your-state prompt.
        #expect(engine.state.deck.first { $0.n == 23 }?.spoken.contains("Choose your state in Settings") == true)
    }

    @Test func testDeckExcludesOnlyQ29WhenAMultiSeatStateHasNoDistrict() {
        let (engine, _) = makeEngine(settings: SettingsBox(StudySettings(jurisdiction: "CA")))
        engine.startTest()
        #expect(!engine.state.deck.contains { $0.n == 29 })
        engine.startStudy()
        #expect(engine.state.deck.first { $0.n == 61 }?.answer == "Gavin Newsom.")
        #expect(engine.state.deck.first { $0.n == 29 }?.spoken.contains("congressional district") == true)
    }

    @Test func stateQuestionsArePersonalizedOncePlaceAndDistrictAreSet() {
        let (engine, _) = makeEngine(settings: SettingsBox(StudySettings(jurisdiction: "CA", district: 12)))
        engine.startStudy()
        let deck = engine.state.deck
        #expect(deck.first { $0.n == 23 }?.answer.hasPrefix("Either one: ") == true)
        #expect(deck.first { $0.n == 29 }?.answer == "Lateefah Simon.")
        #expect(deck.first { $0.n == 61 }?.answer == "Gavin Newsom.")
        #expect(deck.first { $0.n == 62 }?.answer == "Sacramento.")
    }
}
