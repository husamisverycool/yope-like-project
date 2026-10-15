package app.feature.memory.onthisday

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.feature.memory.common.aspectRatio
import app.data.model.Media
import app.data.model.OnThisDayItem
import app.designsystem.generated.Tokens
import app.feature.memory.common.Failure
import app.feature.memory.common.MemoryBackend
import app.feature.memory.common.MemoryCache
import app.feature.memory.common.attempt
import app.feature.memory.common.failureOf
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.Clock
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

/** One photo of a memory year (design/surfaces/onthisday.md, B.2). */
data class MemoryPhoto(
    val postId: String,
    /** Display rendition (single photo) — original until renditions are ready. */
    val displayUrl: String?,
    /** Thumb rendition (grid cell). */
    val thumbUrl: String?,
    /** width / height of the original; the grid keeps each photo's own aspect ratio. */
    val aspectRatio: Float,
    /** Poster's first name. */
    val authorName: String,
    val avatarUrl: String?,
    val createdAt: Instant,
)

/** All photos of one earlier year, API order (newest first). */
data class MemoryYear(val yearsAgo: Int, val photos: List<MemoryPhoto>)

sealed interface OnThisDayState {
    data object Loading : OnThisDayState

    /** Error or offline (same layout, different copy). */
    data class Failed(val offline: Boolean) : OnThisDayState

    /** The day: one screen per year, [index] 0 = newest year (1 year ago first). */
    data class Day(val years: List<MemoryYear>, val index: Int, val zone: ZoneId) : OnThisDayState {
        val year: MemoryYear get() = years[index]
        val isNewest: Boolean get() = index == 0
        val isOldest: Boolean get() = index == years.lastIndex

        /** `layout.onthisday.progress` fill: (index + 1) / years. */
        val progress: Float get() = (index + 1).toFloat() / years.size
    }

    /** The day is over (closed from the oldest year, or every photo was deleted): close the screen. */
    data object Finished : OnThisDayState
}

/**
 * `onthisday` (design/surfaces/onthisday.md). Reads `on_this_day` for the date of (now in the group
 * time zone − `layout.onthisday.dayBoundary` hours), groups rows by `years_ago` ascending and keeps
 * API order inside a year. No writes. `post_deleted` drops photos, years, then the day.
 */
