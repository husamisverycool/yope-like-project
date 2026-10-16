package app.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.LocalMinimumInteractiveComponentSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalViewConfiguration
import androidx.compose.ui.platform.ViewConfiguration
import androidx.compose.ui.unit.DpSize
import app.designsystem.DsTheme
import app.designsystem.generated.Tokens
import app.ui.text.TextRoles

/*
 * The app theme (`layout.global.appearance`: follows the system Light / Dark setting, as Retro does).
 *
 * - App surfaces draw with the generated `Tokens.Colors.global*` getters, which read `LocalDsDarkTheme`
 *   from [DsTheme].
 * - Native components (dialogs, sheets, menus, switches, segmented buttons, text-field cursors) take their
 *   colours from MaterialTheme: Retro's own Android ColorScheme (`color.global.system.*`, light `d42.u` /
 *   dark `d42.v` — retro-package-copy-motion.md §3.2), the M3 baseline for every role Retro leaves at the
 *   default (tokens README → "Platform-drawn components").
 */

/** Light M3 scheme from the `color.global.system.*` light values. */
val AppLightColorScheme: ColorScheme = lightColorScheme(
    primary = Tokens.ColorsLight.globalSystemPrimary,
    onPrimary = Tokens.ColorsLight.globalSystemOnPrimary,
    primaryContainer = Tokens.ColorsLight.globalSystemPrimaryContainer,
    // color.global.system.primaryContainer / .secondaryContainer notes: on-container #000000 / #FFFFFF,
    // the values of color.global.system.onSurface.
    onPrimaryContainer = Tokens.ColorsLight.globalSystemOnSurface,
    secondaryContainer = Tokens.ColorsLight.globalSystemSecondaryContainer,
    onSecondaryContainer = Tokens.ColorsLight.globalSystemOnSurface,
    // color.global.system.surface: "M3 surface / background".
    background = Tokens.ColorsLight.globalSystemSurface,
    onBackground = Tokens.ColorsLight.globalSystemOnSurface,
    surface = Tokens.ColorsLight.globalSystemSurface,
    onSurface = Tokens.ColorsLight.globalSystemOnSurface,
    onSurfaceVariant = Tokens.ColorsLight.globalSystemOnSurfaceVariant,
    outline = Tokens.ColorsLight.globalSystemOutline,
    error = Tokens.ColorsLight.globalSystemError,
    onError = Tokens.ColorsLight.globalSystemOnError,
    surfaceContainerHigh = Tokens.ColorsLight.globalSystemSurfaceContainerHigh,
    surfaceContainerLow = Tokens.ColorsLight.globalSystemSurfaceContainerLow,
)

/** Dark M3 scheme from the `color.global.system.*` dark values. */
val AppDarkColorScheme: ColorScheme = darkColorScheme(
    primary = Tokens.ColorsDark.globalSystemPrimary,
    onPrimary = Tokens.ColorsDark.globalSystemOnPrimary,
    primaryContainer = Tokens.ColorsDark.globalSystemPrimaryContainer,
    onPrimaryContainer = Tokens.ColorsDark.globalSystemOnSurface,
    secondaryContainer = Tokens.ColorsDark.globalSystemSecondaryContainer,
    onSecondaryContainer = Tokens.ColorsDark.globalSystemOnSurface,
    background = Tokens.ColorsDark.globalSystemSurface,
    onBackground = Tokens.ColorsDark.globalSystemOnSurface,
    surface = Tokens.ColorsDark.globalSystemSurface,
    onSurface = Tokens.ColorsDark.globalSystemOnSurface,
    onSurfaceVariant = Tokens.ColorsDark.globalSystemOnSurfaceVariant,
    outline = Tokens.ColorsDark.globalSystemOutline,
    error = Tokens.ColorsDark.globalSystemError,
    onError = Tokens.ColorsDark.globalSystemOnError,
    surfaceContainerHigh = Tokens.ColorsDark.globalSystemSurfaceContainerHigh,
    surfaceContainerLow = Tokens.ColorsDark.globalSystemSurfaceContainerLow,
)

/** The scheme for an appearance. */
fun appColorScheme(dark: Boolean): ColorScheme = if (dark) AppDarkColorScheme else AppLightColorScheme

/**
 * MaterialTheme typography with Retro's overrides (`layout.global.system.typography`): headlineLarge =
 * display 40/48 (`headerTitle`), bodyLarge = Inter 15/18 W600 (`listTitle`), bodyMedium = Inter 14/17 W600,
 * bodySmall = Inter 11/11 W600 (`badge`); every other M3 style stays baseline.
 */
@Composable
fun appTypography(): Typography {
    val headline = TextRoles.headerTitle
    val bodyLarge = TextRoles.listTitle
    val bodyMedium = TextRoles.systemBodyMedium
    val bodySmall = TextRoles.badge
    return remember(headline, bodyLarge, bodyMedium, bodySmall) {
        Typography().copy(headlineLarge = headline, bodyLarge = bodyLarge, bodyMedium = bodyMedium, bodySmall = bodySmall)
    }
}

/**
 * Wraps the whole app, every screen test and every preview. [dark] defaults to the system setting; tests
 * pass it explicitly. Provides [DsTheme] (colour tokens), the M3 scheme and typography for native
 * components, `color.global.textPrimary` as the default content colour, and `size.global.minTouchTarget.android`
 * as the minimum touch target (Compose expands smaller controls' touch bounds to it; M3 components pad to it).
 */
@Composable
fun AppTheme(dark: Boolean = isSystemInDarkTheme(), content: @Composable () -> Unit) {
    DsTheme(dark = dark) {
        MaterialTheme(colorScheme = appColorScheme(dark), typography = appTypography()) {
            val base = LocalViewConfiguration.current
            val target = Tokens.Sizes.globalMinTouchTargetAndroid
            val configuration = remember(base, target) { MinimumTouchTarget(base, DpSize(target, target)) }
            CompositionLocalProvider(
                LocalContentColor provides Tokens.Colors.globalTextPrimary,
                LocalViewConfiguration provides configuration,
                LocalMinimumInteractiveComponentSize provides target,
                content = content,
            )
        }
    }
}

/** The platform view configuration with the token's minimum touch target. */
private class MinimumTouchTarget(private val base: ViewConfiguration, override val minimumTouchTargetSize: DpSize) : ViewConfiguration by base
