package app.ui.media

/*
 * daily.dualimage — the back and front photos of one same-moment answer shown together (mechanics: BeReal; every
 * value a ratio of the main width, read by the worker too; design/surfaces/daily.dualimage.md, MERGE_DECISIONS RC-13).
 * Owned by the capture group, shared through core:ui so every host draws one implementation (lead decision, Pass 4):
 * daily.capture (preview), photo.viewer and chat.thread (a post with a front photo), collage tiles.
 *
 * API
 * ---
 * `DualImage(main: Any?, inset: Any?, contentDescription: String?, modifier: Modifier = Modifier,
 *            cornerRadius: Dp? = null, loadingFill: Color = Tokens.Colors.globalBackgroundDeep)`
 *
 *  - [main] / [inset]: any [DsImage] model — a `Painter` (tests, local decodes) or a Coil model (signed URL, `Uri`,
 *    `File`). [inset] null = single camera (main image only).
 *  - Size: the caller gives the width (e.g. `Modifier.fillMaxWidth()`); the component is 3:4 (`mainAspect`).
 *  - [cornerRadius]: the HOST's outer corners — `radius.global.viewfinder` (18) in daily.capture, `radius.global.photo`
 *    (0) in the viewer, `radius.global.card` on cards. Null = the token's `mainRadiusRatio` × width (only where the host
 *    draws no shape of its own).
 *  - Inset: outer width 0.31 W, 3:4, top-leading at 0.03 W, a 0.0051 W border in `color.global.backgroundDeep`, outer
 *    corners 0.126 × its outer width, inner = outer − border.
 *  - [loadingFill]: the frame until an image is there — `color.global.backgroundDeep` on media hosts (default),
 *    `color.global.control` on page hosts (daily.dualimage → States). Painters fade in with `duration.global.fade`.
 *  - TalkBack: one image element labelled [contentDescription] (`daily.dualimage.a11y.label`, "Back and front photos
 *    from {name}"); null = decorative. No tap-to-swap or drag (not found in any BeReal source).
 *
 * Snapshots: core:ui `DualImageSnapshotTest` (light and dark).
 */

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.painter.Painter
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.unit.Dp
import app.designsystem.generated.Tokens
import app.ui.foundation.DsImage
import app.ui.foundation.FadeVisibility

/** One same-moment answer: back photo with the front photo inset top-leading (see the file header for the API). */
@Composable
fun DualImage(
    main: Any?,
    inset: Any?,
    contentDescription: String?,
    modifier: Modifier = Modifier,
    cornerRadius: Dp? = null,
    loadingFill: Color = Tokens.Colors.globalBackgroundDeep,
) {
    val c = Tokens.Layouts.DailyDualimageLayoutComposition
    BoxWithConstraints(
        modifier
            .aspectRatio(c.mainAspect)
            .then(
                if (contentDescription != null) {
                    Modifier.clearAndSetSemantics {
                        this.contentDescription = contentDescription
                        role = Role.Image
                    }
                } else {
                    Modifier.clearAndSetSemantics { }
                },
            ),
    ) {
        val w = maxWidth
        Box(Modifier.fillMaxSize().clip(RoundedCornerShape(cornerRadius ?: (w * c.mainRadiusRatio))).background(loadingFill)) {
            DualImageLayer(main, loadingFill)
        }
        if (inset != null) {
            val outerW = w * c.insetWidthRatio
            val border = w * c.insetBorderRatio
            val outerR = outerW * c.insetOuterRadiusRatio
            val margin = w * c.insetMarginRatio
            Box(
                Modifier
                    .padding(start = margin, top = margin)
                    .width(outerW)
                    .aspectRatio(c.insetAspect)
                    .clip(RoundedCornerShape(outerR))
                    .background(Tokens.Colors.globalBackgroundDeep)
                    .padding(border),
            ) {
                Box(Modifier.fillMaxSize().clip(RoundedCornerShape(outerR - border)).background(loadingFill)) {
                    DualImageLayer(inset, loadingFill)
                }
            }
        }
    }
}

/** A photo aspect-filled; a [Painter] fades in (`duration.global.fade`) when it arrives, a Coil model loads over [fill]. */
@Composable
private fun DualImageLayer(model: Any?, fill: Color) {
    if (model == null || model is Painter) {
        var last by remember { mutableStateOf(model as Painter?) }
        if (model is Painter) last = model
        FadeVisibility(visible = model != null, modifier = Modifier.fillMaxSize()) {
            last?.let { DsImage(it, null, Modifier.fillMaxSize(), placeholder = fill) }
        }
    } else {
        DsImage(model, null, Modifier.fillMaxSize(), placeholder = fill)
    }
}
