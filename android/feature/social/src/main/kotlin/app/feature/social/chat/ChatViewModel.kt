package app.feature.social.chat

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.data.error.DataError
import app.data.model.ChatTyping
import app.data.model.Group
import app.data.model.Media
import app.feature.social.common.videoDurationMs
import app.data.model.Message
import app.data.model.MessageKind
import app.data.model.Post
import app.data.model.Profile
import app.data.model.PublicAppConfig
import app.data.offline.DataState
import app.data.realtime.GroupEvent
import app.data.repo.ReactionEntry
import app.feature.social.data.SocialData
import app.feature.social.data.dataError
import app.feature.social.reactions.withReaction
import app.feature.social.reactions.withoutReaction
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.channels.BufferOverflow
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.drop
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable
import java.io.File
import java.time.Duration
import java.time.Instant

/** The quote above a reply (`chat.thread.layout.replyQuote`). */
sealed interface Quote {
    /** A reply to a photo: a C-15 row — thumbnail, "Post by {name}" over "Week {n}" (ISO week of the post in the group's zone). */
    data class Photo(val postId: String, val posterName: String?, val thumbPath: String?, val weekNumber: Int?, val videoDurationMs: Long? = null) : Quote

    /** A reply to a message: one grey line, the sender's name in semibold then the quoted text ([text] null = an attachment). */
    data class Text(val messageId: String, val senderName: String?, val text: String?, val attachment: Boolean) : Quote
}

/** What the reply bar replies to (`chat.thread.reply.bar` / `.barSelf`): a photo ([postId]) or a message ([messageId]). */
data class ReplyTarget(val postId: String?, val messageId: String?, val name: String, val self: Boolean)

/**
 * One message as drawn. Photo messages carry their post, media and reaction rows; text and voice messages their own
 * reaction rows (`chat.reactions.layout.messageReactions`, one per person) — never a count.
 */
data class ChatRow(
    val message: Message,
    /** Stable list key: an optimistic row keeps its local key after the server confirms it (no scroll jump). */
    val key: String = message.id,
    /** Shown before `send_message` returned (optimistic). */
    val pending: Boolean = false,
    /** My message that could not be sent: drawn with `chat.thread.layout.failedMessage`; a tap sends it again. */
    val failed: Boolean = false,
    val author: Profile?,
    val mine: Boolean,
    val post: Post? = null,
    val media: Media? = null,
    val reactions: List<ReactionEntry> = emptyList(),
    val quote: Quote? = null,
    /** `edited_at` is set: "Edited" under it (`chat.thread.layout.editMessage`). */
    val edited: Boolean = false,
    /** My own sent text message inside `message_edit_window_s`: the menu offers Edit. */
    val canEdit: Boolean = false,
    /**
     * `chat.thread.layout.batch`: the post ids of the other photos of the batch run this photo leads (posted together, in
     * `created_at` order; set by [app.feature.social.chat.threadItems]), not drawn themselves; empty for every other row.
     */
    val batch: List<String> = emptyList(),
) {
    val id: String get() = message.id
    val kind: MessageKind get() = message.kind

    /** The photo leads photos posted together: its card carries `layout.global.batchMarker`. */
    val isBatch: Boolean get() = batch.isNotEmpty()
}

data class ChatState(
    val phase: Phase = Phase.Loading,
    val me: String? = null,
    val group: Group? = null,
    /** Oldest first. */
    val rows: List<ChatRow> = emptyList(),
    /** Cached rows shown while the network is unreachable. */
    val offline: Boolean = false,
    val loadingOlder: Boolean = false,
    val endReached: Boolean = false,
    val draft: String = "",
    /** The reply bar's target while replying. */
    val replyTo: ReplyTarget? = null,
    /** The group's time zone (week numbers of quoted posts). */
    val zone: java.time.ZoneId = java.time.ZoneId.systemDefault(),
    /** Profiles of the group's members and the thread's senders. */
    val people: Map<String, Profile> = emptyMap(),
    /** The message the composer is editing (`chat.thread.layout.editMessage`); the edit bar shows while set. */
    val editing: String? = null,
    /** First names on the typing line (`chat.thread.layout.typingLine`), in the order they started; never mine, never a count. */
    val typing: List<String> = emptyList(),
) {
    enum class Phase { Loading, Ready, Error, OfflineEmpty }

    val isEmpty: Boolean get() = phase == Phase.Ready && rows.isEmpty()

    fun profileOf(userId: String): Profile? = people[userId]

    /** My avatar (the composer's own avatar). */
    val meAvatar: String? get() = me?.let { people[it]?.avatarPath }
}

