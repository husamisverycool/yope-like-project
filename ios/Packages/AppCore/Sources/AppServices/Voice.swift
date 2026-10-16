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
    /// The waveform: 100 levels of 0…31 (`VoiceLevels`, design/components.md C-36; docs/API.md `voice_levels`).
    public let levels: [Int]

    public init(fileURL: URL, durationMs: Int, levels: [Int]) {
        self.fileURL = fileURL
        self.durationMs = durationMs
        self.levels = levels
    }
}

/// `AVAudioRecorder` segments for `VoiceRecordingSession`: speech-quality AAC, mono, 44.1 kHz, metering on (the peak
/// level feeds the waveform). Pause / continue use the recorder's own `pause()` / `record()`.
final class AudioRecorderEngine: VoiceRecordingEngine {
    private var recorder: AVAudioRecorder?

    private static let settings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
        AVSampleRateKey: 44_100,
        AVNumberOfChannelsKey: 1,
        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
    ]

    func startSegment(at url: URL) throws {
        let recorder = try AVAudioRecorder(url: url, settings: Self.settings)
        recorder.isMeteringEnabled = true
        guard recorder.record() else { throw VoiceRecorder.RecorderError.couldNotStart }
        self.recorder = recorder
    }

    func pauseSegment() {
        recorder?.pause()
    }

    func resumeSegment() -> Bool {
        recorder?.record() ?? false
    }

    func stopSegment() -> Int {
        guard let recorder else { return 0 }
        let ms = Int((recorder.currentTime * 1000).rounded())
        recorder.stop()
        self.recorder = nil
        return ms
    }

    var segmentTimeMs: Int {
        Int(((recorder?.currentTime ?? 0) * 1000).rounded())
    }

    func samplePeak() -> Float {
        guard let recorder, recorder.isRecording else { return 0 }
        recorder.updateMeters()
        return VoiceLevels.linear(decibels: recorder.peakPower(forChannel: 0))
    }

    func deleteFile(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}

/// Records voice with `AVAudioRecorder` (m4a): start, pause, continue, a playable draft while paused, stop (segments
/// joined into one file) or cancel — the locked recording of `chat.voice.layout.locked`. Samples the input's peak level
/// every `VoiceLevels.samplingInterval` while recording (`levels` = the live / draft waveform, C-36).
@MainActor
@Observable
public final class VoiceRecorder {
    public enum RecorderError: Error, Equatable, Sendable {
        case notAuthorized(PermissionStatus)
        case couldNotStart
        case notRecording
        case couldNotJoin
    }

    public private(set) var state: VoiceRecordingSession.State = .idle
    /// A recording exists (recording or paused).
    public var isRecording: Bool { state != .idle }
    /// The waveform of what was recorded so far (100 levels of 0…31).
    public private(set) var levels: [Int] = []
    public private(set) var elapsedMs = 0

    private let engine: AudioRecorderEngine
    private let session: VoiceRecordingSession
    @ObservationIgnored private var meterTask: Task<Void, Never>?
    /// The joined draft of a multi-segment paused recording (for previews), and the segments it was made from.
    @ObservationIgnored private var draft: (url: URL, segments: [URL])?

    public init() {
        let engine = AudioRecorderEngine()
        self.engine = engine
        session = VoiceRecordingSession(engine: engine, makeURL: { VoiceRecorder.newFileURL() })
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
        try activateRecordingSession()
        do {
            try session.start()
        } catch {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            throw RecorderError.couldNotStart
        }
        startMetering()
        publish()
    }

    /// Recording → paused (`AVAudioRecorder.pause()`).
    public func pause() {
        guard state == .recording else { return }
        try? session.pause()
        stopMetering()
        publish()
    }

    /// Paused → recording, at the end of the draft (`AVAudioRecorder.record()`, or a new segment after a preview).
    public func resume() throws {
        guard state == .paused else { throw RecorderError.notRecording }
        try activateRecordingSession()
        try session.resume()
        startMetering()
        publish()
    }

    /// The paused draft as one playable file: the open segment is finished first; several segments are joined.
    public func draftFile() async throws -> URL {
        let segments = try session.finishDraft()
        publish()
        if segments.count == 1, let only = segments.first { return only }
        if let draft, draft.segments == segments { return draft.url }
        discardDraft()
        let url = Self.newFileURL()
        try await VoiceSegments.join(segments, to: url)
        draft = (url, segments)
        return url
    }

