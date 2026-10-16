package app.feature.social.chat

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.data.error.DataError
import app.data.model.Group
import app.data.model.Media
import app.data.model.Message
import app.data.model.MessageKind
import app.data.model.Post
import app.data.model.Profile
import app.data.offline.DataState
import app.data.realtime.GroupEvent
import app.data.repo.ReactionEntry
import app.feature.social.data.SocialData
import app.feature.social.data.dataError
import app.feature.social.reactions.withReaction
import app.feature.social.reactions.withoutReaction
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.channels.BufferOverflow
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

/** The quote above a reply (`chat.thread.layout.replyQuote`). */
sealed interface Quote {
    /** A reply to a photo: a C-15 row — thumbnail, "Post by {name}" over "Week {n}" (ISO week of the post in the group's zone). */
    data class Photo(val postId: String, val posterName: String?, val thumbPath: String?, val weekNumber: Int?) : Quote

    /** A reply to a message: one grey line, the sender's name in semibold then the quoted text ([text] null = an attachment). */
    data class Text(val messageId: String, val senderName: String?, val text: String?, val attachment: Boolean) : Quote
}

/** What the reply bar replies to (`chat.thread.reply.bar` / `.barSelf`): a photo ([postId]) or a message ([messageId]). */
data class ReplyTarget(val postId: String?, val messageId: String?, val name: String, val self: Boolean)

/** One message as drawn. Photo messages carry their post, media and reaction rows (never a count). */
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
) {
    val id: String get() = message.id
    val kind: MessageKind get() = message.kind
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
    /** Quoted messages older than the loaded pages. */
    private val quoted = HashMap<String, Message>()
    private val cacheKey = "chat/$groupId"

    init {
        viewModelScope.launch { loadFirstPage() }
        viewModelScope.launch { loadMeta() }
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

    fun setDraft(text: String) = _state.update { it.copy(draft = text) }

    /**
     * Sends the draft (`send_message` text), optimistically: the message shows at once and the field
     * clears; if the call fails the message stays in the thread as failed
     * (`chat.thread.layout.failedMessage`) and a tap on it sends it again ([retrySend]).
     */
    fun send() {
        val body = _state.value.draft.trim()
        val me = data.currentUserId() ?: return
        if (body.isEmpty()) return
        val reply = _state.value.replyTo
        val local = optimistic(me, MessageKind.Text, body = body, replyToPostId = reply?.postId, replyToMessageId = reply?.messageId)
        _state.update { it.copy(draft = "", replyTo = null) }
        publish()
        deliver(local)
    }

    /** Reply to [row] (context menu "Reply"): the reply bar shows above the composer. A photo message replies to its post. */
    fun startReply(row: ChatRow) {
        val me = data.currentUserId()
        val name = row.author?.firstName.orEmpty()
        val target = if (row.kind == MessageKind.Photo) ReplyTarget(row.message.postId, null, name, row.message.authorId == me)
        else ReplyTarget(null, row.id.takeUnless { it.startsWith(LOCAL_PREFIX) }, name, row.message.authorId == me)
        if (target.postId == null && target.messageId == null) return
        _state.update { it.copy(replyTo = target) }
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
            is GroupEvent.Subscribed -> if (event.resumed) refresh()
            // Selfie reactions show only in photo.viewer (viewer.selfiereaction).
            is GroupEvent.PostInserted, is GroupEvent.Unavailable, is GroupEvent.SelfieReactionChanged -> Unit
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
        val quotedIds = batch.mapNotNull { it.replyToMessageId }.filter { id -> messages.none { it.id == id } && id !in quoted }
        quotedIds.forEach { id -> runCatching { data.message(id) }.getOrNull()?.let { quoted[id] = it } }
        val people = (batch.map { it.authorId } + posts.values.map { it.authorId } + quoted.values.map { it.authorId }).filter { it !in profiles }.distinct()
        if (people.isNotEmpty()) data.profiles(people).forEach { profiles[it.id] = it }
    }

    private suspend fun saveHydration() {
        val value = ChatHydration(
            posts = posts.values.toList(),
            media = media.values.toList(),
            profiles = profiles.values.toList(),
            reactions = reactions.mapValues { (_, list) -> list.map { CachedReaction(it.userId, it.emoji) } },
        )
        runCatching { data.cachePut(cacheKey, ChatHydration.serializer(), value) }
    }

    private suspend fun restoreHydration() {
        val cached = runCatching { data.cacheGet(cacheKey, ChatHydration.serializer()) }.getOrNull() ?: return
        cached.posts.forEach { posts.putIfAbsent(it.id, it) }
        cached.media.forEach { media.putIfAbsent(it.id, it) }
        cached.profiles.forEach { profiles.putIfAbsent(it.id, it) }
        cached.reactions.forEach { (id, list) -> reactions.putIfAbsent(id, list.map { ReactionEntry(it.userId, it.emoji) }) }
    }

    private fun quoteFor(m: Message, post: Post?): Quote? {
        val repliedPost = if (m.kind == MessageKind.Photo) post?.replyToPostId else m.replyToPostId
        if (repliedPost != null) {
            val p = posts[repliedPost] ?: return null
            val week = app.feature.social.common.Formats.isoWeek(p.createdAt.atZone(_state.value.zone).toLocalDate())
            return Quote.Photo(p.id, profiles[p.authorId]?.firstName, media[p.mediaId]?.imagePath(Media.Rendition.Thumb), week)
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
                reactions = m.postId?.let { reactions[it] }.orEmpty(),
                quote = quoteFor(m, post),
            )
        }
        _state.update { it.copy(rows = rows, me = me, people = profiles.toMap()) }
    }

    /** Messages of [ChatRow]s for [Quote] taps etc. */
    fun photoPostIds(): List<String> = messages.mapNotNull { it.postId }

    companion object {
        const val PAGE = 50
        private const val LOCAL_PREFIX = "local-"
    }
}