/** One-shot outcomes the screen turns into haptics, announcements and motion. */
sealed interface ChatEffect {
    data object Sent : ChatEffect
    data object SendFailed : ChatEffect
    data object ReactionFailed : ChatEffect
    /** `edit_message` failed: the edited text is back in the composer (`chat.thread.edit.error`). */
    data object EditFailed : ChatEffect
    data object DeleteFailed : ChatEffect
    data object PhotoDeleted : ChatEffect
    data object RecordFailed : ChatEffect
    /** A message arrived from someone else (announced to TalkBack). */
    data class Incoming(val row: ChatRow) : ChatEffect
}

/** Posts, media, profiles and reaction rows of the thread's page, kept for offline rendering. */
@Serializable
internal data class ChatHydration(
    val posts: List<Post> = emptyList(),
    val media: List<Media> = emptyList(),
    val profiles: List<Profile> = emptyList(),
    val reactions: Map<String, List<CachedReaction>> = emptyMap(),
    /** Reactions on text / voice messages, by message id. */
    val messageReactions: Map<String, List<CachedReaction>> = emptyMap(),
)

@Serializable
internal data class CachedReaction(val userId: String, val emoji: String)

/**
 * `chat.thread` (+ composer, voice, reactions): the first page cache-then-network
 * (`observeMessages`), older pages by `created_at`, realtime inserts / updates / deletions
 * (docs/API.md §8), and the thread's actions.
 */
class ChatViewModel(private val data: SocialData, val groupId: String, private val clock: java.time.Clock = java.time.Clock.systemUTC()) : ViewModel() {
    private val _state = MutableStateFlow(ChatState(me = data.currentUserId()))
    val state: StateFlow<ChatState> = _state.asStateFlow()
    private val _effects = MutableSharedFlow<ChatEffect>(extraBufferCapacity = 16, onBufferOverflow = BufferOverflow.DROP_OLDEST)
    val effects: SharedFlow<ChatEffect> = _effects.asSharedFlow()

    private var messages: List<Message> = emptyList()
    /** Optimistic messages not yet confirmed, by local key. */
    private val pending = LinkedHashMap<String, Message>()
    /** Optimistic messages whose send failed (kept in the thread with the retry affordance). */
    private val failed = HashSet<String>()
    /** Server id → the local key its optimistic row used. */
    private val keys = HashMap<String, String>()
    private val posts = LinkedHashMap<String, Post>()
    private val media = LinkedHashMap<String, Media>()
    private val profiles = LinkedHashMap<String, Profile>()
    private val reactions = LinkedHashMap<String, List<ReactionEntry>>()
    /** Reactions on text / voice messages by message id (`chat.reactions.layout.messageReactions`), oldest first. */
    private val messageReactions = LinkedHashMap<String, List<ReactionEntry>>()
    /** `message_edit_window_s` and `typing_ttl_s`; null until read (no Edit, no typing calls). */
    private var config: PublicAppConfig? = null
    /** The composer's unsent text, put aside while a message is edited. */
    private var draftBeforeEdit = ""
    /** When `set_typing(true)` was last sent; null = not typing as far as the server knows. */
    private var typingSentAt: Instant? = null
    /** People typing: user id → `until`, in the order they started (`chat.thread.layout.typingLine`). */
    private val typists = LinkedHashMap<String, Instant>()
    private var typingExpiry: Job? = null
    /** Quoted messages older than the loaded pages. */
    private val quoted = HashMap<String, Message>()
    private val cacheKey = "chat/$groupId"

    init {
        viewModelScope.launch { loadFirstPage() }
        viewModelScope.launch { loadMeta() }
        viewModelScope.launch { loadTyping() }
        viewModelScope.launch { data.events(groupId).collect(::onEvent) }
        viewModelScope.launch { data.online.distinctUntilChanged().drop(1).collect { online -> if (online) refresh() } }
    }

    private suspend fun loadFirstPage() {
        data.observeMessages(groupId).collect { page -> applyPage(page) }
    }

    private suspend fun applyPage(page: DataState<List<Message>>) {
        val value = page.value
        when {
            value != null -> {
                if (page.source == DataState.Source.Cache) restoreHydration()
                merge(value, replaceNewest = true)
                val hydrated = runCatching { hydrate(messages) }.isSuccess
                if (hydrated && page.source == DataState.Source.Network) saveHydration()
                _state.update {
                    it.copy(
                        phase = ChatState.Phase.Ready,
                        offline = page.error == DataError.Network,
                        endReached = page.source == DataState.Source.Network && value.size < PAGE,
                    )
                }
                publish()
            }
            page.refreshing -> if (messages.isEmpty()) _state.update { it.copy(phase = ChatState.Phase.Loading) }
            else -> _state.update { it.copy(phase = if (page.error == DataError.Network) ChatState.Phase.OfflineEmpty else ChatState.Phase.Error) }
        }
    }

