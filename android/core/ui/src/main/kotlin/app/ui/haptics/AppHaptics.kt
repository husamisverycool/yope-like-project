package app.ui.haptics

import android.view.View
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Stable
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.platform.LocalView
import app.designsystem.Haptics
import app.designsystem.generated.Tokens

/**
 * Plays `haptic` tokens on the current view, through the design system's [Haptics.perform] (API-level
 * fallbacks; the person's system haptics setting is respected):
 *
 * - [tap] — `haptic.global.tap` (Android `VIRTUAL_KEY`), played just **before** a button, tile or card
 *   acts, as Retro's click wrapper does (retro-package-copy-motion.md §3.8, APK-X 'Tap haptic wrapper');
 * - [tick] — `haptic.global.select` (`SEGMENT_FREQUENT_TICK`, `CLOCK_TICK` before API 34): one per step on a
 *   dial / scrubber, a segmented choice, a toggled selection;
 * - [perform] — any other `Tokens.Haptics.global*` (`globalSuccess`, `globalSend`, `globalWarning`, `globalError`).
 */
@Stable
class AppHaptics internal constructor(private val view: View, private val sink: ((Int) -> Unit)? = null) {
    fun perform(token: Int) {
        if (sink != null) sink(Haptics.resolve(token, android.os.Build.VERSION.SDK_INT)) else Haptics.perform(view, token)
    }

    /** `haptic.global.tap` (Android value of the per-platform token). */
    fun tap() = perform(TAP)

    /** `haptic.global.select`. */
    fun tick() = perform(Tokens.Haptics.globalSelect)

    /** `haptic.global.longPressStart` (Android value): a long press that opens a context menu starts. */
    fun longPress() = perform(LONG_PRESS)

    private companion object {
        val TAP: Int = Haptics.named(Tokens.Layouts.GlobalTap.android)
        val LONG_PRESS: Int = Haptics.named(Tokens.Layouts.GlobalLongPressStart.android)
    }
}

/**
 * Receives the haptic constants instead of the view below this point (tests and previews; like
 * `LocalReduceMotionOverride`). Null = play on the view.
 */
val LocalHapticsOverride = staticCompositionLocalOf<((Int) -> Unit)?> { null }

@Composable
fun rememberHaptics(): AppHaptics {
    val view = LocalView.current
    val sink = LocalHapticsOverride.current
    return remember(view, sink) { AppHaptics(view, sink) }
}
