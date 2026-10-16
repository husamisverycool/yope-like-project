package app.feature.social.albums

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.data.error.ApiError
import app.data.error.DataError
import app.data.model.Album
import app.data.model.Media
import app.data.model.MemberRole
import app.data.model.Post
import app.data.model.Profile
import app.data.offline.DataState
import app.data.realtime.GroupEvent
import app.feature.social.data.SocialData
import app.feature.social.data.cached
import app.feature.social.data.dataError
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

/** One album card: the album, its cover (first photo's thumbnail) and who saved it. */
@Serializable
data class AlbumCard(val album: Album, val coverPath: String?, val savedBy: String?, val mine: Boolean = false)

data class AlbumsState(val phase: Phase = Phase.Loading, val cards: List<AlbumCard> = emptyList(), val offline: Boolean = false, val query: String = "") {
    enum class Phase { Loading, Ready, Error, OfflineEmpty }

    /** Rows filtered by album name as typed (`albums.list` search). */
    val shown: List<AlbumCard> get() = query.trim().let { q -> if (q.isEmpty()) cards else cards.filter { it.album.name.contains(q, ignoreCase = true) } }
}

/** `albums.list`: the group's albums, newest first, cache-then-network; refetched on reconnect (albums are not realtime). */
class AlbumsViewModel(private val data: SocialData, private val groupId: String) : ViewModel() {
    private val _state = MutableStateFlow(AlbumsState())
    val state: StateFlow<AlbumsState> = _state.asStateFlow()

    init {
        load()
        viewModelScope.launch { data.online.distinctUntilChanged().drop(1).collect { if (it) load() } }
    }

    fun setQuery(query: String) = _state.update { it.copy(query = query) }

    fun load() {
        viewModelScope.launch {
            data.cached("albums/$groupId", kotlinx.serialization.builtins.ListSerializer(AlbumCard.serializer())) { cards() }.collect { page -> apply(page) }
        }
    }

    private fun apply(page: DataState<List<AlbumCard>>) {
        val value = page.value
        _state.update {
            when {
                value != null -> it.copy(phase = AlbumsState.Phase.Ready, cards = value, offline = page.error == DataError.Network)
                page.refreshing -> if (it.cards.isEmpty()) it.copy(phase = AlbumsState.Phase.Loading) else it
                else -> it.copy(phase = if (page.error == DataError.Network) AlbumsState.Phase.OfflineEmpty else AlbumsState.Phase.Error)
            }
        }
    }

    private suspend fun cards(): List<AlbumCard> {
        val albums = data.albums(groupId)
        val first = albums.associate { a -> a.id to data.albumItems(a.id).minByOrNull { it.position }?.postId }
        val posts = data.posts(first.values.filterNotNull()).associateBy { it.id }
        val media = data.media(posts.values.map { it.mediaId }).associateBy { it.id }
        val people = data.profiles(albums.mapNotNull { it.createdBy }.distinct()).associateBy { it.id }
        return albums.sortedByDescending { it.createdAt }.map { a ->
            val post = first[a.id]?.let(posts::get)
            AlbumCard(a, post?.let { media[it.mediaId]?.imagePath(Media.Rendition.Thumb) }, a.createdBy?.let { people[it]?.firstName }, mine = a.createdBy != null && a.createdBy == data.currentUserId())
        }
    }
}

data class AlbumViewState(
    val phase: Phase = Phase.Loading,
    val album: Album? = null,
    val photos: List<AlbumPhoto> = emptyList(),
    val canDelete: Boolean = false,
    val offline: Boolean = false,
    val renaming: Boolean = false,
    val renameName: String = "",
    val renameError: RenameError? = null,
    val busy: Boolean = false,
    /** The album's creator (`albums.list.row.subtitle`) and whether that is me (`.subtitleMine`). */
    val creatorName: String? = null,
    val mine: Boolean = false,
) {
    enum class Phase { Loading, Ready, NotFound, Error, OfflineEmpty }
}

enum class RenameError { Empty, Save }

data class AlbumPhoto(val post: Post, val thumbPath: String?, val authorName: String?)

sealed interface AlbumEffect {
    data object Renamed : AlbumEffect
    data object Deleted : AlbumEffect
    data object Failed : AlbumEffect
}

@Serializable
internal data class AlbumPayload(val album: Album? = null, val posts: List<Post> = emptyList(), val media: List<Media> = emptyList(), val profiles: List<Profile> = emptyList(), val canDelete: Boolean = false)

/**
 * `albums.view`: the album's items in `position` order, rename (optimistic: the title changes at
 * once and goes back if `rename_album` fails) and delete (creator or admin; `delete_album`).
 * `post_deleted` drops tiles.
 */
class AlbumViewModel(private val data: SocialData, private val groupId: String, private val albumId: String) : ViewModel() {
    private val _state = MutableStateFlow(AlbumViewState())
    val state: StateFlow<AlbumViewState> = _state.asStateFlow()
    private val _effects = MutableSharedFlow<AlbumEffect>(extraBufferCapacity = 8, onBufferOverflow = BufferOverflow.DROP_OLDEST)
    val effects: SharedFlow<AlbumEffect> = _effects.asSharedFlow()
    private var payload: AlbumPayload? = null
    private val removed = HashSet<String>()

