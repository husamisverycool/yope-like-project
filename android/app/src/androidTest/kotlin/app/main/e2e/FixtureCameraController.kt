package app.main.e2e

import android.content.Context
import androidx.camera.core.SurfaceRequest
import androidx.test.platform.app.InstrumentationRegistry
import app.feature.capture.camera.CameraController
import app.feature.capture.camera.VideoStartResult
import app.media.DualCaptureMode
import app.media.Lens
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.withContext
import java.io.File

/**
 * The end-to-end run's camera ([E2eRunner] installs it through `CameraControllers.factory`): binding succeeds, there is
 * no live preview (the viewfinder stays in its black loading state) and a capture writes the sample photo packaged in
 * the test APK (`e2e-photo.jpg`, from fixtures/photos/ by the app module's `e2eFixtures` task). Everything after the
 * shutter — the send-to sheet, the upload queue, storage, `create_post` — is the app's own code against the real stack.
 */
class FixtureCameraController(@Suppress("UNUSED_PARAMETER") context: Context) : CameraController {
    override val preview: StateFlow<SurfaceRequest?> = MutableStateFlow(null)
    override val hasFlash: StateFlow<Boolean> = MutableStateFlow(false)

    override suspend fun bind(lens: Lens, withVideo: Boolean) = Unit

    override suspend fun capturePhoto(output: File, flash: Boolean): File = withContext(Dispatchers.IO) {
        output.parentFile?.mkdirs()
        photo(output)
        output
    }

    /** Video needs premium; the journey never records one. */
    override fun startVideo(output: File, maxDurationMillis: Long, onFinalized: (success: Boolean) -> Unit): VideoStartResult =
        VideoStartResult.NotBound

    override suspend fun dualMode(): DualCaptureMode = DualCaptureMode.Sequential

    override suspend fun bindDual(main: Lens): DualCaptureMode = DualCaptureMode.Sequential

    override suspend fun captureDual(dir: File, main: Lens, flash: Boolean, onFirstTaken: () -> Unit): CameraController.DualResult =
        withContext(Dispatchers.IO) {
            dir.mkdirs()
            val first = File(dir, "main.jpg").also(::photo)
            onFirstTaken()
            val other = File(dir, "other.jpg").also(::photo)
            CameraController.DualResult(first, other, DualCaptureMode.Sequential)
        }

    override suspend fun unbind() = Unit

    private fun photo(target: File) {
        InstrumentationRegistry.getInstrumentation().context.assets.open(ASSET).use { input ->
            target.outputStream().use { input.copyTo(it) }
        }
    }

    private companion object {
        const val ASSET = "e2e-photo.jpg"
    }
}
