package app.feature.social.viewer

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.data.error.ApiError
import app.data.error.DataError
import app.data.model.Media
import app.data.model.Post
import app.data.model.Profile
import app.data.model.WallItemKind
import app.data.realtime.GroupEvent
import app.data.repo.ReactionEntry
import app.feature.social.data.SocialData
import app.feature.social.data.dataError
import app.feature.social.reactions.withReaction
import app.feature.social.reactions.withoutReaction
import app.model.PhotoContext
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.channels.BufferOverflow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.LocalDate

/** One photo of the viewer. [gone] = deleted / no longer visible (`post_not_found`, `post_deleted`). */
data class ViewerPhoto(
    val postId: String,
    val post: Post? = null,
    val media: Media? = null,
    val author: Profile? = null,
    val groupName: String? = null,
    val reactions: List<ReactionEntry> = emptyList(),
    /** Your own "i'm in this" tag; null until known. */
    val tagged: Boolean? = null,
    val tagPending: Boolean = false,
    val loaded: Boolean = false,
    val gone: Boolean = false,
    val loadFailed: Boolean = false,
)

data class ViewerState(
    val phase: Phase = Phase.Loading,
    val me: String? = null,
    val photos: List<ViewerPhoto> = emptyList(),
    val index: Int = 0,
    val draft: String = "",
    val sending: Boolean = false,
    val online: Boolean = true,
    /** Every photo is gone: the viewer closes. */
    val closed: Boolean = false,
) {
    enum class Phase { Loading, Ready }

    val current: ViewerPhoto? get() = photos.getOrNull(index)
    val mine: Boolean get() = current?.post?.authorId != null && current?.post?.authorId == me
}

sealed interface ViewerEffect {
    data object Sent : ViewerEffect
    data object SendFailed : ViewerEffect
    data class Rain(val emoji: String) : ViewerEffect
    data object ReactionFailed : ViewerEffect
    data object Deleted : ViewerEffect
    data object DeleteFailed : ViewerEffect
    data object Saved : ViewerEffect
    data object SaveFailed : ViewerEffect
    data object Tagged : ViewerEffect
    /** `tagging.error`, `tagging.notFound`, `tagging.offline`. */
    data class TagFailed(val reason: TagFailure) : ViewerEffect
}

enum class TagFailure { Error, NotFound, Offline }

/**
 * `photo.viewer`: the opener's photo list ([PhotoContext]), each photo's post / media / author /
 * group / reaction rows / your tag, realtime deletions and reactions, and the viewer's actions.
 */
