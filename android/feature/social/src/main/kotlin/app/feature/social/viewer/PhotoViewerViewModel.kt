package app.feature.social.viewer

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.data.error.ApiError
import app.data.error.DataError
import app.data.model.Media
import app.data.model.Message
import app.data.model.Post
import app.data.model.Profile
import app.data.model.WallItemKind
import app.data.realtime.GroupEvent
import app.data.repo.ReactionEntry
import app.feature.social.common.Formats
import app.feature.social.data.SocialData
import app.feature.social.data.dataError
import app.feature.social.reactions.withReaction
import app.feature.social.reactions.withoutReaction
import app.feature.social.search.SearchResults
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
import java.io.File
import java.time.LocalDate
import java.time.ZoneId

/** One photo of the viewer. [gone] = deleted / no longer visible (`post_not_found`, `post_deleted`). */
data class ViewerPhoto(
    val postId: String,
    val post: Post? = null,
    val media: Media? = null,
    val author: Profile? = null,
    val groupName: String? = null,
    /** The group's time zone (week number of the header). */
    val zone: ZoneId? = null,
    val reactions: List<ReactionEntry> = emptyList(),
    /** Replies to this photo in its group's chat, oldest first (`photo.viewer.layout.comments`). */
    val comments: List<Message> = emptyList(),
    /** Who said "I'm in this", in tag order (`post_tags`) — handed to the memory group's tag run. */
    val tagged: List<String> = emptyList(),
    /** Profiles of the author, commenters, reactors and tagged members. */
    val people: Map<String, Profile> = emptyMap(),
    val loaded: Boolean = false,
    val gone: Boolean = false,
    val loadFailed: Boolean = false,
    /** Selfie reactions (`viewer.selfiereaction`), oldest first, one per person; yours while sending has no id yet. */
    val selfies: List<SelfieEntry> = emptyList(),
    /** Shown from this device's copy while offline (`photo.viewer` → States → offline); reloaded when back online. */
    val fromCache: Boolean = false,
) {
    /** ISO week of the photo in its group's time zone: the week it became visible in (`visibleAt`, docs/API.md §5.8). */
    val weekNumber: Int? get() = post?.let { Formats.isoWeek(it.visibleAt.atZone(zone ?: ZoneId.systemDefault()).toLocalDate()) }
}

data class ViewerState(
    val phase: Phase = Phase.Loading,
    val me: String? = null,
    val photos: List<ViewerPhoto> = emptyList(),
    val index: Int = 0,
    val draft: String = "",
    val online: Boolean = true,
    /** Opened from a wall: the header names the group ("{group} · Week 28"). */
    val fromWall: Boolean = false,
    /** Every photo is gone, or the last one was passed: the viewer closes. */
    val closed: Boolean = false,
    /** Your private favorites among the photos, by media (your own `favorites` rows, then this session's changes). */
    val favorites: Set<String> = emptySet(),
    /** The groups of the photos where you are an admin ("Use as Cover", update_group's rule). */
    val adminGroups: Set<String> = emptySet(),
) {
    enum class Phase { Loading, Ready }

    val current: ViewerPhoto? get() = photos.getOrNull(index)
    val mine: Boolean get() = current?.post?.authorId != null && current?.post?.authorId == me

    /** A selfie can be sent to the current photo: it is loaded and not yours ("You cannot react to your own BeReal"). */
    val canReactWithSelfie: Boolean get() = me != null && current?.post != null && current?.gone != true && !mine
    val taggedByMe: Boolean get() = me != null && current?.tagged?.contains(me) == true

    /** The photo on screen is one of your favorites: the menu offers Unfavorite. */
    val favorite: Boolean get() = current?.post?.mediaId?.let { it in favorites } == true

    /** "Use as Cover": you are an admin of the photo's group and the photo is still there. */
    val canUseAsCover: Boolean get() = current?.gone != true && current?.post?.groupId?.let { it in adminGroups } == true

    /** Your own photo that is still there: the menu's first item edits (or adds) its caption (owner decision 34). */
    val canEditCaption: Boolean get() = mine && current?.gone != true && current?.post != null

    /** The photo on screen has a caption: "Edit Caption"; without one "Add a Caption". */
    val hasCaption: Boolean get() = !current?.post?.caption.isNullOrBlank()
}

