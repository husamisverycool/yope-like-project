package app.ui.foundation

import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.VectorGroup
import androidx.compose.ui.graphics.vector.VectorNode
import androidx.compose.ui.graphics.vector.VectorPath
import androidx.compose.ui.graphics.vector.toPath
import androidx.compose.ui.unit.Dp

/**
 * Where a glyph's ink sits inside its box. Retro's measurements place glyph **ink** (not the glyph box)
 * on the margins — "last glyph's ink at `size.global.headerInset`", "back chevron ink at
 * `size.global.backInset`", "title ink `size.global.headerGap` after the chevron ink" (C-01, C-02) — while
 * Material Symbols draw inside a padded 24-unit viewport. This reads the ink bounds from the icon token's
 * own path data, so placement follows the measured ink whatever glyph a token names.
 */
object GlyphInk {
    private val cache = HashMap<ImageVector, Rect>()

    /** The ink bounds of [icon] in its viewport units (union of every path's bounds; group transforms are not applied — Material Symbols use none). */
    fun bounds(icon: ImageVector): Rect = synchronized(cache) {
        cache.getOrPut(icon) {
            var out: Rect? = null
            fun visit(node: VectorNode) {
                when (node) {
                    is VectorPath -> {
                        val b = node.pathData.toPath().getBounds()
                        out = out?.let { Rect(minOf(it.left, b.left), minOf(it.top, b.top), maxOf(it.right, b.right), maxOf(it.bottom, b.bottom)) } ?: b
                    }
                    is VectorGroup -> node.forEach(::visit)
                }
            }
            visit(icon.root)
            out ?: Rect(0f, 0f, icon.viewportWidth, icon.viewportHeight)
        }
    }

    /** Distance from the box's leading edge to the ink, for [icon] drawn in a [box]-wide box. */
    fun leading(icon: ImageVector, box: Dp): Dp = box * (bounds(icon).left / icon.viewportWidth)

    /** Distance from the ink to the box's trailing edge. */
    fun trailing(icon: ImageVector, box: Dp): Dp = box * ((icon.viewportWidth - bounds(icon).right) / icon.viewportWidth)

    /** Width of the ink when [icon] is drawn in a [box]-wide box. */
    fun width(icon: ImageVector, box: Dp): Dp = box * (bounds(icon).width / icon.viewportWidth)
}