    private suspend fun loadMeta() {
        val group = runCatching { data.group(groupId) }.getOrNull()
        val members = runCatching { data.members(groupId) }.getOrDefault(emptyList())
        members.mapNotNull { it.profile }.forEach { profiles[it.id] = it }
        if (config == null) config = runCatching { data.publicConfig() }.getOrNull()
        val zone = group?.timeZone?.let { runCatching { java.time.ZoneId.of(it) }.getOrNull() } ?: java.time.ZoneId.systemDefault()
        _state.update { it.copy(group = group, zone = zone) }
        publish()
    }

    /** Pull the newest page again (reconnect, foreground, retry). */
    fun refresh() {
        viewModelScope.launch {
            try {
                val page = data.messages(groupId, null)
                merge(page, replaceNewest = true)
                hydrate(messages)
                saveHydration()
                _state.update { it.copy(phase = ChatState.Phase.Ready, offline = false) }
                publish()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Throwable) {
                val error = e.dataError()
                _state.update {
                    if (messages.isEmpty()) it.copy(phase = if (error == DataError.Network) ChatState.Phase.OfflineEmpty else ChatState.Phase.Error)
                    else it.copy(offline = error == DataError.Network)
                }
            }
        }
    }

    /** Retry from the error state. */
    fun retry() {
        _state.update { it.copy(phase = ChatState.Phase.Loading) }
        viewModelScope.launch { loadFirstPage() }
        viewModelScope.launch { loadMeta() }
    }

    /** The page before the oldest message shown (pages of [PAGE]). */
    fun loadOlder() {
        val s = _state.value
        if (s.loadingOlder || s.endReached || messages.isEmpty()) return
        _state.update { it.copy(loadingOlder = true) }
        viewModelScope.launch {
            try {
                val page = data.messages(groupId, messages.first().createdAt)
                merge(page, replaceNewest = false)
                hydrate(page)
                _state.update { it.copy(loadingOlder = false, endReached = page.size < PAGE) }
                publish()
            } catch (e: CancellationException) {
                throw e
            } catch (_: Throwable) {
                _state.update { it.copy(loadingOlder = false) }
            }
        }
    }

    fun setDraft(text: String) {
        _state.update { it.copy(draft = text) }
        typingChanged(text)
    }

    /**
     * Sends the draft (`send_message` text), optimistically: the message shows at once and the field
     * clears; if the call fails the message stays in the thread as failed
     * (`chat.thread.layout.failedMessage`) and a tap on it sends it again ([retrySend]). While editing, saves the edit
     * instead ([saveEdit]).
     */
    fun send() {
        if (_state.value.editing != null) {
            saveEdit()
            return
        }
        val body = _state.value.draft.trim()
        val me = data.currentUserId() ?: return
        if (body.isEmpty()) return
        val reply = _state.value.replyTo
        val local = optimistic(me, MessageKind.Text, body = body, replyToPostId = reply?.postId, replyToMessageId = reply?.messageId)
        _state.update { it.copy(draft = "", replyTo = null) }
        publish()
        deliver(local)
        stopTyping()
    }

    /** Reply to [row] (context menu "Reply"): the reply bar shows above the composer. A photo message replies to its post. */
    fun startReply(row: ChatRow) {
        val me = data.currentUserId()
        val name = row.author?.firstName.orEmpty()
        val target = if (row.kind == MessageKind.Photo) ReplyTarget(row.message.postId, null, name, row.message.authorId == me)
        else ReplyTarget(null, row.id.takeUnless { it.startsWith(LOCAL_PREFIX) }, name, row.message.authorId == me)
        if (target.postId == null && target.messageId == null) return
        if (_state.value.editing != null) cancelEdit()
        _state.update { it.copy(replyTo = target) }
    }

    // ---- editing (`chat.thread.layout.editMessage`) ----

    /** My own sent text message, younger than `message_edit_window_s`; no window known → no Edit. */
    private fun canEdit(m: Message): Boolean {
        val window = config?.messageEditWindowSeconds?.takeIf { it > 0 } ?: return false
        if (m.authorId != data.currentUserId() || m.kind != MessageKind.Text || m.id in pending) return false
        return Duration.between(m.createdAt, clock.instant()) < Duration.ofSeconds(window.toLong())
    }

    /** "Edit": the composer holds the message's text with the edit bar; an unsent draft is put aside, a reply dropped. */
    fun startEdit(row: ChatRow) {
        if (!canEdit(row.message)) return
        if (_state.value.editing == null) draftBeforeEdit = _state.value.draft
        _state.update { it.copy(editing = row.id, replyTo = null, draft = row.message.body.orEmpty()) }
        stopTyping()
    }

