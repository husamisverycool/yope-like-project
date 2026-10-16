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
