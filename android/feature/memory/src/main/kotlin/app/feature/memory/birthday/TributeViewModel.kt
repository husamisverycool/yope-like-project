package app.feature.memory.birthday

import android.content.Context
import android.net.Uri
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.data.model.RenderStatus
import app.designsystem.generated.Tokens
import app.feature.memory.common.EffectQueue
import app.feature.memory.common.Failure
import app.feature.memory.common.MemoryBackend
import app.feature.memory.common.MemoryCache
import app.feature.memory.common.attempt
import app.feature.memory.common.failureOf
import app.feature.memory.share.MemoryFiles
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
import java.time.Clock

/** What the tribute screen's player area shows. */
sealed interface TributeContent {
    data object Loading : TributeContent

    /** `status = 'pending'` (rendering, or re-rendering after a photo was deleted): same as loading. */
    data object Rendering : TributeContent
    data object NotFound : TributeContent
    data object Failed : TributeContent
    data object Offline : TributeContent
    data class Ready(val videoUrl: String, val posterUrl: String?) : TributeContent
}

data class TributeState(
    val content: TributeContent = TributeContent.Loading,
    /** The tribute's group, once loaded ("Report Video" → Next Steps "Leave the group"). */
    val groupId: String? = null,
    val groupName: String? = null,
    /** The honoree's first name (the member's title "{name}'s birthday video"). */
    val honoreeName: String? = null,
    /**
     * The viewer is the honoree ("Your birthday video"). Only the honoree gets Save and Share: the video was made for them
     * and carries other members' photos, which leave the app only through the person they were given to (owner decision
     * 12); contributors watch it in the app.
     */
    val forMe: Boolean = false,
    val saving: Boolean = false,
    val toast: Toast? = null,
    /** Add-only photo access was refused: the native alert with a Settings button. */
    val saveDenied: Boolean = false,
) {
    enum class Toast { Saved, SaveFailed }
}

/** Download / share of the MP4 (Android services behind an interface for tests). */
interface TributeFiles {
    /** Saves the video to the shared Movies collection; false on failure or no access. */
    suspend fun save(url: String, tributeId: String): Boolean

    /** A content:// URI of the downloaded MP4 for the share sheet, or null. */
    suspend fun shareUri(url: String, tributeId: String): Uri?
}

/** [TributeFiles] over [MemoryFiles]: one cached download per tribute. */
class AndroidTributeFiles(context: Context) : TributeFiles {
    private val app = context.applicationContext

    private suspend fun file(url: String, tributeId: String): File? =
        attempt { MemoryFiles.download(url, File(MemoryFiles.dir(app), "tribute-$tributeId.mp4")) }.getOrNull()

    override suspend fun save(url: String, tributeId: String): Boolean {
        val file = file(url, tributeId) ?: return false
        return MemoryFiles.saveVideo(app, file, file.name)
    }

    override suspend fun shareUri(url: String, tributeId: String): Uri? = file(url, tributeId)?.let { MemoryFiles.uriFor(app, it) }
}

/**
 * `birthday.tribute` (design/surfaces/birthday.tribute.md, B). Nobody reads the tribute before `delivered_at` is set
 * and past (RLS, and checked here again); then its honoree and the members who contributed to it (RLS, migration 0034,
 * MERGE FV-3). No writes.
 */
