import Foundation

@MainActor
protocol ScheduledTask: AnyObject {
    func cancel()
}

/// The coroutine-delay seam: keeps StudyEngine a synchronous port of the
/// Kotlin original while remaining testable with virtual time.
@MainActor
protocol StudyScheduler: AnyObject {
    @discardableResult
    func run(after seconds: TimeInterval, _ action: @escaping () -> Void) -> any ScheduledTask
}

/// Production scheduler backed by a main-actor task sleep.
final class MainTaskScheduler: StudyScheduler {
    func run(after seconds: TimeInterval, _ action: @escaping () -> Void) -> any ScheduledTask {
        MainActorTask(seconds: seconds, action: action)
    }
}

private final class MainActorTask: ScheduledTask {
    private let task: Task<Void, Never>

    init(seconds: TimeInterval, action: @escaping () -> Void) {
        task = Task { @MainActor in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            action()
        }
    }

    func cancel() {
        task.cancel()
    }
}
