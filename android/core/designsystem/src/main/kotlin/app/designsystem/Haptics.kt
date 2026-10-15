package app.designsystem

import android.os.Build
import android.view.HapticFeedbackConstants
import android.view.View

/**
 * Plays a `haptic` token (`Tokens.Haptics.*`, a [HapticFeedbackConstants] value) on [View].
 *
 * Constants newer than the device are mapped to the closest older constant using the same
 * table as AndroidX `HapticFeedbackConstantsCompat` (androidx.core 1.18), so behaviour matches the
 * platform library; the mapping is a pure function ([resolve]) so it is unit-tested per API level.
 * The person's system haptics setting is always respected.
 */
object Haptics {
    /** Returns whether feedback was performed. */
    fun perform(view: View, constant: Int): Boolean {
        val resolved = resolve(constant, Build.VERSION.SDK_INT)
        if (resolved == NO_HAPTICS) return false
        return view.performHapticFeedback(resolved)
    }

    /** The constant to play on [sdkInt], or [NO_HAPTICS] when nothing equivalent exists. */
    fun resolve(constant: Int, sdkInt: Int): Int {
        if (constant == NO_HAPTICS) return NO_HAPTICS
        var c = constant
        if (sdkInt < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            c = when (c) {
                TOGGLE_ON, GESTURE_THRESHOLD_ACTIVATE, SEGMENT_TICK -> HapticFeedbackConstants.CONTEXT_CLICK
                TOGGLE_OFF, GESTURE_THRESHOLD_DEACTIVATE, SEGMENT_FREQUENT_TICK -> HapticFeedbackConstants.CLOCK_TICK
                DRAG_START -> HapticFeedbackConstants.LONG_PRESS
                else -> c
            }
        }
        if (sdkInt < Build.VERSION_CODES.R) {
            c = when (c) {
                GESTURE_START, CONFIRM -> HapticFeedbackConstants.VIRTUAL_KEY
                GESTURE_END -> HapticFeedbackConstants.CONTEXT_CLICK
                REJECT -> HapticFeedbackConstants.LONG_PRESS
                else -> c
            }
        }
        if (sdkInt < Build.VERSION_CODES.O_MR1) {
            c = when (c) {
                KEYBOARD_RELEASE, VIRTUAL_KEY_RELEASE, TEXT_HANDLE_MOVE -> NO_HAPTICS
                else -> c
            }
        }
        return c
    }

    // Platform constant values, spelled out so the table compiles against any SDK level.
    const val NO_HAPTICS = -1
    private const val KEYBOARD_RELEASE = 7 // API 27
    private const val VIRTUAL_KEY_RELEASE = 8 // API 27
    private const val TEXT_HANDLE_MOVE = 9 // API 27
    private const val GESTURE_START = 12 // API 30
    private const val GESTURE_END = 13 // API 30
    private const val CONFIRM = 16 // API 30
    private const val REJECT = 17 // API 30
    private const val TOGGLE_ON = 21 // API 34
    private const val TOGGLE_OFF = 22 // API 34
    private const val GESTURE_THRESHOLD_ACTIVATE = 23 // API 34
    private const val GESTURE_THRESHOLD_DEACTIVATE = 24 // API 34
    private const val DRAG_START = 25 // API 34
    private const val SEGMENT_TICK = 26 // API 34
    private const val SEGMENT_FREQUENT_TICK = 27 // API 34
}
