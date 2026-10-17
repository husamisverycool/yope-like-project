package app.feature.capture

import app.feature.capture.camera.CameraZoom
import app.media.Lens
import org.junit.Assert.assertEquals
import org.junit.Test

/** camera.capture zoom arithmetic (`camera.capture.layout.zoom`). */
class CameraZoomTest {
    private companion object {
        const val DELTA = 0.0001f
    }

    @Test
    fun limitIsDeviceMaxCappedAtTenOnTheBackCameraOnly() {
        assertEquals(10f, CameraZoom.limit(16f, Lens.Back), DELTA)
        assertEquals(4f, CameraZoom.limit(4f, Lens.Back), DELTA)
        assertEquals(1f, CameraZoom.limit(0.5f, Lens.Back), DELTA)
        assertEquals(1f, CameraZoom.limit(16f, Lens.Front), DELTA)
    }

    @Test
    fun pinchAndStepsStayWithinOneAndTheLimit() {
        assertEquals(3f, CameraZoom.pinched(2f, 1.5f, 10f), DELTA)
        assertEquals(10f, CameraZoom.pinched(8f, 3f, 10f), DELTA)
        assertEquals(1f, CameraZoom.pinched(2f, 0.1f, 10f), DELTA)
        assertEquals(1f, CameraZoom.clamp(Float.NaN, 10f), DELTA)
        assertEquals(2f, CameraZoom.stepped(1.4f, up = true, limit = 10f), DELTA)
        assertEquals(1f, CameraZoom.stepped(1.6f, up = false, limit = 10f), DELTA)
        assertEquals(10f, CameraZoom.stepped(10f, up = true, limit = 10f), DELTA)
        assertEquals(1f, CameraZoom.stepped(1f, up = false, limit = 10f), DELTA)
    }
}
