package app.designsystem

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.staticCompositionLocalOf

/**
 * Whether colour tokens resolve to their dark value (`{light, dark}` in design/tokens). Read by the
 * generated `Tokens.Colors` getters; provided by [DsTheme]. Outside a [DsTheme] it is light.
 */
val LocalDsDarkTheme = staticCompositionLocalOf { false }

/**
 * Applies the system appearance (Light / Dark) to every colour token below it. The app shell, widgets'
 * configuration activity and tests wrap their content in it; tests pass [dark] explicitly.
 */
@Composable
fun DsTheme(dark: Boolean = isSystemInDarkTheme(), content: @Composable () -> Unit) {
    CompositionLocalProvider(LocalDsDarkTheme provides dark, content = content)
}
