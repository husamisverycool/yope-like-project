import Foundation

/// What a voice recording drives: `AVAudioRecorder` in the app (AppServices `VoiceRecorder`), fakes in tests.
/// A recording is one or more **segments** (files): pausing uses the platform pause and keeps the segment open; a paused
/// draft that is previewed must be a finished file, so the preview closes the open segment and continuing starts a new
/// one (design/surfaces/chat.voice.md → Platform notes; owner decision 16).
public protocol VoiceRecordingEngine: AnyObject {
    /// Starts recording a new segment into `url`.
    func startSegment(at url: URL) throws
    /// Pauses the open segment (`AVAudioRecorder.pause()`).
    func pauseSegment()
    /// Continues the open, paused segment (`AVAudioRecorder.record()`); false when the platform refused.
    func resumeSegment() -> Bool
    /// Stops the open segment and finishes its file; returns its length in milliseconds.
    func stopSegment() -> Int
    /// The open segment's recorded length so far, in milliseconds (0 when none).
    var segmentTimeMs: Int { get }
    /// The input's peak level (0…1, linear) since the previous call.
    func samplePeak() -> Float
    /// Removes a segment file.
    func deleteFile(at url: URL)
}

/// One voice recording: start, pause, continue, finish the draft for a preview, finish or cancel (WhatsApp's locked
/// recording: "tap [pause] to pause recording and preview a draft … Tap [mic] to continue recording"). Samples the peak
/// level while recording (none while paused) for the waveform (`VoiceLevels`).
public final class VoiceRecordingSession {
    public enum State: Equatable, Sendable {
        case idle
        case recording
        case paused
    }

    /// A finished recording: its segment files in order (one file unless it was previewed and continued), length and
    /// the 100 stored levels.
    public struct Result: Equatable, Sendable {
        public let segments: [URL]
        public let durationMs: Int
        public let levels: [Int]
    }

    public enum SessionError: Error, Equatable, Sendable {
        case notIdle
        case notRecording
        case notPaused
    }

    public private(set) var state: State = .idle
    /// Peak levels sampled so far (0…1).
    public private(set) var peaks: [Float] = []
    private var finished: [(url: URL, durationMs: Int)] = []
    private var open: URL?
    private let engine: any VoiceRecordingEngine
    private let makeURL: () -> URL

    /// - Parameter makeURL: a new segment file's location (the temporary directory in the app).
    public init(engine: any VoiceRecordingEngine, makeURL: @escaping () -> URL) {
        self.engine = engine
        self.makeURL = makeURL
    }

    /// Recorded length so far: the finished segments plus the open one.
    public var elapsedMs: Int {
        finished.reduce(0) { $0 + $1.durationMs } + (open == nil ? 0 : engine.segmentTimeMs)
    }

    /// The stored-format levels of what was recorded so far (the live and draft waveforms).
    public var levels: [Int] { VoiceLevels.reduce(peaks) }

    /// Segment files that are finished (a preview can play them).
    public var finishedSegments: [URL] { finished.map(\.url) }

    /// idle → recording.
    public func start() throws {
        guard state == .idle else { throw SessionError.notIdle }
        let url = makeURL()
        try engine.startSegment(at: url)
        open = url
        peaks = []
        finished = []
        state = .recording
    }

    /// Reads one level sample (call every `VoiceLevels.samplingInterval` while recording; ignored otherwise).
    public func sample() {
        guard state == .recording else { return }
        peaks.append(engine.samplePeak())
    }

    /// recording → paused (the open segment pauses).
    public func pause() throws {
        guard state == .recording else { throw SessionError.notRecording }
        engine.pauseSegment()
        state = .paused
    }

    /// paused → recording: the open segment continues; after a preview closed it (or the platform refused to continue),
    /// a new segment starts.
    public func resume() throws {
        guard state == .paused else { throw SessionError.notPaused }
        if open != nil, engine.resumeSegment() {
            state = .recording
            return
        }
        closeOpenSegment()
        let url = makeURL()
        try engine.startSegment(at: url)
        open = url
        state = .recording
    }

    /// A paused draft's finished files, for a preview: closes the open segment first.
    public func finishDraft() throws -> [URL] {
        guard state == .paused else { throw SessionError.notPaused }
        closeOpenSegment()
        return finishedSegments
    }

    /// recording / paused → idle: closes the open segment and returns the recording.
    public func finish() throws -> Result {
        guard state != .idle else { throw SessionError.notRecording }
        closeOpenSegment()
        let result = Result(segments: finishedSegments, durationMs: elapsedMs, levels: levels)
        reset()
        return result
    }

    /// Any state → idle: deletes every segment file.
    public func cancel() {
        guard state != .idle else { return }
        if open != nil { _ = engine.stopSegment() }
        let files = finished.map(\.url) + [open].compactMap { $0 }
        files.forEach(engine.deleteFile(at:))
        reset()
    }

    private func closeOpenSegment() {
        guard let url = open else { return }
        let ms = engine.stopSegment()
        finished.append((url, ms))
        open = nil
    }

    private func reset() {
        open = nil
        finished = []
        peaks = []
        state = .idle
    }
}