/** What the viewer keeps of a photo for offline (`photo.viewer` → States → offline). */
@kotlinx.serialization.Serializable
internal data class ViewerCopy(
    val post: Post,
    val media: Media?,
    val people: List<Profile>,
    val groupName: String?,
    val timeZone: String?,
    val reactions: List<app.feature.social.chat.CachedReaction>,
    val comments: List<Message>,
    val tagged: List<String>,
)

sealed interface ViewerEffect {
    data object Sent : ViewerEffect
    data object SendFailed : ViewerEffect
    data object ReactionFailed : ViewerEffect
    /** Your selfie reached the server: the `viewer.selfiereaction.a11y.sent` announcement. */
    data object SelfieSent : ViewerEffect
    /** Upload or `react_with_selfie` failed: your face left the stack (`viewer.selfiereaction.error`). */
    data object SelfieFailed : ViewerEffect
    data object Deleted : ViewerEffect
    data object DeleteFailed : ViewerEffect
    data object Saved : ViewerEffect
    data object SaveFailed : ViewerEffect
    /** `set_favorite` failed: the heart went back (`photo.viewer.error.favorite`). */
    data object FavoriteFailed : ViewerEffect
    /** "Use as Cover" saved ("Saved!", `week.edit.toast.saved`). */
    data object CoverSet : ViewerEffect
    /** `media_not_ready` (`photo.viewer.error.coverNotReady`). */
    data object CoverNotReady : ViewerEffect
    /** `photo.viewer.error.cover`. */
    data object CoverFailed : ViewerEffect
    /** The album picker put the photo in an album ("Added to Album!", `week.edit.toast.albumSaved`). */
    data object AddedToAlbum : ViewerEffect
    /** `edit_caption` failed: the caption is back as it was (`photo.viewer.error.caption`). */
    data object CaptionFailed : ViewerEffect
}

/**
 * `photo.viewer`: the opener's photo list ([PhotoContext]), each photo's post / media / author / group /
 * reactions / selfie reactions / comments / tags, realtime deletions, reactions and new comments, and the viewer's actions
 * (advance, reply, react, react with a selfie, tag, delete everywhere, save).
 */
