package app.ui.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import app.designsystem.generated.Tokens
import app.designsystem.rememberReduceMotion
import app.ui.text.TextRoles
import kotlinx.coroutines.delay

/**
 * Yope's lime confirmation toast (reference T: "posted in the wall"), as specified by
 * `safety.block.layout.toast`: fill `color.global.accent`, `icon.global.checkmark` + label in
 * `color.global.onAccent` (text role `button`), shape `radius.global.capsule`, placed at the top under
 * the status bar, full width minus `size.global.screenMargin` (the caller applies the margin).
 * Height, glyph size, glyph inset and glyph-to-text gap are the measurements of the same Yope toast
 * in `camera.sendto.layout.toast` (49 / 17 / 19.5 / 11).
 *
 * It stays [ToastDwell.millis] (`safety.block.duration.toast`); [ToastHost] shows one at a time.
 */
@Composable
fun LimeToast(text: String, modifier: Modifier = Modifier) {
    val layout = Tokens.Layouts.CameraSendtoLayoutToast
    Row(
        modifier
            .fillMaxWidth()
            .heightIn(min = layout.height.dp)
            .background(Tokens.Colors.globalAccent, CircleShape)
            .padding(horizontal = layout.glyphInset.dp)
            .semantics { liveRegion = LiveRegionMode.Polite },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(layout.glyphToText.dp),
    ) {
        Icon(Tokens.Icons.globalCheckmark, contentDescription = null, tint = Tokens.Colors.globalOnAccent, modifier = Modifier.size(layout.glyph.dp))
        Text(text, style = TextRoles.button, color = Tokens.Colors.globalOnAccent)
    }
}

/** The toast's dwell time. */
object ToastDwell {
    /**
     * `safety.block.duration.toast` (the platform's short toast, 2 s). Nullable for the callers written
     * while the token was BLOCKED (null meant "no toast").
     */
    val millis: Long? = Tokens.Durations.safetyBlockDurationToast.toLong()
}

/** A request to show [text]; [id] tells two equal texts apart. */
@Immutable
data class ToastMessage(val text: String, val id: Long)

/** The toast a [ToastHost] shows: one at a time, a newer one replaces the current one. */
@Stable
class ToastState {
    var current: ToastMessage? by mutableStateOf(null)
        private set
    private var next = 0L

    fun show(text: String) {
        current = ToastMessage(text, next++)
    }

    fun dismiss(id: Long) {
        if (current?.id == id) current = null
    }
}

/**
 * Shows [state]'s toast at the top of the screen under the status bar, full width minus
 * `size.global.screenMargin` (`safety.block.layout.toast`), for [ToastDwell.millis]. It drops in from
 * the top with `spring.global.platformDefault.android` and leaves the same way; under Reduce Motion
 * (`layout.global.reduceMotion`) it cross-fades. TalkBack announces it (live region of [LimeToast]).
 */
@Composable
fun ToastHost(state: ToastState, modifier: Modifier = Modifier) {
    val dwell = ToastDwell.millis ?: return
    val message = state.current
    val reduceMotion by rememberReduceMotion()
    var last by remember { mutableStateOf<ToastMessage?>(null) }
    if (message != null) last = message
    LaunchedEffect(message?.id) {
        if (message != null) {
            delay(dwell)
            state.dismiss(message.id)
        }
    }
    val spring = Tokens.Springs.globalPlatformDefaultAndroid
    val enter = if (reduceMotion) fadeIn(spring.spec()) else slideInVertically(spring.spec()) { -it } + fadeIn(spring.spec())
    val exit = if (reduceMotion) fadeOut(spring.spec()) else slideOutVertically(spring.spec()) { -it } + fadeOut(spring.spec())
    AnimatedVisibility(
        visible = message != null,
        enter = enter,
        exit = exit,
        modifier = modifier.windowInsetsPadding(WindowInsets.statusBars).padding(horizontal = Tokens.Sizes.globalScreenMargin),
    ) {
        last?.let { LimeToast(it.text) }
    }
}
