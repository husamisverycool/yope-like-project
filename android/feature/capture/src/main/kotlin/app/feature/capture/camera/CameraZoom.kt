// Surface: camera.capture — pinch to zoom on the viewfinder (`camera.capture.layout.zoom`, design/surfaces/camera.capture.md).
package app.feature.capture.camera

import app.designsystem.generated.Tokens
import app.media.Lens
import java.text.NumberFormat
import kotlin.math.roundToInt

/**
 * The zoom arithmetic of camera.capture: back camera only, from `camera.capture.layout.zoom.min` up to the smaller of
 * the camera's largest zoom ratio (CameraX `ZoomState.maxZoomRatio`) and `camera.capture.layout.zoom.max`.
 */
internal object CameraZoom {
    val min: Float get() = Tokens.Layouts.CameraCaptureLayoutZoom.min

    /** The largest ratio offered for [lens] (the front camera does not zoom). */
    fun limit(deviceMax: Float, lens: Lens): Float = when (lens) {
        Lens.Back -> deviceMax.coerceAtMost(Tokens.Layouts.CameraCaptureLayoutZoom.max).coerceAtLeast(min)
        Lens.Front -> min
    }

    fun clamp(ratio: Float, limit: Float): Float = if (ratio.isNaN()) min else ratio.coerceIn(min, limit.coerceAtLeast(min))

    /** One pinch event: CameraX-style incremental scale ([detectTransformGestures]' zoom change). */
    fun pinched(from: Float, scale: Float, limit: Float): Float = clamp(from * scale, limit)

    /** TalkBack increment / decrement: the next whole step up or down. */
    fun stepped(from: Float, up: Boolean, limit: Float): Float {
        val step = Tokens.Layouts.CameraCaptureLayoutZoom.step
        val whole = (from / step).roundToInt() * step
        val next = if (up) (if (whole > from) whole else whole + step) else (if (whole < from) whole else whole - step)
        return clamp(next, limit)
    }

    /** `camera.capture.a11y.zoomValue`'s {factor}: at most one decimal, in the locale's digits. */
    fun spoken(ratio: Float): String = NumberFormat.getNumberInstance().apply {
        minimumFractionDigits = 0
        maximumFractionDigits = 1
    }.format(ratio.toDouble())
}
