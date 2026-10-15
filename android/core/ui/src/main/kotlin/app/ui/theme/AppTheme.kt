package app.ui.theme

import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import app.designsystem.generated.Tokens

/**
 * The app's theme. Dark only (`layout.global.appearance`: "android: dark color scheme only").
 *
 * - App (Yope-referenced) surfaces draw with `Tokens.Colors.global*` directly.
 * - System surfaces (settings, safety, permission rationale, dialogs, sheets) are Material 3
 *   components; their colour roles are the M3 baseline dark scheme recorded as tokens
 *   (`color.global.system.*`, MERGE_DECISIONS F-12) and their type scale is the M3 baseline
 *   (`layout.global.system.typography`), i.e. `MaterialTheme.typography` unchanged.
 */
val AppColorScheme = darkColorScheme(
    primary = Tokens.Colors.globalSystemPrimary,
    surface = Tokens.Colors.globalSystemSurface,
    background = Tokens.Colors.globalSystemSurface,
    onSurface = Tokens.Colors.globalSystemOnSurface,
    onBackground = Tokens.Colors.globalSystemOnSurface,
    onSurfaceVariant = Tokens.Colors.globalSystemOnSurfaceVariant,
    outline = Tokens.Colors.globalSystemOutline,
    error = Tokens.Colors.globalSystemError,
    surfaceContainerHigh = Tokens.Colors.globalSystemSurfaceContainerHigh,
    surfaceContainerLow = Tokens.Colors.globalSystemSurfaceContainerLow,
)

/** Wraps the whole app (and every snapshot test). App text defaults to `color.global.textPrimary`. */
@Composable
fun AppTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = AppColorScheme) {
        CompositionLocalProvider(LocalContentColor provides Tokens.Colors.globalTextPrimary, content = content)
    }
}
