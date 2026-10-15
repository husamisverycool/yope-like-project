package app.feature.capture.sendto

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.data.error.DataError
import app.data.error.DataException
import app.data.media.upload.NewPost
import app.data.model.Group
import app.data.model.MediaKind
import app.data.offline.DataState
import app.feature.capture.data.CaptureData
import app.feature.capture.data.CaptureHandoff
import app.feature.capture.data.CapturePrefs
import app.feature.capture.data.CapturedMedia
import app.feature.capture.data.SendTracker
import app.model.SessionPromptGate
import kotlinx.coroutines.Job
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.io.File

/** A recorded voice note for the post (AAC `.m4a`). */
data class VoiceNoteFile(val file: File, val durationMs: Int)

/**
 * `camera.sendto`: choose one or more groups, optional caption and voice note, send. No edit step.
 * Sending queues the post with `uploads.enqueue` (works offline, resumes) and closes at once; the
 * toast host follows the upload ([SendTracker]).
 */
class SendToViewModel(
    private val data: CaptureData,
    private val handoff: CaptureHandoff,
    private val tracker: SendTracker,
    private val prefs: CapturePrefs,
    private val gate: SessionPromptGate,
    /** Whether the voice-note recorder exists in this build (`chat.voice.layout.recording` BLOCKED in release). */
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

    data class UiState(
        val media: CapturedMedia? = null,
        val groups: Groups = Groups.Loading,
        val selected: Set<String> = emptySet(),
        val caption: String = "",
        val voice: VoiceNoteFile? = null,
        val recordingVoice: Boolean = false,
        val voiceCoachVisible: Boolean = false,
        val premium: Boolean = false,
        /** A reply to a photo: exactly the replied post's group. */
        val replyGroupId: String? = null,
        /** The last attempt to queue failed before anything was queued (toast with retry). */
        val sendError: DataError? = null,
        val micAvailable: Boolean = false,
    ) {
        val visibleGroups: List<Group>
            get() {
                val all = (groups as? Groups.Loaded)?.groups.orEmpty()
                return if (replyGroupId != null) all.filter { it.id == replyGroupId } else all
            }

        /** Hidden with nothing selected (never observed disabled), and for a video a free member cannot post. */
        val sendVisible: Boolean
            get() = media != null && selected.isNotEmpty() && (media.kind != MediaKind.Video || premium)
    }

    sealed interface Event {
        data object Close : Event
        data object Sent : Event
        data object OpenPaywall : Event
        data class SaveToLibrary(val media: CapturedMedia) : Event
        data object CreateGroup : Event
    }

    private val pending = handoff.pending.value
    private val state = MutableStateFlow(
        UiState(
            media = pending?.media,
            replyGroupId = pending?.replyToPostId?.let { pending.contextGroupId },
            micAvailable = voiceRecorderAvailable,
            voiceCoachVisible = voiceRecorderAvailable && !prefs.voiceCoachDone,
        ),
    )
    val ui: StateFlow<UiState> = state.asStateFlow()

    // One-shot events, buffered until the screen collects them.
    private val events = Channel<Event>(Channel.BUFFERED)
    val event: Flow<Event> = events.receiveAsFlow()

    private var preselected = false
    private var loadJob: Job? = null

    init {
        loadGroups()
        viewModelScope.launch {
            val premium = runCatching { data.isPremium() }.getOrDefault(false)
            state.update { it.copy(premium = premium) }
            // A picked video by a free member: the paywall once per session; otherwise send stays hidden.
            if (!premium && pending?.media?.kind == MediaKind.Video && gate.tryClaim()) events.send(Event.OpenPaywall)
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
        if (state.value.replyGroupId != null) return
        state.update { s -> s.copy(selected = if (groupId in s.selected) s.selected - groupId else s.selected + groupId) }
    }

    /** Typed on the photo; `camera.sendto.size.captionMaxLength` (BLOCKED → [maxCaption] null) caps it. */
    fun onCaption(text: String) = state.update { it.copy(caption = maxCaption?.let(text::take) ?: text) }

    fun dismissVoiceCoach() {
        prefs.voiceCoachDone = true
        state.update { it.copy(voiceCoachVisible = false) }
    }

    fun onVoiceRecording(recording: Boolean) {
        if (recording) dismissVoiceCoach()
        state.update { it.copy(recordingVoice = recording) }
    }

    fun onVoiceNote(note: VoiceNoteFile?) {
        state.value.voice?.file?.takeIf { it != note?.file }?.delete()
        state.update { it.copy(voice = note, recordingVoice = false) }
    }

    /** ✕: discards the capture, caption and voice note (no confirmation observed). */
    fun close() {
        handoff.discard()
        state.value.voice?.file?.delete()
        events.trySend(Event.Close)
    }

    fun save() {
        state.value.media?.let { events.trySend(Event.SaveToLibrary(it)) }
    }

    fun createGroup() {
        events.trySend(Event.CreateGroup)
    }

    /** Queues the post for every selected group and closes; the toast host follows the upload. */
    fun send() {
        val s = state.value
        val media = s.media ?: return
        if (!s.sendVisible) return
        val order = s.visibleGroups.filter { it.id in s.selected }
        val caption = s.caption.trim().takeIf { it.isNotEmpty() }
        val post = NewPost(
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
        )
        val draftId = try {
            data.enqueue(post)
        } catch (e: DataException) {
            state.update { it.copy(sendError = e.error) }
            return
        }
        tracker.track(draftId, order.map { it.name })
        // The queue copied the files: drop ours.
        handoff.discard()
        s.voice?.file?.delete()
        state.update { it.copy(sendError = null) }
        events.trySend(Event.Sent)
    }
}
