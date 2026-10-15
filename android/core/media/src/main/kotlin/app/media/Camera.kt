package app.media

import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import androidx.camera.core.CameraInfo
import androidx.camera.core.CameraSelector
import androidx.camera.core.ConcurrentCamera
import androidx.camera.core.ImageCapture
import androidx.camera.core.Preview
import androidx.camera.core.SurfaceRequest
import androidx.camera.core.UseCaseGroup
import androidx.camera.core.takePicture
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.lifecycle.awaitInstance
import androidx.camera.video.FileOutputOptions
import androidx.camera.video.Recorder
import androidx.camera.video.Recording
import androidx.camera.video.VideoCapture
import androidx.camera.video.VideoRecordEvent
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.withContext
import java.io.File

enum class Lens(val facing: Int) {
    Back(CameraSelector.LENS_FACING_BACK),
    Front(CameraSelector.LENS_FACING_FRONT),
}

/** How the daily invitation's front + back capture runs on this device (surface `daily.capture`). */
sealed interface DualCaptureMode {
    /** Both cameras stream and capture at the same moment. */
    data object Concurrent : DualCaptureMode

    /** Back camera first, then front (spec fallback, docs/SPEC_FLAGS.md P5). */
    data object Sequential : DualCaptureMode
}

data class DualCapture(val back: File, val front: File, val mode: DualCaptureMode)

object DualCameraSupport {
    fun hasConcurrentFeature(context: Context): Boolean =
        context.packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_CONCURRENT)

    /** Index of the first concurrent combination containing a back and a front camera. */
    fun frontBackPair(combinations: List<List<Int>>): Int? =
        combinations.indexOfFirst { CameraSelector.LENS_FACING_BACK in it && CameraSelector.LENS_FACING_FRONT in it }.takeIf { it >= 0 }

    /**
     * Concurrent only when the device declares `FEATURE_CAMERA_CONCURRENT` and CameraX reports a
     * supported front+back combination; otherwise sequential.
     */
    fun mode(hasConcurrentFeature: Boolean, combinations: List<List<Int>>): DualCaptureMode =
        if (hasConcurrentFeature && frontBackPair(combinations) != null) DualCaptureMode.Concurrent else DualCaptureMode.Sequential
}

sealed interface VideoStart {
    data class Started(val recording: Recording) : VideoStart

    /** Video posts are a premium perk; the caller shows the paywall (once per session). */
    data object PremiumRequired : VideoStart

    data object NotBound : VideoStart
}

/**
 * One camera screen's CameraX session. Preview frames are exposed as [SurfaceRequest]s for
 * `CameraXViewfinder` (camera-compose); the screens pass draws them.
 */
class CameraSession(private val context: Context, private val lifecycleOwner: LifecycleOwner) {
    private var provider: ProcessCameraProvider? = null
    private var imageCapture: ImageCapture? = null
    private var videoCapture: VideoCapture<Recorder>? = null
    private var dualCaptures: Pair<ImageCapture, ImageCapture>? = null

    private val primary = MutableStateFlow<SurfaceRequest?>(null)
    private val secondary = MutableStateFlow<SurfaceRequest?>(null)

    /** The single camera's viewfinder, or the back camera's in concurrent dual mode. */
    val preview: StateFlow<SurfaceRequest?> = primary.asStateFlow()

    /** The front camera's viewfinder in concurrent dual mode; null otherwise. */
    val secondaryPreview: StateFlow<SurfaceRequest?> = secondary.asStateFlow()

    var lens: Lens = Lens.Back
        private set

    private suspend fun provider(): ProcessCameraProvider =
        provider ?: ProcessCameraProvider.awaitInstance(context).also { provider = it }

    private fun previewInto(target: MutableStateFlow<SurfaceRequest?>) =
        Preview.Builder().build().also { it.setSurfaceProvider { request -> target.value = request } }

    /** Binds preview + one-tap still capture (+ video capture when [withVideo]) on [lens]. */
    suspend fun bind(lens: Lens, withVideo: Boolean = false) = withContext(Dispatchers.Main) {
        val provider = provider()
        provider.unbindAll()
        secondary.value = null
        dualCaptures = null
        val capture = ImageCapture.Builder().setCaptureMode(ImageCapture.CAPTURE_MODE_MINIMIZE_LATENCY).build()
        val group = UseCaseGroup.Builder().addUseCase(previewInto(primary)).addUseCase(capture)
        val video = if (withVideo) VideoCapture.withOutput(Recorder.Builder().build()).also(group::addUseCase) else null
        provider.bindToLifecycle(lifecycleOwner, CameraSelector.Builder().requireLensFacing(lens.facing).build(), group.build())
        imageCapture = capture
        videoCapture = video
        this@CameraSession.lens = lens
    }

