package app.feature.social.common

import android.view.HapticFeedbackConstants
import android.view.View
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.painter.Painter
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.LocalViewConfiguration
import androidx.compose.ui.platform.ViewConfiguration
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.text.BasicText
import app.designsystem.Haptics
import app.designsystem.generated.Tokens
import app.designsystem.toFontFamily
import app.feature.social.data.SocialData
import app.feature.social.data.SocialServices
import app.feature.social.data.UnconfiguredSocialData
import coil3.compose.AsyncImage

/** The data the social screens use (the app's data graph, or a fake in tests). */
val LocalSocialData = staticCompositionLocalOf<SocialData> { UnconfiguredSocialData }

/** Platform services (voice, gallery). */
val LocalSocialServices = staticCompositionLocalOf { SocialServices.Default }

/**
 * Snapshot tests and previews draw photos from this instead of signed URLs (synthetic images,
 * never reference content). Null = load through signed URLs.
 */
val LocalPhotoOverride = staticCompositionLocalOf<((String) -> Painter?)?> { null }

/**
 * Whether elements with a BLOCKED value show their development approximation
 * ([BuildApproximations]; tests may render the release behaviour by providing false).
 */
val LocalApproximations = staticCompositionLocalOf { BuildApproximations.ENABLED }

/**
 * Every social screen's root: native components (M3 sheets, menus, dialogs, indicators) get the
 * dark baseline scheme from the `color.global.system.*` tokens (`layout.global.appearance`: dark
 * only), and every pointer target is at least `size.global.minTouchTarget.android`.
 */
@Composable
fun SocialRoot(content: @Composable () -> Unit) {
    val base = LocalViewConfiguration.current
    val touch = Tokens.Sizes.globalMinTouchTargetAndroid
    val configuration = remember(base, touch) {
        object : ViewConfiguration by base {
            override val minimumTouchTargetSize: DpSize get() = DpSize(touch, touch)
        }
    }
    val scheme = darkColorScheme(
        primary = Tokens.Colors.globalSystemPrimary,
        surface = Tokens.Colors.globalSystemSurface,
        surfaceContainerHigh = Tokens.Colors.globalSystemSurfaceContainerHigh,
        surfaceContainerLow = Tokens.Colors.globalSystemSurfaceContainerLow,
        onSurface = Tokens.Colors.globalSystemOnSurface,
        onSurfaceVariant = Tokens.Colors.globalSystemOnSurfaceVariant,
        outline = Tokens.Colors.globalSystemOutline,
        error = Tokens.Colors.globalSystemError,
    )
    MaterialTheme(colorScheme = scheme) {
        CompositionLocalProvider(LocalViewConfiguration provides configuration, content = content)
    }
}

/** Text styles from tokens: size and weight tokens; weight null = not measured (platform default). */
object Type {
    @Composable
    fun style(size: TextUnit, weight: FontWeight? = null, italic: Boolean = false): TextStyle =
        TextStyle(
            fontSize = size,
            fontWeight = weight,
            fontStyle = if (italic) FontStyle.Italic else null,
            fontFamily = Tokens.Fonts.globalFamily.toFontFamily(),
        )

    @Composable fun body() = style(Tokens.FontSizes.globalBody, Tokens.FontWeights.fontWeightGlobalBody)
    @Composable fun button() = style(Tokens.FontSizes.globalButton, Tokens.FontWeights.fontWeightGlobalButton)
    @Composable fun caption() = style(Tokens.FontSizes.globalCaption, Tokens.FontWeights.fontWeightGlobalCaption)
    @Composable fun headerTitle() = style(Tokens.FontSizes.globalHeaderTitle, Tokens.FontWeights.fontWeightGlobalHeaderTitle)
    @Composable fun sheetTitle() = style(Tokens.FontSizes.globalSheetTitle, Tokens.FontWeights.fontWeightGlobalSheetTitle)
    @Composable fun listTitle() = style(Tokens.FontSizes.globalListTitle, Tokens.FontWeights.fontWeightGlobalListTitle)
    @Composable fun listSubtitle() = style(Tokens.FontSizes.globalListSubtitle, Tokens.FontWeights.fontWeightGlobalListSubtitle)
    @Composable fun emptyTitle() = style(Tokens.FontSizes.globalEmptyTitle, Tokens.FontWeights.fontWeightGlobalEmptyTitle)
    @Composable fun emptyDetail() = style(Tokens.FontSizes.globalEmptyDetail, italic = true)
    @Composable fun overlayTime() = style(Tokens.FontSizes.globalOverlayTime, Tokens.FontWeights.fontWeightGlobalOverlayTime)
    @Composable fun placeholder() = style(Tokens.FontSizes.globalPlaceholder)
}

