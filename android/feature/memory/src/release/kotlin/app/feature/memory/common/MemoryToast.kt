package app.feature.memory.common

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/**
 * Release builds skip the Yope toast: its dwell time is BLOCKED (`camera.sendto.duration.toastVisible`,
 * `safety.block.duration.toast`), the same rule `safety.block` follows. Haptics still play.
 */
@Suppress("UNUSED_PARAMETER")
@Composable
fun MemoryToast(message: String?, onDismiss: () -> Unit, modifier: Modifier = Modifier, success: Boolean = true) = Unit

/** Whether this build shows toasts (DEBUG: yes, for review; release: no while the dwell is BLOCKED). */
const val TOASTS_SHOWN: Boolean = false
