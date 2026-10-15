package app.feature.memory.common

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import app.designsystem.generated.Tokens
import app.designsystem.rememberReduceMotion
import app.ui.components.ToastDwell
import kotlinx.coroutines.delay

/**
 * Renders toasts below this point even if their dwell time were BLOCKED again (layout review in
 * snapshot tests). The app never sets it: toasts show only while `app.ui.components.ToastDwell` has a
 * value (`safety.block.duration.toast`, now sourced: 2 s).
 */
val LocalReviewBlockedToasts = staticCompositionLocalOf { false }

/** Whether toasts are shown: only once `safety.block.duration.toast` is sourced (or under review). */
@Composable
fun toastsShown(): Boolean = ToastDwell.millis != null || LocalReviewBlockedToasts.current

/**
 * The Yope lime toast at the top under the status bar, full width minus `size.global.screenMargin`,
 * capsule (`safety.block.layout.toast`); height, glyph and insets from the measured Yope toast
 * (`camera.sendto.layout.toast`). Success messages lead with `icon.global.checkmark`; failure
 * messages ([success] = false) carry the text only. Dismissed after `ToastDwell.millis`, or on tap.
 */
@Composable
fun MemoryToast(message: String?, onDismiss: () -> Unit, modifier: Modifier = Modifier, success: Boolean = true) {
    if (!toastsShown()) return
    val dismiss by rememberUpdatedState(onDismiss)
    ToastDwell.millis?.let { dwell -> LaunchedEffect(message) { if (message != null) { delay(dwell); dismiss() } } }
    // Keeps the text on screen while the toast leaves.
    var shown by remember { mutableStateOf(message) }
    if (message != null) shown = message
    // Motion of the shared ToastHost (safety.block.layout.toast): drops in with
    // spring.global.platformDefault.android; under Reduce Motion it cross-fades.
    val reduceMotion by rememberReduceMotion()
    val spring = Tokens.Springs.globalPlatformDefaultAndroid
    val enter = if (reduceMotion) fadeIn(spring.spec()) else slideInVertically(spring.spec()) { -it } + fadeIn(spring.spec())
    val exit = if (reduceMotion) fadeOut(spring.spec()) else slideOutVertically(spring.spec()) { -it } + fadeOut(spring.spec())
    val layout = Tokens.Layouts.CameraSendtoLayoutToast
    AnimatedVisibility(
        visible = message != null,
        enter = enter,
        exit = exit,
        modifier = modifier.fillMaxWidth().windowInsetsPadding(WindowInsets.statusBars).padding(horizontal = Tokens.Sizes.globalScreenMargin),
    ) {
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
            BasicText(shown.orEmpty(), style = roleStyle(Tokens.FontSizes.globalButton, Tokens.FontWeights.fontWeightGlobalButton).copy(color = Tokens.Colors.globalOnAccent))
        }
    }
}
