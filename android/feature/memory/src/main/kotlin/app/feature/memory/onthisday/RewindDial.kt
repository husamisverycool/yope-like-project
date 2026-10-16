// Surface: onthisday — the Rewind dial (design/surfaces/onthisday.md B.6, `layout.onthisday.dial`).
// References: references/auto/retro/press/tc-2025-12-rewind-device-b.jpg (RWB, dial at rest),
// references/auto/retro/press/tc-2025-12-rewind-device-a.png (RWA), references/auto/retro/press/tc-2025-12-rewind-panels.png (RWP).
package app.feature.memory.onthisday

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.ProgressBarRangeInfo
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.progressBarRangeInfo
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.setProgress
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.unit.Dp
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.memory.common.MemoryFormats
import app.ui.foundation.GlyphInk
import app.ui.foundation.tapClickable
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.roundToInt
import kotlin.math.sign
import kotlin.math.sin

/** The dial's geometry and drag stepping (`layout.onthisday.dial`), pure so it is unit-tested. */
object DialGeometry {
    private val dial = Tokens.Layouts.OnthisdayDial

    /** Slots around the ring (`count.onthisday.dial.ticks`, 44). */
    val slots: Int get() = Tokens.Counts.onthisdayDialTicks

    /** Pitch between slots in degrees (8.18). */
    val pitch: Float get() = dial.pitchDegrees

    /** Angle of [slot] in degrees, clockwise from 3 o'clock (screen y grows downward): 6° + slot × 8.18°. */
    fun angle(slot: Int): Float = dial.firstSlotDegrees + slot * dial.pitchDegrees

    /** The slot the indicator sits on for memory [index] (`index mod 44`, start slot 0). */
    fun slotOf(index: Int): Int = (index + dial.startSlot.toInt()).mod(slots)

    /** Even slots carry long ticks, odd slots short ones. */
    fun isLong(slot: Int): Boolean = slot % 2 == 0

    /** Angle of [point] around [centre] in degrees, clockwise from 3 o'clock. */
    fun angleOf(point: Offset, centre: Offset): Float =
        Math.toDegrees(atan2((point.y - centre.y).toDouble(), (point.x - centre.x).toDouble())).toFloat()

    /** [to] − [from] wrapped into (−180°, 180°]. */
    fun delta(from: Float, to: Float): Float {
        var d = to - from
        while (d > 180f) d -= 360f
        while (d <= -180f) d += 360f
        return d
    }

    /**
     * Accumulated drag [accumulated] (degrees) → whole slots crossed (+ clockwise = next) and the remainder kept for
     * the next move.
     */
    fun slotsCrossed(accumulated: Float): Pair<Int, Float> {
        val steps = (accumulated / pitch).toInt()
        return steps to (accumulated - steps * pitch)
    }
}

/** Test tags. */
object DialTags {
    const val DIAL = "onthisday.dial"
    const val PLAY = "onthisday.dial.play"
}

/**
 * **The Rewind dial** (`layout.onthisday.dial`): [DialGeometry.slots] ticks on a ring of outer diameter
 * `dimension.onthisday.dial.diameter`, slot 0 at 6° clockwise from 3 o'clock, pitch 8.18°; even slots long
 * (`tickLong`), odd slots short (`tickShort`), every tick `tickWidth` wide measured inward from the outer edge, in
 * `color.onthisday.dial.tick` (round ends as RWB shows; the visible length is the token). The current memory's slot
 * shows the indicator instead of its tick (`indicatorLength`, `color.global.textOnMedia`). Centre: `icon.global.play`
 * / `icon.global.pause` with its ink `dimension.onthisday.dial.glyph` tall, a separate button (play / pause).
 *
 * A circular drag anywhere on the dial steps one memory per slot crossed ([onStep] +1 clockwise = next, −1 =
 * previous); the caller plays `haptic.global.select` per actual step (`TickOnStep`). TalkBack: one adjustable element
 * `onthisday.a11y.dial` with the value `onthisday.a11y.dialValue` ("2 of 5"), increment / decrement and the custom
 * actions `onthisday.a11y.next` / `.previous`.
 */
