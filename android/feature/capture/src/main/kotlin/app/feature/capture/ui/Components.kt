// Shared pieces of the capture screens (camera.capture, camera.sendto, daily.capture,
// daily.dualimage, collage.view). core:ui has no shared components yet (account pass), so they
// are built here from tokens only. References: see each screen's header.
package app.feature.capture.ui

import android.view.View
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.wrapContentSize
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalViewConfiguration
import androidx.compose.ui.platform.ViewConfiguration
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import app.designsystem.Haptics
import app.designsystem.generated.Tokens
import androidx.compose.foundation.Canvas as DrawCanvas
import androidx.compose.ui.graphics.drawscope.Fill as DrawFill

/** Plays a `haptic` token on [view]; constants the device lacks map to the nearest (DS). */
internal fun View.haptic(token: Int) {
    Haptics.perform(this, token)
}

/**
 * Every control below gets at least `size.global.minTouchTarget.android` of hit area: Compose
 * extends pointer bounds of smaller targets to the view configuration's minimum without moving
 * the layout, and this sets that minimum from the token.
 */
@Composable
internal fun MinTouchTargets(content: @Composable () -> Unit) {
    val base = LocalViewConfiguration.current
    val min = Tokens.Sizes.globalMinTouchTargetAndroid
    val config = object : ViewConfiguration by base {
        override val minimumTouchTargetSize: DpSize get() = DpSize(min, min)
    }
    CompositionLocalProvider(LocalViewConfiguration provides config, content = content)
}

/** A capsule (`radius.global.capsule`: radius = height / 2). */
internal val CapsuleShape: Shape = RoundedCornerShape(percent = CAPSULE_PERCENT)
private const val CAPSULE_PERCENT = 50 // provenance-ok: radius.global.capsule = height / 2 expressed as a percentage

/**
 * A circle button: [diameter] circle filled [fill] (null = no fill) holding [icon] in [tint];
 * [glyphSize] null keeps the icon's own size.
 */
@Composable
internal fun CircleIconButton(
    icon: ImageVector,
    contentDescription: String,
    diameter: Dp,
    fill: Color?,
    tint: Color,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    glyphSize: Dp? = null,
) {
    Box(
        modifier = modifier
            .size(diameter)
            .clip(CircleShape)
            .then(if (fill != null) Modifier.background(fill) else Modifier)
            .clickable(onClick = onClick)
            .semantics {
                this.contentDescription = contentDescription
                role = Role.Button
            },
        contentAlignment = Alignment.Center,
    ) {
        Image(
            imageVector = icon,
            contentDescription = null,
            colorFilter = ColorFilter.tint(tint),
            modifier = if (glyphSize != null) Modifier.size(glyphSize) else Modifier,
        )
    }
}

/** An icon drawn at [size] in [tint] (no semantics: callers label the control). */
@Composable
internal fun Glyph(icon: ImageVector, tint: Color, size: Dp?, modifier: Modifier = Modifier) {
    Image(
        imageVector = icon,
        contentDescription = null,
        colorFilter = ColorFilter.tint(tint),
        modifier = modifier.then(if (size != null) Modifier.size(size) else Modifier),
    )
}

/**
 * Yope's empty-state block (`yope.voice.empty-state`; text roles `emptyTitle` / `emptyDetail`,
 * white pill `color.global.surfaceLight` / `.onSurfaceLight`, `radius.global.capsule`, height
 * `camera.capture.size.permissionButtonHeight`, text role `button`). No gap tokens exist between
 * its lines; the pill's label is inset by the capsule radius (height / 2).
 */
@Composable
internal fun EmptyStateBlock(
    title: String,
    detail: String?,
    buttonLabel: String?,
    onButton: (() -> Unit)?,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier.wrapContentSize(), horizontalAlignment = Alignment.CenterHorizontally) {
        BasicText(title, style = CaptureText.emptyTitle.merge(TextStyle(color = Tokens.Colors.globalTextPrimary, textAlign = TextAlign.Center)))
        if (detail != null) {
            BasicText(detail, style = CaptureText.emptyDetail.merge(TextStyle(color = Tokens.Colors.globalTextSecondary, textAlign = TextAlign.Center)))
        }
        if (buttonLabel != null && onButton != null) {
            LightPill(buttonLabel, onButton)
        }
    }
}

