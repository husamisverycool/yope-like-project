package app.feature.social.viewer

import android.content.Context
import android.content.pm.PackageManager
import androidx.camera.core.SurfaceRequest
import androidx.lifecycle.LifecycleOwner
import app.media.CameraSession
import app.media.Lens
import kotlinx.coroutines.flow.StateFlow
import java.io.File

/**
 * The front camera of the selfie capture layer (`viewer.selfiereaction` → Platform notes: CameraX
 * `DEFAULT_FRONT_CAMERA`, preview clipped to a circle). [CameraXSelfieCamera] is the device's; tests use fakes
 * through [SelfieCameras.factory].
 */
interface SelfieCamera {
    /** The live preview (null until the first frame is requested: the "camera starting" state). */
    val preview: StateFlow<SurfaceRequest?>

    /** Binds the front camera with a still capture; throws when it cannot open. */
    suspend fun start()

    /** One still into [output] (JPEG, no location: CameraX adds none). */
    suspend fun capture(output: File): File

    suspend fun stop()
}

/** Creates the layer's camera and tells whether the device has a front camera (none → the entry points are hidden). */
object SelfieCameras {
    @Volatile var factory: (Context, LifecycleOwner) -> SelfieCamera = { context, owner -> CameraXSelfieCamera(context.applicationContext, owner) }

    @Volatile var hasFrontCamera: (Context) -> Boolean = { it.packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_FRONT) }
}

/** core:media's [CameraSession] on [Lens.Front], bound to the viewer's lifecycle. */
class CameraXSelfieCamera(context: Context, owner: LifecycleOwner) : SelfieCamera {
    private val session = CameraSession(context, owner)

    override val preview: StateFlow<SurfaceRequest?> get() = session.preview

    override suspend fun start() = session.bind(Lens.Front)

    override suspend fun capture(output: File): File = session.capturePhoto(output)

    override suspend fun stop() = session.unbind()
}
