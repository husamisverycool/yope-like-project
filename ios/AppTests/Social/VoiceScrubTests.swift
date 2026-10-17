// chat.voice — seeking a voice note by dragging along its waveform and by accessibility steps (`chat.voice.layout.scrub`).
@testable import App
import XCTest

@MainActor
final class VoiceScrubTests: XCTestCase {
    func testDragAndStepPositions() {
        // The waveform starts 30 pt in and is 154 pt wide; right to left it ends 30 pt before the trailing edge.
        XCTAssertEqual(VoiceScrub.waveformMinX(capsuleWidth: 250, leadingInset: 30, waveformWidth: 154, rightToLeft: false), 30)
        XCTAssertEqual(VoiceScrub.waveformMinX(capsuleWidth: 250, leadingInset: 30, waveformWidth: 154, rightToLeft: true), 66)
        XCTAssertEqual(VoiceScrub.fraction(x: 107, waveformMinX: 30, waveformWidth: 154), 0.5, accuracy: 0.0001)
        XCTAssertEqual(VoiceScrub.fraction(x: 0, waveformMinX: 30, waveformWidth: 154), 0, "clamped at the start")
        XCTAssertEqual(VoiceScrub.fraction(x: 400, waveformMinX: 30, waveformWidth: 154), 1, "clamped at the end")

        // 5-s steps on a 20-s note: a quarter each way, clamped to the note.
        XCTAssertEqual(VoiceScrub.step(from: 0.5, durationMs: 20_000, forward: true, stepMs: 5_000), 0.75, accuracy: 0.0001)
        XCTAssertEqual(VoiceScrub.step(from: 0.1, durationMs: 20_000, forward: false, stepMs: 5_000), 0)
        XCTAssertEqual(VoiceScrub.step(from: 0.9, durationMs: 20_000, forward: true, stepMs: 5_000), 1)
        XCTAssertEqual(VoiceScrub.step(from: 0.3, durationMs: 0, forward: true, stepMs: 5_000), 0.3, "unknown length: no move")
    }
}