    init {
        load()
        viewModelScope.launch { data.events(groupId).collect(::onEvent) }
        viewModelScope.launch { data.online.distinctUntilChanged().drop(1).collect { if (it) load() } }
    }

    fun load() {
        viewModelScope.launch {
            data.cached("album/$albumId", AlbumPayload.serializer()) { payload() }.collect { page ->
                val p = page.value
                when {
                    p != null -> publish(p, page.error == DataError.Network)
                    page.refreshing -> _state.update { if (it.album == null) it.copy(phase = AlbumViewState.Phase.Loading) else it }
                    else -> {
                        val e = page.error
                        _state.update {
                            it.copy(
                                phase = when {
                                    e == DataError.Network -> AlbumViewState.Phase.OfflineEmpty
                                    e is DataError.Api && e.code == ApiError.AlbumNotFound -> AlbumViewState.Phase.NotFound
                                    else -> AlbumViewState.Phase.Error
                                },
                            )
                        }
                    }
                }
            }
        }
    }

    private suspend fun payload(): AlbumPayload {
        val album = data.albums(groupId).firstOrNull { it.id == albumId } ?: return AlbumPayload()
        val items = data.albumItems(albumId).sortedBy { it.position }
        val posts = data.posts(items.map { it.postId })
        val media = data.media(posts.map { it.mediaId })
        val profiles = data.profiles((posts.map { it.authorId } + listOfNotNull(album.createdBy)).distinct())
        val me = data.currentUserId()
        val admin = runCatching { data.members(groupId) }.getOrDefault(emptyList()).any { it.member.userId == me && it.member.role == MemberRole.Admin }
        return AlbumPayload(album, posts, media, profiles, canDelete = admin || (me != null && album.createdBy == me))
    }

    private fun publish(p: AlbumPayload, offline: Boolean) {
        payload = p
        val album = p.album
        if (album == null) {
            _state.update { it.copy(phase = AlbumViewState.Phase.NotFound, album = null, photos = emptyList()) }
            return
        }
        val media = p.media.associateBy { it.id }
        val names = p.profiles.associate { it.id to it.firstName }
        val photos = p.posts.filter { it.id !in removed }.map { AlbumPhoto(it, media[it.mediaId]?.imagePath(Media.Rendition.Thumb), names[it.authorId]) }
        val me = data.currentUserId()
        _state.update {
            it.copy(
                phase = AlbumViewState.Phase.Ready,
                album = it.album?.takeIf { a -> a.id == album.id && it.busy } ?: album,
                photos = photos,
                canDelete = p.canDelete,
                offline = offline,
                creatorName = album.createdBy?.let { id -> p.profiles.firstOrNull { pr -> pr.id == id }?.firstName },
                mine = me != null && album.createdBy == me,
            )
        }
    }

    internal fun onEvent(event: GroupEvent) {
        if (event is GroupEvent.PostDeleted) {
            removed += event.postId
            payload?.let { publish(it, _state.value.offline) }
        }
    }

    fun startRename() = _state.update { it.copy(renaming = true, renameName = it.album?.name.orEmpty(), renameError = null) }
    fun cancelRename() = _state.update { it.copy(renaming = false, renameError = null) }
    fun setRenameName(name: String) = _state.update { it.copy(renameName = name, renameError = null) }

    fun rename() {
        val s = _state.value
        val album = s.album ?: return
        val name = s.renameName.trim()
        if (name.isEmpty()) {
            _state.update { it.copy(renameError = RenameError.Empty) }
            _effects.tryEmit(AlbumEffect.Failed)
            return
        }
        // Optimistic: the title changes at once.
        _state.update { it.copy(album = album.copy(name = name), renaming = false, busy = true) }
        viewModelScope.launch {
            try {
                val renamed = data.renameAlbum(album.id, name)
                _state.update { it.copy(album = renamed, busy = false) }
                _effects.emit(AlbumEffect.Renamed)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Throwable) {
                val invalid = e.dataError().let { it is DataError.Api && it.code == ApiError.InvalidName }
                _state.update { it.copy(album = album, busy = false, renaming = true, renameName = name, renameError = if (invalid) RenameError.Empty else RenameError.Save) }
                _effects.emit(AlbumEffect.Failed)
            }
        }
    }

    fun delete() {
        val album = _state.value.album ?: return
        _state.update { it.copy(busy = true) }
        viewModelScope.launch {
            try {
                data.deleteAlbum(album.id)
                _state.update { it.copy(busy = false) }
                _effects.emit(AlbumEffect.Deleted)
            } catch (e: CancellationException) {
                throw e
            } catch (_: Throwable) {
                _state.update { it.copy(busy = false) }
                _effects.emit(AlbumEffect.Failed)
            }
        }
    }
}