class OnThisDayViewModel(
    private val groupId: String,
    private val backend: MemoryBackend,
    private val clock: Clock = Clock.systemUTC(),
    private val cache: MemoryCache = MemoryCache.shared,
) : ViewModel() {
    /** The day as last shown, with the date it belongs to. */
    private data class Cached(val date: LocalDate, val day: OnThisDayState.Day)

    private val cacheKey = MemoryCache.key(backend, "onthisday", groupId)
    private val _state = MutableStateFlow<OnThisDayState>(OnThisDayState.Loading)
    val state: StateFlow<OnThisDayState> = _state.asStateFlow()
    private var load: Job? = null

    init {
        // Cached content first: today's day as last shown paints at once; the refresh replaces it.
        cache.get<Cached>(cacheKey)?.takeIf { it.date == localDate(clock, it.day.zone) }?.let { _state.value = it.day.copy(index = 0) }
        refresh()
        viewModelScope.launch {
            backend.postDeletions(groupId).collect(::onPostDeleted)
        }
    }

    /** "try again" on the error / offline state. */
    fun retry() {
        _state.value = OnThisDayState.Loading
        refresh()
    }

    private fun refresh() {
        load?.cancel()
        load = viewModelScope.launch {
            val shown = _state.value as? OnThisDayState.Day
            if (!backend.isOnline()) {
                // Offline: cached content stays; without it, the offline state.
                if (shown == null) _state.value = OnThisDayState.Failed(offline = true)
                return@launch
            }
            attempt { loadDay(backend, groupId, clock) }
                .onSuccess { day ->
                    _state.update { current ->
                        when {
                            day == null -> OnThisDayState.Finished
                            // Same years as on screen: keep the viewer's position.
                            current is OnThisDayState.Day && current.years.map { it.yearsAgo } == day.years.map { it.yearsAgo } -> day.copy(index = current.index)
                            else -> day
                        }
                    }
                    remember()
                }
                .onFailure { e -> if (shown == null) _state.value = OnThisDayState.Failed(offline = failureOf(e) == Failure.Offline) }
        }
    }

    private fun remember() {
        val day = _state.value as? OnThisDayState.Day
        if (day == null) cache.remove(cacheKey) else cache.put(cacheKey, Cached(localDate(clock, day.zone), day))
    }

    /** Right half: the next (older) year; on the oldest year it closes the day. */
    fun next() = _state.update { s ->
        if (s !is OnThisDayState.Day) s else if (s.isOldest) OnThisDayState.Finished else s.copy(index = s.index + 1)
    }

    /** Left half: the previous (newer) year; nothing on the newest year. */
    fun previous() = _state.update { s ->
        if (s !is OnThisDayState.Day || s.isNewest) s else s.copy(index = s.index - 1)
    }

    /** `post_deleted`: drop the photo, the year when it was its last photo, the day when none remain. */
    fun onPostDeleted(postId: String) {
        _state.update { s ->
            if (s !is OnThisDayState.Day) return@update s
            val current = s.year.yearsAgo
            val years = s.years.map { y -> y.copy(photos = y.photos.filterNot { it.postId == postId }) }.filter { it.photos.isNotEmpty() }
            if (years.isEmpty()) return@update OnThisDayState.Finished
            val index = years.indexOfFirst { it.yearsAgo >= current }.let { if (it < 0) years.lastIndex else it }
            s.copy(years = years, index = index)
        }
        remember()
    }

    companion object {
        /** The date `on_this_day` is asked for (`layout.onthisday.dayBoundary`). */
        fun localDate(clock: Clock, zone: ZoneId): LocalDate =
            clock.instant().atZone(zone).minusHours(Tokens.Layouts.OnthisdayDayBoundary.hour.toLong()).toLocalDate()

        /** Rows grouped by `years_ago` ascending, API order inside each year. */
        fun group(items: List<OnThisDayItem>): List<Pair<Int, List<OnThisDayItem>>> =
            items.groupBy { it.yearsAgo }.toSortedMap().map { (years, rows) -> years to rows }

        /** Loads the day, or null when there is nothing to show. */
        suspend fun loadDay(backend: MemoryBackend, groupId: String, clock: Clock): OnThisDayState.Day? {
            val group = backend.group(groupId) ?: return null
            val zone = runCatching { ZoneId.of(group.timeZone) }.getOrDefault(ZoneId.of("UTC"))
            val items = backend.onThisDay(groupId, localDate(clock, zone))
            if (items.isEmpty()) return null
            val media = backend.media(items.map { it.mediaId }).associateBy { it.id }
            val profiles = backend.profiles(items.map { it.authorId }.distinct()).associateBy { it.id }
            val paths = buildSet {
                media.values.forEach { m ->
                    add(m.imagePath(Media.Rendition.Display))
                    add(m.imagePath(Media.Rendition.Thumb))
                }
                profiles.values.mapNotNullTo(this) { it.avatarPath }
            }
            val urls = backend.signedUrls(paths)
            val years = group(items).map { (yearsAgo, rows) ->
                MemoryYear(
                    yearsAgo,
                    rows.mapNotNull { row ->
                        val m = media[row.mediaId] ?: return@mapNotNull null
                        val author = profiles[row.authorId]
                        MemoryPhoto(
                            postId = row.postId,
                            displayUrl = urls[m.imagePath(Media.Rendition.Display)],
                            thumbUrl = urls[m.imagePath(Media.Rendition.Thumb)],
                            aspectRatio = m.aspectRatio(),
                            authorName = author?.firstName.orEmpty(),
                            avatarUrl = author?.avatarPath?.let(urls::get),
                            createdAt = row.createdAt,
                        )
                    },
                )
            }.filter { it.photos.isNotEmpty() }
            return if (years.isEmpty()) null else OnThisDayState.Day(years, 0, zone)
        }
    }
}