@Composable
fun RewindDial(
    index: Int,
    count: Int,
    playing: Boolean,
    onStep: (Int) -> Unit,
    onTogglePlay: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val step by rememberUpdatedState(onStep)
    val diameter = Tokens.Sizes.onthisdayDialDiameter
    val label = stringResource(R.string.onthisday_a11y_dial)
    val value = stringResource(R.string.onthisday_a11y_dialvalue, MemoryFormats.position(index + 1), MemoryFormats.position(count))
    val next = stringResource(R.string.onthisday_a11y_next)
    val previous = stringResource(R.string.onthisday_a11y_previous)
    val tick = Tokens.Colors.onthisdayDialTick
    val indicator = Tokens.Colors.globalTextOnMedia
    val current = DialGeometry.slotOf(index)
    Box(
        modifier
            .size(diameter)
            .pointerInput(Unit) {
                var last = 0f
                var accumulated = 0f
                val centre = Offset(size.width / 2f, size.height / 2f)
                detectDragGestures(
                    onDragStart = { start ->
                        last = DialGeometry.angleOf(start, centre)
                        accumulated = 0f
                    },
                    onDrag = { change, _ ->
                        val angle = DialGeometry.angleOf(change.position, centre)
                        accumulated += DialGeometry.delta(last, angle)
                        last = angle
                        val (steps, rest) = DialGeometry.slotsCrossed(accumulated)
                        accumulated = rest
                        repeat(kotlin.math.abs(steps)) { step(steps.sign) }
                        change.consume()
                    },
                )
            }
            .semantics {
                contentDescription = label
                stateDescription = value
                progressBarRangeInfo = ProgressBarRangeInfo(index.toFloat(), 0f..(count - 1).coerceAtLeast(1).toFloat(), steps = (count - 2).coerceAtLeast(0))
                setProgress { target ->
                    val delta = (target.roundToInt() - index).sign
                    if (delta != 0) step(delta)
                    delta != 0
                }
                customActions = listOf(
                    CustomAccessibilityAction(next) { step(+1); true },
                    CustomAccessibilityAction(previous) { step(-1); true },
                )
            }
            .testTag(DialTags.DIAL),
        contentAlignment = Alignment.Center,
    ) {
        Canvas(Modifier.fillMaxSize().clearAndSetSemantics { }) {
            val radius = size.minDimension / 2f
            val centre = Offset(size.width / 2f, size.height / 2f)
            val width = Tokens.Sizes.onthisdayDialTickWidth.toPx()
            for (slot in 0 until DialGeometry.slots) {
                val isCurrent = slot == current
                val length = when {
                    isCurrent -> Tokens.Sizes.onthisdayDialIndicatorLength
                    DialGeometry.isLong(slot) -> Tokens.Sizes.onthisdayDialTickLong
                    else -> Tokens.Sizes.onthisdayDialTickShort
                }.toPx()
                val a = Math.toRadians(DialGeometry.angle(slot).toDouble())
                val direction = Offset(cos(a).toFloat(), sin(a).toFloat())
                // Round ends: the stroke runs half its width short at both ends, so the visible length is the token.
                val outer = radius - width / 2f
                val inner = radius - length + width / 2f
                drawLine(
                    color = if (isCurrent) indicator else tick,
                    start = centre + direction * inner,
                    end = centre + direction * outer,
                    strokeWidth = width,
                    cap = StrokeCap.Round,
                )
            }
        }
        val glyph = if (playing) Tokens.Icons.globalPause else Tokens.Icons.globalPlay
        val glyphLabel = stringResource(if (playing) R.string.onthisday_a11y_pause else R.string.onthisday_a11y_play)
        val box = glyphBox(glyph, Tokens.Sizes.onthisdayDialGlyph)
        Box(
            Modifier
                .size(box)
                .clip(CircleShape)
                .tapClickable(onClick = onTogglePlay)
                .semantics { contentDescription = glyphLabel }
                .testTag(DialTags.PLAY),
            contentAlignment = Alignment.Center,
        ) {
            Icon(glyph, contentDescription = null, tint = Tokens.Colors.globalTextOnMedia, modifier = Modifier.size(box))
        }
    }
}

/** The icon box that makes [icon]'s ink [inkHeight] tall (Material Symbols draw inside a padded 24-unit viewport). */
internal fun glyphBox(icon: ImageVector, inkHeight: Dp): Dp = inkHeight * (icon.viewportHeight / GlyphInk.bounds(icon).height)