    /** One-tap still: writes a JPEG to [output]. CameraX adds no location (we never pass one). */
    suspend fun capturePhoto(output: File): File {
        val capture = imageCapture ?: error("bind() first")
        capture.takePicture(ImageCapture.OutputFileOptions.Builder(output).build())
        return output
    }

    /**
     * Starts recording to [output]. [premium] gates it (video posts are premium); audio is added
     * only when the microphone permission is granted.
     */
    @SuppressLint("MissingPermission") // checked via MediaPermissions.isGranted
    fun startVideo(
        output: File,
        premium: Boolean,
        maxDurationMillis: Long?,
        onEvent: (VideoRecordEvent) -> Unit,
    ): VideoStart {
        if (!premium) return VideoStart.PremiumRequired
        val video = videoCapture ?: return VideoStart.NotBound
        val options = FileOutputOptions.Builder(output).apply { maxDurationMillis?.let(::setDurationLimitMillis) }.build()
        var pending = video.output.prepareRecording(context, options)
        if (MediaPermissions.isGranted(context, MediaPermission.Microphone)) pending = pending.withAudioEnabled()
        return VideoStart.Started(pending.start(ContextCompat.getMainExecutor(context)) { onEvent(it) })
    }

    /** The dual-capture mode this device supports. */
    suspend fun dualMode(): DualCaptureMode = withContext(Dispatchers.Main) {
        DualCameraSupport.mode(DualCameraSupport.hasConcurrentFeature(context), facingCombinations(provider()))
    }

    /**
     * Binds for the daily invitation: both cameras concurrently when supported (two viewfinders),
     * else the back camera first. Returns the mode actually bound.
     */
    suspend fun bindDual(): DualCaptureMode = withContext(Dispatchers.Main) {
        val provider = provider()
        val combos = provider.availableConcurrentCameraInfos
        val index = DualCameraSupport.frontBackPair(facingCombinations(provider))
        if (!DualCameraSupport.hasConcurrentFeature(context) || index == null) {
            bind(Lens.Back)
            return@withContext DualCaptureMode.Sequential
        }
        val pair = combos[index]
        val back = pair.first { it.lensFacing == CameraSelector.LENS_FACING_BACK }
        val front = pair.first { it.lensFacing == CameraSelector.LENS_FACING_FRONT }
        val backCapture = ImageCapture.Builder().build()
        val frontCapture = ImageCapture.Builder().build()
        try {
            provider.unbindAll()
            provider.bindToLifecycle(
                listOf(
                    config(back, previewInto(primary), backCapture),
                    config(front, previewInto(secondary), frontCapture),
                ),
            )
            dualCaptures = backCapture to frontCapture
            imageCapture = null
            videoCapture = null
            DualCaptureMode.Concurrent
        } catch (_: IllegalArgumentException) {
            // The HAL refused this combination at bind time: fall back.
            bind(Lens.Back)
            DualCaptureMode.Sequential
        }
    }

    /** Front + back photos into [dir]: at the same moment, or back then front. */
    suspend fun captureDual(dir: File): DualCapture {
        val back = File(dir, "back.jpg")
        val front = File(dir, "front.jpg")
        val concurrent = dualCaptures
        if (concurrent != null) {
            coroutineScope {
                val b = async { concurrent.first.takePicture(ImageCapture.OutputFileOptions.Builder(back).build()) }
                val f = async { concurrent.second.takePicture(ImageCapture.OutputFileOptions.Builder(front).build()) }
                b.await(); f.await()
            }
            return DualCapture(back, front, DualCaptureMode.Concurrent)
        }
        if (lens != Lens.Back || imageCapture == null) bind(Lens.Back)
        capturePhoto(back)
        bind(Lens.Front)
        capturePhoto(front)
        return DualCapture(back, front, DualCaptureMode.Sequential)
    }

    suspend fun unbind() = withContext(Dispatchers.Main) {
        provider?.unbindAll()
        primary.value = null
        secondary.value = null
        imageCapture = null
        videoCapture = null
        dualCaptures = null
    }

    private fun config(info: CameraInfo, preview: Preview, capture: ImageCapture) = ConcurrentCamera.SingleCameraConfig(
        info.cameraSelector,
        UseCaseGroup.Builder().addUseCase(preview).addUseCase(capture).build(),
        lifecycleOwner,
    )

    private fun facingCombinations(provider: ProcessCameraProvider): List<List<Int>> =
        provider.availableConcurrentCameraInfos.map { combo -> combo.map { it.lensFacing } }
}
