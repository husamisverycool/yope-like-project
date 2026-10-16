package app.feature.capture.sendto

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.data.error.DataError
import app.data.media.upload.NewPost
import app.data.model.Group
import app.data.model.MediaKind
import app.data.offline.DataState
import app.feature.capture.data.CaptureData
import app.feature.capture.data.CaptureHandoff
import app.feature.capture.data.CapturedMedia
import app.feature.capture.data.PostSend
import app.model.SessionPromptGate
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

/** A recorded voice note for the post (AAC `.m4a`). */
data class VoiceNoteFile(val file: File, val durationMs: Int)

/**
 * `camera.sendto` (Retro's Postcard composer, RC-5 … RC-8): choose one or more groups, an optional message
 * (the "Add a Message" sheet, at most `camera.sendto.size.captionMaxLength`) and voice note, then Send. The
 * sheet stays open while the post is sent (busy capsule, "Sending…"); success closes it with a toast, a failure
 * shows the native alert with "Try Again" / "Cancel" and keeps everything. Closing asks first only when a
 * message or voice note would be lost.
 */
class SendToViewModel(
    private val data: CaptureData,
    private val handoff: CaptureHandoff,
    private val gate: SessionPromptGate,
    /** Whether the device can record a voice note (false without a microphone). */
    private val voiceRecorderAvailable: Boolean,
    private val maxCaption: Int? = null,
) : ViewModel() {

    sealed interface Groups {
        data object Loading : Groups
        data object Empty : Groups
        data class Loaded(val groups: List<Group>) : Groups
        /** Nothing cached and the load failed. */
        data class Failed(val offline: Boolean) : Groups
    }

    /** The native alert on screen (C-29). */
    sealed interface Alert {
        /** Close with a message or voice note: `camera.sendto.discard.*`. */
        data object Discard : Alert
        /** Upload or `create_post` failed: `camera.sendto.error.*`. */
        data class SendFailed(val offline: Boolean) : Alert
    }

    data class UiState(
        val media: CapturedMedia? = null,
        val groups: Groups = Groups.Loading,
        val selected: Set<String> = emptySet(),
        val caption: String = "",
        val voice: VoiceNoteFile? = null,
        val recordingVoice: Boolean = false,
        /** When the current recording started (device elapsed clock), for the timer. */
        val recordingStartedAt: Long? = null,
        val premium: Boolean = false,
        /** A reply to a photo: exactly the replied post's group. */
        val replyGroupId: String? = null,
        val micAvailable: Boolean = false,
        val sending: Boolean = false,
        val alert: Alert? = null,
    ) {
        val visibleGroups: List<Group>
            get() {
                val all = (groups as? Groups.Loaded)?.groups.orEmpty()
                return if (replyGroupId != null) all.filter { it.id == replyGroupId } else all
            }

        /** Disabled with nothing selected, and for a video a free member cannot post (`premium_required`). */
        val sendEnabled: Boolean
            get() = media != null && !sending && selected.any { id -> visibleGroups.any { it.id == id } } &&
                (media.kind != MediaKind.Video || premium)

        /** Whether closing would lose something the member added (Retro's lost-changes rule). */
        val hasAdditions: Boolean get() = caption.isNotBlank() || voice != null
    }

    sealed interface Event {
        data object Close : Event
        data class Sent(val groupNames: List<String>) : Event
        data object OpenPaywall : Event
        data class SaveToLibrary(val media: CapturedMedia) : Event
        data object CreateGroup : Event
        /** Play `haptic.global.error` (the send failed). */
        data object Failed : Event
    }

    private val pending = handoff.pending.value
    private val state = MutableStateFlow(
        UiState(
            media = pending?.media,
            replyGroupId = pending?.replyToPostId?.let { pending.contextGroupId },
            micAvailable = voiceRecorderAvailable,
        ),
    )
    val ui: StateFlow<UiState> = state.asStateFlow()

    // One-shot events, buffered until the screen collects them.
    private val events = Channel<Event>(Channel.BUFFERED)
    val event: Flow<Event> = events.receiveAsFlow()

    private val sender = PostSend(data, viewModelScope)
    private var sentTo: List<String> = emptyList()
    private var preselected = false
    private var loadJob: Job? = null

    init {
        loadGroups()
        viewModelScope.launch {
            val premium = runCatching { data.isPremium() }.getOrDefault(false)
            state.update { it.copy(premium = premium) }
            // A picked video by a free member: the paywall once per session; otherwise Send stays disabled.
            if (!premium && pending?.media?.kind == MediaKind.Video && gate.tryClaim()) events.send(Event.OpenPaywall)
        }
        viewModelScope.launch {
            sender.status.collect { status ->
                when (status) {
                    PostSend.Status.Idle -> state.update { it.copy(sending = false) }
                    PostSend.Status.Sending -> state.update { it.copy(sending = true, alert = null) }
                    is PostSend.Status.Sent -> {
                        // The queue copied the files: drop ours.
                        handoff.discard()
                        state.value.voice?.file?.delete()
                        state.update { it.copy(sending = false) }
                        events.send(Event.Sent(sentTo))
                    }
                    is PostSend.Status.Failed -> {
                        state.update { it.copy(sending = false, alert = Alert.SendFailed(status.offline)) }
                        events.send(Event.Failed)
                    }
                }
            }
        }
    }

    fun loadGroups() {
        loadJob?.cancel()
        loadJob = viewModelScope.launch {
            data.groups().collect { result -> onGroups(result) }
        }
    }

    private fun onGroups(result: DataState<List<Group>>) {
        val list = result.value
        val groups = when {
            list == null && result.refreshing -> Groups.Loading
            list == null -> when (result.error) {
                DataError.NotSignedIn, DataError.NotConfigured, null -> Groups.Empty
                else -> Groups.Failed(offline = result.error == DataError.Network)
            }
            list.isEmpty() && result.refreshing -> Groups.Loading
            list.isEmpty() -> Groups.Empty
            else -> Groups.Loaded(list)
        }
        state.update { s ->
            var selected = s.selected
            if (!preselected && groups is Groups.Loaded) {
                preselected = true
                val context = pending?.contextGroupId
                val ids = groups.groups.map { it.id }
                selected = when {
                    // From a group (widget, group screen, chat, reply): that group; gone → nothing.
                    context != null -> setOfNotNull(context.takeIf { it in ids })
                    // No context: every group (references preselect everyone; owner to confirm).
                    else -> ids.toSet()
                }
            } else if (groups is Groups.Loaded) {
                selected = selected.filterTo(LinkedHashSet()) { id -> groups.groups.any { it.id == id } }
            }
            s.copy(groups = groups, selected = selected)
        }
    }

    fun toggle(groupId: String) {
        if (state.value.replyGroupId != null || state.value.sending) return
        state.update { s -> s.copy(selected = if (groupId in s.selected) s.selected - groupId else s.selected + groupId) }
    }

    /**
     * The message from the "Add a Message" sheet; input stops at `camera.sendto.size.captionMaxLength`
     * (UTF-16 units, as the counter counts) without splitting an emoji's surrogate pair.
     */
    fun onCaption(text: String) = state.update { it.copy(caption = maxCaption?.let { max -> capCaption(text, max) } ?: text) }

    private fun capCaption(text: String, max: Int): String {
        if (text.length <= max) return text
        val end = if (Character.isHighSurrogate(text[max - 1])) max - 1 else max
        return text.substring(0, end)
    }

    fun onVoiceRecording(recording: Boolean, startedAt: Long? = null) {
        state.update { it.copy(recordingVoice = recording, recordingStartedAt = if (recording) startedAt else null) }
    }

    fun onVoiceNote(note: VoiceNoteFile?) {
        state.value.voice?.file?.takeIf { it != note?.file }?.delete()
        state.update { it.copy(voice = note, recordingVoice = false, recordingStartedAt = null) }
    }

    /** Removes the recorded note (its menu's "Delete recording"). */
    fun deleteVoice() = onVoiceNote(null)

    /** ✕: back to the camera, discarding the capture; asks first when a message or voice note exists. */
    fun close() {
        if (state.value.sending) return
        if (state.value.hasAdditions) {
            state.update { it.copy(alert = Alert.Discard) }
        } else {
            discardAndClose()
        }
    }

    /** "Yes, go back" in the discard alert. */
    fun confirmDiscard() {
        state.update { it.copy(alert = null) }
        discardAndClose()
    }

    private fun discardAndClose() {
        handoff.discard()
        state.value.voice?.file?.delete()
        events.trySend(Event.Close)
    }

    /** Dismisses the alert on screen ("Cancel"): a failed send's draft is withdrawn; everything else stays. */
    fun dismissAlert() {
        if (state.value.alert is Alert.SendFailed) sender.cancel()
        state.update { it.copy(alert = null) }
    }

    /** "Try Again" in the failure alert. */
    fun retry() {
        state.update { it.copy(alert = null) }
        sender.retry()
    }

    fun save() {
        state.value.media?.let { events.trySend(Event.SaveToLibrary(it)) }
    }

    fun createGroup() {
        events.trySend(Event.CreateGroup)
    }

    /** Sends to every selected group; the sheet stays open (busy) until the post exists. */
    fun send() {
        val s = state.value
        val media = s.media ?: return
        if (!s.sendEnabled) return
        val order = s.visibleGroups.filter { it.id in s.selected }
        sentTo = order.map { it.name }
        val caption = s.caption.trim().takeIf { it.isNotEmpty() }
        sender.send(
            NewPost(
                kind = media.kind,
                original = media.file,
                width = media.width,
                height = media.height,
                durationMs = media.durationMs,
                voice = s.voice?.file,
                voiceDurationMs = s.voice?.durationMs,
                groupIds = order.map { it.id },
                caption = caption,
                replyToPostId = pending?.replyToPostId,
            ),
        )
    }
}
