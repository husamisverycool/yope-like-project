package app.ui.foundation

import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.layout
import androidx.compose.ui.unit.Dp
import kotlin.math.roundToInt

/**
 * Places the element so its vertical centre sits [centreY] below the top of its slot (glyphs and pills
 * "centred on the title's cap middle", C-01 / C-02 / C-03). The slot's height is the element's own height
 * pushed down by that offset (never negative), so following content is not overlapped.
 */
fun Modifier.centreAt(centreY: Dp): Modifier = layout { measurable, constraints ->
    val placeable = measurable.measure(constraints.copy(minHeight = 0))
    val top = (centreY.toPx() - placeable.height / 2f).roundToInt().coerceAtLeast(0)
    layout(placeable.width, top + placeable.height) { placeable.place(0, top) }
}

/**
 * Lays the element out with no height of its own, drawn centred on its slot's vertical centre — for a glyph
 * button whose hit area (48 dp) must not change the measured text rhythm of the row it sits in (C-20 "•••").
 */
fun Modifier.overlayCentred(): Modifier = layout { measurable, constraints ->
    val placeable = measurable.measure(constraints.copy(minHeight = 0, maxHeight = androidx.compose.ui.unit.Constraints.Infinity))
    layout(placeable.width, 0) { placeable.place(0, -placeable.height / 2) }
}

/** Ends the element at its last text baseline, so the next element's `paddingFromBaseline(top = pitch)` gives an exact baseline pitch. */
fun Modifier.endAtLastBaseline(): Modifier = layout { measurable, constraints ->
    val placeable = measurable.measure(constraints)
    val baseline = placeable[androidx.compose.ui.layout.LastBaseline]
    val height = if (baseline == androidx.compose.ui.layout.AlignmentLine.Unspecified) placeable.height else baseline
    layout(placeable.width, height) { placeable.place(0, 0) }
}
