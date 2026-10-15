package app.ui.haptics

import android.view.View
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Stable
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalView
import app.designsystem.Haptics

/**
 * Plays `haptic` tokens (`Tokens.Haptics.global*`, e.g. `globalSuccess`, `globalError`,
 * `globalSelect`, `globalWarning`) on the current view, through the design system's
 * [Haptics.perform] (API-level fallbacks; the person's system haptics setting is respected).
 */
@Stable
class AppHaptics internal constructor(private val view: View) {
    fun perform(token: Int) {
        Haptics.perform(view, token)
    }
}

@Composable
fun rememberHaptics(): AppHaptics {
    val view = LocalView.current
    return remember(view) { AppHaptics(view) }
}
