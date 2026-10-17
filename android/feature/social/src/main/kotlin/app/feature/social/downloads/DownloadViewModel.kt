package app.feature.social.downloads

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.data.error.ApiError
import app.data.error.DataError
import app.data.error.DataException
import app.data.error.StorageFailure
import app.data.media.StoragePaths
import app.data.model.DownloadItem
import app.data.model.DownloadScope
import app.data.model.MediaKind
import app.data.repo.PostRepository
import app.feature.social.data.GallerySaver
import app.feature.social.data.SocialData
import app.feature.social.data.dataError
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.channels.BufferOverflow
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import java.time.Instant

/** Where a download stopped: the last photo saved (kept on the device per account and scope). */
data class DownloadCursor(val postedAt: Instant, val postId: String)

/** Keeps each scope's [DownloadCursor] (Continue goes on from it when the page opens again). */
interface DownloadCursors {
    fun get(key: String): DownloadCursor?
    fun put(key: String, cursor: DownloadCursor?)
}

/** [DownloadCursors] in the app's private preferences. */
class PrefsDownloadCursors(context: Context) : DownloadCursors {
    private val prefs = context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    override fun get(key: String): DownloadCursor? {
        val at = prefs.getString("$key.at", null) ?: return null
        val post = prefs.getString("$key.post", null) ?: return null
        return runCatching { DownloadCursor(Instant.parse(at), post) }.getOrNull()
    }

    override fun put(key: String, cursor: DownloadCursor?) {
        val edit = prefs.edit()
        if (cursor == null) edit.remove("$key.at").remove("$key.post") else edit.putString("$key.at", cursor.postedAt.toString()).putString("$key.post", cursor.postId)
        edit.apply()
    }

    private companion object {
        const val PREFS = "social.downloads"
    }
}

/** Saves one original into the photo library; false when it could not be written. */
fun interface DownloadSaver {
    suspend fun save(item: DownloadItem): Boolean
}

/**
 * [DownloadSaver] over the gallery saver of Save to Camera Roll (MediaStore; API 26–28 need WRITE_EXTERNAL_STORAGE, asked
 * by the screen first): the original's bytes, a video as a video. A Live Photo saves its still (Android has no Live Photo,
 * PLATFORM_CONSTRAINTS §Summary, as the viewer's Save does).
 */
class GalleryDownloadSaver(private val context: Context, private val data: SocialData, private val gallery: GallerySaver) : DownloadSaver {
    override suspend fun save(item: DownloadItem): Boolean {
        val bytes = data.download(item.originalPath)
        val ext = item.originalPath.substringAfterLast('.', "").lowercase()
        val fallback = if (item.kind == MediaKind.Video) "video/mp4" else "image/jpeg"
        val mime = runCatching { StoragePaths.contentTypeFor(ext) }.getOrDefault(fallback)
        return gallery.save(context, bytes, mime, ext.ifEmpty { if (item.kind == MediaKind.Video) "mp4" else "jpg" })
    }
}

/** The page's state. Never a number of photos (tenet 2). */
data class DownloadUiState(
    val phase: Phase = Phase.Idle,
    /** An earlier download stopped before the end: the capsule reads Continue. */
    val canResume: Boolean = false,
    /** An album's share saved so far (0…1, a bar without figures); null for your photos (indeterminate). */
    val fraction: Float? = null,
    /** Photo library access was refused (API 26–28): the platform alert with the Settings button. */
    val denied: Boolean = false,
) {
    enum class Phase { Idle, Running, Done, Empty, Failed, Offline }

    val running: Boolean get() = phase == Phase.Running
}

sealed interface DownloadEffect {
    /** Every photo was saved: `haptic.global.success` and the "Saved!" toast. */
    data object Done : DownloadEffect
    /** A failure or a refusal: `haptic.global.error`. */
    data object Failed : DownloadEffect
    /** The album needs premium (`premium_required`): the paywall at the full-quality downloads perk. */
    data object Paywall : DownloadEffect
}

/**
 * `settings.downloads` (owner decisions 29 and 34, research #2: Retro "Download your package", Yope "download all photos"):
 * pages `download_items` and saves each original through [saver], as Save to Camera Roll does (owner decision 28). Your
 * photos: newest first, page by page; an album: all of it in album order. Cancellable; Continue goes on from the last photo
 * saved, also after the page was closed ([cursors]).
 */