    /** The edit bar's close glyph: the message keeps its text, the composer gets back what it held. */
    fun cancelEdit() {
        if (_state.value.editing == null) return
        val restored = draftBeforeEdit
        draftBeforeEdit = ""
        _state.update { it.copy(editing = null, draft = restored) }
    }

    /**
     * Send while editing (`edit_message`): the new text shows at once; the same text closes the bar without a call. On
     * failure (offline, `edit_window_closed`, …) the message gets its text back and the composer holds the edited text
     * with the edit bar again ([ChatEffect.EditFailed]).
     */
    private fun saveEdit() {
        val id = _state.value.editing ?: return
        val body = _state.value.draft.trim()
        if (body.isEmpty()) return
        val before = messages.firstOrNull { it.id == id }
        val restored = draftBeforeEdit
        draftBeforeEdit = ""
        _state.update { it.copy(editing = null, draft = restored) }
        if (before == null || body == before.body) {
            publish()
            return
        }
        messages = messages.map { if (it.id == id) it.copy(body = body, editedAt = clock.instant()) else it }
        publish()
        viewModelScope.launch {
            try {
                val saved = data.editMessage(id, body)
                messages = messages.map { if (it.id == id) saved else it }
                publish()
                _effects.emit(ChatEffect.Sent)
            } catch (e: CancellationException) {
                throw e
            } catch (_: Throwable) {
                if (messages.none { it.id == id }) return@launch
                messages = messages.map { if (it.id == id) before else it }
                if (_state.value.editing == null) {
                    draftBeforeEdit = _state.value.draft
                    _state.update { it.copy(editing = id, draft = body) }
                }
                publish()
                _effects.emit(ChatEffect.EditFailed)
            }
        }
    }

    // ---- typing (`chat.thread.layout.typingLine`) ----

    /**
     * The composer's text changed: `set_typing(true)` while it holds text (again once half of `typing_ttl_s` passed),
     * `set_typing(false)` when it empties. Nothing while editing a message, nothing without a TTL.
     */
    private fun typingChanged(text: String) {
        val ttl = config?.typingTtlSeconds?.takeIf { it > 0 } ?: return
        if (text.isBlank() || _state.value.editing != null) {
            stopTyping()
            return
        }
        val now = clock.instant()
        val sent = typingSentAt
        if (sent != null && Duration.between(sent, now) < Duration.ofMillis(ttl * HALF_SECOND_MS)) return
        typingSentAt = now
        viewModelScope.launch { runCatching { data.setTyping(groupId, true) } }
    }

    /** `set_typing(false)`: the message was sent, the field emptied, or the thread is closing. */
    fun stopTyping() {
        if (typingSentAt == null) return
        typingSentAt = null
        viewModelScope.launch { runCatching { data.setTyping(groupId, false) } }
    }

    private suspend fun loadTyping() {
        val rows = runCatching { data.typing(groupId) }.getOrNull() ?: return
        rows.sortedBy { it.until }.forEach(::applyTyping)
        ensureProfiles(rows.map { it.userId })
        publish()
    }

    /** One `chat_typing` row: a new typist joins the end of the line, a renewal keeps its place, a past `until` leaves. */
    private fun applyTyping(row: ChatTyping) {
        if (row.groupId != groupId || row.userId == data.currentUserId()) return
        val now = clock.instant()
        val current = typists[row.userId]
        when {
            !row.until.isAfter(now) -> typists.remove(row.userId)
            current != null && current.isAfter(now) -> typists[row.userId] = row.until
            else -> {
                typists.remove(row.userId)
                typists[row.userId] = row.until
            }
        }
        scheduleTypingExpiry()
    }

    /** Drops the rows whose `until` passed (the device clock: nothing marks the end of typing). */
    internal fun pruneTyping() {
        val now = clock.instant()
        typists.entries.removeAll { !it.value.isAfter(now) }
        scheduleTypingExpiry()
        publish()
    }

    private fun scheduleTypingExpiry() {
        typingExpiry?.cancel()
        val next = typists.values.minOrNull() ?: return
        val wait = Duration.between(clock.instant(), next).toMillis().coerceAtLeast(0)
        typingExpiry = viewModelScope.launch {
            delay(wait)
            pruneTyping()
        }
    }

    private fun typingNames(): List<String> {
        val now = clock.instant()
        val me = data.currentUserId()
        return typists.filter { (user, until) -> user != me && until.isAfter(now) }.keys.mapNotNull { profiles[it]?.firstName }
    }

    private suspend fun ensureProfiles(ids: Collection<String>) {
        val missing = ids.filter { it !in profiles }.distinct()
        if (missing.isEmpty()) return
        runCatching { data.profiles(missing) }.getOrNull()?.forEach { profiles[it.id] = it }
    }

