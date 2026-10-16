// Surface: camera.sendto → States: sent (C-26). Kept for the app shell's call site (:app AppNavHost).
package app.feature.capture.ui

import androidx.compose.runtime.Composable

/**
 * Formerly the Yope lime toast host over groups.list. In the Retro redesign the send stays in its sheet until
 * it is posted (camera.sendto → send: busy capsule, "Sending…", the modal closes on success) and the capture
 * screens raise their own C-26 platform toasts ("Added to …", "Saved"), which outlive the navigation. Nothing
 * is left to draw here; the call in `AppNavHost` can be removed (account group).
 */
@Deprecated("The capture screens show their own platform toasts (C-26); remove the call.")
@Composable
fun CaptureToastHost() = Unit