/** The white secondary pill of empty states. */
@Composable
internal fun LightPill(label: String, onClick: () -> Unit, modifier: Modifier = Modifier) {
    val height = Tokens.Sizes.cameraCaptureSizePermissionButtonHeight
    Box(
        modifier = modifier
            .height(height)
            .clip(CapsuleShape)
            .background(Tokens.Colors.globalSurfaceLight)
            .clickable(onClick = onClick)
            .semantics { role = Role.Button }
            .padding(horizontal = height / 2),
        contentAlignment = Alignment.Center,
    ) {
        BasicText(label, style = CaptureText.button.merge(TextStyle(color = Tokens.Colors.globalOnSurfaceLight)), maxLines = 1)
    }
}

/**
 * The lime confirmation / error bar (`camera.sendto.layout.toast`): `color.global.accent`,
 * `icon.global.check` (C-12) and the text in `color.global.onAccent`, text role `button`; an
 * optional trailing text action (`camera.sendto.error.retry`).
 */
@Composable
internal fun LimeToast(text: String, actionLabel: String?, onAction: (() -> Unit)?, modifier: Modifier = Modifier) {
    val toast = Tokens.Layouts.CameraSendtoLayoutToast
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = toast.marginHorizontal.dp)
            .heightIn(min = toast.height.dp)
            .clip(RoundedCornerShape(toast.cornerRadius.dp))
            .background(Tokens.Colors.globalAccent)
            .semantics(mergeDescendants = true) {},
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Spacer(Modifier.width(toast.glyphInset.dp))
        Glyph(Tokens.Icons.globalCheck, Tokens.Colors.globalOnAccent, toast.glyph.dp)
        Spacer(Modifier.width(toast.glyphToText.dp))
        BasicText(
            text,
            style = CaptureText.button.merge(TextStyle(color = Tokens.Colors.globalOnAccent)),
            modifier = Modifier.weight(1f),
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
        )
        if (actionLabel != null && onAction != null) {
            BasicText(
                actionLabel,
                style = CaptureText.button.merge(TextStyle(color = Tokens.Colors.globalOnAccent)),
                modifier = Modifier
                    .clickable(onClick = onAction)
                    .semantics { role = Role.Button }
                    .padding(horizontal = toast.glyphInset.dp),
            )
        } else {
            Spacer(Modifier.width(toast.glyphInset.dp))
        }
    }
}

/**
 * Yope's coach tooltip (`camera.capture.layout.coach`): lime body with an optional leading glyph,
 * the text and ✕, and a pointer under it whose apex sits [pointerX] from the body's start
 * (null = centred). Text `camera.capture.fontSize.coach` / `.fontWeight.coach` in
 * `color.global.onAccent`.
 */