    fun cancelReply() = _state.update { it.copy(replyTo = null) }

    /**
     * Uploads and sends a recorded voice message with its waveform (`send_message` voice, `p_voice_levels`; C-36), shown at
     * once; a failure leaves it failed with retry. Malformed [levels] are not sent (the API would refuse them).
     */
    fun sendVoice(file: File, durationMs: Int, levels: List<Int>? = null) {
        val me = data.currentUserId() ?: return
        val local = optimistic(me, MessageKind.Voice, voicePath = file.absolutePath, durationMs = durationMs)
            .copy(voiceLevels = levels?.takeIf(app.voice.VoiceLevels::isValid))
            .also { pending[it.id] = it }
        publish()
        deliver(local)
    }

    /** Sends a failed message again (tap on its indicator, label or bubble). */
    fun retrySend(localId: String) {
        val local = pending[localId] ?: return
        if (!failed.remove(localId)) return
        publish()
        deliver(local)
    }

    private fun deliver(local: Message) {
        viewModelScope.launch {
            try {
                val sent = when (local.kind) {
                    MessageKind.Voice -> data.sendVoice(groupId, File(local.voicePath.orEmpty()), local.voiceDurationMs ?: 0, local.voiceLevels)
                    else -> data.sendText(groupId, local.body.orEmpty(), local.replyToPostId, local.replyToMessageId)
                }
                if (local.kind == MessageKind.Voice) File(local.voicePath.orEmpty()).delete()
                if (local.id in pending) confirm(local.id, sent)
                _effects.emit(ChatEffect.Sent)
            } catch (e: CancellationException) {
                throw e
            } catch (_: Throwable) {
                if (local.id in pending) {
                    failed += local.id
                    publish()
                }
                _effects.emit(ChatEffect.SendFailed)
            }
        }
    }

    private fun optimistic(
        me: String,
        kind: MessageKind,
        body: String? = null,
        voicePath: String? = null,
        durationMs: Int? = null,
        replyToPostId: String? = null,
        replyToMessageId: String? = null,
    ): Message {
        val now = clock.instant().let { n -> messages.lastOrNull()?.createdAt?.let { last -> if (last.isAfter(n)) last.plusMillis(1) else n } ?: n }
        val message = Message(
            id = LOCAL_PREFIX + java.util.UUID.randomUUID(),
            groupId = groupId,
            authorId = me,
            kind = kind,
            body = body,
            postId = null,
            voicePath = voicePath,
            voiceDurationMs = durationMs,
            replyToPostId = replyToPostId,
            replyToMessageId = replyToMessageId,
            createdAt = now,
        )
        pending[message.id] = message
        return message
    }

    /** The server's row replaces the optimistic one under the same list key. */
    private suspend fun confirm(localId: String, sent: Message) {
        pending.remove(localId)
        failed.remove(localId)
        keys[sent.id] = localId
        merge(listOf(sent), replaceNewest = false)
        runCatching { hydrate(listOf(sent)) }
        _state.update { if (it.phase != ChatState.Phase.Ready) it.copy(phase = ChatState.Phase.Ready) else it }
        publish()
    }

    fun recordFailed() {
        _effects.tryEmit(ChatEffect.RecordFailed)
    }

    /** `react`: the sticker joins the cluster at once; removed again if the call fails. */
    fun react(postId: String, emoji: String) {
        val me = data.currentUserId() ?: return
        reactions[postId] = withReaction(reactions[postId].orEmpty(), me, emoji)
        publish()
        viewModelScope.launch {
            try {
                data.react(postId, emoji)
            } catch (e: CancellationException) {
                throw e
            } catch (_: Throwable) {
                reactions[postId] = withoutReaction(reactions[postId].orEmpty(), me, emoji)
                publish()
                _effects.emit(ChatEffect.ReactionFailed)
            }
        }
    }

    /** `unreact`: your sticker leaves at once (unless someone else used that emoji); restored if the call fails. */
    fun unreact(postId: String, emoji: String) {
        val me = data.currentUserId() ?: return
        val before = reactions[postId].orEmpty()
        if (before.none { it.userId == me && it.emoji == emoji }) return
        reactions[postId] = withoutReaction(before, me, emoji)
        publish()
        viewModelScope.launch {
            try {
                data.unreact(postId, emoji)
            } catch (e: CancellationException) {
                throw e
            } catch (_: Throwable) {
                reactions[postId] = withReaction(reactions[postId].orEmpty(), me, emoji)
                publish()
                _effects.emit(ChatEffect.ReactionFailed)
            }
        }
    }

