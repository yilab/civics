import Foundation
import Testing
@testable import Civics

// MARK: - Fakes

private final class FakeSpeechEngine: SpeechEngine {
    var callback: (any SpeechEngineCallback)?
    var speechRate: Float = 1.0
    private(set) var spoken: [(utteranceID: String, text: String)] = []
    private(set) var stopCount = 0

    func speak(utteranceID: String, text: String) {
        spoken.append((utteranceID, text))
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

    private func makeEngine(
        settings: SettingsBox,
        scheduler: ManualScheduler = ManualScheduler(),
        onKnownChanged: @escaping (Int, Bool) -> Void = { _, _ in }
    ) -> (StudyEngine, FakeSpeechEngine) {
        let speech = FakeSpeechEngine()
        let engine = StudyEngine(
            speech: speech,
            repo: repo,
            settings: settings,
            scheduler: scheduler,
            onKnownChanged: onKnownChanged
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

    @Test func aSpeechErrorStopsTheEngineInsteadOfCascading() {
        let (engine, speech) = makeEngine(settings: SettingsBox(StudySettings(thinkSeconds: 0, autoAdvance: true)))
        engine.primaryAction()
        speech.callback?.onError(utteranceID: "q-1")
        #expect(engine.state.phase == .idle)
    }

    @Test func announceMetaSettingDropsTheQuestionNumberPrefix() {
        let (engine, speech) = makeEngine(settings: SettingsBox(StudySettings(announceMeta: false)))
        engine.primaryAction()
        #expect(speech.spoken.last?.text == repo.byNumber(1)?.question)
    }
}
