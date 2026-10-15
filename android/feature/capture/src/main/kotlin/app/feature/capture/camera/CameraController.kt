package app.feature.capture.camera

import android.annotation.SuppressLint
import android.content.Context
import androidx.camera.core.Camera
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
import app.media.DualCameraSupport
import app.media.DualCaptureMode
import app.media.Lens
import app.media.MediaPermission
import app.media.MediaPermissions
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.withContext
import java.io.File

/** A running video recording; [stop] finalizes the file (the event callback reports it). */
fun interface VideoRecording {
    fun stop()
}

sealed interface VideoStartResult {
    data class Started(val recording: VideoRecording) : VideoStartResult
    data object NotBound : VideoStartResult
}

/**
 * The camera the capture screens drive. [CameraXController] is the device's; tests use fakes.
 * Built on core:media's types ([Lens], [DualCaptureMode], [DualCameraSupport]); it adds what the
 * foundation's `CameraSession` lacks for these screens: the flash (camera.capture /
 * daily.capture flash toggle, hidden without a flash unit) and the capture order of the flip.
 */
interface CameraController {
    /** The live viewfinder (null until the first frame is requested: the black loading state). */
    val preview: StateFlow<SurfaceRequest?>

    /** Whether the bound camera has a flash unit (the flash toggle is hidden otherwise). */
    val hasFlash: StateFlow<Boolean>

    suspend fun bind(lens: Lens, withVideo: Boolean)

    /** One-tap still into [output] (JPEG, no location). */
    suspend fun capturePhoto(output: File, flash: Boolean): File

    /** Starts recording into [output] (audio only with the microphone permission). */
    fun startVideo(output: File, maxDurationMillis: Long, onFinalized: (success: Boolean) -> Unit): VideoStartResult

    /** The front + back mode this device supports. */
    suspend fun dualMode(): DualCaptureMode

    /** Binds for the daily capture: both cameras when supported (preview of [main]), else [main]. */
    suspend fun bindDual(main: Lens): DualCaptureMode

    /**
     * The daily capture: the photo from [main] (the live lens) and from the other lens, at the same
     * moment when supported, else [main] first then the other (sequential fallback). The other
     * photo is null when that camera failed (a single-camera answer, `daily.dualimage`).
     */
    suspend fun captureDual(dir: File, main: Lens, flash: Boolean, onFirstTaken: () -> Unit): DualResult

    suspend fun unbind()

    data class DualResult(val main: File, val other: File?, val mode: DualCaptureMode)
}

/** Creates the controller a capture screen drives; tests replace [factory]. */
object CameraControllers {
    @Volatile var factory: (Context, LifecycleOwner) -> CameraController = { context, owner -> CameraXController(context.applicationContext, owner) }
}

/** CameraX implementation of [CameraController] for one screen's lifecycle. */
class CameraXController(private val context: Context, private val lifecycleOwner: LifecycleOwner) : CameraController {
    private var provider: ProcessCameraProvider? = null
    private var imageCapture: ImageCapture? = null
    private var videoCapture: VideoCapture<Recorder>? = null
    private var dual: Pair<ImageCapture, ImageCapture>? = null
    private var boundLens: Lens? = null

    private val previewState = MutableStateFlow<SurfaceRequest?>(null)
    override val preview: StateFlow<SurfaceRequest?> = previewState.asStateFlow()

    private val flashState = MutableStateFlow(false)
    override val hasFlash: StateFlow<Boolean> = flashState.asStateFlow()

    private suspend fun provider(): ProcessCameraProvider =
        provider ?: ProcessCameraProvider.awaitInstance(context).also { provider = it }

    private fun previewInto(target: MutableStateFlow<SurfaceRequest?>) =
        Preview.Builder().build().also { it.setSurfaceProvider { request -> target.value = request } }

    override suspend fun bind(lens: Lens, withVideo: Boolean) = withContext(Dispatchers.Main) {
        val provider = provider()
        provider.unbindAll()
        dual = null
        val capture = ImageCapture.Builder().setCaptureMode(ImageCapture.CAPTURE_MODE_MINIMIZE_LATENCY).build()
        val group = UseCaseGroup.Builder().addUseCase(previewInto(previewState)).addUseCase(capture)
        val video = if (withVideo) VideoCapture.withOutput(Recorder.Builder().build()).also(group::addUseCase) else null
        val camera: Camera = provider.bindToLifecycle(lifecycleOwner, CameraSelector.Builder().requireLensFacing(lens.facing).build(), group.build())
        imageCapture = capture
        videoCapture = video
        boundLens = lens
        flashState.value = camera.cameraInfo.hasFlashUnit()
    }

    override suspend fun capturePhoto(output: File, flash: Boolean): File {
        val capture = imageCapture ?: error("bind() first")
        capture.flashMode = if (flash && flashState.value) ImageCapture.FLASH_MODE_ON else ImageCapture.FLASH_MODE_OFF
        capture.takePicture(ImageCapture.OutputFileOptions.Builder(output).build())
        return output
    }