    /**
     * An emoji on a text / voice message (`chat.reactions.layout.messageReactions`): one per person — another emoji
     * replaces mine at once, my own emoji again takes it back; undone if the call fails.
     */
    fun reactToMessage(messageId: String, emoji: String) {
        val me = data.currentUserId() ?: return
        val before = messageReactions[messageId].orEmpty()
        if (before.any { it.userId == me && it.emoji == emoji }) {
            unreactToMessage(messageId)
            return
        }
        val m = messages.firstOrNull { it.id == messageId } ?: return
        if (m.kind != MessageKind.Text && m.kind != MessageKind.Voice) return
        messageReactions[messageId] = before.filterNot { it.userId == me } + ReactionEntry(me, emoji)
        publish()
        viewModelScope.launch {
            try {
                data.reactToMessage(messageId, emoji)
            } catch (e: CancellationException) {
                throw e
            } catch (_: Throwable) {
                messageReactions[messageId] = before
                publish()
                _effects.emit(ChatEffect.ReactionFailed)
            }
        }
    }

    /** Takes my reaction off a message (`unreact_to_message`): at once, restored if the call fails. */
    fun unreactToMessage(messageId: String) {
        val me = data.currentUserId() ?: return
        val before = messageReactions[messageId].orEmpty()
        if (before.none { it.userId == me }) return
        messageReactions[messageId] = before.filterNot { it.userId == me }
        publish()
        viewModelScope.launch {
            try {
                data.unreactToMessage(messageId)
            } catch (e: CancellationException) {
                throw e
            } catch (_: Throwable) {
                messageReactions[messageId] = before
                publish()
                _effects.emit(ChatEffect.ReactionFailed)
            }
        }
    }

    /** Your own text / voice message (`delete_message`, after the confirmation): removed at once, restored if the call fails. A failed (never sent) one just goes. */
    fun deleteMessage(messageId: String) {
        pending[messageId]?.let { local ->
            pending.remove(messageId)
            failed.remove(messageId)
            if (local.kind == MessageKind.Voice) File(local.voicePath.orEmpty()).delete()
            publish()
            return
        }
        val removed = messages.firstOrNull { it.id == messageId } ?: return
        remove(messageId)
        viewModelScope.launch {
            try {
                data.deleteMessage(messageId)
            } catch (e: CancellationException) {
                throw e
            } catch (_: Throwable) {
                merge(listOf(removed), replaceNewest = false)
                publish()
                _effects.emit(ChatEffect.DeleteFailed)
            }
        }
    }

    /**
     * `delete_media` on your own photo message (after the viewer's confirmation): the photo goes from every group,
     * chat and album; its message leaves the thread at once and comes back if the call fails.
     */
    fun deletePhoto(postId: String) {
        val post = posts[postId] ?: return
        val removed = messages.filter { it.postId == postId }
        messages = messages.filterNot { it.postId == postId }
        publish()
        viewModelScope.launch {
            try {
                data.deleteMedia(post.mediaId)
                _effects.emit(ChatEffect.PhotoDeleted)
            } catch (e: CancellationException) {
                throw e
            } catch (_: Throwable) {
                merge(removed, replaceNewest = false)
                publish()
                _effects.emit(ChatEffect.DeleteFailed)
            }
        }
    }

