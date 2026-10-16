package app.feature.social.walls

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.data.error.DataError
import app.data.model.Collage
import app.data.model.Media
import app.data.model.Profile
import app.data.model.RenderStatus
import app.data.model.WallItem
import app.data.model.WallItemKind
import app.data.offline.DataState
import app.data.realtime.GroupEvent
import app.feature.social.data.SocialData
import app.feature.social.data.dataError
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.drop
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable
import java.text.Collator
import java.time.Instant
import java.util.Locale

/** One wall tile: a photo (its thumbnail) or a same-moment collage (only `ready` ones are shown). */
sealed interface WallTile {
    val key: String
    val createdAt: Instant
    val groupId: String?

    data class Photo(val postId: String, val mediaId: String, val thumbPath: String?, override val createdAt: Instant, override val groupId: String?) : WallTile {
        override val key get() = "p:$postId"
    }

    data class CollageTile(val collageId: String, val imagePath: String?, val invitationId: String?, override val createdAt: Instant, override val groupId: String?) : WallTile {
        override val key get() = "c:$collageId"
    }
}

data class WallState(
    val phase: Phase = Phase.Loading,
    val person: Profile? = null,
    val tiles: List<WallTile> = emptyList(),
    val offline: Boolean = false,
    val loadingMore: Boolean = false,
    val endReached: Boolean = false,
) {
    enum class Phase { Loading, Ready, Error, OfflineEmpty }

    val isEmpty: Boolean get() = phase == Phase.Ready && tiles.isEmpty()
}

@Serializable
internal data class WallHydration(val media: List<Media> = emptyList(), val collages: List<Collage> = emptyList(), val person: Profile? = null)

/**
 * One person's wall (`wall(p_user_id)`, docs/API.md §6.4): the first page cache-then-network,
 * pages of [PAGE] by `p_before`, `post_deleted` on the shared groups drops tiles, refetch on
 * reconnect. Used by `walls.mine`, `walls.member` and the selected wall of `walls.browse`.
 */
class WallLoader(private val data: SocialData, private val scope: CoroutineScope, val userId: String) {
    private val _state = MutableStateFlow(WallState())
    val state: StateFlow<WallState> = _state.asStateFlow()

    private var items: List<WallItem> = emptyList()
    private val media = LinkedHashMap<String, Media>()
    private val collages = LinkedHashMap<String, Collage>()
    private var person: Profile? = null
    private val subscriptions = HashMap<String, Job>()
    private val jobs = ArrayList<Job>()
    private val cacheKey = "wall/$userId"

    fun start() {
        jobs += scope.launch { data.observeWall(userId).collect(::apply) }
        jobs += scope.launch { person = runCatching { data.profiles(listOf(userId)).firstOrNull() }.getOrNull() ?: person; publish() }
        jobs += scope.launch { data.online.distinctUntilChanged().drop(1).collect { online -> if (online) refresh() } }
    }

    fun stop() {
        jobs.forEach { it.cancel() }
        subscriptions.values.forEach { it.cancel() }
    }

    private suspend fun apply(page: DataState<List<WallItem>>) {
        val value = page.value
        when {
            value != null -> {
                if (page.source == DataState.Source.Cache) restore()
                items = value
                val ok = runCatching { hydrate(value) }.isSuccess
                if (ok && page.source == DataState.Source.Network) save()
                _state.update {
                    it.copy(
                        phase = WallState.Phase.Ready,
                        offline = page.error == DataError.Network,
                        endReached = page.source == DataState.Source.Network && value.size < PAGE,
                    )
                }
                publish()
                subscribe()
            }
            page.refreshing -> if (items.isEmpty()) _state.update { it.copy(phase = WallState.Phase.Loading) }
            else -> _state.update { it.copy(phase = if (page.error == DataError.Network) WallState.Phase.OfflineEmpty else WallState.Phase.Error) }
        }
    }

    fun refresh() {
        scope.launch {
            try {
                val page = data.wall(userId, null, PAGE)
                // The fresh first page replaces what it covers; older pages already loaded stay below it.
                val oldest = page.lastOrNull()?.createdAt
                val tail = if (page.size < PAGE || oldest == null) emptyList() else items.filter { it.createdAt.isBefore(oldest) }
                items = (page + tail).distinctBy { it.key() }
                hydrate(items)
                save()
                _state.update { it.copy(phase = WallState.Phase.Ready, offline = false) }
                publish()
                subscribe()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Throwable) {
                val error = e.dataError()
                _state.update { if (items.isEmpty()) it.copy(phase = if (error == DataError.Network) WallState.Phase.OfflineEmpty else WallState.Phase.Error) else it.copy(offline = error == DataError.Network) }
            }
        }
    }

    fun retry() {
        _state.update { it.copy(phase = WallState.Phase.Loading) }
        refresh()
    }

    /** The next page (newest first; `p_before` = the last `created_at`). */
    fun loadMore() {
        val s = _state.value
        if (s.loadingMore || s.endReached || items.isEmpty() || s.phase != WallState.Phase.Ready) return
        _state.update { it.copy(loadingMore = true) }
        scope.launch {
            try {
                val page = data.wall(userId, items.last().createdAt, PAGE)
                items = (items + page).distinctBy { it.key() }
                hydrate(page)
                _state.update { it.copy(loadingMore = false, endReached = page.size < PAGE) }
                publish()
                subscribe()
            } catch (e: CancellationException) {
                throw e
            } catch (_: Throwable) {
                _state.update { it.copy(loadingMore = false) }
            }
        }
    }