class TributeViewModel(
    private val tributeId: String,
    private val backend: MemoryBackend,
    private val files: TributeFiles,
    private val clock: Clock = Clock.systemUTC(),
    private val cache: MemoryCache = MemoryCache.shared,
) : ViewModel() {
    private val cacheKey = MemoryCache.key(backend, "birthday.tribute", tributeId)
    private val _state = MutableStateFlow(TributeState())
    val state: StateFlow<TributeState> = _state.asStateFlow()
    private val queue = EffectQueue()
    val effects = queue.effects
    private val shares = Channel<Uri>(Channel.BUFFERED)

    /** content:// URIs to hand to the share sheet. */
    val shareRequests: Flow<Uri> = shares.receiveAsFlow()
    private var load: Job? = null

    init {
        // Cached content first: the video as last shown starts preparing at once; the refresh confirms it.
        cache.get<TributeState>(cacheKey)?.let { _state.value = it }
        refresh()
    }

    /** "try again" on the error state. */
    fun retry() {
        _state.update { it.copy(content = TributeContent.Loading) }
        refresh()
    }

    private fun refresh() {
        load?.cancel()
        load = viewModelScope.launch {
            val shown = _state.value.content is TributeContent.Ready
            val content = loadContent()
            // Offline or a transient failure keeps cached content on screen.
            if (shown && (content == TributeContent.Offline || content == TributeContent.Failed)) return@launch
            _state.update { it.copy(content = content) }
            val s = _state.value
            if (s.content is TributeContent.Ready) cache.put(cacheKey, s.copy(saving = false, toast = null, saveDenied = false)) else cache.remove(cacheKey)
        }
    }

    /** On resume: a tribute that was rendering is fetched again. */
    fun refreshIfRendering() {
        if (_state.value.content == TributeContent.Rendering) refresh()
    }

    private suspend fun loadContent(): TributeContent {
        if (!backend.isOnline()) return TributeContent.Offline
        return attempt {
            val tribute = backend.tribute(tributeId) ?: return@attempt TributeContent.NotFound
            val delivered = tribute.deliveredAt?.let { !it.isAfter(clock.instant()) } == true
            // VidDay: "The final video is private right from the start!" — for everyone, until it is given.
            if (!delivered) return@attempt TributeContent.NotFound
            val forMe = tribute.honoreeId == backend.currentUserId
            val honoree = if (forMe) null else backend.profiles(listOf(tribute.honoreeId)).firstOrNull()?.firstName
            _state.update { it.copy(groupId = tribute.groupId, groupName = backend.group(tribute.groupId)?.name, honoreeName = honoree, forMe = forMe) }
            val video = tribute.videoPath
            if (tribute.status != RenderStatus.Ready || video == null) return@attempt TributeContent.Rendering
            val urls = backend.signedUrls(listOfNotNull(video, tribute.posterPath))
            val videoUrl = urls[video] ?: return@attempt TributeContent.NotFound
            TributeContent.Ready(videoUrl, tribute.posterPath?.let(urls::get))
        }.getOrElse { e ->
            when (failureOf(e)) {
                Failure.Offline -> TributeContent.Offline
                Failure.NotFound -> TributeContent.NotFound
                else -> TributeContent.Failed
            }
        }
    }

    /** "Download" (the honoree's): saves the MP4; toast `birthday.tribute.saved` / `.saveFailed`. */
    fun save(accessGranted: Boolean = true) {
        if (!_state.value.forMe) return
        val ready = _state.value.content as? TributeContent.Ready ?: return
        if (_state.value.saving) return
        if (!accessGranted) {
            queue.haptic(Tokens.Haptics.globalError)
            _state.update { it.copy(saveDenied = true) }
            return
        }
        _state.update { it.copy(saving = true, toast = null) }
        viewModelScope.launch { saveFinished(files.save(ready.videoUrl, tributeId)) }
    }

    private fun saveFinished(ok: Boolean) {
        queue.haptic(if (ok) Tokens.Haptics.globalSuccess else Tokens.Haptics.globalError)
        _state.update { it.copy(saving = false, toast = if (ok) TributeState.Toast.Saved else TributeState.Toast.SaveFailed) }
    }

    /** "Share" (the honoree's): the system share sheet with the MP4 file. */
    fun share() {
        if (!_state.value.forMe) return
        val ready = _state.value.content as? TributeContent.Ready ?: return
        viewModelScope.launch {
            val uri = files.shareUri(ready.videoUrl, tributeId)
            // No copy exists for a failed share; the error haptic is the only feedback.
            if (uri != null) shares.trySend(uri) else queue.haptic(Tokens.Haptics.globalError)
        }
    }

    fun dismissToast() = _state.update { it.copy(toast = null) }

    fun dismissSaveDenied() = _state.update { it.copy(saveDenied = false) }
}
