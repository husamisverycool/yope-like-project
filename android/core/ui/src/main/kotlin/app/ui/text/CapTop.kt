package app.ui.text

import android.graphics.Paint
import android.graphics.Rect
import android.graphics.Typeface
import androidx.compose.foundation.layout.paddingFrom
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.FirstBaseline
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalFontFamilyResolver
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontSynthesis
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.isSpecified

/**
 * Text placement by cap top. The reference measurements give a title's position as the distance to its
 * cap top (`groups.create.size.sheetTopToTitle`: "sheet top edge to the title's cap top"), not to the
 * top of the text box, which sits higher by the font's ascent minus its cap height (about 9 dp for a
 * 40 sp title). [capTopAt] places a text's first line so its cap top is exactly that distance below
 * the top of the modified element, at any font scale.
 */
object CapTop {
    /** The cap height ("H") of [style]'s resolved platform font at the current density and font scale. */
    @Composable
    fun height(style: TextStyle): Dp {
        val density = LocalDensity.current
        val resolver = LocalFontFamilyResolver.current
        return remember(style, density, resolver) {
            val typeface = resolver.resolve(
                style.fontFamily,
                style.fontWeight ?: FontWeight.Normal,
                style.fontStyle ?: FontStyle.Normal,
                style.fontSynthesis ?: FontSynthesis.All,
            ).value as? Typeface ?: Typeface.DEFAULT
            val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                this.typeface = typeface
                textSize = with(density) { style.fontSize.toPx() }
            }
            val bounds = Rect()
            paint.getTextBounds(CAP_SAMPLE, 0, CAP_SAMPLE.length, bounds)
            with(density) { (-bounds.top).toDp() }
        }
    }

    private const val CAP_SAMPLE = "H"
}

/**
 * Pads the top of a text so its first line's cap top sits [distance] below the top of this element
 * ([capHeight] from [CapTop.height] for the text's style). [distance] unspecified: no change.
 */
fun Modifier.capTopAt(distance: Dp, capHeight: Dp): Modifier =
    if (distance.isSpecified) paddingFrom(FirstBaseline, before = distance + capHeight) else this