class DownloadViewModel(
    private val data: SocialData,
    private val scope: DownloadScope,
    private val saver: DownloadSaver,
    private val cursors: DownloadCursors,
) : ViewModel() {
    private val key = cursorKey(data.currentUserId(), scope)
    private val _state = MutableStateFlow(DownloadUiState(canResume = cursors.get(key) != null))
    val state: StateFlow<DownloadUiState> = _state.asStateFlow()
    private val _effects = MutableSharedFlow<DownloadEffect>(extraBufferCapacity = 8, onBufferOverflow = BufferOverflow.DROP_OLDEST)
    val effects: SharedFlow<DownloadEffect> = _effects.asSharedFlow()
    private var job: Job? = null

    /** Download / Continue. */
    fun start() {
        if (_state.value.running) return
        _state.update { it.copy(phase = DownloadUiState.Phase.Running, fraction = if (scope is DownloadScope.InAlbum) (it.fraction ?: 0f) else null) }
        job = viewModelScope.launch { run() }
    }

    /** Cancel: stops after the photo being saved; Continue goes on from there. */
    fun cancel() {
        job?.cancel()
    }

    /** The screen's permission request was refused (API 26–28). */
    fun accessDenied() {
        _state.update { it.copy(denied = true) }
        _effects.tryEmit(DownloadEffect.Failed)
    }

    fun dismissDenied() = _state.update { it.copy(denied = false) }

    private suspend fun run() {
        val start = cursors.get(key)
        var savedAny = start != null
        try {
            when (scope) {
                DownloadScope.Mine -> {
                    var before = start?.postedAt
                    while (true) {
                        val page = data.downloadItems(scope, before)
                        for (item in page) {
                            currentCoroutineContext().ensureActive()
                            save(item)
                            savedAny = true
                        }
                        if (page.size < PostRepository.DOWNLOAD_PAGE) break
                        before = page.last().postedAt
                    }
                }
                is DownloadScope.InAlbum -> {
                    val items = data.downloadItems(scope, null)
                    val first = start?.let { c -> items.indexOfFirst { it.postId == c.postId }.takeIf { it >= 0 }?.plus(1) } ?: 0
                    if (items.isNotEmpty()) _state.update { it.copy(fraction = first.toFloat() / items.size) }
                    for (index in first until items.size) {
                        currentCoroutineContext().ensureActive()
                        save(items[index])
                        savedAny = true
                        _state.update { it.copy(fraction = (index + 1).toFloat() / items.size) }
                    }
                }
            }
            cursors.put(key, null)
            _state.update { it.copy(phase = if (savedAny) DownloadUiState.Phase.Done else DownloadUiState.Phase.Empty, canResume = false) }
            if (savedAny) _effects.emit(DownloadEffect.Done)
        } catch (e: CancellationException) {
            _state.update { it.copy(phase = DownloadUiState.Phase.Idle, canResume = cursors.get(key) != null) }
            throw e
        } catch (e: Throwable) {
            // Cancelled while a read or a save was running (it may surface as a network error): stopped, not failed.
            if (!currentCoroutineContext().isActive) {
                _state.update { it.copy(phase = DownloadUiState.Phase.Idle, canResume = cursors.get(key) != null) }
                return
            }
            val error = e.dataError()
            if (error is DataError.Api && error.code == ApiError.PremiumRequired) {
                _state.update { it.copy(phase = DownloadUiState.Phase.Idle, canResume = cursors.get(key) != null) }
                _effects.emit(DownloadEffect.Paywall)
                return
            }
            val phase = if (error == DataError.Network) DownloadUiState.Phase.Offline else DownloadUiState.Phase.Failed
            _state.update { it.copy(phase = phase, canResume = cursors.get(key) != null) }
            _effects.emit(DownloadEffect.Failed)
        }
    }

    /** One original into the library, then its place is kept; a photo deleted meanwhile is skipped. */
    private suspend fun save(item: DownloadItem) {
        val ok = try {
            saver.save(item)
        } catch (e: DataException) {
            val error = e.error
            if (error is DataError.Storage && error.kind == StorageFailure.NotFound) true else throw e
        }
        if (!ok) throw DataException(DataError.FileUnavailable)
        cursors.put(key, DownloadCursor(item.postedAt, item.postId))
    }

    companion object {
        fun cursorKey(userId: String?, scope: DownloadScope): String = when (scope) {
            DownloadScope.Mine -> "${userId.orEmpty()}.mine"
            is DownloadScope.InAlbum -> "${userId.orEmpty()}.album.${scope.albumId}"
        }
    }
}