    internal suspend fun onEvent(event: GroupEvent) {
        when (event) {
            is GroupEvent.MessageInserted -> {
                val isNew = messages.none { it.id == event.message.id }
                // My own message can arrive before send_message returns: adopt the optimistic row.
                pending.values.firstOrNull { it.authorId == event.message.authorId && it.kind == event.message.kind && it.body == event.message.body && it.voiceDurationMs == event.message.voiceDurationMs }
                    ?.let { local -> pending.remove(local.id); failed.remove(local.id); keys[event.message.id] = local.id }
                insert(event.message)
                if (isNew && event.message.authorId != data.currentUserId()) {
                    _state.value.rows.firstOrNull { it.id == event.message.id }?.let { _effects.emit(ChatEffect.Incoming(it)) }
                }
            }
            is GroupEvent.MessageUpdated -> {
                // An edit (`edit_message`) or a reply losing its target: the row changes in place.
                if (event.message.id in quoted) quoted[event.message.id] = event.message
                messages = messages.map { if (it.id == event.message.id) event.message else it }
                runCatching { hydrate(listOf(event.message)) }
                publish()
            }
            is GroupEvent.MessageDeleted -> remove(event.messageId)
            is GroupEvent.PostUpdated -> {
                posts[event.post.id] = event.post
                publish()
            }
            is GroupEvent.PostDeleted -> {
                posts.remove(event.postId)
                reactions.remove(event.postId)
                messages = messages
                    .filterNot { it.postId == event.postId }
                    .map { if (it.replyToPostId == event.postId) it.copy(replyToPostId = null) else it }
                posts.replaceAll { _, p -> if (p.replyToPostId == event.postId) p.copy(replyToPostId = null) else p }
                publish()
            }
            is GroupEvent.ReactionAdded -> {
                val r = event.reaction
                if (messages.any { it.postId == r.postId }) {
                    val current = reactions[r.postId].orEmpty()
                    if (current.none { it.userId == r.userId && it.emoji == r.emoji }) reactions[r.postId] = current + ReactionEntry(r.userId, r.emoji)
                    publish()
                }
            }
            is GroupEvent.ReactionsChanged -> {
                runCatching { data.reactions(listOf(event.postId)) }.getOrNull()?.let { fresh ->
                    reactions[event.postId] = fresh[event.postId].orEmpty()
                    publish()
                }
            }
            is GroupEvent.MessageReactionChanged -> {
                val r = event.reaction
                if (messages.any { it.id == r.messageId }) {
                    messageReactions[r.messageId] = messageReactions[r.messageId].orEmpty().filterNot { it.userId == r.userId } + ReactionEntry(r.userId, r.emoji, r.createdAt)
                    ensureProfiles(listOf(r.userId))
                    publish()
                }
            }
            is GroupEvent.MessageReactionsChanged -> {
                if (messages.none { it.id == event.messageId }) return
                runCatching { data.messageReactions(listOf(event.messageId)) }.getOrNull()?.let { fresh ->
                    messageReactions[event.messageId] = fresh[event.messageId].orEmpty()
                    ensureProfiles(messageReactions[event.messageId].orEmpty().map { it.userId })
                    publish()
                }
            }
            is GroupEvent.TypingChanged -> {
                applyTyping(event.typing)
                ensureProfiles(listOf(event.typing.userId))
                publish()
            }
            is GroupEvent.Subscribed -> if (event.resumed) {
                refresh()
                if (event.stream == GroupEvent.Stream.Changes) loadTyping()
            }
            // Selfie reactions show only in photo.viewer (viewer.selfiereaction); a reveal reaches the chat as its photo
            // messages (MessageInserted), not through the developing state.
            is GroupEvent.PostInserted, is GroupEvent.Unavailable, is GroupEvent.SelfieReactionChanged, is GroupEvent.DevelopingChanged -> Unit
        }
    }

    private suspend fun insert(message: Message) {
        merge(listOf(message), replaceNewest = false)
        runCatching { hydrate(listOf(message)) }
        _state.update { if (it.phase != ChatState.Phase.Ready) it.copy(phase = ChatState.Phase.Ready) else it }
        publish()
    }

    private fun remove(messageId: String) {
        messages = messages.filterNot { it.id == messageId }
        messageReactions.remove(messageId)
        if (_state.value.editing == messageId) cancelEdit()
        publish()
    }

    /**
     * Merges a page (newest first from the API) into [messages] (kept oldest first). With
     * [replaceNewest], messages newer than the page's oldest that are not in it were deleted meanwhile.
     */
    private fun merge(page: List<Message>, replaceNewest: Boolean) {
        val byId = LinkedHashMap<String, Message>()
        val oldestInPage = page.minOfOrNull { it.createdAt }
        messages.forEach { m ->
            val dropped = replaceNewest && oldestInPage != null && page.size >= 1 && !m.createdAt.isBefore(oldestInPage) && page.none { it.id == m.id }
            if (!dropped) byId[m.id] = m
        }
        page.forEach { byId[it.id] = it }
        messages = byId.values.sortedWith(compareBy<Message> { it.createdAt }.thenBy { it.id })
    }

