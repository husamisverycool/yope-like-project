package app.ui.foundation

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.painter.Painter
import androidx.compose.ui.layout.ContentScale
import app.designsystem.generated.Tokens
import coil3.compose.AsyncImage

/**
 * A photo from any source: a [Painter] (tests, local previews) or a Coil model (URL, `Uri`, `File`).
 * Aspect-fill by default (Retro's tiles, cards and thumbnails are aspect-fill, RV §3.8). While nothing is
 * loaded (null model) the area shows [placeholder] — the placeholder fill of C-17 / C-28
 * (`color.global.control`) unless the caller is on a media surface.
 */
@Composable
fun DsImage(
    model: Any?,
    contentDescription: String?,
    modifier: Modifier = Modifier,
    contentScale: ContentScale = ContentScale.Crop,
    placeholder: Color = Tokens.Colors.globalControl,
) {
    when (model) {
        is Painter -> Image(model, contentDescription, modifier, contentScale = contentScale)
        null -> Box(modifier.background(placeholder))
        else -> AsyncImage(model = model, contentDescription = contentDescription, modifier = modifier.background(placeholder), contentScale = contentScale)
    }
}

/**
 * The bottom scrim under white text on photos (`layout.global.photoScrim`): black from transparent
 * (`startOpacity`) at `startAt` of the height to `color.global.scrim` (black 60 %, = `endOpacity`) at the
 * bottom edge. Used by photo tiles (C-17), full-bleed media (C-35) and the tab bar over a photo (C-04).
 */
object PhotoScrim {
    val brush: Brush
        get() {
            val end = Tokens.Colors.globalScrim
            val scrim = Tokens.Layouts.GlobalPhotoScrim
            return Brush.verticalGradient(
                0f to end.copy(alpha = scrim.startOpacity),
                scrim.startAt to end.copy(alpha = scrim.startOpacity),
                1f to end.copy(alpha = scrim.endOpacity),
            )
        }
}

/** Draws [PhotoScrim] over the whole box. */
@Composable
fun PhotoScrimOverlay(modifier: Modifier = Modifier) {
    Box(modifier.fillMaxSize().background(PhotoScrim.brush))
}