    private suspend fun hydrate(batch: List<WallItem>) {
        val mediaIds = batch.mapNotNull { it.mediaId }.filter { it !in media }
        val collageIds = batch.mapNotNull { it.collageId }.filter { it !in collages }
        coroutineScope {
            val m = async { if (mediaIds.isEmpty()) emptyList() else data.media(mediaIds) }
            val c = async { if (collageIds.isEmpty()) emptyList() else data.collages(collageIds) }
            m.await().forEach { media[it.id] = it }
            c.await().forEach { collages[it.id] = it }
        }
    }

    private fun subscribe() {
        items.flatMap { it.groupIds }.distinct().filter { it !in subscriptions }.forEach { group ->
            subscriptions[group] = scope.launch { data.events(group).collect(::onEvent) }
        }
    }

    internal fun onEvent(event: GroupEvent) {
        when (event) {
            is GroupEvent.PostDeleted -> {
                val before = items.size
                items = items.filterNot { it.postId == event.postId || (event.mediaId != null && it.mediaId == event.mediaId) }
                if (items.size != before) publish()
            }
            is GroupEvent.Subscribed -> if (event.resumed) refresh()
            else -> Unit
        }
    }

    private suspend fun save() {
        runCatching { data.cachePut(cacheKey, WallHydration.serializer(), WallHydration(media.values.toList(), collages.values.toList(), person)) }
    }

    private suspend fun restore() {
        val cached = runCatching { data.cacheGet(cacheKey, WallHydration.serializer()) }.getOrNull() ?: return
        cached.media.forEach { media.putIfAbsent(it.id, it) }
        cached.collages.forEach { collages.putIfAbsent(it.id, it) }
        if (person == null) person = cached.person
    }

    private fun publish() {
        val tiles = items.mapNotNull { item ->
            when (item.itemKind) {
                WallItemKind.Post -> {
                    val postId = item.postId ?: return@mapNotNull null
                    val mediaId = item.mediaId ?: return@mapNotNull null
                    WallTile.Photo(postId, mediaId, media[mediaId]?.imagePath(Media.Rendition.Thumb), item.createdAt, item.groupIds.firstOrNull())
                }
                WallItemKind.Collage -> {
                    val id = item.collageId ?: return@mapNotNull null
                    val collage = collages[id]
                    // Only ready collages are shown (docs/API.md §5.13).
                    if (collage != null && collage.status != RenderStatus.Ready) return@mapNotNull null
                    WallTile.CollageTile(id, collage?.imagePath, collage?.invitationId, item.createdAt, collage?.groupId ?: item.groupIds.firstOrNull())
                }
            }
        }
        _state.update { it.copy(tiles = tiles, person = person ?: it.person) }
    }

    private fun WallItem.key(): String = postId ?: collageId ?: createdAt.toString()

    companion object {
        const val PAGE = 50
    }
}

/** `walls.mine` / `walls.member`: one person's wall. */
class WallViewModel(data: SocialData, userId: String) : ViewModel() {
    val loader = WallLoader(data, viewModelScope, userId).also { it.start() }
    val state: StateFlow<WallState> get() = loader.state
}

data class BrowseState(
    val phase: Phase = Phase.Loading,
    /** Everyone who shares at least one group with me (not me). */
    val people: List<Profile> = emptyList(),
    /** True when I have no group, or nobody else is in mine. */
    val alone: Boolean = false,
    val query: String = "",
) {
    enum class Phase { Loading, Ready, Error, OfflineEmpty }

    /** The grid filtered by display name as typed (`walls.browse` search). */
    val shown: List<Profile> get() = query.trim().let { q -> if (q.isEmpty()) people else people.filter { it.displayName.contains(q, ignoreCase = true) } }
}

/**
 * `walls.browse`: everyone sharing a group with me, in the order `walls.browse.layout.rowOrder` (Apple Photos'
 * people grid "Sort by Name": display name A to Z in the device locale's collation, ignoring case and accents; ties
 * by profile id — [orderedByName]).
 */
class BrowseViewModel(private val data: SocialData, private val locale: Locale = Locale.getDefault()) : ViewModel() {
    private val _state = MutableStateFlow(BrowseState())
    val state: StateFlow<BrowseState> = _state.asStateFlow()

    init {
        load()
    }

    fun load() {
        viewModelScope.launch {
            val me = data.currentUserId()
            try {
                val groups = data.myGroups()
                val members = coroutineScope { groups.map { g -> async { data.members(g.id) } }.awaitAll() }.flatten()
                val others = members.mapNotNull { it.profile }.distinctBy { it.id }.filter { it.id != me }
                val ordered = orderedByName(others, locale)
                _state.update { it.copy(phase = BrowseState.Phase.Ready, people = ordered, alone = ordered.isEmpty()) }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Throwable) {
                _state.update { it.copy(phase = if (e.dataError() == DataError.Network) BrowseState.Phase.OfflineEmpty else BrowseState.Phase.Error) }
            }
        }
    }

    fun setQuery(query: String) = _state.update { it.copy(query = query) }

    fun retry() {
        _state.update { it.copy(phase = BrowseState.Phase.Loading) }
        load()
    }
}

/**
 * `walls.browse.layout.rowOrder`: [people] by display name, A to Z, in [locale]'s collation ignoring case and accents
 * (`Collator` PRIMARY strength — the comparison iOS makes with `.caseInsensitive` + `.diacriticInsensitive`); equal
 * names by profile id so the order is stable.
 */
fun orderedByName(people: List<Profile>, locale: Locale = Locale.getDefault()): List<Profile> {
    val collator = Collator.getInstance(locale).apply { strength = Collator.PRIMARY }
    return people.sortedWith { a, b -> collator.compare(a.displayName, b.displayName).takeIf { it != 0 } ?: a.id.compareTo(b.id) }
}
