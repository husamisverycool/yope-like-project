@testable import AppModels
import Foundation
import XCTest

/// C-36 levels and bars (owner decision 16): Telegram's 100 five-bit values, width-driven bars, split progress.
final class VoiceLevelsTests: XCTestCase {
    func testReduceKeepsOneHundredFiveBitValues() {
        let peaks = (0..<333).map { Float($0 % 37) / 36 }
        let levels = VoiceLevels.reduce(peaks)
        XCTAssertEqual(levels.count, 100)
        XCTAssertTrue(VoiceLevels.isValid(levels))
        XCTAssertLessThanOrEqual(levels.max() ?? 0, 31)
        XCTAssertGreaterThan(levels.max() ?? 0, 0)
    }

    func testReduceScalesToOnePointEightTimesTheMeanBucketPeak() {
        // Two loud buckets among quiet ones: mean = (2 × 0.9 + 98 × 0.1) / 100 = 0.116, scale = 0.2088.
        var peaks = Array(repeating: Float(0.1), count: 100)
        peaks[10] = 0.9
        peaks[60] = 0.9
        let levels = VoiceLevels.reduce(peaks)
        XCTAssertEqual(levels[10], 31)
        XCTAssertEqual(levels[60], 31)
        XCTAssertEqual(levels[0], Int((0.1 * 31 / (1.8 * 0.116)).rounded(.down)))
    }

    func testSilenceStaysAtZeroBelowTheFloor() {
        // Telegram's floor (2500 / 32767): faint noise never fills the bars.
        let levels = VoiceLevels.reduce(Array(repeating: 0.005, count: 400))
        XCTAssertEqual(Set(levels), [2])
        XCTAssertEqual(VoiceLevels.reduce([]), Array(repeating: 0, count: 100))
    }

    func testShortRecordingsRepeatSamplesAcrossBuckets() {
        let levels = VoiceLevels.reduce([0.05, 0.5, 0.05, 0.9])
        XCTAssertEqual(levels.count, 100)
        XCTAssertEqual(levels[0], levels[24], "each of the four samples fills a quarter of the buckets")
        XCTAssertEqual(levels[75], 31)
        XCTAssertLessThan(levels[50], levels[75])
    }

    func testReduceIgnoresNonFiniteAndOutOfRangeSamples() {
        let levels = VoiceLevels.reduce([.nan, -1, 4, .infinity])
        XCTAssertTrue(VoiceLevels.isValid(levels))
    }

    func testValidity() {
        XCTAssertTrue(VoiceLevels.isValid(Array(repeating: 31, count: 100)))
        XCTAssertFalse(VoiceLevels.isValid(Array(repeating: 31, count: 99)))
        XCTAssertFalse(VoiceLevels.isValid(Array(repeating: 32, count: 100)))
        XCTAssertFalse(VoiceLevels.isValid(Array(repeating: -1, count: 100)))
    }

    func testDecibelsAndPCMToLinear() {
        XCTAssertEqual(VoiceLevels.linear(decibels: 0), 1, accuracy: 1e-6)
        XCTAssertEqual(VoiceLevels.linear(decibels: -20), 0.1, accuracy: 1e-6)
        XCTAssertEqual(VoiceLevels.linear(decibels: -160), 0, accuracy: 1e-6)
        XCTAssertEqual(VoiceLevels.linear(decibels: -.infinity), 0)
        XCTAssertEqual(VoiceLevels.linear(pcm16: 32767), 1)
        XCTAssertEqual(VoiceLevels.linear(pcm16: 40000), 1)
        XCTAssertEqual(VoiceLevels.linear(pcm16: -3), 0)
    }

    // MARK: Bars

    func testBarCountFollowsTheWidth() {
        // 154 pt at 2.0 + 2.1: 38 bars (Apple Messages draws 38).
        XCTAssertEqual(WaveformBars.count(width: 154, barWidth: 2, gap: 2.1), 38)
        XCTAssertEqual(WaveformBars.count(width: 2, barWidth: 2, gap: 2.1), 1)
        XCTAssertEqual(WaveformBars.count(width: 0, barWidth: 2, gap: 2.1), 0)
        let bars = WaveformBars(levels: Array(repeating: 5, count: 100), width: 154, barWidth: 2, gap: 2.1, minHeight: 2, maxHeight: 20)
        XCTAssertEqual(bars.heights.count, 38)
        let wide = WaveformBars(levels: [1, 2, 3], width: 1000, barWidth: 2, gap: 2.1, minHeight: 2, maxHeight: 20)
        XCTAssertEqual(wide.heights.count, 3, "never more bars than stored levels")
    }

    func testBarsTakeTheBucketPeakAndScaleToTheNotesLargestLevel() {
        var levels = Array(repeating: 0, count: 100)
        levels[3] = 10
        levels[50] = 20
        let bars = WaveformBars(levels: levels, width: 4 * 4.1 - 2.1, barWidth: 2, gap: 2.1, minHeight: 2, maxHeight: 22)
        XCTAssertEqual(bars.heights.count, 4)
        XCTAssertEqual(bars.heights[0], 2 + 20 * 0.5, accuracy: 1e-9, "bucket 0–24 peaks at 10 = half the note's max")
        XCTAssertEqual(bars.heights[2], 22, accuracy: 1e-9, "the loudest bucket reaches the full height")
        XCTAssertEqual(bars.heights[1], 2, accuracy: 1e-9, "silence is a dot")
    }

    func testMissingLevelsDrawDots() {
        let bars = WaveformBars(levels: nil, width: 154, barWidth: 2, gap: 2.1, minHeight: 2, maxHeight: 20)
        XCTAssertEqual(bars.heights.count, 38)
        XCTAssertTrue(bars.heights.allSatisfy { $0 == 2 })
        XCTAssertEqual(WaveformBars(levels: [], width: 154, barWidth: 2, gap: 2.1, minHeight: 2, maxHeight: 20), bars)
    }

    func testProgressPlaysWholeBarsAndSplitsTheOneUnderTheEdge() {
        let bars = WaveformBars(levels: Array(repeating: 9, count: 100), width: 10 * 4.1 - 2.1, barWidth: 2, gap: 2.1, minHeight: 2, maxHeight: 20)
        XCTAssertEqual(bars.heights.count, 10)
        let total = 10 * 4.1 - 2.1
        let progress = (3 * 4.1 + 1) / total // one point into bar 3
        XCTAssertEqual(bars.playedShare(of: 2, progress: progress), 1)
        XCTAssertEqual(bars.playedShare(of: 3, progress: progress), 0.5, accuracy: 1e-9)
        XCTAssertEqual(bars.playedShare(of: 4, progress: progress), 0)
        XCTAssertEqual(bars.playedShare(of: 9, progress: 0), 0)
        XCTAssertEqual(bars.playedShare(of: 9, progress: 1), 1)
    }
}