class PhotoViewerViewModel(
    private val data: SocialData,
    private val groupId: String,
    private val postId: String,
    private val context: PhotoContext,
    private val contextId: String,
    private val weekStart: LocalDate?,
) : ViewModel() {
    private val _state = MutableStateFlow(ViewerState(me = data.currentUserId()))
    val state: StateFlow<ViewerState> = _state.asStateFlow()
    private val _effects = MutableSharedFlow<ViewerEffect>(extraBufferCapacity = 16, onBufferOverflow = BufferOverflow.DROP_OLDEST)
    val effects: SharedFlow<ViewerEffect> = _effects.asSharedFlow()

    private val groupNames = HashMap<String, String>()
    private val subscriptions = HashMap<String, Job>()
    private val loading = HashSet<String>()

    init {
        viewModelScope.launch { load() }
        viewModelScope.launch { data.online.collect { online -> _state.update { it.copy(online = online) } } }
    }

    /**
     * The opened photo shows at once; the opener's list arrives after and is spliced around it,
     * keeping the photo on screen and whatever is already loaded (no state flash).
     */
    private suspend fun load() {
        _state.update { it.copy(phase = ViewerState.Phase.Ready, photos = listOf(ViewerPhoto(postId)), index = 0) }
        prefetch()
        if (context == PhotoContext.Single) return
        val ids = runCatching { contextIds() }.getOrNull() ?: return
        if (postId !in ids) return
        _state.update { s ->
            val known = s.photos.associateBy { it.postId }
            val currentId = s.current?.postId ?: postId
            val photos = ids.filter { id -> known[id]?.gone != true || id == currentId }.map { id -> known[id] ?: ViewerPhoto(id) }
            s.copy(photos = photos, index = photos.indexOfFirst { it.postId == currentId }.coerceAtLeast(0))
        }
        prefetch()
    }

    /** The opener's list, in the order the spec gives for it. */
    private suspend fun contextIds(): List<String> = when (context) {
        PhotoContext.Single -> listOf(postId)
        PhotoContext.Chat -> {
            // The thread's photos, chronological: feed pages back until the opened photo is in.
            val pages = ArrayList<Post>()
            var before: java.time.Instant? = null
            var guard = 0
            while (guard++ < MAX_PAGES) {
                val page = data.feed(contextId, before)
                pages += page
                if (page.any { it.id == postId } || page.size < FEED_PAGE || page.isEmpty()) break
                before = page.last().createdAt
            }
            pages.distinctBy { it.id }.sortedBy { it.createdAt }.map { it.id }
        }
        PhotoContext.Wall -> {
            val items = ArrayList<String>()
            var before: java.time.Instant? = null
            var guard = 0
            while (guard++ < MAX_PAGES) {
                val page = data.wall(contextId, before, WALL_PAGE)
                items += page.filter { it.itemKind == WallItemKind.Post }.mapNotNull { it.postId }
                if (postId in items || page.size < WALL_PAGE || page.isEmpty()) break
                before = page.last().createdAt
            }
            items.distinct()
        }
        PhotoContext.Week -> {
            val start = weekStart ?: return listOf(postId)
            data.historyWeeks(contextId, start.plusDays(DAYS_IN_WEEK), 1).firstOrNull { it.weekStart == start }?.postIds.orEmpty()
        }
        PhotoContext.Recap -> data.recap(contextId)?.items.orEmpty()
        PhotoContext.Album -> data.albumItems(contextId).sortedBy { it.position }.map { it.postId }
    }

    /** Moves to [index] (swipe) and loads that photo and its neighbours. */
    fun select(index: Int) {
        if (index == _state.value.index || index !in _state.value.photos.indices) return
        _state.update { it.copy(index = index, draft = it.draft) }
        prefetch()
    }

    private fun prefetch() {
        val s = _state.value
        listOf(s.index, s.index + 1, s.index - 1).mapNotNull { s.photos.getOrNull(it) }.filter { !it.loaded && !it.gone }.forEach { photo ->
            if (loading.add(photo.postId)) viewModelScope.launch { loadPhoto(photo.postId) }
        }
    }

    private suspend fun loadPhoto(id: String) {
        try {
            val post = data.posts(listOf(id)).firstOrNull()
            if (post == null) {
                update(id) { it.copy(gone = true, loaded = true) }
                return
            }
            subscribe(post.groupId)
            val media = data.media(listOf(post.mediaId)).firstOrNull()
            val author = data.profiles(listOf(post.authorId)).firstOrNull()
            val groupName = groupNames[post.groupId] ?: data.group(post.groupId)?.name?.also { groupNames[post.groupId] = it }
            val reactions = data.reactions(listOf(id))[id].orEmpty()
            val tagged = runCatching { data.isTaggedByMe(id) }.getOrNull()
            update(id) { it.copy(post = post, media = media, author = author, groupName = groupName, reactions = reactions, tagged = tagged, loaded = true, loadFailed = false) }
        } catch (e: CancellationException) {
            throw e
        } catch (e: Throwable) {
            val error = e.dataError()
            if (error is DataError.Api && error.code == ApiError.PostNotFound) update(id) { it.copy(gone = true, loaded = true) }
            else update(id) { it.copy(loadFailed = true) }
        } finally {
            loading.remove(id)
        }
    }

    private fun subscribe(group: String) {
        if (subscriptions.containsKey(group)) return
        subscriptions[group] = viewModelScope.launch { data.events(group).collect(::onEvent) }
    }

    internal suspend fun onEvent(event: GroupEvent) {
        when (event) {
            is GroupEvent.PostDeleted -> {
                val s = _state.value
                val i = s.photos.indexOfFirst { it.postId == event.postId }
                if (i < 0) return
                if (i == s.index) update(event.postId) { it.copy(gone = true) }
                else _state.update { st ->
                    val photos = st.photos.filterIndexed { j, _ -> j != i }
                    st.copy(photos = photos, index = if (i < st.index) st.index - 1 else st.index)
                }
            }
            is GroupEvent.ReactionAdded -> {
                val r = event.reaction
                update(r.postId) { p -> if (p.reactions.any { it.userId == r.userId && it.emoji == r.emoji }) p else p.copy(reactions = p.reactions + ReactionEntry(r.userId, r.emoji)) }
            }
            is GroupEvent.ReactionsChanged -> {
                if (_state.value.photos.none { it.postId == event.postId }) return
                runCatching { data.reactions(listOf(event.postId)) }.getOrNull()?.let { rows -> update(event.postId) { it.copy(reactions = rows[event.postId].orEmpty()) } }
            }
            else -> Unit
        }
    }

    fun setDraft(text: String) = _state.update { it.copy(draft = text) }

    /** `send_message(text, p_reply_to_post_id)`: the reply appears in the chat. */
    fun sendReply() {
        val post = _state.value.current?.post ?: return
        val body = _state.value.draft.trim()
        if (body.isEmpty() || _state.value.sending) return
        _state.update { it.copy(sending = true) }
        viewModelScope.launch {
            try {
                data.sendText(post.groupId, body, replyToPostId = post.id)
                _state.update { it.copy(sending = false, draft = if (it.draft.trim() == body) "" else it.draft) }
                _effects.emit(ViewerEffect.Sent)
            } catch (e: CancellationException) {
                throw e
            } catch (_: Throwable) {
                _state.update { it.copy(sending = false) }
                _effects.emit(ViewerEffect.SendFailed)
            }
        }
    }

    fun react(emoji: String) {
        val me = data.currentUserId() ?: return
        val id = _state.value.current?.post?.id ?: return
        update(id) { it.copy(reactions = withReaction(it.reactions, me, emoji)) }
        _effects.tryEmit(ViewerEffect.Rain(emoji))
        viewModelScope.launch {
            try {
                data.react(id, emoji)
            } catch (e: CancellationException) {
                throw e
            } catch (_: Throwable) {
                update(id) { it.copy(reactions = withoutReaction(it.reactions, me, emoji)) }
                _effects.emit(ViewerEffect.ReactionFailed)
            }
        }
    }

    /**
     * "i'm in this" (tagging.md): offline → no change + `tagging.offline`; otherwise the toggle flips
     * at once, ≤ one call in flight, and reverts on failure.
     */
    fun toggleTag() {
        val photo = _state.value.current ?: return
        val id = photo.post?.id ?: return
        if (photo.tagPending) return
        if (!_state.value.online) {
            _effects.tryEmit(ViewerEffect.TagFailed(TagFailure.Offline))
            return
        }
        val before = photo.tagged == true
        update(id) { it.copy(tagged = !before, tagPending = true) }
        _effects.tryEmit(ViewerEffect.Tagged)
        viewModelScope.launch {
            try {
                if (before) data.untagSelf(id) else data.tagSelf(id)
                update(id) { it.copy(tagPending = false) }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Throwable) {
                val error = e.dataError()
                val reason = when {
                    error is DataError.Api && error.code == ApiError.PostNotFound -> TagFailure.NotFound
                    error == DataError.Network -> TagFailure.Offline
                    else -> TagFailure.Error
                }
                update(id) { it.copy(tagged = before, tagPending = false, gone = it.gone || reason == TagFailure.NotFound) }
                _effects.emit(ViewerEffect.TagFailed(reason))
            }
        }
    }

    /** `delete_media` (owner only, after the confirmation): gone everywhere; the viewer moves on or closes. */
    fun deleteEverywhere() {
        val photo = _state.value.current ?: return
        val mediaId = photo.media?.id ?: photo.post?.mediaId ?: return
        viewModelScope.launch {
            try {
                data.deleteMedia(mediaId)
                _state.update { s ->
                    val photos = s.photos.filterNot { it.postId == photo.postId || it.post?.mediaId == mediaId }
                    s.copy(photos = photos, index = s.index.coerceAtMost((photos.size - 1).coerceAtLeast(0)), closed = photos.isEmpty())
                }
                prefetch()
                _effects.emit(ViewerEffect.Deleted)
            } catch (e: CancellationException) {
                throw e
            } catch (_: Throwable) {
                _effects.emit(ViewerEffect.DeleteFailed)
            }
        }
    }

    /** Bytes of the current original (save to the photo library). */
    suspend fun originalBytes(): Pair<ByteArray, String>? {
        val media = _state.value.current?.media ?: return null
        return runCatching { data.download(media.originalPath) to media.originalPath }.getOrNull()
    }

    fun saved(ok: Boolean) {
        _effects.tryEmit(if (ok) ViewerEffect.Saved else ViewerEffect.SaveFailed)
    }

    fun retryLoad() {
        val id = _state.value.current?.postId ?: return
        update(id) { it.copy(loadFailed = false) }
        if (loading.add(id)) viewModelScope.launch { loadPhoto(id) }
    }

    private fun update(id: String, transform: (ViewerPhoto) -> ViewerPhoto) {
        _state.update { s -> s.copy(photos = s.photos.map { if (it.postId == id) transform(it) else it }) }
    }

    private companion object {
        const val MAX_PAGES = 20
        const val FEED_PAGE = 30
        const val WALL_PAGE = 50
        const val DAYS_IN_WEEK = 7L
    }
}
