package app.feature.capture.daily

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.data.error.DataError
import app.data.error.DataException
import app.data.media.upload.NewPost
import app.data.model.MediaKind
import app.feature.capture.camera.CameraController
import app.feature.capture.data.CaptureData
import app.feature.capture.data.PostSend
import app.media.DualCaptureMode
import app.media.Lens
import app.model.CountdownState
import app.model.ServerClock
import app.model.SessionPromptGate
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.io.File

/**
 * `daily.capture`: the countdown to the server's `closes_at` in the title slot while the window is open (the
 * group name afterwards), back + front together (sequential fallback), the preview with retake, and Send with
 * `p_invitation_id` (never fails for lateness; no label). The cover stays open while the post is sent (busy
 * capsule); success closes it, a failure shows the native alert and keeps the preview (as `camera.sendto`).
 */
class DailyCaptureViewModel(
    private val data: CaptureData,
    private val gate: SessionPromptGate,
    private val captureDir: File,
    val groupId: String,
    val invitationId: String,
    private val clock: ServerClock = ServerClock(),
    private val sizeOf: (File) -> Pair<Int, Int>? = { null },
) : ViewModel() {

    enum class Permission { Checking, Granted, Denied }
    enum class Session { Starting, Live, Unavailable }
    enum class Phase { Live, Capturing, Preview }

    data class UiState(
        val permission: Permission = Permission.Checking,
        val session: Session = Session.Starting,
        val phase: Phase = Phase.Live,
        /** Open while the window is; null before the invitation loads and once it closed. */
        val countdown: CountdownState.Open? = null,
        val groupName: String? = null,
        /** The member's first name for the dual image's label. */
        val myName: String? = null,
        val mainLens: Lens = Lens.Back,
        val flashOn: Boolean = false,
        val hasFlash: Boolean = false,
        val mode: DualCaptureMode? = null,
        /** Capturing: the first photo was taken and fades in behind the spinner. */
        val firstTaken: Boolean = false,
        val main: File? = null,
        val inset: File? = null,
        val sending: Boolean = false,
        /** The send failed: the alert with `camera.sendto.error.*` (offline or not). */
        val sendFailedOffline: Boolean? = null,
    )

    sealed interface Event {
        data class Sent(val groupName: String?) : Event
        /** Play `haptic.global.error`. */
        data object Failed : Event
    }

    private val state = MutableStateFlow(UiState())
    val ui: StateFlow<UiState> = state.asStateFlow()
    private val events = Channel<Event>(Channel.BUFFERED)
    val event: Flow<Event> = events.receiveAsFlow()

    private var controller: CameraController? = null
    private var countdownJob: Job? = null
    private val sender = PostSend(data, viewModelScope)

    init {
        // No premium prompt (or any prompt) while capturing.
        gate.enter(SessionPromptGate.Blocker.Capture)
        viewModelScope.launch {
            val invitation = runCatching { data.invitation(invitationId) }.getOrNull()
            if (invitation != null) startCountdown(invitation.closesAt)
        }
        viewModelScope.launch {
            sender.status.collect { status ->
                when (status) {
                    PostSend.Status.Idle -> state.update { it.copy(sending = false) }
                    PostSend.Status.Sending -> state.update { it.copy(sending = true, sendFailedOffline = null) }
                    is PostSend.Status.Sent -> {
                        state.value.main?.parentFile?.deleteRecursively()
                        state.update { it.copy(sending = false) }
                        events.send(Event.Sent(state.value.groupName))
                    }
                    is PostSend.Status.Failed -> {
                        state.update { it.copy(sending = false, sendFailedOffline = status.offline) }
                        events.send(Event.Failed)
                    }
                }
            }
        }
        viewModelScope.launch {
            val name = runCatching { data.group(groupId)?.name }.getOrNull()
            val me = runCatching { data.myFirstName() }.getOrNull()
            state.update { it.copy(groupName = name, myName = me) }
        }
    }

    private fun startCountdown(closesAt: java.time.Instant) {
        countdownJob?.cancel()
        countdownJob = viewModelScope.launch {
            CountdownState.ticks(closesAt) { clock.now() }.collect { tick ->
                state.update { it.copy(countdown = tick as? CountdownState.Open) }
            }
        }
    }

    fun onPermission(granted: Boolean) = state.update { it.copy(permission = if (granted) Permission.Granted else Permission.Denied) }

    fun attach(controller: CameraController) {
        this.controller = controller
        viewModelScope.launch { controller.hasFlash.collect { has -> state.update { it.copy(hasFlash = has) } } }
        startSession()
    }

    fun startSession() {
        if (state.value.permission != Permission.Granted) return
        state.update { it.copy(session = Session.Starting) }
        viewModelScope.launch { rebind() }
    }

    private suspend fun rebind() {
        val c = controller ?: return
        try {
            val mode = c.bindDual(state.value.mainLens)
            state.update { it.copy(session = Session.Live, mode = mode) }
        } catch (e: CancellationException) {
            throw e
        } catch (_: Exception) {
            state.update { it.copy(session = Session.Unavailable) }
        }
    }

    fun toggleFlash() = state.update { it.copy(flashOn = !it.flashOn) }

    /** Swaps which camera is the main photo for this capture. */
    fun flip() {
        if (state.value.phase != Phase.Live) return
        state.update { it.copy(mainLens = if (it.mainLens == Lens.Back) Lens.Front else Lens.Back, flashOn = false) }
        viewModelScope.launch { rebind() }
    }

    /** The shutter: both photos (at once, or main then the other). */
    fun capture() {
        val c = controller ?: return
        val s = state.value
        if (s.phase != Phase.Live || s.session != Session.Live) return
        state.update { it.copy(phase = Phase.Capturing, firstTaken = false) }
        viewModelScope.launch {
            try {
                val dir = File(captureDir, "daily-${System.nanoTime()}").apply { mkdirs() }
                val result = c.captureDual(dir, s.mainLens, flash = s.flashOn && s.hasFlash) {
                    state.update { it.copy(firstTaken = true) }
                }
                state.update { it.copy(phase = Phase.Preview, main = result.main, inset = result.other, mode = result.mode) }
            } catch (e: CancellationException) {
                throw e
            } catch (_: Exception) {
                state.update { it.copy(phase = Phase.Live, session = Session.Unavailable) }
            }
        }
    }

    /** Retake: back to the live screen (unlimited, never counted). */
    fun retake() {
        val s = state.value
        s.main?.parentFile?.deleteRecursively()
        if (s.sending) return
        state.update { it.copy(phase = Phase.Live, main = null, inset = null, firstTaken = false, sendFailedOffline = null) }
        viewModelScope.launch { rebind() }
    }

    /** Send: posts with the invitation id; the cover stays (busy) until the post exists. */
    fun send() {
        val s = state.value
        val main = s.main ?: return
        if (s.sending) return
        val mainSize = sizeOf(main)
        val insetSize = s.inset?.let(sizeOf)
        sender.send(
            NewPost(
                kind = MediaKind.Photo,
                original = main,
                width = mainSize?.first,
                height = mainSize?.second,
                front = s.inset,
                frontWidth = insetSize?.first,
                frontHeight = insetSize?.second,
                groupIds = listOf(groupId),
                invitationId = invitationId,
            ),
        )
    }

    /** "Try Again" in the failure alert. */
    fun retrySend() {
        state.update { it.copy(sendFailedOffline = null) }
        sender.retry()
    }

    /** "Cancel" in the failure alert: the draft is withdrawn, the preview stays. */
    fun dismissSendError() {
        sender.cancel()
        state.update { it.copy(sendFailedOffline = null) }
    }

    /** Dismiss: an unsent preview is discarded; the invitation stays answerable from the group. */
    fun discard() {
        state.value.main?.parentFile?.deleteRecursively()
    }

    override fun onCleared() {
        gate.exit(SessionPromptGate.Blocker.Capture)
    }
}