@Composable
internal fun CoachTooltip(
    text: String,
    closeLabel: String,
    onClose: () -> Unit,
    modifier: Modifier = Modifier,
    leadingIcon: ImageVector? = null,
    pointerX: Dp? = null,
    maxLines: Int = 1,
) {
    val coach = Tokens.Layouts.CameraCaptureLayoutCoach
    val textStyle = CaptureText.style(Tokens.FontSizes.cameraCaptureFontSizeCoach, Tokens.FontWeights.cameraCaptureFontWeightCoach)
        .merge(TextStyle(color = Tokens.Colors.globalOnAccent))
    Column(modifier = modifier.width(androidx.compose.foundation.layout.IntrinsicSize.Max)) {
        Row(
            modifier = Modifier
                .heightIn(min = coach.height.dp)
                .clip(RoundedCornerShape(coach.cornerRadius.dp))
                .background(Tokens.Colors.globalAccent)
                .padding(horizontal = coach.paddingHorizontal.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            if (leadingIcon != null) {
                // "leading video glyph (at the text size)".
                Glyph(leadingIcon, Tokens.Colors.globalOnAccent, app.designsystem.scaledDp(Tokens.FontSizes.cameraCaptureFontSizeCoach))
                Spacer(Modifier.width(coach.textToCloseGap.dp))
            }
            BasicText(text, style = textStyle, maxLines = maxLines, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f, fill = false))
            Spacer(Modifier.width(coach.textToCloseGap.dp))
            CircleIconButton(
                icon = Tokens.Icons.globalClose,
                contentDescription = closeLabel,
                diameter = coach.closeGlyph.dp,
                fill = null,
                tint = Tokens.Colors.globalOnAccent,
                onClick = onClose,
                glyphSize = coach.closeGlyph.dp,
            )
        }
        Box(Modifier.fillMaxWidth().height(coach.pointerHeight.dp)) {
            val pointerW = coach.pointerWidth.dp
            DrawCanvas(
                modifier = Modifier
                    .size(pointerW, coach.pointerHeight.dp)
                    .then(if (pointerX != null) Modifier.offset(x = pointerX - pointerW / 2) else Modifier.align(Alignment.TopCenter)),
            ) {
                val p = Path().apply {
                    moveTo(0f, 0f)
                    lineTo(size.width, 0f)
                    lineTo(size.width / 2f, size.height)
                    close()
                }
                drawPath(p, Tokens.Colors.globalAccent, style = DrawFill)
            }
        }
    }
}

/**
 * The dual image (`daily.dualimage.layout.composition`): every value is a ratio of the main image
 * width W. Main 3:4, corners 0.0455 W; inset (front photo) outer width 0.31 W, 3:4, top-leading
 * at 0.03 W, a 0.0051 W border in `color.global.backgroundDeep`, outer corners 0.126 × the
 * inset's outer width, inner corners = outer − border. Frames stay `backgroundDeep` while loading.
 */
@Composable
internal fun DualImage(main: ImageBitmap?, inset: ImageBitmap?, contentDescription: String?, modifier: Modifier = Modifier) {
    val c = Tokens.Layouts.DailyDualimageLayoutComposition
    androidx.compose.foundation.layout.BoxWithConstraints(
        modifier = modifier
            .aspectRatio(c.mainAspect)
            .then(
                if (contentDescription != null) Modifier.clearAndSetSemantics { this.contentDescription = contentDescription } else Modifier,
            ),
    ) {
        val w = maxWidth
        val mainShape = RoundedCornerShape(w * c.mainRadiusRatio)
        Box(Modifier.fillMaxSize().clip(mainShape).background(Tokens.Colors.globalBackgroundDeep)) {
            if (main != null) Image(main, contentDescription = null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
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
                Image(
                    inset,
                    contentDescription = null,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.fillMaxSize().clip(RoundedCornerShape(outerR - border)),
                )
            }
        }
    }
}

/**
 * A shutter: a [ring]-wide ring whose outer edge is [outer], the gap inside it in [gapColor], and
 * a centred [disc]. The gap is what outer, ring and disc leave (their tokens are honoured; the
 * camera's gap token does not add up with them, see design/verification/camera.capture.md).
 */
@Composable
internal fun ShutterDisc(
    outer: Dp,
    ring: Dp,
    disc: Dp,
    ringColor: Color,
    gapColor: Color,
    discColor: Color,
    modifier: Modifier = Modifier,
) {
    Box(modifier.size(outer), contentAlignment = Alignment.Center) {
        Box(Modifier.size(outer).clip(CircleShape).background(gapColor).border(ring, ringColor, CircleShape))
        Box(Modifier.size(disc).clip(CircleShape).background(discColor))
    }
}

/** Centre-aligned single line of [text] in [style]. */
@Composable
internal fun CenteredText(text: String, style: TextStyle, modifier: Modifier = Modifier) {
    BasicText(text, style = style.merge(TextStyle(textAlign = TextAlign.Center)), modifier = modifier)
}
