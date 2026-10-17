package app.feature.memory.onthisday

import android.net.Uri
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.data.model.HistoryWeek
import app.data.model.Media
import app.data.model.Post
import app.designsystem.generated.Tokens
import app.feature.memory.common.EffectQueue
import app.feature.memory.common.Failure
import app.feature.memory.common.MemoryBackend
import app.feature.memory.common.MemoryCache
import app.feature.memory.common.attempt
import app.feature.memory.common.failureOf
import app.feature.memory.share.PhotoFiles
import kotlinx.coroutines.Job
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.Clock
import java.time.LocalDate
import java.time.ZoneId
import kotlin.random.Random

/** One memory: one post (design/surfaces/onthisday.md, "Memory order"). */
data class Memory(
    val postId: String,
    val authorId: String,
    /** The poster's first name (subtitle, photo label). */
    val authorName: String,
    /** Display rendition (the original until renditions are ready). */
    val displayUrl: String?,
    /** Storage path of the original (save / share sign it on demand). */
    val originalPath: String,
    /** The day it was posted, in the group's time zone (the date title). */
    val date: LocalDate,
)

/** Which memories the dial steps through. */
enum class MemoryMode {
    /** Today's month and day in earlier years (`on_this_day`), newest first. */
    Day,

    /** Random picks from the group's whole history (the dice): previous goes back through the picks shown. */
    Shuffle,
}

sealed interface OnThisDayState {
    data object Loading : OnThisDayState

    /** Error or offline (same block, different copy). */
    data class Failed(val offline: Boolean) : OnThisDayState

    /** Every memory was deleted while the page was open. */
    data object Empty : OnThisDayState

    /** Nothing for today when the page opened (the entry is hidden then): the page closes. */
    data object Finished : OnThisDayState

    /** The Rewind page: [memories] in dial order, [index] = the current memory (slot `index mod 44`). */
    data class Page(
        val memories: List<Memory>,
        val index: Int,
        val groupName: String,
        val mode: MemoryMode = MemoryMode.Day,
        val playing: Boolean = false,
        /** A random pick is loading (the dice or a step past the last pick). */
        val picking: Boolean = false,
    ) : OnThisDayState {
        val memory: Memory get() = memories[index]
        val isFirst: Boolean get() = index == 0

        /** In shuffle mode there is always a next pick. */
        val isLast: Boolean get() = mode == MemoryMode.Day && index == memories.lastIndex
    }
}

/** A one-shot request to the screen. */
sealed interface OnThisDayEvent {
    /** Toast (C-26). */
    data class Toast(val kind: Kind) : OnThisDayEvent {
        enum class Kind { Saved, SaveFailed, Deleted }
    }

    /** The share sheet with the memory's original. */
    data class Share(val uri: Uri) : OnThisDayEvent

    /** Add-only photo access was refused: the native alert with a Settings button. */
    data object SaveDenied : OnThisDayEvent
}

/**
 * `onthisday` — Retro's Rewind for one group (design/surfaces/onthisday.md). Reads `on_this_day` for the date of
 * (now in the group time zone − `layout.onthisday.dayBoundary`); one post = one memory, API order (newest first) =
 * dial order. The dice switches to random memories from `group_history_weeks` (respects `free_history_days`).
 * Writes: `delete_post` (own memory); save and share are files. `post_deleted` drops a memory.
 */
