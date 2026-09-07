import AVFoundation
import MediaPlayer

/// Keeps TTS playback alive with the screen off and routes lock-screen /
/// headset media buttons (AirPods stem presses) into the study engine.
/// The CivicsPlayer + CivicsAudioService analog: iOS has no service split, so
/// one class owns the remote commands, the now-playing info, and the audio session.
@MainActor
final class PlaybackCoordinator {

    private let engine: StudyEngine

    /// Nothing is posted to the lock screen until the user starts a session,
    /// like CivicsPlayer's hasStarted gate.
    private var hasStarted = false

    init(engine: StudyEngine) {
        self.engine = engine
    }

    func start() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [])

        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in self?.play(); return .success }
        center.pauseCommand.addTarget { [weak self] _ in self?.pause(); return .success }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in self?.togglePlayPause(); return .success }
        center.nextTrackCommand.addTarget { [weak self] _ in self?.next(); return .success }
        center.previousTrackCommand.addTarget { [weak self] _ in self?.previous(); return .success }

        // Audio focus analog: a call or other app taking the audio session pauses
        // the study session; there is no auto-resume, matching Android.
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] note in
            let type = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            if type == AVAudioSession.InterruptionType.began.rawValue {
                self?.engine.pause()
            }
        }

        // AUDIO_BECOMING_NOISY analog: headphones unplugged pauses playback.
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] note in
            let reason = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            if reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue {
                self?.engine.pause()
            }
        }

        engine.observeState { [weak self] state in
            guard let self else { return }
            if state.playing { hasStarted = true }
            updatePlaybackResources(playing: state.playing)
            updateNowPlaying(state)
        }
    }

    // MARK: - Transport funnel (the MediaController analog)

    /// The primary screen button and headset play both land here.
    func play() {
        hasStarted = true
        activateSession()
        engine.primaryAction()
    }

    func pause() {
        engine.pause()
    }

    func next() {
        hasStarted = true
        activateSession()
        engine.next()
    }

    func previous() {
        hasStarted = true
        activateSession()
        engine.previous()
    }

    func togglePlayPause() {
        if engine.state.playing { pause() } else { play() }
    }

    // MARK: - Audio session / now playing

    private func activateSession() {
        // Activate before the first utterance so speech is never gated.
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private func updatePlaybackResources(playing: Bool) {
        let session = AVAudioSession.sharedInstance()
        if playing {
            // Held through the silent phases (thinking / awaiting advance) too —
            // otherwise iOS suspends the app in the background and the timers die.
            try? session.setActive(true)
        } else if hasStarted {
            // Released on pause so other audio can resume, like abandoning focus.
            try? session.setActive(false)
        }
    }

    private func updateNowPlaying(_ state: StudyState) {
        let center = MPNowPlayingInfoCenter.default()
        guard hasStarted, let q = state.current else {
            center.nowPlayingInfo = nil
            return
        }
        center.nowPlayingInfo = [
            MPMediaItemPropertyTitle: "Question \(q.n)",
            MPMediaItemPropertyArtist: q.category,
            MPMediaItemPropertyAlbumTitle: state.answerRevealed ? "\(q.question) — \(q.answer)" : q.question,
            // No meaningful seek position; a zero duration suppresses the scrubber.
            MPMediaItemPropertyPlaybackDuration: 0,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: 0,
            MPNowPlayingInfoPropertyPlaybackRate: state.playing ? 1.0 : 0.0,
        ]
    }
}
