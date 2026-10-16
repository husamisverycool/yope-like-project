package app.ui.haptics

import android.view.View
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Stable
import androidx.compose.runtime.remember
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
class AppHaptics internal constructor(private val view: View) {
    fun perform(token: Int) {
        Haptics.perform(view, token)
    }

    /** `haptic.global.tap` (Android value of the per-platform token). */
    fun tap() {
        Haptics.perform(view, TAP)
    }

    /** `haptic.global.select`. */
    fun tick() {
        Haptics.perform(view, Tokens.Haptics.globalSelect)
    }

    /** `haptic.global.longPressStart` (Android value): a long press that opens a context menu starts. */
    fun longPress() {
        Haptics.perform(view, LONG_PRESS)
    }

    private companion object {
        val TAP: Int = Haptics.named(Tokens.Layouts.GlobalTap.android)
        val LONG_PRESS: Int = Haptics.named(Tokens.Layouts.GlobalLongPressStart.android)
    }
}

@Composable
fun rememberHaptics(): AppHaptics {
    val view = LocalView.current
    return remember(view) { AppHaptics(view) }
}