class OnThisDayViewModel(
    private val groupId: String,
    private val backend: MemoryBackend,
    private val files: PhotoFiles,
    private val clock: Clock = Clock.systemUTC(),
    private val cache: MemoryCache = MemoryCache.shared,
    private val random: Random = Random.Default,
) : ViewModel() {
    /** The day as last shown, with the date it belongs to. */
    private data class Cached(val date: LocalDate, val zone: ZoneId, val page: OnThisDayState.Page)

    private val cacheKey = MemoryCache.key(backend, "onthisday", groupId)
    private val _state = MutableStateFlow<OnThisDayState>(OnThisDayState.Loading)
    val state: StateFlow<OnThisDayState> = _state.asStateFlow()
    private val queue = EffectQueue()
    val effects = queue.effects
    private val events = Channel<OnThisDayEvent>(Channel.BUFFERED)
    val requests: Flow<OnThisDayEvent> = events.receiveAsFlow()
    private var load: Job? = null
    private var zone: ZoneId = ZoneId.of("UTC")

    /** The group's history weeks (shuffle source), read once per session. */
    private var weeks: List<HistoryWeek>? = null

    /** The memories of today, kept while shuffling. */
    private var day: List<Memory> = emptyList()

    init {
        // Cached content first: today's page as last shown paints at once; the refresh replaces it.
        cache.get<Cached>(cacheKey)?.takeIf { it.date == localDate(clock, it.zone) }?.let {
            zone = it.zone
            day = it.page.memories
            _state.value = it.page.copy(index = 0, playing = false, mode = MemoryMode.Day, picking = false)
        }
        refresh()
        viewModelScope.launch { backend.postDeletions(groupId).collect(::onPostDeleted) }
    }

    /** "Try Again" on the error / offline block. */
    fun retry() {
        _state.value = OnThisDayState.Loading
        refresh()
    }

    private fun refresh() {
        load?.cancel()
        load = viewModelScope.launch {
            val shown = _state.value as? OnThisDayState.Page
            if (!backend.isOnline()) {
                // Offline: cached content stays; without it, the offline block.
                if (shown == null) _state.value = OnThisDayState.Failed(offline = true)
                return@launch
            }
            attempt { loadDay() }
                .onSuccess { loaded ->
                    if (loaded == null) {
                        cache.remove(cacheKey)
                        if (shown == null || shown.mode == MemoryMode.Day) _state.value = OnThisDayState.Finished
                        return@onSuccess
                    }
                    day = loaded.memories
                    _state.update { current ->
                        when {
                            current !is OnThisDayState.Page -> loaded
                            // Shuffling keeps its picks; the day behind it is refreshed.
                            current.mode == MemoryMode.Shuffle -> current
                            // Keep the viewer on the same memory.
                            else -> loaded.copy(index = loaded.memories.indexOfFirst { it.postId == current.memory.postId }.takeIf { it >= 0 } ?: 0, playing = current.playing)
                        }
                    }
                    cache.put(cacheKey, Cached(localDate(clock, zone), zone, loaded))
                }
                .onFailure { e -> if (shown == null) _state.value = OnThisDayState.Failed(offline = failureOf(e) == Failure.Offline) }
        }
    }

    private suspend fun loadDay(): OnThisDayState.Page? {
        val group = backend.group(groupId) ?: return null
        zone = runCatching { ZoneId.of(group.timeZone) }.getOrDefault(ZoneId.of("UTC"))
        val items = backend.onThisDay(groupId, localDate(clock, zone))
        if (items.isEmpty()) return null
        val media = backend.media(items.map { it.mediaId }).associateBy { it.id }
        val names = backend.profiles(items.map { it.authorId }.distinct()).associate { it.id to it.firstName.orEmpty() }
        val urls = backend.signedUrls(media.values.map { it.imagePath(Media.Rendition.Display) }.toSet())
        val memories = items.mapNotNull { row ->
            val m = media[row.mediaId] ?: return@mapNotNull null
            Memory(row.postId, row.authorId, names[row.authorId].orEmpty(), urls[m.imagePath(Media.Rendition.Display)], m.originalPath, row.createdAt.atZone(zone).toLocalDate())
        }
        return if (memories.isEmpty()) null else OnThisDayState.Page(memories, 0, group.name)
    }

    // ---- the dial ----------------------------------------------------------------------------------

    /**
     * One slot crossed on the dial: [delta] +1 = next (clockwise, older), −1 = previous. Stops at the first and last
     * memory (no wrap); in shuffle mode a step past the last pick picks a new random memory.
     */
    fun step(delta: Int) {
        val page = _state.value as? OnThisDayState.Page ?: return
        val target = page.index + delta
        when {
            target < 0 -> Unit
            target <= page.memories.lastIndex -> _state.value = page.copy(index = target)
            page.mode == MemoryMode.Shuffle -> pickRandom(append = true)
            else -> Unit
        }
    }

    /** Play / pause (the dial centre). Playing from the last memory starts again at the first. */
    fun togglePlay() = _state.update { s ->
        if (s !is OnThisDayState.Page) s
        else if (!s.playing && s.isLast) s.copy(playing = true, index = 0)
        else s.copy(playing = !s.playing)
    }

    /** Automatic step while playing (`duration.onthisday.playHold`): next memory; stops after the last one. */
    fun advance() {
        val page = _state.value as? OnThisDayState.Page ?: return
        if (!page.playing) return
        if (page.isLast) _state.value = page.copy(playing = false) else step(+1)
    }

    /** The dice: a random memory from the group's whole history; the subtitle switches to "Memories · {name}". */
    fun shuffle() = pickRandom(append = false)

    /**
     * Mode menu "On this day…" (Retro's Rewind mode menu): back from shuffle to the day's memories, at the newest one.
     * In day mode it changes nothing. No haptic of its own (the menu plays the tap).
     */
    fun showDay() {
        val page = _state.value as? OnThisDayState.Page ?: return
        if (page.mode != MemoryMode.Shuffle || day.isEmpty()) return
        _state.value = page.copy(memories = day, index = 0, mode = MemoryMode.Day, playing = false, picking = false)
    }

    private fun pickRandom(append: Boolean) {
        val page = _state.value as? OnThisDayState.Page ?: return
        if (page.picking) return
        if (!backend.isOnline()) {
            queue.haptic(Tokens.Haptics.globalError)
            return
        }
        _state.value = page.copy(picking = true)
        viewModelScope.launch {
            val picked = attempt { randomMemory(exclude = page.memories.map { it.postId }.toSet()) }.getOrNull()
            _state.update { s ->
                if (s !is OnThisDayState.Page) return@update s
                if (picked == null) {
                    queue.haptic(Tokens.Haptics.globalError)
                    return@update s.copy(picking = false, playing = false)
                }
                if (append && s.mode == MemoryMode.Shuffle) {
                    s.copy(memories = s.memories + picked, index = s.memories.size, picking = false)
                } else {
                    s.copy(memories = listOf(picked), index = 0, mode = MemoryMode.Shuffle, picking = false)
                }
            }
        }
    }

    /** A random week of the history, then a random post of it (never one already shown when others exist). */
    private suspend fun randomMemory(exclude: Set<String>): Memory? {
        val all = weeks ?: historyWeeks().also { weeks = it }
        val ids = all.flatMap { it.postIds }
        if (ids.isEmpty()) return null
        val fresh = all.map { w -> w.copy(postIds = w.postIds.filterNot(exclude::contains)) }.filter { it.postIds.isNotEmpty() }
        val week = (fresh.ifEmpty { all }).let { it[random.nextInt(it.size)] }
        val postId = week.postIds[random.nextInt(week.postIds.size)]
        val post: Post = backend.posts(listOf(postId)).firstOrNull() ?: return null
        val m = backend.media(listOf(post.mediaId)).firstOrNull() ?: return null
        val name = backend.profiles(listOf(post.authorId)).firstOrNull()?.firstName.orEmpty()
        val path = m.imagePath(Media.Rendition.Display)
        return Memory(post.id, post.authorId, name, backend.signedUrls(listOf(path))[path], m.originalPath, post.createdAt.atZone(zone).toLocalDate())
    }

    /** `group_history_weeks` paged by [SHUFFLE_PAGE] until a page comes back short. */
    private suspend fun historyWeeks(): List<HistoryWeek> {
        val out = mutableListOf<HistoryWeek>()
        var before: LocalDate? = null
        while (true) {
            val page = backend.historyWeeks(groupId, before, SHUFFLE_PAGE)
            out += page
            if (page.size < SHUFFLE_PAGE) break
            before = page.last().weekStart
        }
        return out
    }

    // ---- menu and share ------------------------------------------------------------------------------

    /**
     * Whether the current memory is yours (menu: Delete Post; the share circle) or someone else's (Report Post): sharing
     * out of the app is for your own photos (owner decision 12). Save to Camera Roll is on every memory (decision 28).
     */
    fun isMine(memory: Memory): Boolean = memory.authorId == backend.currentUserId

    /** "Save to Camera Roll" (any memory you can see, owner decision 28): the original into the photo library; toast saved / failed. */
    fun save(accessGranted: Boolean = true) {
        val memory = (_state.value as? OnThisDayState.Page)?.memory ?: return
        if (!accessGranted) {
            queue.haptic(Tokens.Haptics.globalError)
            events.trySend(OnThisDayEvent.SaveDenied)
            return
        }
        viewModelScope.launch {
            val url = attempt { backend.signedUrls(listOf(memory.originalPath))[memory.originalPath] }.getOrNull()
            val ok = url != null && files.save(url, memory.postId)
            queue.haptic(if (ok) Tokens.Haptics.globalSuccess else Tokens.Haptics.globalError)
            events.trySend(OnThisDayEvent.Toast(if (ok) OnThisDayEvent.Toast.Kind.Saved else OnThisDayEvent.Toast.Kind.SaveFailed))
        }
    }

    /** Share (your own memory only): the original to the system share sheet. */
    fun share() {
        val memory = (_state.value as? OnThisDayState.Page)?.memory?.takeIf(::isMine) ?: return
        viewModelScope.launch {
            val url = attempt { backend.signedUrls(listOf(memory.originalPath))[memory.originalPath] }.getOrNull()
            val uri = url?.let { files.shareUri(it, memory.postId) }
            if (uri != null) events.trySend(OnThisDayEvent.Share(uri)) else queue.haptic(Tokens.Haptics.globalError)
        }
    }

    /** "Yes, delete": `delete_post` on your memory; it leaves the dial; toast "Deleted". */
    fun delete() {
        val memory = (_state.value as? OnThisDayState.Page)?.memory ?: return
        if (!isMine(memory)) return
        queue.haptic(Tokens.Haptics.globalWarning)
        viewModelScope.launch {
            attempt { backend.deletePost(memory.postId) }
                .onSuccess {
                    onPostDeleted(memory.postId)
                    events.trySend(OnThisDayEvent.Toast(OnThisDayEvent.Toast.Kind.Deleted))
                }
                .onFailure { queue.haptic(Tokens.Haptics.globalError) }
        }
    }

    /** `post_deleted`: drop that memory; if it was shown, show the next (or previous) one. */
    fun onPostDeleted(postId: String) {
        day = day.filterNot { it.postId == postId }
        _state.update { s ->
            if (s !is OnThisDayState.Page) return@update s
            val at = s.memories.indexOfFirst { it.postId == postId }
            if (at < 0) return@update s
            val memories = s.memories.filterNot { it.postId == postId }
            when {
                memories.isEmpty() && s.mode == MemoryMode.Shuffle && day.isNotEmpty() -> s.copy(memories = day, index = 0, mode = MemoryMode.Day, playing = false)
                memories.isEmpty() -> OnThisDayState.Empty
                at < s.index -> s.copy(memories = memories, index = s.index - 1)
                else -> s.copy(memories = memories, index = s.index.coerceAtMost(memories.lastIndex))
            }
        }
        val page = _state.value as? OnThisDayState.Page
        if (page != null && page.mode == MemoryMode.Day) cache.put(cacheKey, Cached(localDate(clock, zone), zone, page)) else if (_state.value == OnThisDayState.Empty) cache.remove(cacheKey)
    }

    companion object {
        /** `group_history_weeks` page size for the dice (onthisday.md → Data: `p_limit: 52`, a year of weeks). */
        const val SHUFFLE_PAGE = 52

        /** The date `on_this_day` is asked for (`layout.onthisday.dayBoundary`). */
        fun localDate(clock: Clock, zone: ZoneId): LocalDate =
            clock.instant().atZone(zone).minusHours(Tokens.Layouts.OnthisdayDayBoundary.hour.toLong()).toLocalDate()
    }
}
