package app.ui.components

import android.content.Context
import android.widget.Toast
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext

/**
 * C-26 Toasts and confirmations on Android: the **platform `Toast`, `LENGTH_SHORT`** (Retro calls
 * `Toast.makeText(…, LENGTH_SHORT)` for its confirmations — "Saved!", "Copied!", "Invite link copied to
 * clipboard"; RP §3.9; `easing.global.native.toast`). PLATFORM look and duration; the copy is Retro's voice
 * (`retro.voice.*`). C-28 progress lines ("Updating…") are shown the same way. Android announces toasts to
 * TalkBack itself.
 */
object PlatformToast {
    /** Shows [text] now (any thread with a Looper; call from the main thread). */
    fun show(context: Context, text: String) {
        Toast.makeText(context.applicationContext, text, Toast.LENGTH_SHORT).show()
    }
}

/** A confirmation to show; [id] tells two equal texts apart. */
@Immutable
data class ToastMessage(val text: String, val id: Long)

/**
 * Confirmations raised from anywhere (a view model, an environment object) that outlive the navigation that
 * follows them: [show] queues one, [ToastHost] turns it into a [PlatformToast]. A newer message replaces a
 * pending one (the platform queues the ones already shown).
 */
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

/** Shows [state]'s confirmations as platform toasts (C-26). Draws nothing itself; [modifier] is accepted for call-site compatibility. */
@Composable
fun ToastHost(state: ToastState, @Suppress("UNUSED_PARAMETER") modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val message = state.current
    LaunchedEffect(message?.id) {
        if (message != null) {
            PlatformToast.show(context, message.text)
            state.dismiss(message.id)
        }
    }
}
