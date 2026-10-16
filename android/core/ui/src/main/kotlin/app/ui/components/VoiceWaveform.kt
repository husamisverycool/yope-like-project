// Component: C-36 Voice waveform (design/components.md; owner decision 16). Tokens `layout.global.waveform`,
// `size.global.waveformBarWidth` / `.waveformBarGap` / `.waveformBarMinHeight`. Evidence:
// references/auto/imessage/apple-support/messages-audio-message-ios27.png (38 bars, 2.02 / 2.07 pt),
// references/auto/whatsapp/store/whatsapp-store-02.png (silent bars are dots, idle all unplayed),
// references/auto/whatsapp/blog/whatsapp-blog-2022-03-voice-updates.png (bars up to 0.553 of the capsule; played /
// unplayed); measurements design/research/voice-waveform.md.
package app.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.height
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.drawscope.clipRect
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.unit.Dp
import app.designsystem.generated.Tokens
import kotlin.math.floor
import kotlin.math.max

/**
 * The bars C-36 draws for a width (`layout.global.waveform`), in any length unit: the count follows the width (Telegram
 * Desktop: ⌊(width + gap) ÷ (bar + gap)⌋, at most the number of levels), each bar the peak of its bucket of [levels]
 * (null or empty → every bar at [minHeight], the fallback for notes without levels); heights run from [minHeight] (a dot)
 * to [maxHeight], scaled to the note's largest level.
 */
class WaveformBars(levels: List<Int>?, width: Float, val barWidth: Float, val gap: Float, minHeight: Float, maxHeight: Float) {
    val heights: List<Float>

    init {
        val source = levels?.takeIf { it.isNotEmpty() } ?: List(SAMPLES) { 0 }
        val count = minOf(count(width, barWidth, gap), source.size)
        val bars = bucketPeaks(source, count)
        val largest = source.max().toFloat()
        val low = minOf(minHeight, maxHeight)
        heights = bars.map { value -> if (largest <= 0f) low else low + (maxHeight - low) * value / largest }
    }

    /** The leading edge of bar [index]. */
    fun x(index: Int): Float = index * (barWidth + gap)

    /**
     * The share (0…1) of bar [index] that is played at [progress] (0…1 of the drawn width): bars left of the progress edge
     * are played, the bar under it is split at the edge (Telegram Desktop), the rest unplayed.
     */
    fun playedShare(index: Int, progress: Float): Float {
        if (heights.isEmpty() || barWidth <= 0f) return 0f
        val total = x(heights.size - 1) + barWidth
        val edge = progress.coerceIn(0f, 1f) * total
        return ((edge - x(index)) / barWidth).coerceIn(0f, 1f)
    }

    companion object {
        /** Values stored per note (`layout.global.waveform.samples`). */
        val SAMPLES: Int get() = Tokens.Layouts.GlobalWaveform.samples.toInt()

        /** How many bars fit [width]: ⌊(width + gap) ÷ (barWidth + gap)⌋. */
        fun count(width: Float, barWidth: Float, gap: Float): Int {
            val pitch = barWidth + gap
            if (width <= 0f || pitch <= 0f) return 0
            return max(0, floor((width + gap) / pitch).toInt())
        }

        private fun bucketPeaks(values: List<Int>, count: Int): List<Int> {
            if (count <= 0) return emptyList()
            return List(count) { index ->
                val start = index * values.size / count
                val end = max(start + 1, (index + 1) * values.size / count).coerceAtMost(values.size)
                values.subList(start, end).max()
            }
        }
    }
}

/**
 * C-36 voice waveform: capsule-ended bars (`size.global.waveformBarWidth`, `.waveformBarGap` apart, corners = width ÷ 2)
 * centred on the row's middle, from `size.global.waveformBarMinHeight` (a dot) to `layout.global.waveform.maxHeightRatio`
 * × [holderHeight] (the capsule or field that holds it). Idle ([progress] null): every bar unplayed
 * (`color.global.textSecondary`); playing or paused part-way: bars left of the progress edge played
 * (`color.global.textPrimary`, media `color.global.textOnMedia`), the bar under the edge split. [levels] null (an older
 * note): every bar a dot. Decorative for TalkBack: the holder reads the note. The width comes from [modifier].
 */
@Composable
fun VoiceWaveform(
    levels: List<Int>?,
    holderHeight: Dp,
    modifier: Modifier = Modifier,
    progress: Float? = null,
    onMedia: Boolean = false,
) {
    val played = if (onMedia) Tokens.Colors.globalTextOnMedia else Tokens.Colors.globalTextPrimary
    val unplayed = Tokens.Colors.globalTextSecondary
    val maxHeight = holderHeight * Tokens.Layouts.GlobalWaveform.maxHeightRatio
    Canvas(modifier.height(maxHeight).clearAndSetSemantics {}) {
        val barWidth = Tokens.Sizes.globalWaveformBarWidth.toPx()
        val bars = WaveformBars(
            levels = levels,
            width = size.width,
            barWidth = barWidth,
            gap = Tokens.Sizes.globalWaveformBarGap.toPx(),
            minHeight = Tokens.Sizes.globalWaveformBarMinHeight.toPx(),
            maxHeight = maxHeight.toPx(),
        )
        val corner = CornerRadius(barWidth / 2, barWidth / 2)
        bars.heights.forEachIndexed { index, h ->
            val topLeft = Offset(bars.x(index), (size.height - h) / 2)
            val barSize = Size(barWidth, h)
            val share = progress?.let { bars.playedShare(index, it) } ?: 0f
            if (share >= 1f) {
                drawRoundRect(played, topLeft, barSize, corner)
            } else {
                drawRoundRect(unplayed, topLeft, barSize, corner)
                if (share > 0f) {
                    clipRect(left = topLeft.x, top = topLeft.y, right = topLeft.x + barWidth * share, bottom = topLeft.y + h) {
                        drawRoundRect(played, topLeft, barSize, corner)
                    }
                }
            }
        }
    }
}
