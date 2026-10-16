package app.designsystem

import android.content.Context
import android.content.res.Configuration
import android.content.res.Resources
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
 * Applies the system appearance (Light / Dark) to every colour token below it
 * (`layout.global.appearance`: follows the system setting). The app shell (core:ui `AppTheme`, which
 * wraps this), the widgets' configuration activity and tests wrap their content in it; tests pass
 * [dark] explicitly.
 */
@Composable
fun DsTheme(dark: Boolean = isSystemInDarkTheme(), content: @Composable () -> Unit) {
    CompositionLocalProvider(LocalDsDarkTheme provides dark, content = content)
}

/**
 * The appearance outside composition (notifications, Glance `ColorProvider`s, `Application`,
 * window and system-bar colours): there the generated `@Composable` colour getters cannot be read, so
 * code picks `Tokens.ColorsDark.*` or `Tokens.ColorsLight.*` with [isDark].
 */
object DsAppearance {
    /** Whether [configuration] is in the dark appearance (the system Light / Dark setting). */
    fun isDark(configuration: Configuration): Boolean =
        configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK == Configuration.UI_MODE_NIGHT_YES

    /** Whether [context]'s configuration is dark. */
    fun isDark(context: Context): Boolean = isDark(context.resources.configuration)

    /** The system-wide appearance, for code without a context (e.g. a notification accent read when posting). */
    fun isSystemDark(): Boolean = isDark(Resources.getSystem().configuration)

    /** [light] or [dark] for [context]'s appearance (e.g. `pick(ctx, Tokens.ColorsLight.globalAccent, Tokens.ColorsDark.globalAccent)`). */
    fun <T> pick(context: Context, light: T, dark: T): T = if (isDark(context)) dark else light

    /** [light] or [dark] for the system appearance. */
    fun <T> pickSystem(light: T, dark: T): T = if (isSystemDark()) dark else light
}
