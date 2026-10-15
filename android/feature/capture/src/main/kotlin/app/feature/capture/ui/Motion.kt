package app.feature.capture.ui

import android.graphics.Paint
import android.graphics.Rect
import android.graphics.Typeface
import android.os.Build
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import app.designsystem.DSSpring
import app.designsystem.generated.Tokens
import kotlin.math.PI

/**
 * A spring whose response is a measured duration (daily.capture → Motion: "each is a spring with
 * the platform default damping … and response = the measured duration", as
 * `camera.capture.spring.shutterPress`). Converted like designgen's springs:
 * stiffness = (2π / response)², damping = `spring.global.platformDefault.android` damping.
 */
internal fun springWithResponse(responseMs: Float): DSSpring {
    val seconds = responseMs / MILLIS_PER_SECOND
    val omega = 2.0 * PI / seconds
    return DSSpring(dampingRatio = Tokens.Springs.globalPlatformDefaultAndroid.dampingRatio, stiffness = (omega * omega).toFloat())
}

private const val MILLIS_PER_SECOND = 1000f // provenance-ok: unit conversion

/**
 * Distance from a glyph's top to the baseline for [sample] at [size] / [weight] in the platform
 * face, so a spec position given as a cap or digit top ("digits top 92.3", "cap top 69 pt below")
 * can be placed by baseline.
 */
@Composable
internal fun glyphTopToBaseline(size: TextUnit, weight: FontWeight?, sample: String): Dp {
    val density = LocalDensity.current
    val px = with(density) { size.toPx() }
    val paint = Paint().apply {
        textSize = px
        typeface = when {
            weight == null -> Typeface.DEFAULT
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.P -> Typeface.create(Typeface.DEFAULT, weight.weight, false)
            weight >= FontWeight.SemiBold -> Typeface.DEFAULT_BOLD
            else -> Typeface.DEFAULT
        }
    }
    val bounds = Rect()
    paint.getTextBounds(sample, 0, sample.length, bounds)
    return with(density) { (-bounds.top).toDp() }
}
