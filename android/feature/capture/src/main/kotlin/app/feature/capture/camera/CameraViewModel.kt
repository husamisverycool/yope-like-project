package app.feature.capture.camera

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.data.model.MediaKind
import app.feature.capture.data.CaptureData
import app.feature.capture.data.CaptureHandoff
import app.feature.capture.data.CapturePrefs
import app.feature.capture.data.CapturedMedia
import app.media.Lens
import app.model.SessionPromptGate
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.io.File

/**
 * `camera.capture`: opens to the camera; one tap captures a photo and hands it to `camera.sendto`
 * (no edit step); a long press records a video for premium members (a free member's first long
 * press in a session opens the paywall, later ones do nothing; a tap always captures).
 */
class CameraViewModel(
    private val data: CaptureData,
    private val handoff: CaptureHandoff,
    private val prefs: CapturePrefs,
    private val gate: SessionPromptGate,
    private val captureDir: File,
    /** The group the camera was opened for (widget, group screen, chat); preselected in send-to. */
    val contextGroupId: String?,
    /** A reply to a photo with a photo (photo.viewer → camera), carried to `create_post`. */
    val replyToPostId: String? = null,
    private val clock: () -> Long = System::currentTimeMillis,
    /** Video length, for a recorded or picked video (MediaMetadataRetriever on device). */
    private val durationOf: (File) -> Long? = { null },
    /** Pixel size of a captured photo (EXIF orientation applied). */
    private val sizeOf: (File) -> Pair<Int, Int>? = { null },
) : ViewModel() {

    enum class Permission { Checking, Granted, Denied }
    enum class Session { Starting, Live, Unavailable }

    data class UiState(
        val permission: Permission = Permission.Checking,
        val session: Session = Session.Starting,
        val lens: Lens = Lens.Back,
        val flashOn: Boolean = false,
        val hasFlash: Boolean = false,
        /** Video recording is available to this member (premium). */
        val videoAvailable: Boolean = false,
        val coachDone: Boolean = false,
        val recording: Boolean = false,
        val capturing: Boolean = false,
    ) {
        val showControls: Boolean get() = permission == Permission.Granted && session != Session.Unavailable

        /** The coach shows once per install, only to members who can record video. */
        val coachVisible: Boolean get() = videoAvailable && !coachDone && showControls
    }

    sealed interface Event {
        data object OpenSendTo : Event
        data object OpenPaywall : Event
        /** The first video asks for the microphone (never before a photo). */
        data object AskMicrophone : Event
        /** Announce `camera.capture.a11y.recording`. */
        data object RecordingStarted : Event
    }

    private val state = MutableStateFlow(UiState(lens = if (prefs.frontLensThisSession) Lens.Front else Lens.Back, coachDone = prefs.holdToRecordCoachDone))
    val ui: StateFlow<UiState> = state.asStateFlow()

    // One-shot events, buffered until the screen collects them.
    private val events = Channel<Event>(Channel.BUFFERED)
    val event: Flow<Event> = events.receiveAsFlow()

    private var controller: CameraController? = null
    private var recording: VideoRecording? = null
    private var recordingFile: File? = null

    init {
        viewModelScope.launch {
            val premium = runCatching { data.isPremium() }.getOrDefault(false)
            state.update { it.copy(videoAvailable = premium) }
            if (state.value.session == Session.Live) rebind()
        }
    }

    fun onPermission(granted: Boolean) {
        state.update { it.copy(permission = if (granted) Permission.Granted else Permission.Denied) }
    }

    /** The screen's controller is ready (lifecycle-bound); start the session. */
    fun attach(controller: CameraController) {
        this.controller = controller
        viewModelScope.launch {
            controller.hasFlash.collect { has -> state.update { it.copy(hasFlash = has) } }
        }
        startSession()
    }

    /** "try again" on the unavailable state, or a fresh start. */
    fun startSession() {
        if (state.value.permission != Permission.Granted) return
        state.update { it.copy(session = Session.Starting) }
        viewModelScope.launch { rebind() }
    }

    private suspend fun rebind() {
        val c = controller ?: return
        try {
            c.bind(state.value.lens, withVideo = state.value.videoAvailable)
            state.update { it.copy(session = Session.Live) }
        } catch (e: CancellationException) {
            throw e
        } catch (_: Exception) {
            state.update { it.copy(session = Session.Unavailable) }
        }
    }

    fun onSessionInterrupted() {
        state.update { it.copy(session = Session.Unavailable, recording = false) }
    }

    fun toggleFlash() = state.update { it.copy(flashOn = !it.flashOn) }

    fun flip() {
        val next = if (state.value.lens == Lens.Back) Lens.Front else Lens.Back
        prefs.frontLensThisSession = next == Lens.Front
        state.update { it.copy(lens = next, flashOn = false) }
        viewModelScope.launch { rebind() }
    }

    fun dismissCoach() {
        prefs.holdToRecordCoachDone = true
        state.update { it.copy(coachDone = true) }
    }

    /** Tap: one photo, then send-to. */
    fun capturePhoto() {
        val c = controller ?: return
        if (state.value.capturing || state.value.recording || state.value.session != Session.Live) return
        state.update { it.copy(capturing = true) }
        viewModelScope.launch {
            try {
                val file = c.capturePhoto(File(captureDir, "photo-${clock()}.jpg"), flash = state.value.flashOn && state.value.hasFlash)
                val size = sizeOf(file)
                handoff.put(CapturedMedia(MediaKind.Photo, file, size?.first, size?.second, durationMs = null, fromLibrary = false), contextGroupId, replyToPostId)
                events.send(Event.OpenSendTo)
            } catch (e: CancellationException) {
                throw e
            } catch (_: Exception) {
                state.update { it.copy(session = Session.Unavailable) }
            } finally {
                state.update { it.copy(capturing = false) }
            }
        }
    }

    /**
     * Long press start. Premium: records (the first time asks for the microphone instead). Free:
     * the session's first long press opens the paywall (at most one prompt per session).
     */
    fun startVideo(microphoneAsked: Boolean) {
        if (state.value.capturing || state.value.recording || state.value.session != Session.Live) return
        if (!state.value.videoAvailable) {
            if (gate.tryClaim()) events.trySend(Event.OpenPaywall)
            return
        }
        if (!microphoneAsked) {
            events.trySend(Event.AskMicrophone)
            return
        }
        val c = controller ?: return
        val file = File(captureDir, "video-${clock()}.mp4")
        val result = c.startVideo(file, VIDEO_MAX_MS) { ok -> onVideoFinalized(file, ok) }
        if (result is VideoStartResult.Started) {
            recording = result.recording
            recordingFile = file
            state.update { it.copy(recording = true) }
            events.trySend(Event.RecordingStarted)
        }
    }

    /** Release: stops recording (also stops by itself at `camera.capture.duration.videoMax`). */
    fun stopVideo() {
        recording?.stop()
        recording = null
    }

    private fun onVideoFinalized(file: File, ok: Boolean) {
        recording = null
        recordingFile = null
        state.update { it.copy(recording = false) }
        if (!ok || !file.isFile) {
            file.delete()
            return
        }
        // The first recorded video ends the coach for good.
        dismissCoach()
        val duration = durationOf(file)?.toInt()?.takeIf { it > 0 } ?: run { file.delete(); return }
        handoff.put(CapturedMedia(MediaKind.Video, file, null, null, duration, fromLibrary = false), contextGroupId, replyToPostId)
        events.trySend(Event.OpenSendTo)
    }

    /** A photo or video picked in the system Photo Picker (already copied to [file]). */
    fun onPicked(file: File, kind: MediaKind) {
        val media = when (kind) {
            MediaKind.Video -> {
                val duration = durationOf(file)?.toInt()?.takeIf { it > 0 } ?: return
                CapturedMedia(MediaKind.Video, file, null, null, duration, fromLibrary = true)
            }
            else -> {
                val size = sizeOf(file)
                CapturedMedia(MediaKind.Photo, file, size?.first, size?.second, null, fromLibrary = true)
            }
        }
        handoff.put(media, contextGroupId, replyToPostId)
        events.trySend(Event.OpenSendTo)
    }

    override fun onCleared() {
        recording?.stop()
    }

    companion object {
        /** `camera.capture.duration.videoMax` (10 s). */
        val VIDEO_MAX_MS: Long get() = app.designsystem.generated.Tokens.Durations.cameraCaptureDurationVideoMax.toLong()
    }
}
