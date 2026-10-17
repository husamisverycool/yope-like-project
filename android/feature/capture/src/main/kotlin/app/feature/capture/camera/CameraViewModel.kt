package app.feature.capture.camera

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.data.error.DataError
import app.data.error.DataException
import app.data.media.upload.NewPost
import app.data.media.upload.UploadProgress
import app.data.model.Developing
import app.data.model.Group
import app.data.model.MediaKind
import app.feature.capture.data.CaptureData
import app.feature.capture.data.CaptureHandoff
import app.feature.capture.data.CapturePrefs
import app.feature.capture.data.CapturedMedia
import app.feature.capture.data.PickedFile
import app.feature.capture.sendto.SendToViewModel
import app.media.Lens
import app.model.SessionPromptGate
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.io.File
import java.time.Instant
import java.time.LocalDate

/**
 * `camera.capture`: opens to the camera; one tap captures a photo and hands it to `camera.sendto`
 * (no edit step); a long press records a video for premium members (a free member's first long
 * press in a session opens the paywall, later ones do nothing; a tap always captures).
 * `camera.overnight` adds the 9 AM mode: photos queued to develop in the chosen groups at the next reveal.
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
    /** The weekly question being answered (`question.weekly` B): carried to send-to, linked after posting. */
    val questionId: String? = null,
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
        /** `camera.overnight`: 9 AM or Now (Now at every app launch, MERGE_DECISIONS ON-1). */
        val mode: CaptureMode = CaptureMode.Now,
        /** The mode control is offered (not on a reply to a photo: `create_overnight_post` has no reply). */
        val overnightAvailable: Boolean = true,
        /** The member's groups for the destination pill and sheet (`camera.sendto`'s loading / empty / failed states). */
        val groups: SendToViewModel.Groups = SendToViewModel.Groups.Loading,
        /** The groups the next 9 AM photos develop for. */
        val destinations: Set<String> = emptySet(),
        val destinationSheet: Boolean = false,
        /**
         * `my_developing()`: whether your photos are developing and the next reveal — for the developing stack in the leading
         * slot, which stays empty while `camera.overnight.layout.stackCards` is BLOCKED.
         */
        val developing: Developing? = null,
        /** camera.trim: a library video longer than `camera.capture.duration.videoMax` waiting in the trimmer. */
        val trim: TrimRequest? = null,
        /** camera.trim: the picked video could not be trimmed — the "Video too long" alert. */
        val videoTooLong: Boolean = false,
        /**
         * The most items the library picker offers (`batch_max_photos`, a public app_config key; several photos in one
         * post); 1 until the server's value is known.
         */
        val selectionLimit: Int = 1,
        /** `camera.capture.layout.zoom`: the back camera's zoom ratio (min after a flip; the front camera does not zoom). */
        val zoom: Float = CameraZoom.min,
        /** The bound camera's largest zoom ratio (CameraX `ZoomState.maxZoomRatio`). */
        val deviceMaxZoom: Float = 1f,
    ) {
        val showControls: Boolean get() = permission == Permission.Granted && session != Session.Unavailable

        /** The largest zoom offered for the active lens (min: no zoom). */
        val zoomLimit: Float get() = CameraZoom.limit(deviceMaxZoom, lens)

        /** The live viewfinder takes pinches and is an adjustable TalkBack element. */
        val zoomAvailable: Boolean get() = permission == Permission.Granted && session == Session.Live && zoomLimit > CameraZoom.min

        /** The coach shows once per install, only to members who can record video, never in 9 AM mode. */
        val coachVisible: Boolean get() = videoAvailable && !coachDone && showControls && mode == CaptureMode.Now

        /** 9 AM mode hides the library circle (a picked photo was already seen). */
        val showLibrary: Boolean get() = mode == CaptureMode.Now

        /** The chosen groups in the member's group order (what `create_overnight_post` gets). */
        val destinationGroups: List<Group> get() = (groups as? SendToViewModel.Groups.Loaded)?.groups.orEmpty().filter { it.id in destinations }
    }

    sealed interface Event {
        data object OpenSendTo : Event
        data object OpenPaywall : Event
        /** The first video asks for the microphone (never before a photo). */
        data object AskMicrophone : Event
        /** Announce `camera.capture.a11y.recording`. */
        data object RecordingStarted : Event
        /** A 9 AM photo was taken and queued: announce `camera.overnight.a11y.captured` with its [reveal]. */
        data class OvernightCaptured(val reveal: Instant) : Event
        /** A 9 AM photo could not be queued or failed after its retries: `camera.sendto.error.sendFailed` (C-26 toast). */
        data object OvernightFailed : Event
    }

    private val state = MutableStateFlow(
        UiState(lens = if (prefs.frontLensThisSession) Lens.Front else Lens.Back, coachDone = prefs.holdToRecordCoachDone, overnightAvailable = replyToPostId == null),
    )
    val ui: StateFlow<UiState> = state.asStateFlow()

    // One-shot events, buffered until the screen collects them.
    private val events = Channel<Event>(Channel.BUFFERED)
    val event: Flow<Event> = events.receiveAsFlow()

    private var controller: CameraController? = null
    private var recording: VideoRecording? = null
    private var recordingFile: File? = null

    private var groupsJob: Job? = null

    /** A library selection on its way to send-to: each video over the limit goes through the trimmer in turn first. */
    private val selection = mutableListOf<CapturedMedia>()

    init {
        viewModelScope.launch {
            val premium = runCatching { data.isPremium() }.getOrDefault(false)
            state.update { it.copy(videoAvailable = premium) }
            if (state.value.session == Session.Live) rebind()
        }
        viewModelScope.launch {
            val limit = runCatching { data.batchMaxPhotos() }.getOrNull()
            if (limit != null && limit > 0) state.update { it.copy(selectionLimit = limit) }
        }
    }

    // ---- camera.overnight (part A) ------------------------------------------------------------

    /** The member's groups (cache first), with the session's destinations or the default: the camera's group, else all. */
    fun loadGroups() {
        groupsJob?.cancel()
        groupsJob = viewModelScope.launch {
            data.groups().collect { result ->
                val list = result.value
                val groups = when {
                    list == null && result.refreshing -> SendToViewModel.Groups.Loading
                    list == null -> when (result.error) {
                        DataError.NotSignedIn, DataError.NotConfigured, null -> SendToViewModel.Groups.Empty
                        else -> SendToViewModel.Groups.Failed(offline = result.error == DataError.Network)
                    }
                    list.isEmpty() && result.refreshing -> SendToViewModel.Groups.Loading
                    list.isEmpty() -> SendToViewModel.Groups.Empty
                    else -> SendToViewModel.Groups.Loaded(list)
                }
                state.update { s ->
                    val ids = (groups as? SendToViewModel.Groups.Loaded)?.groups?.map { it.id } ?: return@update s.copy(groups = groups)
                    val chosen = prefs.overnightGroups ?: s.destinations.takeIf { it.isNotEmpty() } ?: defaultDestinations(ids)
                    s.copy(groups = groups, destinations = chosen.filterTo(LinkedHashSet()) { it in ids })
                }
            }
        }
    }

    /** Every group selected (owner decision 11, as `camera.sendto`), or the group the camera was opened for. */
    private fun defaultDestinations(ids: List<String>): Set<String> = contextGroupId?.let { setOfNotNull(it.takeIf { id -> id in ids }) } ?: ids.toSet()

    /**
     * The mode control. The first switch to 9 AM in an app session opens the destination sheet (Dispo's roll drawer);
     * afterwards the session's choice is kept.
     */
    fun selectMode(mode: CaptureMode) {
        if (!state.value.overnightAvailable || state.value.recording || mode == state.value.mode) return
        state.update { it.copy(mode = mode, destinationSheet = mode == CaptureMode.Later && prefs.overnightGroups == null) }
        if (mode == CaptureMode.Later) {
            // Read only once 9 AM is used: the camera is the app's first screen.
            if (groupsJob == null) loadGroups()
            refreshDeveloping()
        }
    }

    /** The destination pill. */
    fun openDestinations() = state.update { it.copy(destinationSheet = true) }

    fun toggleDestination(groupId: String) =
        state.update { s -> s.copy(destinations = if (groupId in s.destinations) s.destinations - groupId else s.destinations + groupId) }

    /** Done (or the sheet swiped away): the choice is kept for the session; nothing selected switches back to Now. */
    fun confirmDestinations() {
        val s = state.value
        val loaded = s.groups is SendToViewModel.Groups.Loaded
        if (loaded) prefs.overnightGroups = s.destinations
        state.update {
            it.copy(destinationSheet = false, mode = if (loaded && it.destinations.isNotEmpty()) it.mode else CaptureMode.Now)
        }
    }

    private fun refreshDeveloping() {
        viewModelScope.launch {
            runCatching { data.myDeveloping() }.getOrNull()?.let { d -> state.update { it.copy(developing = d) } }
        }
    }

    /**
     * 9 AM mode's shutter: the photo is stored in app storage and queued (`camera.overnight.layout.uploadQueue`: works
     * offline, uploads on reconnect, the local copy goes once uploaded) as `create_overnight_post` to the chosen groups — no
     * preview, no send-to; the camera stays ready. Never written to the photo library.
     */
    private suspend fun captureOvernight(c: CameraController) {
        val groups = state.value.destinationGroups
        if (groups.isEmpty()) {
            state.update { it.copy(destinationSheet = true) }
            return
        }
        val file = c.capturePhoto(File(captureDir, "night-${clock()}.jpg"), flash = state.value.flashOn && state.value.hasFlash)
        val size = sizeOf(file)
        val draft = try {
            data.enqueue(NewPost(kind = MediaKind.Photo, original = file, width = size?.first, height = size?.second, groupIds = groups.map { it.id }, overnight = true))
        } catch (_: DataException) {
            null
        } finally {
            // The queue copied the photo into its own folder.
            file.delete()
        }
        if (draft == null) {
            events.send(Event.OvernightFailed)
            return
        }
        events.send(Event.OvernightCaptured(OvernightReveal.earliest(Instant.ofEpochMilli(clock()), groups)))
        viewModelScope.launch {
            data.progress(draft).first { it is UploadProgress.Done || it is UploadProgress.Failed }.let { result ->
                if (result is UploadProgress.Failed) events.send(Event.OvernightFailed) else refreshDeveloping()
            }
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
        viewModelScope.launch {
            controller.maxZoomRatio.collect { max ->
                state.update { it.copy(deviceMaxZoom = max, zoom = CameraZoom.clamp(it.zoom, CameraZoom.limit(max, it.lens))) }
            }
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
            // The camera binds unzoomed: the screen's zoom is applied again (min after a flip).
            if (state.value.zoom != CameraZoom.min) c.setZoomRatio(state.value.zoom)
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
        // Zoom resets when the camera flips.
        state.update { it.copy(lens = next, flashOn = false, zoom = CameraZoom.min) }
        viewModelScope.launch { rebind() }
    }

    /** One pinch event on the viewfinder: [scale] is the change since the previous event. */
    fun zoomBy(scale: Float) {
        val s = state.value
        if (!s.zoomAvailable) return
        applyZoom(CameraZoom.pinched(s.zoom, scale, s.zoomLimit))
    }

    /** TalkBack increment / decrement: the next whole zoom step. */
    fun stepZoom(up: Boolean) {
        val s = state.value
        if (!s.zoomAvailable) return
        applyZoom(CameraZoom.stepped(s.zoom, up, s.zoomLimit))
    }

    private fun applyZoom(ratio: Float) {
        if (ratio == state.value.zoom) return
        state.update { it.copy(zoom = ratio) }
        controller?.setZoomRatio(ratio)
    }

    /**
     * A tap on the viewfinder, mapped to the preview surface: focus and exposure there, continuous autofocus again after
     * `camera.capture.duration.focusReset` (CameraX auto-cancel).
     */
    fun focusAt(x: Float, y: Float) {
        if (state.value.session != Session.Live) return
        controller?.focusAt(x, y, app.designsystem.generated.Tokens.Durations.cameraCaptureDurationFocusReset.toLong())
    }

    fun dismissCoach() {
        prefs.holdToRecordCoachDone = true
        state.update { it.copy(coachDone = true) }
    }

    /** Tap: one photo, then send-to (in 9 AM mode: queued to develop, the camera stays). */
    fun capturePhoto() {
        val c = controller ?: return
        if (state.value.capturing || state.value.recording || state.value.session != Session.Live) return
        state.update { it.copy(capturing = true) }
        viewModelScope.launch {
            try {
                if (state.value.mode == CaptureMode.Later) {
                    captureOvernight(c)
                    return@launch
                }
                val file = c.capturePhoto(File(captureDir, "photo-${clock()}.jpg"), flash = state.value.flashOn && state.value.hasFlash)
                val size = sizeOf(file)
                handoff.put(CapturedMedia(MediaKind.Photo, file, size?.first, size?.second, durationMs = null, fromLibrary = false), contextGroupId, replyToPostId, questionId)
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
        // 9 AM mode: photos only, hold does nothing (camera.overnight → shutter).
        if (state.value.mode == CaptureMode.Later) return
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
        handoff.put(CapturedMedia(MediaKind.Video, file, null, null, duration, fromLibrary = false), contextGroupId, replyToPostId, questionId)
        events.trySend(Event.OpenSendTo)
    }

    /**
     * A photo or video picked in the system Photo Picker (already copied to [file]). A video longer than the camera's
     * limit goes to the trimmer first (camera.trim; the server refuses longer videos, `video_too_long`).
     */
    fun onPicked(file: File, kind: MediaKind, takenOn: LocalDate? = null) = onPickedAll(listOf(PickedFile(file, kind, takenOn)))

    /**
     * Several items picked (or shared from another app, `share.in`) at once, in the order picked: one send-to for the
     * whole selection, each item its own post with the same `batch_id`. Each video over the limit goes through the
     * trimmer in turn — its Cancel leaves that video out, a clip that cannot be written is left out after the "Video too
     * long" alert — and the others go on to send-to. [sharedGroupId]: the group picked in the share sheet's per-group
     * targets (share.in), preselected in send-to instead of the camera's own context.
     */
    fun onPickedAll(picked: List<PickedFile>, sharedGroupId: String? = null) {
        val items = picked.mapNotNull { item ->
            when (item.kind) {
                MediaKind.Video -> {
                    val duration = durationOf(item.file)?.toInt()?.takeIf { it > 0 }
                    if (duration == null) {
                        item.file.delete()
                        null
                    } else {
                        CapturedMedia(MediaKind.Video, item.file, null, null, duration, fromLibrary = true, takenOn = item.takenOn)
                    }
                }
                else -> {
                    val size = sizeOf(item.file)
                    CapturedMedia(MediaKind.Photo, item.file, size?.first, size?.second, null, fromLibrary = true, takenOn = item.takenOn)
                }
            }
        }
        if (items.isEmpty()) return
        val kept = items.map { it.file }.toSet()
        selection.filter { it.file !in kept }.forEach { it.file.delete() }
        selection.clear()
        selection += items
        selectionGroupId = sharedGroupId
        continueSelection()
    }

    /** The group picked in the share sheet for the selection being prepared (share.in); null: the camera's context. */
    private var selectionGroupId: String? = null

    /** The next video over the limit opens the trimmer; with none left, send-to opens on the selection. */
    private fun continueSelection() {
        val long = selection.firstOrNull { it.kind == MediaKind.Video && VideoLimit.isTooLong((it.durationMs ?: 0).toLong()) }
        if (long != null) {
            state.update { it.copy(trim = TrimRequest(long.file, (long.durationMs ?: 0).toLong())) }
            return
        }
        val first = selection.firstOrNull() ?: return
        val more = selection.drop(1)
        selection.clear()
        handoff.put(first, selectionGroupId ?: contextGroupId, replyToPostId, questionId, more)
        selectionGroupId = null
        events.trySend(Event.OpenSendTo)
    }

    /** Where the trimmer writes the clip (the capture folder, like a recording). */
    fun trimTarget(): File = File(captureDir, "trim-${clock()}.mp4")

    /**
     * The trimmer closed: the clip takes the video's place in the selection; Cancel leaves the video out (back to the
     * camera when it was the only item); a failure shows the alert.
     */
    fun onTrimmed(trimmed: File?, failed: Boolean) {
        val request = state.value.trim ?: return
        state.update { it.copy(trim = null) }
        request.file.delete()
        val index = selection.indexOfFirst { it.file == request.file }
        val original = selection.getOrNull(index)
        if (trimmed == null) {
            if (index >= 0) selection.removeAt(index)
            if (failed) state.update { it.copy(videoTooLong = true) } else continueSelection()
            return
        }
        val duration = durationOf(trimmed)?.takeIf { it > 0 }
        if (duration == null || VideoLimit.isTooLong(duration)) {
            trimmed.delete()
            if (index >= 0) selection.removeAt(index)
            state.update { it.copy(videoTooLong = true) }
            return
        }
        val clip = CapturedMedia(MediaKind.Video, trimmed, null, null, duration.toInt(), fromLibrary = true, takenOn = original?.takenOn)
        if (index >= 0) {
            selection[index] = clip
        } else {
            selection.clear()
            selection += clip
        }
        continueSelection()
    }

    /** The "Video too long" alert closed: the rest of the selection goes on (nothing when it was the only item). */
    fun dismissVideoTooLong() {
        state.update { it.copy(videoTooLong = false) }
        continueSelection()
    }

    override fun onCleared() {
        recording?.stop()
    }

    companion object {
        /** `camera.capture.duration.videoMax` (10 s). */
        val VIDEO_MAX_MS: Long get() = app.designsystem.generated.Tokens.Durations.cameraCaptureDurationVideoMax.toLong()
    }
}
