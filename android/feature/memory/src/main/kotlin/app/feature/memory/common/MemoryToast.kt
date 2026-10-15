package app.feature.memory.common

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import app.designsystem.generated.Tokens
import app.ui.components.ToastDwell
import kotlinx.coroutines.delay

/**
 * Renders BLOCKED toasts below this point, for layout review in snapshot tests only. The app never
 * sets it: while the dwell time is BLOCKED no toast is shown in any build (the shared rule of
 * `app.ui.components.ToastDwell`, `safety.block` Gaps).
 */
val LocalReviewBlockedToasts = staticCompositionLocalOf { false }

/** Whether toasts are shown: only once `safety.block.duration.toast` is sourced (or under review). */
@Composable
fun toastsShown(): Boolean = ToastDwell.millis != null || LocalReviewBlockedToasts.current

/**
 * The Yope lime toast at the top under the status bar, full width minus `size.global.screenMargin`,
 * capsule (`safety.block.layout.toast`); height, glyph and insets from the measured Yope toast
 * (`camera.sendto.layout.toast`). Success messages lead with `icon.global.checkmark`; failure
 * messages ([success] = false) carry the text only. Dismissed after the dwell time, or on tap.
 */
@Composable
fun MemoryToast(message: String?, onDismiss: () -> Unit, modifier: Modifier = Modifier, success: Boolean = true) {
    if (message == null || !toastsShown()) return
    val dismiss by rememberUpdatedState(onDismiss)
    ToastDwell.millis?.let { dwell -> LaunchedEffect(message) { delay(dwell); dismiss() } }
    val layout = Tokens.Layouts.CameraSendtoLayoutToast
    Box(modifier.fillMaxWidth().windowInsetsPadding(WindowInsets.statusBars).padding(horizontal = Tokens.Sizes.globalScreenMargin)) {
        Row(
            Modifier
                .fillMaxWidth()
                .heightIn(min = layout.height.dp)
                .background(Tokens.Colors.globalAccent, CircleShape)
                .clickable(onClick = onDismiss)
                .padding(horizontal = layout.glyphInset.dp)
                .semantics { liveRegion = LiveRegionMode.Polite },
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(layout.glyphToText.dp),
        ) {
            if (success) GlyphIcon(Tokens.Icons.globalCheckmark, layout.glyph.dp, Tokens.Colors.globalOnAccent)
            BasicText(message, style = roleStyle(Tokens.FontSizes.globalButton, Tokens.FontWeights.fontWeightGlobalButton).copy(color = Tokens.Colors.globalOnAccent))
        }
    }
}