    /// Stops and returns the recording (one file; segments are joined).
    public func stop() async throws -> VoiceRecording {
        guard state != .idle else { throw RecorderError.notRecording }
        stopMetering()
        let result = try session.finish()
        publish()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        let file: URL
        if result.segments.count == 1, let only = result.segments.first {
            file = only
            discardDraft()
        } else if let draft, draft.segments == result.segments {
            file = draft.url
            self.draft = nil
            result.segments.forEach { try? FileManager.default.removeItem(at: $0) }
        } else {
            discardDraft()
            file = Self.newFileURL()
            do {
                try await VoiceSegments.join(result.segments, to: file)
            } catch {
                result.segments.forEach { try? FileManager.default.removeItem(at: $0) }
                throw RecorderError.couldNotJoin
            }
            result.segments.forEach { try? FileManager.default.removeItem(at: $0) }
        }
        return VoiceRecording(fileURL: file, durationMs: result.durationMs, levels: result.levels)
    }

    /// Stops and deletes the recording.
    public func cancel() {
        guard state != .idle else { return }
        stopMetering()
        session.cancel()
        discardDraft()
        publish()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func activateRecordingSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        try audioSession.setActive(true)
    }

    private func startMetering() {
        meterTask?.cancel()
        let interval = VoiceLevels.samplingInterval
        meterTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.sampleLevel()
                try? await Task.sleep(for: interval)
            }
        }
    }

    private func stopMetering() {
        meterTask?.cancel()
        meterTask = nil
    }

    private func sampleLevel() {
        session.sample()
        publish()
    }

    private func publish() {
        state = session.state
        elapsedMs = session.elapsedMs
        levels = session.state == .idle ? [] : session.levels
    }

    private func discardDraft() {
        if let draft { try? FileManager.default.removeItem(at: draft.url) }
        draft = nil
    }

    nonisolated static func newFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")
    }
}

/// Joins recording segments into one `.m4a` (`AVMutableComposition` + `AVAssetExportSession`, AAC).
enum VoiceSegments {
    static func join(_ segments: [URL], to output: URL) async throws {
        let composition = AVMutableComposition()
        guard let track = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw VoiceRecorder.RecorderError.couldNotJoin
        }
        var cursor = CMTime.zero
        for url in segments {
            let asset = AVURLAsset(url: url)
            let duration = try await asset.load(.duration)
            guard let source = try await asset.loadTracks(withMediaType: .audio).first else { continue }
            try track.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: source, at: cursor)
            cursor = CMTimeAdd(cursor, duration)
        }
        try? FileManager.default.removeItem(at: output)
        guard let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else {
            throw VoiceRecorder.RecorderError.couldNotJoin
        }
        if #available(iOS 18, *) {
            try await export.export(to: output, as: .m4a)
        } else {
            export.outputURL = output
            export.outputFileType = .m4a
            await export.export()
            guard export.status == .completed else { throw export.error ?? VoiceRecorder.RecorderError.couldNotJoin }
        }
    }
}

/// The waveform of an audio file that came without levels (C-36 fallback, Telegram Desktop's `countVoiceWaveform`):
/// decodes it to 16-bit PCM, takes the peak of every `VoiceLevels.samplingInterval` and reduces like a recording.
public enum VoiceFileLevels {
    public static func levels(of url: URL) async -> [Int]? {
        await Task.detached(priority: .utility) { () -> [Int]? in
            let asset = AVURLAsset(url: url)
            guard let track = try? await asset.loadTracks(withMediaType: .audio).first,
                  let reader = try? AVAssetReader(asset: asset) else { return nil }
            let sampleRate = 44_100
            let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false,
                AVNumberOfChannelsKey: 1,
                AVSampleRateKey: sampleRate,
            ])
            guard reader.canAdd(output) else { return nil }
            reader.add(output)
            guard reader.startReading() else { return nil }
            let window = max(1, VoiceLevels.samplingIntervalMs * sampleRate / 1000)
            var peaks: [Float] = []
            var peak = 0
            var count = 0
            while let buffer = output.copyNextSampleBuffer() {
                guard let block = CMSampleBufferGetDataBuffer(buffer) else { continue }
                let length = CMBlockBufferGetDataLength(block)
                var samples = [Int16](repeating: 0, count: length / MemoryLayout<Int16>.size)
                let status = samples.withUnsafeMutableBytes { raw -> OSStatus in
                    guard let base = raw.baseAddress else { return -1 }
                    return CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: raw.count, destination: base)
                }
                guard status == kCMBlockBufferNoErr else { continue }
                for sample in samples {
                    peak = max(peak, abs(Int(sample)))
                    count += 1
                    if count >= window {
                        peaks.append(VoiceLevels.linear(pcm16: peak))
                        peak = 0
                        count = 0
                    }
                }
            }
            if count > 0 { peaks.append(VoiceLevels.linear(pcm16: peak)) }
            guard reader.status == .completed, !peaks.isEmpty else { return nil }
            return VoiceLevels.reduce(peaks)
        }.value
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
