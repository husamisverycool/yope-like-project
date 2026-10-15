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
import app.data.model.RenderStatus
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

/** The quote part of a reply to a photo (S5-r): the poster's first name and the photo's thumbnail. */
data class Quote(val postId: String, val posterName: String?, val thumbPath: String?)

/** One message as drawn. Photo messages carry their post, media and reaction rows (never a count). */
data class ChatRow(
    val message: Message,
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
    /** The newest ready recap (the film-strip circle is hidden while there is none). */
    val recapId: String? = null,
    val creatorName: String? = null,
    val iAmCreator: Boolean = false,
    val addedNames: List<String> = emptyList(),
    val draft: String = "",
    val sending: Boolean = false,
) {
    enum class Phase { Loading, Ready, Error, OfflineEmpty }

    val isEmpty: Boolean get() = phase == Phase.Ready && rows.isEmpty()

    /** First names by user id (Activity sheet, labels). */
    fun nameOf(userId: String): String? = rows.firstOrNull { it.message.authorId == userId }?.author?.firstName
}

/** One-shot outcomes the screen turns into haptics, announcements and motion. */
sealed interface ChatEffect {
    data object Sent : ChatEffect
    data object SendFailed : ChatEffect
    data class Rain(val emoji: String) : ChatEffect
    data object ReactionFailed : ChatEffect
    data object DeleteFailed : ChatEffect
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
class ChatViewModel(private val data: SocialData, val groupId: String) : ViewModel() {
    private val _state = MutableStateFlow(ChatState(me = data.currentUserId()))
    val state: StateFlow<ChatState> = _state.asStateFlow()
    private val _effects = MutableSharedFlow<ChatEffect>(extraBufferCapacity = 16, onBufferOverflow = BufferOverflow.DROP_OLDEST)
    val effects: SharedFlow<ChatEffect> = _effects.asSharedFlow()

    private var messages: List<Message> = emptyList()
    private val posts = LinkedHashMap<String, Post>()
    private val media = LinkedHashMap<String, Media>()
    private val profiles = LinkedHashMap<String, Profile>()
    private val reactions = LinkedHashMap<String, List<ReactionEntry>>()
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
        val recap = runCatching { data.recaps(groupId) }.getOrDefault(emptyList()).firstOrNull { it.status == RenderStatus.Ready }
        members.mapNotNull { it.profile }.forEach { profiles[it.id] = it }
        val me = data.currentUserId()
        val creator = group?.createdBy
        _state.update {
            it.copy(
                group = group,
                recapId = recap?.id,
                iAmCreator = creator != null && creator == me,
                creatorName = members.firstOrNull { m -> m.member.userId == creator }?.profile?.firstName,
                addedNames = members.filter { m -> m.member.userId != creator }.mapNotNull { m -> m.profile?.firstName },
            )
        }
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

    /** Sends the draft (`send_message` text). The draft is kept when sending fails. */
    fun send() {
        val body = _state.value.draft.trim()
        if (body.isEmpty() || _state.value.sending) return
        _state.update { it.copy(sending = true) }
        viewModelScope.launch {
            try {
                val sent = data.sendText(groupId, body)
                insert(sent)
                _state.update { it.copy(sending = false, draft = if (it.draft.trim() == body) "" else it.draft) }
                _effects.emit(ChatEffect.Sent)
            } catch (e: CancellationException) {
                throw e
            } catch (_: Throwable) {
                _state.update { it.copy(sending = false) }
                _effects.emit(ChatEffect.SendFailed)
            }
        }
    }

    /** Uploads and sends a recorded voice message (`send_message` voice). */
    fun sendVoice(file: File, durationMs: Int) {
        viewModelScope.launch {
            try {
                val sent = data.sendVoice(groupId, file, durationMs)
                insert(sent)
                _effects.emit(ChatEffect.Sent)
            } catch (e: CancellationException) {
                throw e
            } catch (_: Throwable) {
                _effects.emit(ChatEffect.SendFailed)
            } finally {
                file.delete()
            }
        }
    }

    fun recordFailed() {
        _effects.tryEmit(ChatEffect.RecordFailed)
    }

    /** `react`: the sticker joins the cluster at once; removed again if the call fails. */
    fun react(postId: String, emoji: String) {
        val me = data.currentUserId() ?: return
        reactions[postId] = withReaction(reactions[postId].orEmpty(), me, emoji)
        publish()
        _effects.tryEmit(ChatEffect.Rain(emoji))
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

    /** Your own text / voice message (`delete_message`, after the confirmation). */
    fun deleteMessage(messageId: String) {
        viewModelScope.launch {
            try {
                data.deleteMessage(messageId)
                remove(messageId)
            } catch (e: CancellationException) {
                throw e
            } catch (_: Throwable) {
                _effects.emit(ChatEffect.DeleteFailed)
            }
        }
    }

    internal suspend fun onEvent(event: GroupEvent) {
        when (event) {
            is GroupEvent.MessageInserted -> {
                val isNew = messages.none { it.id == event.message.id }
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
            is GroupEvent.PostInserted, is GroupEvent.Unavailable -> Unit
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
        val people = (batch.map { it.authorId } + posts.values.map { it.authorId }).filter { it !in profiles }.distinct()
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

    private fun quoteFor(postId: String?): Quote? {
        val post = postId?.let(posts::get) ?: return null
        val m = media[post.mediaId]
        return Quote(post.id, profiles[post.authorId]?.firstName, m?.imagePath(Media.Rendition.Thumb))
    }

    private fun publish() {
        val me = data.currentUserId()
        val rows = messages.mapNotNull { m ->
            val post = m.postId?.let(posts::get)
            if (m.kind == MessageKind.Photo && m.postId == null) return@mapNotNull null
            ChatRow(
                message = m,
                author = profiles[m.authorId],
                mine = m.authorId == me,
                post = post,
                media = post?.let { media[it.mediaId] },
                reactions = m.postId?.let { reactions[it] }.orEmpty(),
                quote = quoteFor(if (m.kind == MessageKind.Photo) post?.replyToPostId else m.replyToPostId),
            )
        }
        _state.update { it.copy(rows = rows, me = me) }
    }

    /** Messages of [ChatRow]s for [Quote] taps etc. */
    fun photoPostIds(): List<String> = messages.mapNotNull { it.postId }

    companion object {
        const val PAGE = 50
    }
}
