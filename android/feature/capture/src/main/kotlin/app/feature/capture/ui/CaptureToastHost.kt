// Surface: camera.sendto → States: sent / error / offline (the toast shown on the screen the
// member returns to). Reference: references/auto/yope/frames/a-chuongxetank-7694968408424582452-t7.73-posted-toast-contacts-card.png.
package app.feature.capture.ui

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import app.designsystem.rememberReduceMotion
import kotlinx.coroutines.delay
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.capture.data.CaptureServices
import app.feature.capture.data.SendTracker

/**
 * The send toast at `camera.sendto.layout.toast.top`. A failed or offline send shows
 * `camera.sendto.error.sendFailed` / `.offline` with "try again" until it is sent, with
 * `haptic.global.error` (the send haptic plays optimistically when the post is queued). A sent post
 * shows "posted in …" for `camera.sendto.duration.toastVisible`. Both drop in from the top with
 * `spring.global.platformDefault.android` and leave the same way; under Reduce Motion they
 * cross-fade (`safety.block.layout.toast` enter, the same Yope toast).
 *
 * Placed by every capture screen; the app shell may place it over its own screens too
 * (`groups.list` is where Yope shows it).
 */
@Composable
fun CaptureToastHost(tracker: SendTracker = CaptureServices.tracker(LocalContext.current)) {
    val failure by tracker.failure.collectAsStateWithLifecycle()
    val view = LocalView.current
    var posted by remember { mutableStateOf<SendTracker.Sent?>(null) }
    LaunchedEffect(tracker) {
        tracker.sent.collect { sent ->
            posted = sent
            delay(Tokens.Durations.cameraSendtoDurationToastVisible.toLong())
            if (posted == sent) posted = null
        }
    }
    LaunchedEffect(failure?.draftId, failure is SendTracker.Failure.SendFailed) {
        if (failure is SendTracker.Failure.SendFailed) view.haptic(Tokens.Haptics.globalError)
    }
    // The last shown content stays while the toast leaves.
    var lastPost by remember { mutableStateOf<SendTracker.Sent?>(null) }
    posted?.let { lastPost = it }
    AnimatedToast(visible = failure == null && posted != null, Modifier.testTag("capture.toast.posted")) {
        val shown = lastPost ?: return@AnimatedToast
        LimeToast(
            text = if (shown.groupNames.size == 1) {
                stringResource(R.string.camera_sendto_toast_postedone, shown.groupNames.single())
            } else {
                stringResource(R.string.camera_sendto_toast_postedmany)
            },
            actionLabel = null,
            onAction = null,
            modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
        )
    }

    var lastFailure by remember { mutableStateOf<SendTracker.Failure?>(null) }
    failure?.let { lastFailure = it }
    AnimatedToast(visible = failure != null, Modifier.testTag("capture.toast")) {
        val current = lastFailure ?: return@AnimatedToast
        LimeToast(
            text = stringResource(if (current is SendTracker.Failure.Offline) R.string.camera_sendto_error_offline else R.string.camera_sendto_error_sendfailed),
            actionLabel = stringResource(R.string.camera_sendto_error_retry),
            onAction = { tracker.retry(current.draftId) },
            modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
        )
    }
}

/**
 * A toast slot at `camera.sendto.layout.toast.top`: drops in from the top with
 * `spring.global.platformDefault.android` and leaves the same way; Reduce Motion cross-fades.
 */
@Composable
internal fun AnimatedToast(visible: Boolean, modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    val reduceMotion by rememberReduceMotion()
    val spring = Tokens.Springs.globalPlatformDefaultAndroid
    AnimatedVisibility(
        visible = visible,
        enter = if (reduceMotion) fadeIn(spring.spec()) else slideInVertically(spring.spec()) { -it } + fadeIn(spring.spec()),
        exit = if (reduceMotion) fadeOut(spring.spec()) else slideOutVertically(spring.spec()) { -it } + fadeOut(spring.spec()),
        modifier = modifier.fillMaxWidth().padding(top = Tokens.Layouts.CameraSendtoLayoutToast.top.dp),
    ) { content() }
}