class PhotoViewerViewModel(
    private val data: SocialData,
    private val groupId: String,
    private val postId: String,
    private val context: PhotoContext,
    private val contextId: String,
    private val weekStart: LocalDate?,
) : ViewModel() {
    // From a wall, your favorites, or a search over all your groups: the header's second line names the photo's group.
    private val _state = MutableStateFlow(
        ViewerState(
            me = data.currentUserId(),
            fromWall = context == PhotoContext.Wall || context == PhotoContext.Favorites ||
                (context == PhotoContext.Search && SearchResults.spansGroups(contextId)),
        ),
    )
    val state: StateFlow<ViewerState> = _state.asStateFlow()
    private val _effects = MutableSharedFlow<ViewerEffect>(extraBufferCapacity = 16, onBufferOverflow = BufferOverflow.DROP_OLDEST)
    val effects: SharedFlow<ViewerEffect> = _effects.asSharedFlow()

    private val groups = HashMap<String, app.data.model.Group?>()
    /** Your selfie being sent, per post (kept through reloads until the call returns). */
    private val pending = HashMap<String, SelfieEntry>()
    private val tempFiles = ArrayList<File>()
    private val subscriptions = HashMap<String, Job>()
    private val loading = HashSet<String>()
    /** Whether you are an admin, per group (read once with the group). */
    private val roles = HashMap<String, Boolean>()
    /** ≤ one `set_favorite` in flight per photo (by media). */
    private val favoritePending = HashSet<String>()

    init {
        viewModelScope.launch { load() }
        viewModelScope.launch {
            data.online.collect { online ->
                val wasOffline = !_state.value.online
                _state.update { it.copy(online = online) }
                // photo.viewer → offline: back online, what failed or came from this device's copy loads again.
                if (online && wasOffline) reloadStale()
            }
        }
    }

    /** The photos on and around the screen that failed or show this device's copy, loaded again. */
    private fun reloadStale() {
        val s = _state.value
        listOf(s.index, s.index + 1, s.index - 1).mapNotNull { s.photos.getOrNull(it) }.filter { it.loadFailed || it.fromCache }.forEach { photo ->
            if (loading.add(photo.postId)) viewModelScope.launch { loadPhoto(photo.postId) }
        }
    }

    /**
     * The opened photo shows at once; the opener's list arrives after and is spliced around it, keeping the
     * photo on screen and whatever is already loaded.
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
            data.historyWeeks(contextId, start.plusDays(Formats.DAYS_IN_WEEK), 1).firstOrNull { it.weekStart == start }?.postIds.orEmpty()
        }
        PhotoContext.Recap -> data.recap(contextId)?.items.orEmpty()
        PhotoContext.Album -> data.albumItems(contextId).sortedBy { it.position }.map { it.postId }
        PhotoContext.Question -> data.questionAnswers(contextId)
        // favorites: your favorites in their order (newest favorite first), one post per photo.
        PhotoContext.Favorites -> data.myFavorites(null, FAVORITES_PAGE).map { it.postId }.distinct()
        // search.photos: the results in their order, as the search page kept them (none after a new process: the photo alone).
        PhotoContext.Search -> SearchResults.postIds(contextId) ?: listOf(postId)
        PhotoContext.Reveal -> {
            // camera.overnight C: the photos revealed together, oldest first; a photo shared at once stays alone.
            val post = data.posts(listOf(postId)).firstOrNull()
            if (post?.revealedAt == null) listOf(postId) else data.revealedWith(post)
        }
    }

    /** Moves to [index] and loads that photo and its neighbours. */
    fun select(index: Int) {
        if (index == _state.value.index || index !in _state.value.photos.indices) return
        _state.update { it.copy(index = index) }
        prefetch()
    }

    /** Tap to advance (`photo.viewer.layout.advance`): past the last photo the viewer closes. */
    fun next() {
        val s = _state.value
        if (s.index + 1 < s.photos.size) select(s.index + 1) else _state.update { it.copy(closed = true) }
    }

    /** "Tap left to go back": nothing before the first photo. */
    fun previous() {
        val s = _state.value
        if (s.index > 0) select(s.index - 1)
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
            val group = if (groups.containsKey(post.groupId)) groups[post.groupId] else data.group(post.groupId).also { groups[post.groupId] = it }
            loadFavoriteAndRole(post)
            val reactions = data.reactions(listOf(id))[id].orEmpty()
            val comments = runCatching { data.replies(post.groupId, id) }.getOrDefault(emptyList())
            val tags = runCatching { data.tags(id) }.getOrDefault(emptyList()).map { it.userId }
            val selfies = runCatching { data.selfieReactions(listOf(id))[id] }.getOrNull().orEmpty().map(SelfieEntry::of)
            val ids = (listOf(post.authorId) + comments.map { it.authorId } + reactions.map { it.userId } + tags + selfies.map { it.userId }).distinct()
            val people = data.profiles(ids).associateBy { it.id }
            val zone = group?.timeZone?.let { runCatching { ZoneId.of(it) }.getOrNull() }
            update(id) {
                it.copy(
                    post = post, media = media, author = people[post.authorId], groupName = group?.name, zone = zone, reactions = reactions,
                    comments = comments, tagged = tags, people = people, loaded = true, loadFailed = false,
                    selfies = withPending(id, selfies), fromCache = false,
                )
            }
            runCatching {
                data.cachePut(cacheKey(id), ViewerCopy.serializer(), ViewerCopy(post, media, people.values.toList(), group?.name, group?.timeZone,
                    reactions.map { app.feature.social.chat.CachedReaction(it.userId, it.emoji) }, comments, tags))
            }
        } catch (e: CancellationException) {
            throw e
        } catch (e: Throwable) {
            val error = e.dataError()
            if (error is DataError.Api && error.code == ApiError.PostNotFound) update(id) { it.copy(gone = true, loaded = true) }
            else {
                // photo.viewer → offline: this device's copy of the photo (from an earlier visit, else the thread's page
                // cache); nothing cached → the error line (tap retries; loaded again when back online).
                val copy = cachedCopy(id)
                if (copy != null) update(id) { copy(it) } else update(id) { it.copy(loadFailed = true) }
            }
        } finally {
            loading.remove(id)
        }
    }

    /** Whether the photo is one of your favorites, and whether you are an admin of its group (kept on failure). */
    private suspend fun loadFavoriteAndRole(post: Post) {
        if (post.mediaId !in favoritePending) {
            runCatching { data.favoriteMediaIds(listOf(post.mediaId)) }.getOrNull()?.let { found ->
                if (post.mediaId !in favoritePending) {
                    _state.update { s -> s.copy(favorites = if (post.mediaId in found) s.favorites + post.mediaId else s.favorites - post.mediaId) }
                }
            }
        }
        if (!roles.containsKey(post.groupId)) {
            val me = data.currentUserId()
            runCatching { data.members(post.groupId) }.getOrNull()?.let { members ->
                val admin = members.any { it.member.userId == me && it.member.role == app.data.model.MemberRole.Admin }
                roles[post.groupId] = admin
                if (admin) _state.update { s -> s.copy(adminGroups = s.adminGroups + post.groupId) }
            }
        }
    }

    /**
     * Favorite / Unfavorite (`set_favorite`, private): applied at once; back as it was with [ViewerEffect.FavoriteFailed] if
     * the call fails. Taps wait while one is in flight.
     */
    fun toggleFavorite() {
        val photo = _state.value.current ?: return
        if (photo.gone) return
        val mediaId = photo.post?.mediaId ?: return
        if (!favoritePending.add(mediaId)) return
        val was = mediaId in _state.value.favorites
        _state.update { s -> s.copy(favorites = if (was) s.favorites - mediaId else s.favorites + mediaId) }
        viewModelScope.launch {
            try {
                data.setFavorite(mediaId, !was)
            } catch (e: CancellationException) {
                throw e
            } catch (_: Throwable) {
                _state.update { s -> s.copy(favorites = if (was) s.favorites + mediaId else s.favorites - mediaId) }
                _effects.emit(ViewerEffect.FavoriteFailed)
            } finally {
                favoritePending.remove(mediaId)
            }
        }
    }

    /** "Use as Cover" (`set_group_cover_from_post`, admins): [ViewerEffect.CoverSet]; `media_not_ready` → [ViewerEffect.CoverNotReady]. */
    fun useAsCover() {
        val s = _state.value
        if (!s.canUseAsCover) return
        val post = s.current?.post ?: return
        viewModelScope.launch {
            try {
                data.setGroupCover(post.groupId, post.id)
                _effects.emit(ViewerEffect.CoverSet)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Throwable) {
                val error = e.dataError()
                if (error is DataError.Api && error.code == ApiError.NotGroupAdmin) {
                    roles[post.groupId] = false
                    _state.update { it.copy(adminGroups = it.adminGroups - post.groupId) }
                }
                _effects.emit(if (error is DataError.Api && error.code == ApiError.MediaNotReady) ViewerEffect.CoverNotReady else ViewerEffect.CoverFailed)
            }
        }
    }

    /** The album picker added the photo or saved a new album with it. */
    fun addedToAlbum() {
        _effects.tryEmit(ViewerEffect.AddedToAlbum)
    }

    /**
     * "Save" in the caption dialog (`photo.viewer.layout.editCaption`): `edit_caption` on your own photo, any time; blank
     * removes the caption, unchanged text sends nothing. The new caption shows at once with "Edited"; the server's row
     * replaces it; a failure puts the caption back with [ViewerEffect.CaptionFailed].
     */
    fun saveCaption(text: String, postId: String? = _state.value.current?.postId) {
        val photo = _state.value.photos.firstOrNull { it.postId == postId } ?: return
        val post = photo.post ?: return
        if (photo.gone || post.authorId != _state.value.me) return
        val caption = text.take(CAPTION_MAX).trim()
        if (caption == post.caption.orEmpty().trim()) return
        val shown = post.copy(caption = caption.ifEmpty { null }, captionEditedAt = post.captionEditedAt ?: java.time.Instant.now())
        update(post.id) { it.copy(post = shown) }
        viewModelScope.launch {
            try {
                val row = data.editCaption(post.id, caption)
                update(post.id) { it.copy(post = row) }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Throwable) {
                val error = e.dataError()
                if (error is DataError.Api && error.code == ApiError.PostNotFound) update(post.id) { it.copy(gone = true) }
                else update(post.id) { if (it.post == shown) it.copy(post = post) else it }
                _effects.emit(ViewerEffect.CaptionFailed)
            }
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
                update(r.postId) { p -> if (p.reactions.any { it.userId == r.userId && it.emoji == r.emoji }) p else p.copy(reactions = p.reactions + ReactionEntry(r.userId, r.emoji, r.createdAt)) }
            }
            is GroupEvent.ReactionsChanged -> {
                if (_state.value.photos.none { it.postId == event.postId }) return
                runCatching { data.reactions(listOf(event.postId)) }.getOrNull()?.let { rows -> update(event.postId) { it.copy(reactions = rows[event.postId].orEmpty()) } }
                // Removed selfies arrive as this broadcast too (docs/API.md §14.1).
                runCatching { data.selfieReactions(listOf(event.postId)) }.getOrNull()?.let { rows ->
                    update(event.postId) { it.copy(selfies = withPending(event.postId, rows[event.postId].orEmpty().map(SelfieEntry::of), it.selfies)) }
                }
            }
            is GroupEvent.SelfieReactionChanged -> {
                val row = event.selfie
                if (_state.value.photos.none { it.postId == row.postId }) return
                val known = _state.value.photos.any { it.people.containsKey(row.userId) }
                val profile = if (known) null else runCatching { data.profiles(listOf(row.userId)).firstOrNull() }.getOrNull()
                update(row.postId) { p ->
                    val previous = p.selfies.firstOrNull { it.userId == row.userId }
                    // Your own row coming back keeps the still you just took on screen (no reload of the same face).
                    val entry = SelfieEntry.of(row).copy(localFile = previous?.localFile?.takeIf { previous.imagePath == null || previous.imagePath == row.imagePath })
                    p.copy(selfies = p.selfies.filterNot { it.userId == row.userId } + entry, people = profile?.let { p.people + (it.id to it) } ?: p.people)
                }
            }
            is GroupEvent.MessageInserted -> {
                val m = event.message
                val target = m.replyToPostId ?: return
                if (_state.value.photos.none { it.postId == target }) return
                val profile = if (_state.value.photos.any { it.people.containsKey(m.authorId) }) null else runCatching { data.profiles(listOf(m.authorId)).firstOrNull() }.getOrNull()
                update(target) { p ->
                    if (p.comments.any { it.id == m.id }) p
                    else p.copy(comments = (p.comments + m).sortedBy { it.createdAt }, people = profile?.let { p.people + (it.id to it) } ?: p.people)
                }
            }
            is GroupEvent.MessageDeleted -> _state.update { s -> s.copy(photos = s.photos.map { p -> p.copy(comments = p.comments.filterNot { it.id == event.messageId }) }) }
            // A caption edited on another device (`edit_caption`) or a reply losing its target: the post changes in place.
            is GroupEvent.PostUpdated -> update(event.post.id) { p -> if (p.post == null) p else p.copy(post = event.post) }
            else -> Unit
        }
    }

    fun setDraft(text: String) = _state.update { it.copy(draft = text) }

    /**
     * `send_message(text, p_reply_to_post_id)`: the comment joins the list and the thread. Optimistic: the field
     * clears at once; if the call fails the text comes back (unless something new was typed).
     */
    fun sendReply() {
        val post = _state.value.current?.post ?: return
        val body = _state.value.draft.trim()
        if (body.isEmpty()) return
        _state.update { it.copy(draft = "") }
        viewModelScope.launch {
            try {
                val sent = data.sendText(post.groupId, body, replyToPostId = post.id)
                update(post.id) { p -> if (p.comments.any { it.id == sent.id }) p else p.copy(comments = p.comments + sent) }
                _effects.emit(ViewerEffect.Sent)
            } catch (e: CancellationException) {
                throw e
            } catch (_: Throwable) {
                _state.update { if (it.draft.isEmpty()) it.copy(draft = body) else it }
                _effects.emit(ViewerEffect.SendFailed)
            }
        }
    }

    /** Your own comment (`delete_message`, after the confirmation): gone at once, back if the call fails. */
    fun unsendComment(messageId: String) {
        val photo = _state.value.photos.firstOrNull { p -> p.comments.any { it.id == messageId } } ?: return
        val removed = photo.comments.first { it.id == messageId }
        update(photo.postId) { p -> p.copy(comments = p.comments - removed) }
        viewModelScope.launch {
            try {
                data.deleteMessage(messageId)
            } catch (e: CancellationException) {
                throw e
            } catch (_: Throwable) {
                update(photo.postId) { p -> p.copy(comments = (p.comments + removed).sortedBy { it.createdAt }) }
                _effects.emit(ViewerEffect.DeleteFailed)
            }
        }
    }

    fun react(emoji: String) {
        val me = data.currentUserId() ?: return
        val id = _state.value.current?.post?.id ?: return
        update(id) { it.copy(reactions = withReaction(it.reactions, me, emoji)) }
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

    /** `unreact` (picker, quick row, your row in the Reactions sheet): gone at once; back if the call fails. */
    fun unreact(emoji: String) {
        val me = data.currentUserId() ?: return
        val id = _state.value.current?.post?.id ?: return
        if (_state.value.current?.reactions.orEmpty().none { it.userId == me && it.emoji == emoji }) return
        update(id) { it.copy(reactions = withoutReaction(it.reactions, me, emoji)) }
        viewModelScope.launch {
            try {
                data.unreact(id, emoji)
            } catch (e: CancellationException) {
                throw e
            } catch (_: Throwable) {
                update(id) { it.copy(reactions = withReaction(it.reactions, me, emoji)) }
                _effects.emit(ViewerEffect.ReactionFailed)
            }
        }
    }

    /**
     * `react_with_selfie` with the still [file] just taken in the capture layer (`viewer.selfiereaction` → sending): your face
     * joins the leading end of the stack at once, replacing an earlier one (one per person per post); if the upload or the
     * call fails it leaves again ([ViewerEffect.SelfieFailed]).
     */
    fun sendSelfie(file: File) {
        val me = data.currentUserId() ?: return
        val s = _state.value
        val post = s.current?.post ?: return
        if (!s.canReactWithSelfie) return
        val before = s.current?.selfies?.firstOrNull { it.userId == me }
        val sending = SelfieEntry(id = null, userId = me, imagePath = null, createdAt = null, localFile = file)
        tempFiles += file
        pending[post.id] = sending
        update(post.id) { p -> p.copy(selfies = p.selfies.filterNot { it.userId == me } + sending) }
        viewModelScope.launch {
            try {
                val row = data.reactWithSelfie(post.id, file)
                if (pending[post.id] === sending) pending.remove(post.id)
                update(post.id) { p ->
                    if (p.selfies.none { it === sending }) p
                    else p.copy(selfies = p.selfies.map { if (it === sending) SelfieEntry.of(row).copy(localFile = file) else it })
                }
                _effects.emit(ViewerEffect.SelfieSent)
            } catch (e: CancellationException) {
                throw e
            } catch (_: Throwable) {
                if (pending[post.id] === sending) pending.remove(post.id)
                update(post.id) { p ->
                    if (p.selfies.none { it === sending }) p
                    else p.copy(selfies = p.selfies.filterNot { it === sending } + listOfNotNull(before))
                }
                _effects.emit(ViewerEffect.SelfieFailed)
            }
        }
    }

    /**
     * `remove_selfie_reaction`: yours (tap your row in the Reactions sheet), or — on your own photo, after the confirmation —
     * [userId]'s. Gone at once (the face fades out); back if the call fails.
     */
    fun removeSelfie(userId: String) {
        val me = data.currentUserId() ?: return
        val s = _state.value
        val post = s.current?.post ?: return
        if (userId != me && !s.mine) return
        val selfies = s.current?.selfies.orEmpty()
        val at = selfies.indexOfFirst { it.userId == userId && it.id != null }
        if (at < 0) return
        val removed = selfies[at]
        update(post.id) { p -> p.copy(selfies = p.selfies.filterNot { it.userId == userId }) }
        viewModelScope.launch {
            try {
                data.removeSelfieReaction(post.id, userId.takeIf { it != me })
            } catch (e: CancellationException) {
                throw e
            } catch (_: Throwable) {
                update(post.id) { p ->
                    if (p.selfies.any { it.userId == userId }) p
                    else p.copy(selfies = p.selfies.toMutableList().apply { add(at.coerceAtMost(size), removed) })
                }
                _effects.emit(ViewerEffect.ReactionFailed)
            }
        }
    }

    /** [rows] from the server plus your selfie still being sent to [postId] (it replaces your older row). */
    private fun withPending(postId: String, rows: List<SelfieEntry>, current: List<SelfieEntry> = emptyList()): List<SelfieEntry> {
        val sending = pending[postId] ?: return rows.map { row -> current.firstOrNull { it.id == row.id && it.imagePath == row.imagePath }?.let { row.copy(localFile = it.localFile) } ?: row }
        return rows.filterNot { it.userId == sending.userId } + sending
    }

    override fun onCleared() {
        // The stills taken here were uploaded (or failed): selfies are never kept on the device (owner decision 12).
        tempFiles.forEach { it.delete() }
    }

    /** The photo was deleted meanwhile: it shows as gone, as for a realtime `post_deleted`. */
    fun markGone(postId: String) = update(postId) { it.copy(gone = true) }

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

    fun saved(ok: Boolean) {
        _effects.tryEmit(if (ok) ViewerEffect.Saved else ViewerEffect.SaveFailed)
    }

    fun retryLoad() {
        val id = _state.value.current?.postId ?: return
        update(id) { it.copy(loadFailed = false) }
        if (loading.add(id)) viewModelScope.launch { loadPhoto(id) }
    }

    private fun cacheKey(postId: String) = "viewer/$postId"

    /** The photo as this device last saw it: the viewer's own copy, else the post in its group's thread cache. */
    private suspend fun cachedCopy(id: String): ((ViewerPhoto) -> ViewerPhoto)? {
        runCatching { data.cacheGet(cacheKey(id), ViewerCopy.serializer()) }.getOrNull()?.let { c ->
            val people = c.people.associateBy { it.id }
            val zone = c.timeZone?.let { runCatching { ZoneId.of(it) }.getOrNull() }
            return { p ->
                p.copy(
                    post = c.post, media = c.media, author = people[c.post.authorId], groupName = c.groupName, zone = zone,
                    reactions = c.reactions.map { ReactionEntry(it.userId, it.emoji) }, comments = c.comments, tagged = c.tagged, people = people,
                    loaded = true, loadFailed = false, fromCache = true,
                )
            }
        }
        val thread = runCatching { data.cacheGet("chat/$groupId", app.feature.social.chat.ChatHydration.serializer()) }.getOrNull() ?: return null
        val post = thread.posts.firstOrNull { it.id == id } ?: return null
        val people = thread.profiles.associateBy { it.id }
        return { p ->
            p.copy(
                post = post, media = thread.media.firstOrNull { it.id == post.mediaId }, author = people[post.authorId], people = people,
                reactions = thread.reactions[id].orEmpty().map { ReactionEntry(it.userId, it.emoji) },
                loaded = true, loadFailed = false, fromCache = true,
            )
        }
    }

    private fun update(id: String, transform: (ViewerPhoto) -> ViewerPhoto) {
        _state.update { s -> s.copy(photos = s.photos.map { if (it.postId == id) transform(it) else it }) }
    }

    companion object {
        private const val MAX_PAGES = 20
        private const val FEED_PAGE = 30
        private const val WALL_PAGE = 50
        private const val FAVORITES_PAGE = 200

        /** `posts.caption`: at most 1000 characters (docs/API.md §5.8; `invalid_caption` above). */
        const val CAPTION_MAX = 1000
    }
}
