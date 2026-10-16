package app.feature.capture.collage

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.data.error.DataError
import app.data.error.DataException
import app.data.model.Collage
import app.data.model.RenderStatus
import app.feature.capture.data.CaptureData
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.io.File
import java.time.Instant
import java.time.LocalDate

/**
 * `collage.view` (+ `collage.share`): the same-moment collage of one daily invitation, as the
 * worker composed it (option B pages). Cached pages first; the network replaces them.
 */
class CollageViewModel(
    private val data: CaptureData,
    val groupId: String,
    val invitationId: String,
    private val cacheDir: File,
    private val now: () -> Instant = Instant::now,
    /** While the worker composes (or the window is still open), how often to look again. */
    private val pollMillis: Long = POLL_MILLIS,
) : ViewModel() {

    sealed interface Content {
        data object Loading : Content
        /** Window closed and nobody answered: no collage row. */
        data object Empty : Content
        data object Error : Content
        data object Offline : Content
        /** [pages]: local files in order (null = not downloaded yet); [shareable]: `share_path` is set. */
        data class Ready(val pages: List<File?>, val shareable: Boolean) : Content
    }

    data class UiState(
        val content: Content = Content.Loading,
        val date: LocalDate? = null,
        val groupName: String? = null,
        val page: Int = 0,
        val sharing: Boolean = false,
        /** The collage's first photo (display rendition), downloaded: the blurred backdrop (L-7); null until it is here. */
        val backdrop: File? = null,
    )

    sealed interface Event {
        data class Share(val file: File) : Event
        /** No sheet opens: a toast with `camera.sendto.error.offline` / `.generic`; the next tap retries. */
        data class ShareFailed(val offline: Boolean) : Event
    }

    private val state = MutableStateFlow(UiState())
    val ui: StateFlow<UiState> = state.asStateFlow()
    private val events = Channel<Event>(Channel.BUFFERED)
    val event: Flow<Event> = events.receiveAsFlow()

    private var collage: Collage? = null
    private var loadJob: Job? = null

    init {
        cachedPages()?.let { pages -> state.update { it.copy(content = Content.Ready(pages, shareable = false)) } }
        backdropFile().takeIf { it.isFile }?.let { file -> state.update { it.copy(backdrop = file) } }
        viewModelScope.launch {
            val name = runCatching { data.group(groupId)?.name }.getOrNull()
            state.update { it.copy(groupName = name) }
        }
        load()
    }

    fun onPage(page: Int) = state.update { it.copy(page = page) }

    /** Loads (and the error states' "try again"). */
    fun load() {
        loadJob?.cancel()
        loadJob = viewModelScope.launch {
            while (true) {
                val again = try {
                    loadOnce()
                } catch (e: CancellationException) {
                    throw e
                } catch (e: Exception) {
                    val error = (e as? DataException)?.error
                    val cached = state.value.content as? Content.Ready
                    if (cached == null) state.update { it.copy(content = if (error == DataError.Network) Content.Offline else Content.Error) }
                    false
                }
                if (!again) break
                delay(pollMillis)
            }
        }
    }

    /** Returns whether to look again later (the collage is being composed). */
    private suspend fun loadOnce(): Boolean {
        val invitation = data.invitation(invitationId)
        if (invitation != null) state.update { it.copy(date = invitation.localDate) }
        val c = data.collageForInvitation(invitationId)
        collage = c
        val cached = state.value.content as? Content.Ready
        when {
            c == null -> {
                val open = invitation != null && !now().isAfter(invitation.closesAt)
                if (cached == null) state.update { it.copy(content = if (open) Content.Loading else Content.Empty) }
                return open
            }
            c.status == RenderStatus.Failed -> {
                if (cached == null) state.update { it.copy(content = Content.Error) }
                return false
            }
            c.status == RenderStatus.Pending || c.imagePath == null -> {
                // Recomposing: the previous pages stay until the new paths arrive.
                if (cached == null) state.update { it.copy(content = Content.Loading) }
                return true
            }
        }
        val ready = c
        val paths = ready.pagePaths()
        val urls = data.signedUrls(paths)
        val files = paths.map { pageFile(it) }
        // Page 1 first, so the screen shows it as soon as it is here.
        files.forEachIndexed { index, file ->
            if (!file.isFile) urls[paths[index]]?.let { data.download(it, file) }
            if (index == 0 || files[index].isFile) {
                state.update { it.copy(content = Content.Ready(files.map { f -> f.takeIf { it.isFile } }, shareable = ready.sharePath != null)) }
            }
        }
        rememberPages(files)
        loadBackdrop(ready)
        return false
    }

    /** The first photo for the backdrop (page 1's image stands in until it is here); failures keep page 1. */
    private suspend fun loadBackdrop(collage: Collage) {
        if (state.value.backdrop != null) return
        try {
            val path = data.collageFirstPhotoPath(collage) ?: return
            val url = data.signedUrls(listOf(path))[path] ?: return
            val file = backdropFile()
            data.download(url, file)
            state.update { it.copy(backdrop = file) }
        } catch (e: CancellationException) {
            throw e
        } catch (_: Exception) {
            // Decorative: page 1 stays behind the card.
        }
    }

    private fun backdropFile(): File = File(File(cacheDir, PAGES_DIR), "inv-$invitationId-first.jpg")

    /** "share": downloads the current page's 9:16 share image (`share-<n>.jpg`) and hands it to the Sharesheet. */
    fun share() {
        val c = collage ?: return
        val sharePath = c.sharePath ?: return
        if (state.value.sharing) return
        val n = state.value.page + 1
        val folder = sharePath.substringBeforeLast('/', missingDelimiterValue = "")
        val path = if (folder.isEmpty()) "share-$n.jpg" else "$folder/share-$n.jpg"
        state.update { it.copy(sharing = true) }
        viewModelScope.launch {
            try {
                val url = data.signedUrls(listOf(path))[path] ?: throw DataException(DataError.FileUnavailable)
                val file = File(File(cacheDir, SHARE_DIR), "share-$n.jpg")
                data.download(url, file)
                events.send(Event.Share(file))
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                // No sheet opens; the pill stays and the next tap retries (collage.share → States).
                events.send(Event.ShareFailed(offline = (e as? DataException)?.error == DataError.Network))
            } finally {
                state.update { it.copy(sharing = false) }
            }
        }
    }

    private fun pageFile(path: String): File = File(File(cacheDir, PAGES_DIR), path.replace('/', '_'))

    private fun manifest(): File = File(File(cacheDir, PAGES_DIR), "inv-$invitationId.txt")

    private fun rememberPages(files: List<File>) {
        runCatching { manifest().apply { parentFile?.mkdirs() }.writeText(files.joinToString("\n") { it.name }) }
    }

    private fun cachedPages(): List<File?>? {
        val names = runCatching { manifest().takeIf { it.isFile }?.readLines() }.getOrNull()?.filter { it.isNotBlank() } ?: return null
        val files = names.map { File(File(cacheDir, PAGES_DIR), it) }
        return files.takeIf { it.isNotEmpty() && it.first().isFile }?.map { f -> f.takeIf { it.isFile } }
    }

    companion object {
        /** Transport: how often a composing collage is looked up again (not a design value). */
        const val POLL_MILLIS = 5_000L
        const val PAGES_DIR = "collage-pages"
        const val SHARE_DIR = "collage-share"
    }
}
