#if os(iOS)
import AppModels
@preconcurrency import AVFoundation
import Foundation
import Observation

/// A finished voice note / voice message (`chat.voice`, caption voice notes).
public struct VoiceRecording: Hashable, Sendable {
    /// AAC in an `.m4a` container, in the temporary directory.
    public let fileURL: URL
    public let durationMs: Int
    /// Normalized levels (0…1), one per metering interval, for drawing the waveform.
    public let levels: [Float]
}

enum AudioLevel {
    /// dBFS (−160…0) → linear amplitude 0…1.
    static func normalized(decibels: Float) -> Float {
        guard decibels.isFinite else { return 0 }
        return min(1, max(0, powf(10, decibels / 20)))
    }
}

/// Records voice with `AVAudioRecorder` (m4a) and samples its level for the waveform.
@MainActor
@Observable
public final class VoiceRecorder {
    public enum RecorderError: Error, Equatable, Sendable {
        case notAuthorized(PermissionStatus)
        case couldNotStart
        case notRecording
    }

    public private(set) var isRecording = false
    /// Levels sampled so far (live waveform).
    public private(set) var levels: [Float] = []
    public private(set) var elapsedMs = 0

    private let meteringInterval: Duration
    @ObservationIgnored private var recorder: AVAudioRecorder?
    @ObservationIgnored private var meterTask: Task<Void, Never>?

    /// - Parameter meteringInterval: how often a level sample is taken (waveform resolution).
    public init(meteringInterval: Duration) {
        self.meteringInterval = meteringInterval
    }

    public static func permission() -> PermissionStatus {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: return .granted
        case .denied: return .denied
        case .undetermined: return .notDetermined
        @unknown default: return .denied
        }
    }

    public static func requestPermission() async -> PermissionStatus {
        if permission() == .notDetermined {
            _ = await AVAudioApplication.requestRecordPermission()
        }
        return permission()
    }

    public func start() throws {
        let status = Self.permission()
        guard status == .granted else { throw RecorderError.notAuthorized(status) }
        cancel()
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        try audioSession.setActive(true)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")
        // Speech-quality AAC: mono, 44.1 kHz.
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.isMeteringEnabled = true
        guard recorder.record() else {
            try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            throw RecorderError.couldNotStart
        }
        self.recorder = recorder
        levels = []
        elapsedMs = 0
        isRecording = true
        let interval = meteringInterval
        meterTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.sample()
                try? await Task.sleep(for: interval)
            }
        }
    }

    private func sample() {
        guard let recorder, recorder.isRecording else { return }
        recorder.updateMeters()
        levels.append(AudioLevel.normalized(decibels: recorder.averagePower(forChannel: 0)))
        elapsedMs = Int((recorder.currentTime * 1000).rounded())
    }

    /// Stops and returns the recording.
    public func stop() throws -> VoiceRecording {
        guard let recorder else { throw RecorderError.notRecording }
        let duration = recorder.currentTime
        recorder.stop()
        finish()
        return VoiceRecording(
            fileURL: recorder.url,
            durationMs: Int((duration * 1000).rounded()),
            levels: levels
        )
    }

    /// Stops and deletes the recording.
    public func cancel() {
        guard let recorder else { return }
        recorder.stop()
        recorder.deleteRecording()
        finish()
    }

    private func finish() {
        meterTask?.cancel()
        meterTask = nil
        recorder = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

/// Plays voice notes / voice messages from local files (download signed URLs first).
@MainActor
@Observable
public final class VoicePlayer {
    public private(set) var isPlaying = false
    public private(set) var currentURL: URL?
    /// 0…1 through the current file.
    public private(set) var progress: Double = 0
    public private(set) var durationMs = 0

    private let progressInterval: Duration
    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var progressTask: Task<Void, Never>?
    private let delegate = PlayerDelegate()

    /// - Parameter progressInterval: how often `progress` updates while playing.
    public init(progressInterval: Duration) {
        self.progressInterval = progressInterval
        delegate.onFinish = { [weak self] in
            Task { @MainActor in self?.didFinish() }
        }
    }

    public func play(fileURL: URL) throws {
        if currentURL == fileURL, let player, !player.isPlaying {
            resume()
            return
        }
        stop()
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playback, mode: .spokenAudio)
        try audioSession.setActive(true)
        let player = try AVAudioPlayer(contentsOf: fileURL)
        player.delegate = delegate
        player.prepareToPlay()
        self.player = player
        currentURL = fileURL
        durationMs = Int((player.duration * 1000).rounded())
        resume()
    }

    public func pause() {
        player?.pause()
        isPlaying = false
        progressTask?.cancel()
    }

    public func resume() {
        guard let player else { return }
        player.play()
        isPlaying = true
        startProgressUpdates()
    }

    public func seek(toFraction fraction: Double) {
        guard let player else { return }
        player.currentTime = player.duration * min(1, max(0, fraction))
        updateProgress()
    }

    public func stop() {
        progressTask?.cancel()
        progressTask = nil
        player?.stop()
        player = nil
        currentURL = nil
        isPlaying = false
        progress = 0
        durationMs = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func startProgressUpdates() {
        progressTask?.cancel()
        let interval = progressInterval
        progressTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.updateProgress()
                try? await Task.sleep(for: interval)
            }
        }
    }

    private func updateProgress() {
        guard let player, player.duration > 0 else { return }
        progress = player.currentTime / player.duration
    }

    private func didFinish() {
        progressTask?.cancel()
        isPlaying = false
        progress = 1
    }

    private final class PlayerDelegate: NSObject, AVAudioPlayerDelegate {
        var onFinish: (() -> Void)?

        func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
            onFinish?()
        }
    }
}
#endif
