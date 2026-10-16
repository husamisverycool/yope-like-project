package app.feature.social.common

import android.view.View
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.painter.Painter
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.Dp
import app.designsystem.Haptics
import app.designsystem.LocalDsDarkTheme
import app.designsystem.generated.Tokens
import app.feature.social.data.SocialData
import app.feature.social.data.SocialServices
import app.feature.social.data.UnconfiguredSocialData
import app.ui.foundation.DsImage
import app.ui.theme.AppTheme

/** The data the social screens use (the app's data graph, or a fake in tests). */
val LocalSocialData = staticCompositionLocalOf<SocialData> { UnconfiguredSocialData }

/** Platform services (voice, gallery). */
val LocalSocialServices = staticCompositionLocalOf { SocialServices.Default }

/**
 * Snapshot tests and previews draw photos from this instead of signed URLs (the sample photos of
 * `fixtures/photos/`, never reference content). Null = load through signed URLs.
 */
val LocalPhotoOverride = staticCompositionLocalOf<((String) -> Painter?)?> { null }

/**
 * Whether elements with a BLOCKED value show their development approximation
 * ([BuildApproximations]; tests render the release behaviour by providing false).
 */
val LocalApproximations = staticCompositionLocalOf { BuildApproximations.ENABLED }

/**
 * The appearance outside a media surface: menus, alerts and sheets presented over the viewer or the recap
 * preview follow the system appearance (`photo.viewer.layout.appearance` → sheets), while the media
 * surface itself is dark in both. Null = not inside a media surface.
 */
private val LocalOuterDark = staticCompositionLocalOf<Boolean?> { null }

/**
 * Every social screen's root: core:ui `AppTheme` (DsTheme + the M3 scheme from `color.global.system.*`), in
 * the system appearance (`layout.global.appearance`); tests pass [dark].
 */
@Composable
fun SocialRoot(dark: Boolean = isSystemInDarkTheme(), content: @Composable () -> Unit) = AppTheme(dark = dark, content = content)

/**
 * A media surface (`photo.viewer`, the `week.recap` preview): rendered in the dark appearance in both system
 * appearances (`photo.viewer.layout.appearance`, tokens README "Media stays dark"); [SystemAppearance] restores
 * the system one for what is presented over it.
 */
@Composable
fun MediaAppearance(content: @Composable () -> Unit) {
    val outer = LocalOuterDark.current ?: LocalDsDarkTheme.current
    CompositionLocalProvider(LocalOuterDark provides outer) { AppTheme(dark = true, content = content) }
}

/** Native menus, alerts and sheets over a media surface: the system appearance (`photo.viewer.layout.appearance` → sheets). */
@Composable
fun SystemAppearance(content: @Composable () -> Unit) {
    val outer = LocalOuterDark.current
    if (outer == null) content() else AppTheme(dark = outer, content = content)
}

/** Whether an element gated by a BLOCKED value shows: once [unblocked] ([SocialBlocked]), or as the development approximation. */
@Composable
fun shows(unblocked: Boolean): Boolean = unblocked || LocalApproximations.current

/** `stringResource` for the generated copy (`app.designsystem.R.string.*`). */
@Composable
fun stringRes(id: Int, vararg args: Any): String = androidx.compose.ui.res.stringResource(id, *args)

/** Says [text] through TalkBack (announcements of results the screen does not draw). */
@Suppress("DEPRECATION")
fun announce(view: View, text: String) {
    view.announceForAccessibility(text)
}

/**
 * A `haptic` layout token's Android value ("DRAG_START (API 34+; none below)", "SEGMENT_FREQUENT_TICK (API 34+;
 * CLOCK_TICK below)"): the constant it names first; [noneBelow34] honours "none below".
 */
fun namedHaptic(androidValue: String, noneBelow34: Boolean = false): Int {
    if (noneBelow34 && android.os.Build.VERSION.SDK_INT < android.os.Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return Haptics.NO_HAPTICS
    return Haptics.named(androidValue.trim().substringBefore(' '))
}

/** The signed URL of [path] (null while loading or when it cannot be read). */
@Composable
fun signedUrl(path: String?): String? {
    val data = LocalSocialData.current
    val url by produceState<String?>(null, path) { value = path?.let { p -> runCatching { data.signedUrls(listOf(p))[p] }.getOrNull() } }
    return url
}

/**
 * The image model of a private photo by storage path, for core:ui `DsImage` / `Avatar`: the test painter
 * ([LocalPhotoOverride]) or its signed URL (docs/API.md §7); null while unknown.
 */
@Composable
fun photoModel(path: String?): Any? {
    val override = LocalPhotoOverride.current
    if (override != null) return path?.let(override)
    return signedUrl(path)
}

/**
 * A private photo by storage path through core:ui `DsImage` (aspect fill by default). [fallbackPath] (the
 * thumbnail) shows until [path] (the display rendition) has loaded; [placeholder] fills the area while
 * nothing is loaded (`color.global.control`; `color.global.backgroundDeep` on media).
 */
@Composable
fun RemotePhoto(
    path: String?,
    contentDescription: String?,
    modifier: Modifier = Modifier,
    contentScale: ContentScale = ContentScale.Crop,
    fallbackPath: String? = null,
    placeholder: Color = Tokens.Colors.globalControl,
) {
    val main = photoModel(path)
    val fallback = if (fallbackPath != null && fallbackPath != path) photoModel(fallbackPath) else null
    if (fallback == null || main is Painter) {
        DsImage(main ?: fallback, contentDescription, modifier, contentScale, placeholder)
        return
    }
    Box(modifier) {
        DsImage(fallback, null, Modifier.fillMaxSize(), contentScale, placeholder)
        if (main != null) DsImage(main, contentDescription, Modifier.fillMaxSize(), contentScale, placeholder)
    }
}

/** A person's avatar by storage path through core:ui `Avatar` (C-23; no photo → `icon.global.person`). */
@Composable
fun PersonAvatar(path: String?, size: Dp, modifier: Modifier = Modifier, fallbackIcon: ImageVector = Tokens.Icons.globalPerson) {
    app.ui.components.Avatar(photoModel(path), size, modifier, fallbackIcon)
}
