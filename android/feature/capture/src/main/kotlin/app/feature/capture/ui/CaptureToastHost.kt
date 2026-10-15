// Surface: camera.sendto → States: sent / error / offline (the toast shown on the screen the
// member returns to). Reference: references/auto/yope/frames/a-chuongxetank-7694968408424582452-t7.73-posted-toast-contacts-card.png.
package app.feature.capture.ui

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
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
 * `camera.sendto.error.sendFailed` / `.offline` with "try again" until it is sent; a successful
 * send plays `haptic.global.send` (failure `haptic.global.error`). The "posted in …" toast is not
 * shown: its visible duration `camera.sendto.duration.toastVisible` is BLOCKED.
 *
 * Placed by every capture screen; the app shell may place it over its own screens too
 * (`groups.list` is where Yope shows it).
 */
@Composable
fun CaptureToastHost(tracker: SendTracker = CaptureServices.tracker(LocalContext.current)) {
    val failure by tracker.failure.collectAsStateWithLifecycle()
    val view = LocalView.current
    LaunchedEffect(tracker) {
        tracker.sent.collect { view.haptic(Tokens.Haptics.globalSend) }
    }
    LaunchedEffect(failure?.draftId, failure is SendTracker.Failure.SendFailed) {
        if (failure is SendTracker.Failure.SendFailed) view.haptic(Tokens.Haptics.globalError)
    }
    val current = failure ?: return
    Box(Modifier.fillMaxWidth().padding(top = Tokens.Layouts.CameraSendtoLayoutToast.top.dp).testTag("capture.toast")) {
        LimeToast(
            text = stringResource(if (current is SendTracker.Failure.Offline) R.string.camera_sendto_error_offline else R.string.camera_sendto_error_sendfailed),
            actionLabel = stringResource(R.string.camera_sendto_error_retry),
            onAction = { tracker.retry(current.draftId) },
            modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
        )
    }
}
