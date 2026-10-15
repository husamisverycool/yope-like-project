package app.feature.memory.common

import android.content.Context
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.painter.Painter
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.foundation.text.BasicText
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.max
import app.designsystem.DSFontFamily
import app.designsystem.dsTextStyle
import app.designsystem.generated.Tokens
import coil3.compose.AsyncImage
import coil3.request.ImageRequest
import coil3.request.allowHardware

/*
 * Building blocks shared by the memory screens. core:ui (account pass) has no shared components
 * yet, so the foundation roles these use are assembled here from tokens only
 * (design/tokens/README.md "Quick role finder").
 */

/** A text role from tokens in [family] (the platform face for every memory surface). */
@Composable
fun roleStyle(
    size: TextUnit,
    weight: FontWeight,
    lineHeight: TextUnit = TextUnit.Unspecified,
    family: DSFontFamily = Tokens.Fonts.globalFamily,
): TextStyle = dsTextStyle(size, weight, family, lineHeight)

/** Distance to move a [visual]-sized control so its larger touch box keeps the visual position. */
fun touchOutset(visual: Dp): Dp = (max(visual, Tokens.Sizes.globalMinTouchTargetAndroid) - visual) / 2

/**
 * Header circle icon button (`size.global.headerButton`, `color.global.controlOnDeep`). Its hit area
 * is at least `size.global.minTouchTarget.android`; the circle sits centred in it, so callers place
 * it [touchOutset] closer to the edge than the visual inset.
 */
@Composable
fun HeaderCircleButton(
    icon: ImageVector,
    contentDescription: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    diameter: Dp = Tokens.Sizes.globalHeaderButton,
    fill: Color = Tokens.Colors.globalControlOnDeep,
    tint: Color = Tokens.Colors.globalTextPrimary,
    glyph: Dp? = null,
) {
    val touch = max(diameter, Tokens.Sizes.globalMinTouchTargetAndroid)
    Box(
        modifier
            .size(touch)
            .clickable(role = Role.Button, onClick = onClick)
            .semantics { this.contentDescription = contentDescription },
        contentAlignment = Alignment.Center,
    ) {
        Box(Modifier.size(diameter).clip(CircleShape).background(fill), contentAlignment = Alignment.Center) {
            Icon(icon, contentDescription = null, tint = tint, modifier = if (glyph != null) Modifier.size(glyph) else Modifier)
        }
    }
}

/** How a primary button looks while disabled. */
sealed interface DisabledLook {
    /** Yope's measured disabled fill / label (`groups.create.color.buttonDisabled*`). */
    data class Colors(val fill: Color, val label: Color) : DisabledLook

    /** The platform disabled state: the theme's `android:disabledAlpha` over the enabled look. */
    data class Alpha(val alpha: Float) : DisabledLook
}

/** The platform's disabled opacity (`android.R.attr.disabledAlpha` of the current theme). */
fun platformDisabledAlpha(context: Context): Float {
    val a = context.obtainStyledAttributes(intArrayOf(android.R.attr.disabledAlpha))
    return try {
        a.getFloat(0, 1f)
    } finally {
        a.recycle()
    }
}

/**
 * A filled button (lime primary or white secondary). [busy] shows the platform activity indicator
 * in place of the label (`easing.global.native` activityIndicator) and ignores taps.
 */
@Composable
fun FilledButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    height: Dp,
    shape: Shape,
    fill: Color,
    label: Color,
    textStyle: TextStyle,
    enabled: Boolean = true,
    busy: Boolean = false,
    disabled: DisabledLook = DisabledLook.Alpha(platformDisabledAlpha(LocalContext.current)),
    leading: ImageVector? = null,
) {
    val colors = when {
        enabled -> fill to label
        disabled is DisabledLook.Colors -> disabled.fill to disabled.label
        else -> fill to label
    }
    val alpha = if (!enabled && disabled is DisabledLook.Alpha) disabled.alpha else 1f
    Box(
        modifier
            .heightIn(min = height)
            .alpha(alpha)
            .clip(shape)
            .background(colors.first)
            .clickable(enabled = enabled && !busy, role = Role.Button, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        if (busy) {
            CircularProgressIndicator(color = colors.second)
        } else {
            androidx.compose.foundation.layout.Row(verticalAlignment = Alignment.CenterVertically) {
                if (leading != null) {
                    Icon(leading, contentDescription = null, tint = colors.second)
                    Spacer(Modifier.size(Tokens.Sizes.globalHeaderGap))
                }
                BasicText(text, style = textStyle.copy(color = colors.second, textAlign = TextAlign.Center))
            }
        }
    }
}

/** The lime primary button of a Yope form (`size.global.buttonHeight`, `radius.global.button`, text role `button`). */
@Composable
fun LimeButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    busy: Boolean = false,
    height: Dp = Tokens.Sizes.globalButtonHeight,
    shape: Shape = RoundedCornerShape(Tokens.Radii.globalButton),
    textStyle: TextStyle = roleStyle(Tokens.FontSizes.globalButton, Tokens.FontWeights.fontWeightGlobalButton),
    disabled: DisabledLook = DisabledLook.Colors(Tokens.Colors.groupsCreateColorButtonDisabledFill, Tokens.Colors.groupsCreateColorButtonDisabledLabel),
) = FilledButton(text, onClick, modifier, height, shape, Tokens.Colors.globalAccent, Tokens.Colors.globalOnAccent, textStyle, enabled, busy, disabled)

