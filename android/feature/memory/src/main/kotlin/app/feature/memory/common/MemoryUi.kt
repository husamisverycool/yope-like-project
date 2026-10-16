package app.feature.memory.common

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.painter.Painter
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.core.view.WindowCompat
import app.designsystem.LocalDsDarkTheme
import app.designsystem.generated.Tokens
import app.ui.components.EmptyState
import app.ui.components.MediaPill
import app.ui.components.MediaPillStyle
import app.ui.foundation.endAtLastBaseline
import app.ui.theme.AppTheme
import coil3.compose.AsyncImage
import coil3.request.ImageRequest
import coil3.request.allowHardware

/*
 * Building blocks shared by the memory screens, on top of the core:ui component library (C-01 … C-35).
 * Everything visual comes from `Tokens.*` and the components; this file only adds the memory group's media
 * rules (`layout.global.appearance.media`: media pages render their subtree in the dark appearance, sheets over
 * them follow the system — MERGE RM-16) and the test seam for images.
 */

/**
 * Renders [content] in the dark appearance (`layout.global.appearance.media`: the Rewind page, the story frame,
 * the postcard-style composer and the tribute page stay dark in both appearances). Use [SystemAppearance] inside
 * it for native menus, sheets and dialogs, which follow the system setting.
 */
@Composable
fun MediaAppearance(content: @Composable () -> Unit) {
    val outer = LocalDsDarkTheme.current
    AppTheme(dark = true) {
        androidx.compose.runtime.CompositionLocalProvider(LocalOuterDark provides outer, content = content)
    }
}

/** The appearance outside the nearest [MediaAppearance] (the system setting in the app; the snapshot's in tests). */
private val LocalOuterDark = staticCompositionLocalOf<Boolean?> { null }

/**
 * Restores the appearance outside a [MediaAppearance] for native menus, sheets and dialogs drawn from inside it
 * (`layout.global.appearance.media`: "sheets over them follow the appearance"); outside any [MediaAppearance] (a
 * host that forces its own dark subtree, e.g. the photo viewer) it is the system setting.
 */
@Composable
fun SystemAppearance(content: @Composable () -> Unit) {
    val outer = LocalOuterDark.current ?: androidx.compose.foundation.isSystemInDarkTheme()
    AppTheme(dark = outer, content = content)
}

/**
 * C-27 error / offline / not-found block on a media page (black in both appearances): title text role
 * `emptyTitle` in `color.global.textOnMedia`, detail `emptyDetail` in secondary text, and — with [retry] — the
 * light pill (C-09 `MediaPill`, `color.global.surfaceLight` / `color.global.onSurfaceLight`, `size.global.pillHeight`)
 * `size.global.emptyTitleToAction` below the last baseline. Call it inside [MediaAppearance] (the block's
 * colours are the dark values: `color.global.textPrimary` dark = white).
 */
@Composable
fun MediaMessage(title: String, detail: String?, modifier: Modifier = Modifier, retry: String? = null, onRetry: () -> Unit = {}) {
    Column(modifier, horizontalAlignment = Alignment.CenterHorizontally) {
        Box(Modifier.endAtLastBaseline()) { EmptyState(title, detail) }
        if (retry != null) {
            Spacer(Modifier.height(Tokens.Sizes.globalEmptyTitleToAction))
            MediaPill(retry, onRetry, style = MediaPillStyle.Light)
        }
    }
}

/** Light status-bar and navigation-bar icons while a media page is shown (the page is black in both appearances). */
@Composable
fun LightSystemBarIcons() {
    val view = LocalView.current
    DisposableEffect(view) {
        val controller = view.context.findActivity()?.window?.let { WindowCompat.getInsetsController(it, view) }
        val status = controller?.isAppearanceLightStatusBars
        val navigation = controller?.isAppearanceLightNavigationBars
        controller?.isAppearanceLightStatusBars = false
        controller?.isAppearanceLightNavigationBars = false
        onDispose {
            if (controller != null && status != null) controller.isAppearanceLightStatusBars = status
            if (controller != null && navigation != null) controller.isAppearanceLightNavigationBars = navigation
        }
    }
}

/**
 * Supplies images by URL below this point (snapshot tests use the sample photos, never network). Null = load with
 * Coil.
 */
val LocalMemoryImages = staticCompositionLocalOf<((String) -> Painter?)?> { null }

/**
 * A remote image from a signed URL (aspect-fill by default, as Retro's tiles and pages). While nothing is loaded
 * the area shows [placeholder] (`color.global.backgroundDeep` on media, `color.global.control` on a page, C-28).
 * [onSettled] runs once the image has loaded or failed (the share renderer waits for it). [software] decodes into a
 * software bitmap, for drawing into a bitmap.
 */
@Composable
fun MemoryImage(
    url: String?,
    contentDescription: String?,
    modifier: Modifier = Modifier,
    contentScale: ContentScale = ContentScale.Crop,
    placeholder: Color = Tokens.Colors.globalBackgroundDeep,
    software: Boolean = false,
    onSettled: (() -> Unit)? = null,
) {
    val override = LocalMemoryImages.current
    if (url == null) {
        Box(modifier.background(placeholder))
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
        modifier = modifier.background(placeholder),
        contentScale = contentScale,
        onSuccess = { onSettled?.invoke() },
        onError = { onSettled?.invoke() },
    )
}

/**
 * Starts loading [urls] into the image caches now, so they show at once when their card or memory appears (no
 * image popping in after a step). Nothing when tests supply images.
 */
@Composable
fun PreloadImages(urls: List<String>) {
    if (LocalMemoryImages.current != null || urls.isEmpty()) return
    val context = LocalContext.current
    LaunchedEffect(urls) {
        val loader = coil3.SingletonImageLoader.get(context)
        urls.forEach { url -> loader.enqueue(ImageRequest.Builder(context).data(url).build()) }
    }
}

/** The activity hosting [this] context, if any (window flags, system bars). */
tailrec fun android.content.Context.findActivity(): android.app.Activity? = when (this) {
    is android.app.Activity -> this
    is android.content.ContextWrapper -> baseContext.findActivity()
    else -> null
}
