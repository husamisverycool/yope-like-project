package app.feature.social.albums

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.data.error.ApiError
import app.data.error.DataError
import app.data.model.Media
import app.feature.social.common.videoDurationMs
import app.feature.social.data.SocialData
import app.feature.social.data.dataError
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.channels.BufferOverflow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/** A failure the album sheets show with `week.edit.error.save` (`haptic.global.error`). */
sealed interface AlbumAddEffect {
    data object Failed : AlbumAddEffect
}

data class AlbumAddState(
    val phase: Phase = Phase.Loading,
    /** The group's photos the album does not hold, newest week first, newest photo first inside a week. */
    val photos: List<AlbumPhoto> = emptyList(),
    /** Picked post ids in the order picked. */
    val picked: List<String> = emptyList(),
    val saving: Boolean = false,
    /** The photos were added: the sheet closes. */
    val done: Boolean = false,
) {
    enum class Phase { Loading, Ready, Empty, Error, OfflineEmpty }

    val canAdd: Boolean get() = picked.isNotEmpty() && !saving
}

/**
 * `albums.view.layout.add` ("Add Photos", albums anyone can add to — migration 0039): the photos of the first page of the
 * group's weeks (`group_history_weeks`) the album does not hold; pick several, then `add_to_album` in the order picked.
 */
class AlbumAddViewModel(
    private val data: SocialData,
    private val groupId: String,
    private val albumId: String,
    private val excluding: Set<String>,
) : ViewModel() {
    private val _state = MutableStateFlow(AlbumAddState())
    val state: StateFlow<AlbumAddState> = _state.asStateFlow()
    private val _effects = MutableSharedFlow<AlbumAddEffect>(extraBufferCapacity = 4, onBufferOverflow = BufferOverflow.DROP_OLDEST)
    val effects: SharedFlow<AlbumAddEffect> = _effects.asSharedFlow()

    init {
        load()
    }

    fun load() {
        _state.update { it.copy(phase = AlbumAddState.Phase.Loading) }
        viewModelScope.launch {
            try {
                val weeks = data.historyWeeks(groupId, null, WEEKS)
                val ids = weeks.sortedByDescending { it.weekStart }.flatMap { it.postIds.reversed() }.distinct().filter { it !in excluding }
                val posts = data.posts(ids).associateBy { it.id }
                val media = data.media(posts.values.map { it.mediaId }).associateBy { it.id }
                val names = runCatching { data.profiles(posts.values.map { it.authorId }.distinct()) }.getOrDefault(emptyList()).associate { it.id to it.firstName }
                val photos = ids.mapNotNull { id -> posts[id] }.map { post ->
                    val m = media[post.mediaId]
                    AlbumPhoto(post, m?.imagePath(Media.Rendition.Thumb), names[post.authorId], m?.videoDurationMs)
                }
                _state.update { s ->
                    val shown = photos.map { it.post.id }.toSet()
                    s.copy(phase = if (photos.isEmpty()) AlbumAddState.Phase.Empty else AlbumAddState.Phase.Ready, photos = photos, picked = s.picked.filter { it in shown })
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Throwable) {
                val offline = e.dataError() == DataError.Network
                _state.update { it.copy(phase = if (offline) AlbumAddState.Phase.OfflineEmpty else AlbumAddState.Phase.Error) }
            }
        }
    }

    /** A tap on a cell: picks or un-picks it. */
    fun toggle(postId: String) = _state.update { s ->
        when {
            postId in s.picked -> s.copy(picked = s.picked - postId)
            s.photos.any { it.post.id == postId } -> s.copy(picked = s.picked + postId)
            else -> s
        }
    }

    /** "Add" → `add_to_album`; a failure keeps the selection ([AlbumAddEffect.Failed]). */
    fun add() {
        val s = _state.value
        if (!s.canAdd) return
        _state.update { it.copy(saving = true) }
        viewModelScope.launch {
            try {
                data.addToAlbum(albumId, s.picked)
                _state.update { it.copy(saving = false, done = true) }
            } catch (e: CancellationException) {
                throw e
            } catch (_: Throwable) {
                _state.update { it.copy(saving = false) }
                _effects.emit(AlbumAddEffect.Failed)
            }
        }
    }

    private companion object {
        /** The first page of the group's weeks (`week.history`'s `group_history_weeks(p_limit: 8)`). */
        const val WEEKS = 8
    }
}

data class AlbumPickerState(
    val saving: Boolean = false,
    /** The photo is in an album now: the sheet closes and the viewer confirms ("Added to Album!"). */
    val done: Boolean = false,
    /** The "New Album" name sheet (week.edit's). */
    val naming: Boolean = false,
    val name: String = "",
    /** `week.edit.error.albumName` under the field. */
    val nameMissing: Boolean = false,
)

/**
 * `photo.viewer.layout.albumPicker` (Add to Album): a tap on one of the group's albums adds the photo (`add_to_album`);
 * "New Album" saves a new album holding it (`save_album`). The album rows come from [AlbumsViewModel].
 */
class AlbumPickerViewModel(private val data: SocialData, private val groupId: String, private val postId: String) : ViewModel() {
    private val _state = MutableStateFlow(AlbumPickerState())
    val state: StateFlow<AlbumPickerState> = _state.asStateFlow()
    private val _effects = MutableSharedFlow<AlbumAddEffect>(extraBufferCapacity = 4, onBufferOverflow = BufferOverflow.DROP_OLDEST)
    val effects: SharedFlow<AlbumAddEffect> = _effects.asSharedFlow()

    fun add(albumId: String) {
        if (_state.value.saving) return
        _state.update { it.copy(saving = true) }
        viewModelScope.launch {
            try {
                data.addToAlbum(albumId, listOf(postId))
                _state.update { it.copy(saving = false, done = true) }
            } catch (e: CancellationException) {
                throw e
            } catch (_: Throwable) {
                _state.update { it.copy(saving = false) }
                _effects.emit(AlbumAddEffect.Failed)
            }
        }
    }

    fun startNaming() = _state.update { it.copy(naming = true, name = "", nameMissing = false) }
    fun cancelNaming() = _state.update { it.copy(naming = false, nameMissing = false) }
    fun setName(name: String) = _state.update { it.copy(name = name, nameMissing = false) }

    /** "Create Album" → `save_album` with this photo. */
    fun create() {
        val s = _state.value
        val name = s.name.trim()
        if (name.isEmpty()) {
            _state.update { it.copy(nameMissing = true) }
            return
        }
        if (s.saving) return
        _state.update { it.copy(saving = true) }
        viewModelScope.launch {
            try {
                data.saveAlbum(groupId, name, listOf(postId))
                _state.update { it.copy(saving = false, naming = false, done = true) }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Throwable) {
                val invalid = e.dataError().let { it is DataError.Api && it.code == ApiError.InvalidName }
                _state.update { it.copy(saving = false, nameMissing = invalid) }
                _effects.emit(AlbumAddEffect.Failed)
            }
        }
    }
}