/** Yope's white secondary pill (`color.global.surfaceLight` / `onSurfaceLight`, `radius.global.capsule`). */
@Composable
fun LightPill(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    height: Dp = Tokens.Sizes.globalButtonHeight,
) = FilledButton(
    text, onClick, modifier, height, CircleShape, Tokens.Colors.globalSurfaceLight, Tokens.Colors.globalOnSurfaceLight,
    roleStyle(Tokens.FontSizes.globalButton, Tokens.FontWeights.fontWeightGlobalButton), enabled,
)

/** The platform activity indicator, in the dark scheme's primary role (`color.global.system.primary`). */
@Composable
fun PlatformSpinner(modifier: Modifier = Modifier) {
    CircularProgressIndicator(modifier, color = Tokens.Colors.globalSystemPrimary)
}

/**
 * The app default voice's message layout (`yope.voice.error` / empty state): text roles `emptyTitle`
 * (header) and `emptyDetail`, centred, then an optional white pill.
 */
@Composable
fun MessageBlock(
    title: String,
    detail: String?,
    modifier: Modifier = Modifier,
    action: String? = null,
    onAction: () -> Unit = {},
) {
    Column(modifier, horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
        BasicText(
            title,
            Modifier.padding(horizontal = Tokens.Sizes.globalButtonMarginH).semantics { heading() },
            style = roleStyle(Tokens.FontSizes.globalEmptyTitle, Tokens.FontWeights.fontWeightGlobalEmptyTitle)
                .copy(color = Tokens.Colors.globalTextPrimary, textAlign = TextAlign.Center),
        )
        if (detail != null) {
            Spacer(Modifier.size(Tokens.Sizes.globalListGap))
            BasicText(
                detail,
                Modifier.padding(horizontal = Tokens.Sizes.globalButtonMarginH),
                // `fontSize.global.emptyDetail` is measured on an italic line (token element note).
                style = roleStyle(Tokens.FontSizes.globalEmptyDetail, Tokens.FontWeights.fontWeightGlobalListSubtitle)
                    .copy(color = Tokens.Colors.globalTextSecondary, textAlign = TextAlign.Center, fontStyle = FontStyle.Italic),
            )
        }
        if (action != null) {
            Spacer(Modifier.size(Tokens.Sizes.globalListGap))
            LightPill(action, onAction, Modifier.fillMaxWidth().padding(horizontal = Tokens.Sizes.globalButtonMarginH))
        }
    }
}

/**
 * Supplies images by URL below this point (snapshot tests use generated bitmaps, never network or
 * reference material). Null = load with Coil.
 */
val LocalMemoryImages = staticCompositionLocalOf<((String) -> Painter?)?> { null }

/**
 * A remote image from a signed URL. [onSettled] runs once the image has loaded or failed (the share
 * renderer waits for it). [software] decodes into a software bitmap, for drawing into a bitmap.
 */
@Composable
fun MemoryImage(
    url: String?,
    contentDescription: String?,
    modifier: Modifier = Modifier,
    contentScale: ContentScale = ContentScale.Crop,
    software: Boolean = false,
    onSettled: (() -> Unit)? = null,
) {
    val override = LocalMemoryImages.current
    if (url == null) {
        Box(modifier)
        LaunchedEffect(Unit) { onSettled?.invoke() }
        return
    }
    val painter = override?.invoke(url)
    if (painter != null) {
        Image(painter, contentDescription, modifier, contentScale = contentScale)
        LaunchedEffect(url) { onSettled?.invoke() }
        return
    }
    val context = LocalContext.current
    val request = remember(url, software) { ImageRequest.Builder(context).data(url).allowHardware(!software).build() }
    AsyncImage(
        model = request,
        contentDescription = contentDescription,
        modifier = modifier,
        contentScale = contentScale,
        onSuccess = { onSettled?.invoke() },
        onError = { onSettled?.invoke() },
    )
}

/** Height of the safe-area header row (status bar + one header circle's touch box): content starts below it. */
@Composable
fun headerClearance(): Dp =
    androidx.compose.foundation.layout.WindowInsets.statusBars.asPaddingValues().calculateTopPadding() +
        max(Tokens.Sizes.globalHeaderButton, Tokens.Sizes.globalMinTouchTargetAndroid)

/** A screen-reader heading. */
fun Modifier.heading(): Modifier = semantics { heading() }