/** One line of text in a token style. */
@Composable
fun Line(
    text: String,
    style: TextStyle,
    color: Color,
    modifier: Modifier = Modifier,
    maxLines: Int = 1,
    align: TextAlign? = null,
) {
    BasicText(
        text = text,
        modifier = modifier,
        style = style.copy(color = color, textAlign = align ?: TextAlign.Unspecified),
        maxLines = maxLines,
        overflow = TextOverflow.Ellipsis,
    )
}

/** A glyph from an icon token at the vector's own size unless [size] is given. */
@Composable
fun Glyph(icon: ImageVector, tint: Color, modifier: Modifier = Modifier, size: Dp? = null, contentDescription: String? = null) {
    Image(
        imageVector = icon,
        contentDescription = contentDescription,
        colorFilter = ColorFilter.tint(tint),
        modifier = if (size != null) modifier.size(size) else modifier,
    )
}

/** Yope's header circle (`size.global.headerButton`) with a glyph in `color.global.textPrimary`. */
@Composable
fun HeaderCircle(icon: ImageVector, label: String, fill: Color, onClick: () -> Unit, modifier: Modifier = Modifier) {
    Box(
        modifier
            .size(Tokens.Sizes.globalHeaderButton)
            .clip(CircleShape)
            .background(fill)
            .clickable(role = Role.Button, onClickLabel = null, onClick = onClick)
            .semantics { contentDescription = label },
        contentAlignment = Alignment.Center,
    ) {
        Glyph(icon, Tokens.Colors.globalTextPrimary)
    }
}

/** The platform activity indicator (`easing.global.native.activityIndicator`). */
@Composable
fun ActivityIndicator(modifier: Modifier = Modifier) {
    CircularProgressIndicator(modifier)
}

/**
 * Yope's "Loading" HUD (groups.create): `groups.create.size.hud` area with the platform indicator
 * over `groups.create.hud.loading`. The HUD's container shape is BLOCKED
 * (`chat.thread.radius.loadingHud`), so its `groups.create.color.hud` box is not drawn.
 */
@Composable
fun LoadingHud(modifier: Modifier = Modifier) {
    Box(modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(Modifier.size(Tokens.Sizes.groupsCreateSizeHud), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
            ActivityIndicator()
            Line(
                stringRes(app.designsystem.R.string.groups_create_hud_loading),
                Type.style(Tokens.FontSizes.groupsCreateFontSizeHudLabel),
                Tokens.Colors.globalTextPrimary,
            )
        }
    }
}

/** The white secondary pill of Yope's empty states (`groups.screen.size.lightPillHeight`, `groups.screen.radius.lightPill`). */
@Composable
fun LightPill(label: String, icon: ImageVector?, onClick: () -> Unit, modifier: Modifier = Modifier) {
    Row(
        modifier
            .height(Tokens.Sizes.groupsScreenSizeLightPillHeight)
            .clip(RoundedCornerShape(Tokens.Radii.groupsScreenRadiusLightPill))
            .background(Tokens.Colors.globalSurfaceLight)
            .clickable(role = Role.Button, onClick = onClick)
            .padding(horizontal = Tokens.Sizes.globalScreenMargin),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalHeaderGap),
    ) {
        if (icon != null) Glyph(icon, Tokens.Colors.globalOnSurfaceLight)
        Line(label, Type.button(), Tokens.Colors.globalOnSurfaceLight)
    }
}

/** A pill action of an empty state. */
data class PillAction(val label: String, val icon: ImageVector?, val onClick: () -> Unit)

/** Yope's centred empty state: bold title, gray italic detail, optional white pill (`yope.voice.empty-state`). */
@Composable
fun EmptyState(title: String, detail: String?, pill: PillAction?, modifier: Modifier = Modifier) {
    Column(
        modifier.fillMaxWidth().padding(horizontal = Tokens.Sizes.globalScreenMargin),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalListGap),
    ) {
        Line(title, Type.emptyTitle(), Tokens.Colors.globalTextPrimary, maxLines = Int.MAX_VALUE, align = TextAlign.Center, modifier = Modifier.semantics { heading() })
        if (detail != null) Line(detail, Type.emptyDetail(), Tokens.Colors.globalTextSecondary, maxLines = Int.MAX_VALUE, align = TextAlign.Center)
        if (pill != null) LightPill(pill.label, pill.icon, pill.onClick)
    }
}