    @SuppressLint("MissingPermission") // audio is added only when MediaPermissions says granted
    override fun startVideo(output: File, maxDurationMillis: Long, onFinalized: (Boolean) -> Unit): VideoStartResult {
        val video = videoCapture ?: return VideoStartResult.NotBound
        val options = FileOutputOptions.Builder(output).setDurationLimitMillis(maxDurationMillis).build()
        var pending = video.output.prepareRecording(context, options)
        if (MediaPermissions.isGranted(context, MediaPermission.Microphone)) pending = pending.withAudioEnabled()
        val recording: Recording = pending.start(ContextCompat.getMainExecutor(context)) { event ->
            if (event is VideoRecordEvent.Finalize) {
                // A duration-limit stop is a normal end of a recording.
                onFinalized(event.error == VideoRecordEvent.Finalize.ERROR_NONE || event.error == VideoRecordEvent.Finalize.ERROR_DURATION_LIMIT_REACHED)
            }
        }
        return VideoStartResult.Started { recording.stop() }
    }

    override suspend fun dualMode(): DualCaptureMode = withContext(Dispatchers.Main) {
        DualCameraSupport.mode(DualCameraSupport.hasConcurrentFeature(context), facingCombinations(provider()))
    }

    /** Binds both cameras concurrently when supported (preview of [main]); else [main] alone. */
    override suspend fun bindDual(main: Lens): DualCaptureMode = withContext(Dispatchers.Main) {
        val provider = provider()
        val index = DualCameraSupport.frontBackPair(facingCombinations(provider))
        if (!DualCameraSupport.hasConcurrentFeature(context) || index == null) {
            bind(main, withVideo = false)
            return@withContext DualCaptureMode.Sequential
        }
        val pair = provider.availableConcurrentCameraInfos[index]
        val mainInfo = pair.first { it.lensFacing == main.facing }
        val otherInfo = pair.first { it.lensFacing != main.facing }
        val mainCapture = ImageCapture.Builder().build()
        val otherCapture = ImageCapture.Builder().build()
        val discard = MutableStateFlow<SurfaceRequest?>(null)
        try {
            provider.unbindAll()
            val concurrent: ConcurrentCamera = provider.bindToLifecycle(
                listOf(config(mainInfo, previewInto(previewState), mainCapture), config(otherInfo, previewInto(discard), otherCapture)),
            )
            dual = mainCapture to otherCapture
            imageCapture = null
            videoCapture = null
            boundLens = main
            flashState.value = concurrent.cameras.firstOrNull()?.cameraInfo?.hasFlashUnit() ?: false
            DualCaptureMode.Concurrent
        } catch (_: IllegalArgumentException) {
            bind(main, withVideo = false)
            DualCaptureMode.Sequential
        }
    }

    override suspend fun captureDual(dir: File, main: Lens, flash: Boolean, onFirstTaken: () -> Unit): CameraController.DualResult {
        val mainFile = File(dir, "main.jpg")
        val otherFile = File(dir, "other.jpg")
        val concurrent = dual
        if (concurrent != null) {
            concurrent.first.flashMode = if (flash && flashState.value) ImageCapture.FLASH_MODE_ON else ImageCapture.FLASH_MODE_OFF
            val other = coroutineScope {
                val m = async { concurrent.first.takePicture(ImageCapture.OutputFileOptions.Builder(mainFile).build()) }
                val o = async { runCatching { concurrent.second.takePicture(ImageCapture.OutputFileOptions.Builder(otherFile).build()) }.isSuccess }
                m.await()
                onFirstTaken()
                o.await()
            }
            return CameraController.DualResult(mainFile, otherFile.takeIf { other && it.isFile }, DualCaptureMode.Concurrent)
        }
        if (boundLens != main || imageCapture == null) bind(main, withVideo = false)
        capturePhoto(mainFile, flash)
        onFirstTaken()
        val otherLens = if (main == Lens.Back) Lens.Front else Lens.Back
        val other = runCatching {
            bind(otherLens, withVideo = false)
            capturePhoto(otherFile, flash = false)
        }.getOrNull()
        return CameraController.DualResult(mainFile, other?.takeIf { it.isFile }, DualCaptureMode.Sequential)
    }

    override suspend fun unbind() = withContext(Dispatchers.Main) {
        provider?.unbindAll()
        previewState.value = null
        imageCapture = null
        videoCapture = null
        dual = null
        boundLens = null
    }

    private fun config(info: CameraInfo, preview: Preview, capture: ImageCapture) = ConcurrentCamera.SingleCameraConfig(
        info.cameraSelector,
        UseCaseGroup.Builder().addUseCase(preview).addUseCase(capture).build(),
        lifecycleOwner,
    )

    private fun facingCombinations(provider: ProcessCameraProvider): List<List<Int>> =
        provider.availableConcurrentCameraInfos.map { combo -> combo.map { it.lensFacing } }
}
