package app.feature.social.common

import android.view.HapticFeedbackConstants
import android.view.View
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.layout.statusBars
import androidx.compose.ui.unit.dp
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.painter.Painter
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.VectorGroup
import androidx.compose.ui.graphics.vector.VectorNode
import androidx.compose.ui.graphics.vector.VectorPath
import androidx.compose.ui.graphics.vector.toPath
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.foundation.text.BasicText
import app.designsystem.Haptics
import app.designsystem.generated.Tokens
import app.designsystem.toFontFamily
import app.feature.social.data.SocialData
import app.feature.social.data.SocialServices
import app.feature.social.data.UnconfiguredSocialData
import app.ui.components.EmptyStateAction
import app.ui.components.HeaderCircleButton
import app.ui.components.HeaderCircleFill
import app.ui.theme.AppTheme
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
 * Every social screen's root: the app theme (core:ui `AppTheme`: dark only, M3 system roles from
 * `color.global.system.*`). Compose expands every pointer target to the platform minimum
 * (`size.global.minTouchTarget.android`, 48 dp) without changing the layout.
 */
@Composable
fun SocialRoot(content: @Composable () -> Unit) = AppTheme(content)

/** Whether an element gated by a BLOCKED value shows: once [unblocked] ([SocialBlocked]), or as the development approximation. */
@Composable
fun shows(unblocked: Boolean): Boolean = unblocked || LocalApproximations.current

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

/** Text in a token style, one line by default, tail-truncated. */
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

/** A glyph from an icon token at the vector's own (platform) size unless [size] is given. */
@Composable
fun Glyph(icon: ImageVector, tint: Color, modifier: Modifier = Modifier, size: Dp? = null, contentDescription: String? = null) {
    Image(
        imageVector = icon,
        contentDescription = contentDescription,
        colorFilter = ColorFilter.tint(tint),
        modifier = if (size != null) modifier.size(size) else modifier,
    )
}

/**
 * A glyph whose *ink* is [inkHeight] tall (or [inkWidth] wide): the specs measure glyph ink
 * (e.g. `photo.viewer.dimension.closeGlyph` "✕ glyph height"), while a vector icon has padding
 * inside its viewport, so the vector is scaled by its path bounds.
 */
@Composable
fun InkGlyph(icon: ImageVector, tint: Color, modifier: Modifier = Modifier, inkHeight: Dp? = null, inkWidth: Dp? = null) {
    val bounds = remember(icon) { inkBounds(icon) }
    val scale = when {
        inkHeight != null && bounds.height > 0f -> inkHeight / bounds.height
        inkWidth != null && bounds.width > 0f -> inkWidth / bounds.width
        else -> null
    }
    if (scale == null) Glyph(icon, tint, modifier)
    else Glyph(icon, tint, modifier, size = scale * icon.viewportHeight)
}

/** Union of the path bounds of [icon], in viewport units. */
fun inkBounds(icon: ImageVector): Rect {
    var rect: Rect? = null
    fun visit(node: VectorNode) {
        when (node) {
            is VectorGroup -> node.forEach(::visit)
            is VectorPath -> {
                val b = node.pathData.toPath().getBounds()
                rect = rect?.let { Rect(minOf(it.left, b.left), minOf(it.top, b.top), maxOf(it.right, b.right), maxOf(it.bottom, b.bottom)) } ?: b
            }
        }
    }
    visit(icon.root)
    return rect ?: Rect(0f, 0f, icon.viewportWidth, icon.viewportHeight)
}

/** A header circle (core:ui `HeaderCircleButton`): `size.global.headerButton`, glyph in `color.global.textPrimary`. */
@Composable
fun HeaderCircle(icon: ImageVector, label: String, fill: HeaderCircleFill, onClick: () -> Unit, modifier: Modifier = Modifier) {
    HeaderCircleButton(icon, label, onClick, modifier, fill)
}

/** The platform activity indicator (`easing.global.native.activityIndicator`). */
@Composable
fun ActivityIndicator(modifier: Modifier = Modifier) {
    CircularProgressIndicator(modifier)
}

/**
 * Yope's "Loading" HUD centred over the screen (core:ui `LoadingHud`, label
 * `groups.create.hud.loading`). Its corner radius is BLOCKED (`chat.thread.radius.loadingHud`);
 * the shared component draws the box square.
 */
@Composable
fun LoadingHud(modifier: Modifier = Modifier) {
    Box(modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        val radius = SocialBlocked.loadingHudRadius
        val label = stringRes(app.designsystem.R.string.groups_create_hud_loading)
        if (radius != null) app.ui.components.LoadingHud(label, shape = app.ui.components.hudShape(radius)) else app.ui.components.LoadingHud(label)
    }
}

/** A pill action of an empty state. */
data class PillAction(val label: String, val icon: ImageVector?, val onClick: () -> Unit)

/** Yope's centred empty state (core:ui `EmptyState`): bold title, gray italic detail, optional white pill. */
@Composable
fun EmptyState(title: String, detail: String?, pill: PillAction?, modifier: Modifier = Modifier) {
    app.ui.components.EmptyState(title, detail, modifier, pill?.let { EmptyStateAction(it.label, it.onClick, it.icon) })
}

/**
 * A confirmation that would show as Yope's lime toast. The toast's dwell is BLOCKED
 * (`camera.sendto.duration.toastVisible`, `safety.block.duration.toast`; core:ui `ToastDwell`):
 * like every screen of the app, no toast is drawn while it is; the text is announced to TalkBack.
 */
@Composable
fun ConfirmationToast(text: String?, modifier: Modifier = Modifier, onShown: () -> Unit) {
    val view = LocalView.current
    if (text == null) return
    val dwell = SocialBlocked.toastDwellMs
    androidx.compose.runtime.LaunchedEffect(text) {
        announce(view, text)
        if (dwell != null) kotlinx.coroutines.delay(dwell)
        onShown()
    }
    if (dwell != null) {
        app.ui.components.LimeToast(
            text,
            modifier
                .windowInsetsPadding(androidx.compose.foundation.layout.WindowInsets.Companion.statusBars)
                .padding(horizontal = Tokens.Layouts.CameraSendtoLayoutToast.marginHorizontal.dp),
        )
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

/** `stringResource` for the generated copy (`app.designsystem.R.string.*`). */
@Composable
fun stringRes(id: Int, vararg args: Any): String = androidx.compose.ui.res.stringResource(id, *args)

/** The signed URL of [path] (null while loading or when it cannot be read). */
@Composable
fun signedUrl(path: String?): String? {
    val data = LocalSocialData.current
    val url by produceState<String?>(null, path) { value = path?.let { p -> runCatching { data.signedUrls(listOf(p))[p] }.getOrNull() } }
    return url
}

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
    val url = signedUrl(path)
    val fallbackUrl = signedUrl(fallbackPath)
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

/** A person's (or group's) avatar by storage path, through core:ui `Avatar` (fallback glyph when there is none). */
@Composable
fun Avatar(path: String?, size: Dp, modifier: Modifier = Modifier, fallbackIcon: ImageVector = Tokens.Icons.globalPerson) {
    val override = LocalPhotoOverride.current
    val image: Any? = if (override != null) path?.let(override) else signedUrl(path)
    app.ui.components.Avatar(image, size, modifier, fallbackIcon)
}
