import Foundation

/// The levels behind a voice note's waveform (owner decision 16; design/components.md C-36; tokens
/// `layout.global.waveform`; docs/API.md §5.8 / §5.9 `voice_levels`).
///
/// Format: Telegram's voice waveform — 100 values of 0…31 (https://core.telegram.org/constructor/documentAttributeAudio:
/// "a series of bitpacked 5-bit values"; its example implementation `getWaveform2` keeps 100 samples). The recorder reads
/// its peak level every `samplingInterval`; `reduce` turns those peaks into the 100 stored values with that
/// implementation's rule: the peak of each bucket, scaled by max(2500 / 32767, 1.8 × the mean bucket peak), capped at 31.
public enum VoiceLevels {
    /// Values stored per note (`layout.global.waveform.samples`).
    public static let sampleCount = 100
    /// The largest stored value: 5 bits (`layout.global.waveform.levelMax`).
    public static let maxLevel = 31
    /// How often the recorder's peak level is read: 3 s of speech fill the 100 buckets
    /// (`layout.global.waveform.sampling`).
    public static let samplingInterval: Duration = .milliseconds(30)
    /// Telegram's scale floor, 2500 on the 16-bit range.
    static let scaleFloor: Float = 2500 / 32767
    /// Telegram's scale: 1.8 × the mean bucket peak.
    static let meanFactor: Float = 1.8

    /// The 100 stored values (0…31) for the peak levels (0…1, linear) sampled while recording. No samples → silence.
    public static func reduce(_ peaks: [Float]) -> [Int] {
        let buckets = bucketPeaks(peaks.map { min(1, max(0, $0.isFinite ? $0 : 0)) }, count: sampleCount)
        let mean = buckets.reduce(0, +) / Float(buckets.count)
        let scale = max(scaleFloor, meanFactor * mean)
        return buckets.map { min(maxLevel, Int(($0 * Float(maxLevel) / scale).rounded(.down))) }
    }

    /// True for a stored waveform the API accepts: exactly `sampleCount` values of 0…`maxLevel`.
    public static func isValid(_ levels: [Int]) -> Bool {
        levels.count == sampleCount && levels.allSatisfy { (0...maxLevel).contains($0) }
    }

    /// `AVAudioRecorder.peakPower(forChannel:)` (dBFS, −160…0) → linear amplitude 0…1.
    public static func linear(decibels: Float) -> Float {
        guard decibels.isFinite else { return 0 }
        return min(1, max(0, powf(10, decibels / 20)))
    }

    /// A 16-bit PCM sample magnitude → linear amplitude 0…1.
    public static func linear(pcm16 magnitude: Int) -> Float {
        Float(min(max(magnitude, 0), Int(Int16.max))) / Float(Int16.max)
    }

    /// `count` buckets over `values`, each the peak of its slice; fewer values than buckets repeat values (a short note
    /// still fills every bucket). Empty input → zeros.
    static func bucketPeaks(_ values: [Float], count: Int) -> [Float] {
        guard count > 0 else { return [] }
        guard !values.isEmpty else { return Array(repeating: 0, count: count) }
        return (0..<count).map { index in
            let range = bucket(index, of: count, over: values.count)
            return values[range].max() ?? 0
        }
    }

    static func bucket(_ index: Int, of count: Int, over total: Int) -> Range<Int> {
        let start = index * total / count
        let end = max(start + 1, (index + 1) * total / count)
        return start..<min(end, total)
    }
}

/// The bars C-36 draws for a width (`layout.global.waveform`): count, heights and the played share of each bar.
public struct WaveformBars: Equatable, Sendable {
    /// Bar heights in points, leading to trailing.
    public let heights: [Double]
    public let barWidth: Double
    public let gap: Double

    /// - Parameters:
    ///   - levels: the stored levels (any count; 0…`VoiceLevels.maxLevel`); nil or empty → every bar at `minHeight`
    ///     (the fallback for notes without levels).
    ///   - width: the waveform's width; the bar count follows it (Telegram Desktop: ⌊width ÷ (bar + gap)⌋, at most the
    ///     number of levels), each bar the peak of its bucket of levels.
    ///   - minHeight / maxHeight: a silent bar (a dot) and the tallest bar; heights scale with the level ÷ the note's
    ///     largest level.
    public init(levels: [Int]?, width: Double, barWidth: Double, gap: Double, minHeight: Double, maxHeight: Double) {
        self.barWidth = barWidth
        self.gap = gap
        let source = (levels?.isEmpty == false) ? levels! : Array(repeating: 0, count: VoiceLevels.sampleCount)
        let fit = Self.count(width: width, barWidth: barWidth, gap: gap)
        let count = min(fit, source.count)
        let floats = source.map(Float.init)
        let bars = VoiceLevels.bucketPeaks(floats, count: count)
        let largest = Double(source.max() ?? 0)
        let low = min(minHeight, maxHeight)
        heights = bars.map { value in
            guard largest > 0 else { return low }
            return low + (maxHeight - low) * Double(value) / largest
        }
    }

    /// How many bars fit `width`: ⌊(width + gap) ÷ (barWidth + gap)⌋.
    public static func count(width: Double, barWidth: Double, gap: Double) -> Int {
        let pitch = barWidth + gap
        guard width > 0, pitch > 0 else { return 0 }
        return max(0, Int(((width + gap) / pitch).rounded(.down)))
    }

    /// The leading edge of bar `index`.
    public func x(of index: Int) -> Double {
        Double(index) * (barWidth + gap)
    }

    /// The share (0…1) of bar `index` that is played at `progress` (0…1 of the drawn width): bars left of the progress
    /// edge are played, the bar under it is split at the edge (Telegram Desktop), the rest unplayed.
    public func playedShare(of index: Int, progress: Double) -> Double {
        guard !heights.isEmpty, barWidth > 0 else { return 0 }
        let total = x(of: heights.count - 1) + barWidth
        let edge = min(1, max(0, progress)) * total
        let left = x(of: index)
        return min(1, max(0, (edge - left) / barWidth))
    }
}