    /** Loads what [batch] needs that is not known yet: posts (photo messages and replied photos), media, reactions, profiles. */
    private suspend fun hydrate(batch: List<Message>) {
        val photoPosts = batch.mapNotNull { it.postId }
        val replied = batch.mapNotNull { it.replyToPostId }
        val missingPosts = (photoPosts + replied).filter { it !in posts }
        if (missingPosts.isNotEmpty()) data.posts(missingPosts).forEach { posts[it.id] = it }
        // A photo replying to a photo (create_post p_reply_to_post_id) quotes its replied post too.
        val second = photoPosts.mapNotNull { posts[it]?.replyToPostId }.filter { it !in posts }
        if (second.isNotEmpty()) data.posts(second).forEach { posts[it.id] = it }
        val mediaIds = posts.values.map { it.mediaId }.filter { it !in media }
        if (mediaIds.isNotEmpty()) data.media(mediaIds).forEach { media[it.id] = it }
        val reactionPosts = photoPosts.filter { it in posts }
        if (reactionPosts.isNotEmpty()) {
            val rows = data.reactions(reactionPosts)
            reactionPosts.forEach { id -> reactions[id] = rows[id].orEmpty() }
        }
        // Reactions on text / voice messages; a failure here leaves the rest of the page drawn.
        val reactable = batch.filter { (it.kind == MessageKind.Text || it.kind == MessageKind.Voice) && it.id !in pending }.map { it.id }
        if (reactable.isNotEmpty()) {
            runCatching { data.messageReactions(reactable) }.getOrNull()?.let { rows -> reactable.forEach { id -> messageReactions[id] = rows[id].orEmpty() } }
        }
        val quotedIds = batch.mapNotNull { it.replyToMessageId }.filter { id -> messages.none { it.id == id } && id !in quoted }
        quotedIds.forEach { id -> runCatching { data.message(id) }.getOrNull()?.let { quoted[id] = it } }
        val reactors = reactable.flatMap { id -> messageReactions[id].orEmpty().map { it.userId } }
        val people = (batch.map { it.authorId } + posts.values.map { it.authorId } + quoted.values.map { it.authorId } + reactors).filter { it !in profiles }.distinct()
        if (people.isNotEmpty()) data.profiles(people).forEach { profiles[it.id] = it }
    }

    private suspend fun saveHydration() {
        val value = ChatHydration(
            posts = posts.values.toList(),
            media = media.values.toList(),
            profiles = profiles.values.toList(),
            reactions = reactions.mapValues { (_, list) -> list.map { CachedReaction(it.userId, it.emoji) } },
            messageReactions = messageReactions.mapValues { (_, list) -> list.map { CachedReaction(it.userId, it.emoji) } },
        )
        runCatching { data.cachePut(cacheKey, ChatHydration.serializer(), value) }
    }

    private suspend fun restoreHydration() {
        val cached = runCatching { data.cacheGet(cacheKey, ChatHydration.serializer()) }.getOrNull() ?: return
        cached.posts.forEach { posts.putIfAbsent(it.id, it) }
        cached.media.forEach { media.putIfAbsent(it.id, it) }
        cached.profiles.forEach { profiles.putIfAbsent(it.id, it) }
        cached.reactions.forEach { (id, list) -> reactions.putIfAbsent(id, list.map { ReactionEntry(it.userId, it.emoji) }) }
        cached.messageReactions.forEach { (id, list) -> messageReactions.putIfAbsent(id, list.map { ReactionEntry(it.userId, it.emoji) }) }
    }

    private fun quoteFor(m: Message, post: Post?): Quote? {
        val repliedPost = if (m.kind == MessageKind.Photo) post?.replyToPostId else m.replyToPostId
        if (repliedPost != null) {
            val p = posts[repliedPost] ?: return null
            val week = app.feature.social.common.Formats.isoWeek(p.visibleAt.atZone(_state.value.zone).toLocalDate())
            return Quote.Photo(p.id, profiles[p.authorId]?.firstName, media[p.mediaId]?.imagePath(Media.Rendition.Thumb), week, media[p.mediaId]?.videoDurationMs)
        }
        val id = m.replyToMessageId ?: return null
        val q = messages.firstOrNull { it.id == id } ?: quoted[id] ?: return null
        return Quote.Text(q.id, profiles[q.authorId]?.firstName, q.body?.takeIf { it.isNotBlank() }, attachment = q.kind != MessageKind.Text)
    }

    private fun publish() {
        val me = data.currentUserId()
        val all = (messages + pending.values).sortedWith(compareBy<Message> { it.createdAt }.thenBy { it.id })
        val rows = all.mapNotNull { m ->
            val post = m.postId?.let(posts::get)
            if (m.kind == MessageKind.Photo && m.postId == null) return@mapNotNull null
            ChatRow(
                message = m,
                key = keys[m.id] ?: m.id,
                pending = m.id in pending && m.id !in failed,
                failed = m.id in failed,
                author = profiles[m.authorId],
                mine = m.authorId == me,
                post = post,
                media = post?.let { media[it.mediaId] },
                reactions = if (m.kind == MessageKind.Photo) m.postId?.let { reactions[it] }.orEmpty() else messageReactions[m.id].orEmpty(),
                quote = quoteFor(m, post),
                edited = m.editedAt != null,
                canEdit = canEdit(m),
            )
        }
        _state.update { it.copy(rows = rows, me = me, people = profiles.toMap(), typing = typingNames()) }
    }

    /** Messages of [ChatRow]s for [Quote] taps etc. */
    fun photoPostIds(): List<String> = messages.mapNotNull { it.postId }

    companion object {
        const val PAGE = 50
        private const val LOCAL_PREFIX = "local-"
        /** `typing_ttl_s / 2` in milliseconds per second of TTL. */
        private const val HALF_SECOND_MS = 500L
    }
}