/**
 * The lime toast (`camera.sendto.layout.toast`) under the status bar. Its dwell is BLOCKED
 * (`camera.sendto.duration.toastVisible`): release builds announce the text instead of drawing it;
 * development builds draw it until it is tapped.
 */
@Composable
fun LimeToast(text: String?, onDismiss: () -> Unit, modifier: Modifier = Modifier) {
    val view = LocalView.current
    val approximations = LocalApproximations.current
    if (text == null) return
    androidx.compose.runtime.LaunchedEffect(text) { announce(view, text) }
    if (!approximations) {
        androidx.compose.runtime.LaunchedEffect(text) { onDismiss() }
        return
    }
    val toast = Tokens.Layouts.CameraSendtoLayoutToast
    Row(
        modifier
            .windowInsetsPadding(WindowInsets.statusBars)
            .padding(horizontal = toast.marginHorizontal.dp)
            .fillMaxWidth()
            .height(toast.height.dp)
            .clip(RoundedCornerShape(toast.cornerRadius.dp))
            .background(Tokens.Colors.globalAccent)
            .clickable(onClick = onDismiss)
            .padding(start = toast.glyphInset.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Glyph(Tokens.Icons.globalCheck, Tokens.Colors.globalOnAccent, size = toast.glyph.dp)
        Spacer(Modifier.width(toast.glyphToText.dp))
        Line(text, Type.button(), Tokens.Colors.globalOnAccent)
    }
}

/** Says [text] through TalkBack (errors and confirmations whose visual is BLOCKED or absent). */
@Suppress("DEPRECATION")
fun announce(view: View, text: String) {
    view.announceForAccessibility(text)
}

/** Plays haptic tokens: `Tokens.Haptics.*` constants and the `android` names of `haptic` layout tokens. */
class SocialHaptics(private val view: View) {
    fun play(constant: Int) {
        Haptics.perform(view, constant)
    }

    /** A `HapticFeedbackConstants` field name (`LONG_PRESS`, `DRAG_START`, …); "none" / "system" play nothing. */
    fun playNamed(name: String) {
        val constant = runCatching { HapticFeedbackConstants::class.java.getField(name).getInt(null) }.getOrNull() ?: return
        Haptics.perform(view, constant)
    }
}

@Composable
fun rememberHaptics(): SocialHaptics {
    val view = LocalView.current
    return remember(view) { SocialHaptics(view) }
}

/** `stringResource` that also works with the designsystem module's resources. */
@Composable
fun stringRes(id: Int, vararg args: Any): String = androidx.compose.ui.res.stringResource(id, *args)

/**
 * A private photo by storage path: a signed URL loaded with Coil (docs/API.md §7), or the test
 * override. [fallbackPath] (e.g. the thumbnail) shows until [path] has loaded.
 */
@Composable
fun RemotePhoto(
    path: String?,
    contentDescription: String?,
    modifier: Modifier = Modifier,
    contentScale: ContentScale = ContentScale.Crop,
    fallbackPath: String? = null,
) {
    val override = LocalPhotoOverride.current
    if (override != null) {
        val painter = (path ?: fallbackPath)?.let(override)
        if (painter != null) Image(painter, contentDescription, modifier, contentScale = contentScale) else Box(modifier)
        return
    }
    val data = LocalSocialData.current
    val url by produceState<String?>(null, path) { value = path?.let { p -> runCatching { data.signedUrls(listOf(p))[p] }.getOrNull() } }
    val fallbackUrl by produceState<String?>(null, fallbackPath) { value = fallbackPath?.let { p -> runCatching { data.signedUrls(listOf(p))[p] }.getOrNull() } }
    val context = LocalContext.current
    Box(modifier) {
        if (fallbackUrl != null) AsyncImage(model = fallbackUrl, contentDescription = null, modifier = Modifier.fillMaxSize(), contentScale = contentScale)
        if (url != null) {
            AsyncImage(
                model = coil3.request.ImageRequest.Builder(context).data(url).build(),
                contentDescription = contentDescription,
                modifier = Modifier.fillMaxSize(),
                contentScale = contentScale,
            )
        }
    }
}

/** A person's avatar circle: the photo, or `icon.global.person` when there is none. */
@Composable
fun Avatar(path: String?, size: Dp, modifier: Modifier = Modifier) {
    Box(modifier.size(size).clip(CircleShape), contentAlignment = Alignment.Center) {
        if (path != null) RemotePhoto(path, null, Modifier.fillMaxSize()) else Glyph(Tokens.Icons.globalPerson, Tokens.Colors.globalTextSecondary)
    }
}
