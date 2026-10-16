package app.voice

import kotlin.math.floor
import kotlin.math.max

/**
 * The levels behind a voice note's waveform (owner decision 16; design/components.md C-36; tokens
 * `layout.global.waveform`; docs/API.md §5.8 / §5.9 `voice_levels`).
 *
 * Format: Telegram's voice waveform — 100 values of 0…31 (https://core.telegram.org/constructor/documentAttributeAudio:
 * "a series of bitpacked 5-bit values"; its example implementation `getWaveform2` keeps 100 samples). The recorder reads
 * its peak level every [SAMPLING_INTERVAL_MS]; [reduce] turns those peaks into the 100 stored values with that
 * implementation's rule: the peak of each bucket, scaled by max(2500 / 32767, 1.8 × the mean bucket peak), capped at 31.
 */
object VoiceLevels {
    /** Values stored per note (`layout.global.waveform.samples`). */
    const val SAMPLE_COUNT = 100

    /** The largest stored value: 5 bits (`layout.global.waveform.levelMax`). */
    const val MAX_LEVEL = 31

    /** How often the recorder's peak level is read: 3 s of speech fill the 100 buckets (`layout.global.waveform.sampling`). */
    const val SAMPLING_INTERVAL_MS = 30L

    /** [android.media.MediaRecorder.getMaxAmplitude] is a 16-bit PCM peak. */
    const val MAX_AMPLITUDE = 32767

    /** Telegram's scale floor, 2500 on the 16-bit range. */
    private const val SCALE_FLOOR = 2500f / 32767f

    /** Telegram's scale: 1.8 × the mean bucket peak. */
    private const val MEAN_FACTOR = 1.8f

    /** A 16-bit peak (`getMaxAmplitude()`, a PCM sample magnitude) → linear 0…1. */
    fun level(amplitude: Int): Float = amplitude.coerceIn(0, MAX_AMPLITUDE).toFloat() / MAX_AMPLITUDE

    /** The 100 stored values (0…31) for the peak levels (0…1, linear) sampled while recording. No samples → silence. */
    fun reduce(peaks: List<Float>): List<Int> {
        val buckets = bucketPeaks(peaks.map { if (it.isFinite()) it.coerceIn(0f, 1f) else 0f }, SAMPLE_COUNT)
        val mean = buckets.sum() / buckets.size
        val scale = max(SCALE_FLOOR, MEAN_FACTOR * mean)
        return buckets.map { minOf(MAX_LEVEL, floor(it * MAX_LEVEL / scale).toInt()) }
    }

    /** True for a stored waveform the API accepts: exactly [SAMPLE_COUNT] values of 0…[MAX_LEVEL]. */
    fun isValid(levels: List<Int>?): Boolean = levels != null && levels.size == SAMPLE_COUNT && levels.all { it in 0..MAX_LEVEL }

    /**
     * [count] buckets over [values], each the peak of its slice; fewer values than buckets repeat values (a short note
     * still fills every bucket). Empty input → zeros.
     */
    fun bucketPeaks(values: List<Float>, count: Int): List<Float> {
        if (count <= 0) return emptyList()
        if (values.isEmpty()) return List(count) { 0f }
        return List(count) { index ->
            val start = index * values.size / count
            val end = max(start + 1, (index + 1) * values.size / count).coerceAtMost(values.size)
            values.subList(start, end).max()
        }
    }
}
