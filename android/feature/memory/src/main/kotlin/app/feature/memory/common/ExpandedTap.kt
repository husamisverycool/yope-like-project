package app.feature.memory.common

import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.input.pointer.PointerEvent
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.PointerEventType
import androidx.compose.ui.input.pointer.PointerId
import androidx.compose.ui.input.pointer.changedToDown
import androidx.compose.ui.input.pointer.changedToUp
import androidx.compose.ui.node.CompositionLocalConsumerModifierNode
import androidx.compose.ui.node.LayoutAwareModifierNode
import androidx.compose.ui.node.ModifierNodeElement
import androidx.compose.ui.node.PointerInputModifierNode
import androidx.compose.ui.node.TouchBoundsExpansion
import androidx.compose.ui.node.currentValueOf
import androidx.compose.ui.node.requireDensity
import androidx.compose.ui.platform.InspectorInfo
import androidx.compose.ui.platform.LocalViewConfiguration
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntSize

/**
 * A tap target that keeps its layout size but takes touches in at least [minHeight] (`size.global.minTouchTarget.*`):
 * the touch bounds grow evenly above and below (Compose `TouchBoundsExpansion`). For an inline control whose layout
 * must stay one text line high — the tag run in the viewer's footer line — where `minimumInteractiveComponentSize`
 * would grow the line. Accessibility gets its click from the caller's semantics.
 */
internal fun Modifier.expandedTap(minHeight: Dp, enabled: Boolean, onTap: () -> Unit): Modifier =
    this then ExpandedTapElement(minHeight, enabled, onTap)

private data class ExpandedTapElement(val minHeight: Dp, val enabled: Boolean, val onTap: () -> Unit) : ModifierNodeElement<ExpandedTapNode>() {
    override fun create() = ExpandedTapNode(minHeight, enabled, onTap)

    override fun update(node: ExpandedTapNode) {
        node.minHeight = minHeight
        node.enabled = enabled
        node.onTap = onTap
    }

    override fun InspectorInfo.inspectableProperties() {
        name = "expandedTap"
    }
}

private class ExpandedTapNode(var minHeight: Dp, var enabled: Boolean, var onTap: () -> Unit) :
    Modifier.Node(), PointerInputModifierNode, LayoutAwareModifierNode, CompositionLocalConsumerModifierNode {
    private var height = 0
    private var down: PointerId? = null
    private var downAt = Offset.Zero

    override val touchBoundsExpansion: TouchBoundsExpansion
        get() {
            val extra = ((with(requireDensity()) { minHeight.roundToPx() } - height) / 2).coerceAtLeast(0)
            return TouchBoundsExpansion(top = extra, bottom = extra)
        }

    override fun onRemeasured(size: IntSize) {
        height = size.height
    }

    override fun onPointerEvent(pointerEvent: PointerEvent, pass: PointerEventPass, bounds: IntSize) {
        if (pass != PointerEventPass.Main) return
        val change = pointerEvent.changes.firstOrNull() ?: return
        when (pointerEvent.type) {
            PointerEventType.Press -> if (enabled && change.changedToDown() && !change.isConsumed) {
                down = change.id
                downAt = change.position
            }
            PointerEventType.Move -> if (change.id == down) {
                val slop = currentValueOf(LocalViewConfiguration).touchSlop
                if (change.isConsumed || (change.position - downAt).getDistance() > slop) down = null
            }
            PointerEventType.Release -> if (change.id == down) {
                down = null
                if (enabled && change.changedToUp() && !change.isConsumed) {
                    change.consume()
                    onTap()
                }
            }
            else -> Unit
        }
    }

    override fun onCancelPointerInput() {
        down = null
    }
}
