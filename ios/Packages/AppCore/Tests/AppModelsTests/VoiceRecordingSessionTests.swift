@testable import AppModels
import Foundation
import XCTest

/// The recorder's state machine (pause / continue / preview / finish / cancel) with a fake engine.
final class VoiceRecordingSessionTests: XCTestCase {
    private final class FakeEngine: VoiceRecordingEngine {
        var log: [String] = []
        var openTimeMs = 0
        var segmentLengths: [Int] = []
        var deleted: [URL] = []
        var refuseResume = false
        var peak: Float = 0.5
        var failStart = false

        func startSegment(at url: URL) throws {
            if failStart { throw CocoaError(.fileWriteUnknown) }
            log.append("start \(url.lastPathComponent)")
            openTimeMs = 0
        }

        func pauseSegment() { log.append("pause") }

        func resumeSegment() -> Bool {
            log.append(refuseResume ? "resume refused" : "resume")
            return !refuseResume
        }

        func stopSegment() -> Int {
            log.append("stop")
            segmentLengths.append(openTimeMs)
            let ms = openTimeMs
            openTimeMs = 0
            return ms
        }

        var segmentTimeMs: Int { openTimeMs }
        func samplePeak() -> Float { peak }
        func deleteFile(at url: URL) { deleted.append(url) }
    }

    private var counter = 0
    private func makeSession(_ engine: FakeEngine) -> VoiceRecordingSession {
        VoiceRecordingSession(engine: engine) { [unowned self] in
            counter += 1
            return URL(fileURLWithPath: "/tmp/segment-\(counter).m4a")
        }
    }

    func testPauseAndContinueUseThePlatformPauseOnOneSegment() throws {
        let engine = FakeEngine()
        let session = makeSession(engine)
        try session.start()
        engine.openTimeMs = 1200
        try session.pause()
        XCTAssertEqual(session.state, .paused)
        XCTAssertEqual(session.elapsedMs, 1200)
        try session.resume()
        XCTAssertEqual(session.state, .recording)
        engine.openTimeMs = 3000
        let result = try session.finish()
        XCTAssertEqual(engine.log, ["start segment-1.m4a", "pause", "resume", "stop"])
        XCTAssertEqual(result.segments.map(\.lastPathComponent), ["segment-1.m4a"])
        XCTAssertEqual(result.durationMs, 3000)
        XCTAssertEqual(session.state, .idle)
    }

    func testPreviewClosesTheSegmentAndContinuingStartsANewOne() throws {
        let engine = FakeEngine()
        let session = makeSession(engine)
        try session.start()
        engine.openTimeMs = 2000
        try session.pause()
        let draft = try session.finishDraft()
        XCTAssertEqual(draft.map(\.lastPathComponent), ["segment-1.m4a"], "the preview plays a finished file")
        XCTAssertEqual(session.elapsedMs, 2000)
        XCTAssertEqual(try session.finishDraft().count, 1, "a second preview closes nothing new")
        try session.resume()
        engine.openTimeMs = 1500
        XCTAssertEqual(session.elapsedMs, 3500, "the draft plus the new segment")
        let result = try session.finish()
        XCTAssertEqual(result.segments.map(\.lastPathComponent), ["segment-1.m4a", "segment-2.m4a"])
        XCTAssertEqual(result.durationMs, 3500)
        XCTAssertEqual(engine.log, ["start segment-1.m4a", "pause", "stop", "start segment-2.m4a", "stop"])
    }

    func testARefusedResumeStartsANewSegment() throws {
        let engine = FakeEngine()
        let session = makeSession(engine)
        try session.start()
        engine.openTimeMs = 800
        try session.pause()
        engine.refuseResume = true
        try session.resume()
        XCTAssertEqual(session.state, .recording)
        XCTAssertEqual(engine.log, ["start segment-1.m4a", "pause", "resume refused", "stop", "start segment-2.m4a"])
        XCTAssertEqual(session.elapsedMs, 800)
    }

    func testLevelsAreSampledOnlyWhileRecording() throws {
        let engine = FakeEngine()
        let session = makeSession(engine)
        session.sample()
        XCTAssertTrue(session.peaks.isEmpty, "idle: no samples")
        try session.start()
        session.sample()
        session.sample()
        try session.pause()
        session.sample()
        XCTAssertEqual(session.peaks.count, 2, "paused: no samples")
        try session.resume()
        engine.peak = 1
        session.sample()
        XCTAssertEqual(session.peaks, [0.5, 0.5, 1])
        XCTAssertEqual(session.levels.count, 100)
        let result = try session.finish()
        XCTAssertTrue(VoiceLevels.isValid(result.levels))
        // 0.5, 0.5, 1 over 100 buckets: mean 0.67, scale 1.206 → 12 and 25 (Telegram's rule).
        XCTAssertEqual(result.levels.first, 12)
        XCTAssertEqual(result.levels.last, 25)
    }

    func testCancelDeletesEverySegment() throws {
        let engine = FakeEngine()
        let session = makeSession(engine)
        try session.start()
        try session.pause()
        _ = try session.finishDraft()
        try session.resume()
        session.cancel()
        XCTAssertEqual(engine.deleted.map(\.lastPathComponent), ["segment-1.m4a", "segment-2.m4a"])
        XCTAssertEqual(session.state, .idle)
        XCTAssertEqual(session.elapsedMs, 0)
        session.cancel()
        XCTAssertEqual(engine.deleted.count, 2, "cancelling twice deletes nothing more")
    }

    func testInvalidTransitionsThrow() throws {
        let engine = FakeEngine()
        let session = makeSession(engine)
        XCTAssertThrowsError(try session.pause())
        XCTAssertThrowsError(try session.resume())
        XCTAssertThrowsError(try session.finish())
        XCTAssertThrowsError(try session.finishDraft())
        try session.start()
        XCTAssertThrowsError(try session.start())
        XCTAssertThrowsError(try session.resume(), "recording: nothing to continue")
        XCTAssertThrowsError(try session.finishDraft(), "only a paused draft is previewed")
    }

    func testAFailedStartLeavesTheSessionIdle() {
        let engine = FakeEngine()
        engine.failStart = true
        let session = makeSession(engine)
        XCTAssertThrowsError(try session.start())
        XCTAssertEqual(session.state, .idle)
    }
}
