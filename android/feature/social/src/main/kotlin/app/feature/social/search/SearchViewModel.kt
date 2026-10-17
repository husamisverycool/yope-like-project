// Surface: search.photos — design/surfaces/search.photos.md ("States", "Data & actions"). Owner decision 34 (research #6).
package app.feature.social.search

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.data.error.DataError
import app.data.model.Media
import app.data.model.PhotoSearchHit
import app.data.model.Post
import app.data.repo.Member
import app.feature.social.common.videoDurationMs
import app.feature.social.data.PhotoSearchQuery
import app.feature.social.data.SocialData
import app.feature.social.data.dataError
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.util.concurrent.ConcurrentHashMap

/** One member chip: you first (`search.photos.member.you`), then the members by joining order. */
data class SearchMember(val userId: String, val name: String, val isMe: Boolean)

/** One photo found, with what its cell shows. */
data class SearchResult(val hit: PhotoSearchHit, val post: Post, val thumbPath: String?, val authorName: String?, val videoDurationMs: Long? = null)

data class SearchState(
    val text: String = "",
    val memberId: String? = null,
    val from: LocalDate? = null,
    val to: LocalDate? = null,
    val phase: Phase = Phase.Idle,
    /** In search order (newest first); never counted on screen (tenet 2). */
    val results: List<SearchResult> = emptyList(),
    val members: List<SearchMember> = emptyList(),
    val hasMore: Boolean = false,
    val loadingMore: Boolean = false,
) {
    enum class Phase {
        /** Nothing typed, no chip on: `search.photos.idle.*`. */
        Idle,
        Loading,
        Results,
        /** `search.photos.empty.title`. */
        Empty,
        /** `search.photos.error` (tap searches again). */
        Error,
        /** `search.photos.offline` (tap searches again). */
        Offline,
    }

    val hasDates: Boolean get() = from != null || to != null
}

/**
 * The photo lists search pages hand to `photo.viewer` ([app.model.PhotoContext.Search]), for this process: the results
 * in their order under the page's key, and whether they span several groups (the viewer then names each photo's group).
 */
object SearchResults {
    private data class Entry(val postIds: List<String>, val spansGroups: Boolean)

    private val entries = ConcurrentHashMap<String, Entry>()

    fun put(key: String, postIds: List<String>, spansGroups: Boolean) {
        entries[key] = Entry(postIds, spansGroups)
    }

    fun postIds(key: String): List<String>? = entries[key]?.postIds

    fun spansGroups(key: String): Boolean = entries[key]?.spansGroups == true
}

/**
 * `search.photos`: `search_photos` with every criterion the page holds (the field's text on the keyboard's search key, one
 * member, a date range), in [groupId] or — null — all your groups. A new search cancels the one before it; pages of
 * [PAGE] with `p_before` = the last row's `created_at`. Member chips: the group's members, or every member of every group
 * you are in (each person once). No face or AI search; no count anywhere.
 */
class SearchViewModel(private val data: SocialData, private val groupId: String?) : ViewModel() {
    private val _state = MutableStateFlow(SearchState())
    val state: StateFlow<SearchState> = _state.asStateFlow()

    /** The key the results are kept under for the viewer ([SearchResults]). */
    val resultsKey: String = "search:" + (groupId ?: ALL_GROUPS)

    private var job: Job? = null
    /** The query the shown results answer (paging repeats it, whatever the field holds now). */
    private var asked: PhotoSearchQuery? = null
    private val media = HashMap<String, Media>()
    private val names = HashMap<String, String?>()

    init {
        viewModelScope.launch { loadMembers() }
    }

    private fun query(s: SearchState = _state.value) = PhotoSearchQuery(s.text, groupId, s.memberId, s.from, s.to)

    /** The field was edited; clearing the last criterion goes back to idle at once. */
    fun setText(text: String) {
        _state.update { it.copy(text = text) }
        if (query().isEmpty && _state.value.phase != SearchState.Phase.Idle) reset()
    }

    /** One member at a time: choosing another moves the selection; the chosen one again clears it. */
    fun toggleMember(userId: String) {
        _state.update { it.copy(memberId = if (it.memberId == userId) null else userId) }
        search()
    }

    /** The date filter (inclusive, group-local days); a reversed range is put in order. */
    fun setDates(from: LocalDate, to: LocalDate) {
        _state.update { it.copy(from = minOf(from, to), to = maxOf(from, to)) }
        search()
    }

    fun clearDates() {
        _state.update { it.copy(from = null, to = null) }
        search()
    }

    /** Searches with every criterion the page holds; none → idle (nothing is asked). */
    fun search() {
        val query = query()
        job?.cancel()
        if (query.isEmpty) {
            reset()
            return
        }
        _state.update { it.copy(phase = SearchState.Phase.Loading, hasMore = false, loadingMore = false) }
        job = viewModelScope.launch {
            try {
                val hits = data.searchPhotos(query, null, PAGE)
                val rows = hydrate(hits)
                asked = query
                SearchResults.put(resultsKey, rows.map { it.post.id }, spansGroups = groupId == null)
                _state.update {
                    it.copy(
                        phase = if (rows.isEmpty()) SearchState.Phase.Empty else SearchState.Phase.Results,
                        results = rows,
                        hasMore = hits.size == PAGE,
                    )
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Throwable) {
                asked = null
                val offline = e.dataError() == DataError.Network
                _state.update { it.copy(phase = if (offline) SearchState.Phase.Offline else SearchState.Phase.Error, results = emptyList(), hasMore = false) }
            }
        }
    }

    /** The next page when the grid reaches its end; a failure keeps what is shown (reaching the end again retries). */
    fun loadMore() {
        val s = _state.value
        val query = asked ?: return
        val last = s.results.lastOrNull()?.hit ?: return
        if (!s.hasMore || s.loadingMore || s.phase != SearchState.Phase.Results) return
        _state.update { it.copy(loadingMore = true) }
        job = viewModelScope.launch {
            try {
                val hits = data.searchPhotos(query, last.createdAt, PAGE)
                val known = _state.value.results.map { it.post.id }.toSet()
                val rows = hydrate(hits.filter { it.postId !in known })
                val all = _state.value.results + rows
                SearchResults.put(resultsKey, all.map { it.post.id }, spansGroups = groupId == null)
                _state.update { it.copy(results = all, hasMore = hits.size == PAGE, loadingMore = false) }
            } catch (e: CancellationException) {
                _state.update { it.copy(loadingMore = false) }
                throw e
            } catch (_: Throwable) {
                _state.update { it.copy(loadingMore = false) }
            }
        }
    }

    private fun reset() {
        job?.cancel()
        asked = null
        _state.update { it.copy(phase = SearchState.Phase.Idle, results = emptyList(), hasMore = false, loadingMore = false) }
    }

    /** The rows' posts (visible ones only), thumbnails and authors' first names, in the rows' order. */
    private suspend fun hydrate(hits: List<PhotoSearchHit>): List<SearchResult> {
        if (hits.isEmpty()) return emptyList()
        val posts = data.posts(hits.map { it.postId }).associateBy { it.id }
        val wantedMedia = posts.values.map { it.mediaId }.filter { it !in media }.distinct()
        if (wantedMedia.isNotEmpty()) data.media(wantedMedia).forEach { media[it.id] = it }
        val people = posts.values.map { it.authorId }.filter { it !in names }.distinct()
        if (people.isNotEmpty()) runCatching { data.profiles(people) }.getOrNull()?.forEach { names[it.id] = it.firstName }
        return hits.mapNotNull { hit ->
            val post = posts[hit.postId] ?: return@mapNotNull null
            val m = media[post.mediaId]
            SearchResult(hit, post, m?.imagePath(Media.Rendition.Thumb), names[post.authorId], m?.videoDurationMs)
        }
    }

    private suspend fun loadMembers() {
        val me = data.currentUserId()
        val people = ArrayList<Member>()
        if (groupId != null) {
            people += membersOf(groupId)
        } else {
            val groups = runCatching { data.myGroups() }.getOrDefault(emptyList())
            for (group in groups) people += membersOf(group.id)
        }
        // Joining order (a stable sort keeps the order people who joined at the same moment came in); each person once.
        val ordered = people.sortedBy { it.member.joinedAt }.distinctBy { it.member.userId }
        ordered.forEach { m -> m.profile?.let { names[it.id] = it.firstName } }
        val chips = ordered.map { m ->
            val mine = m.member.userId == me
            SearchMember(m.member.userId, if (mine) "" else m.profile?.firstName.orEmpty(), mine)
        }
        _state.update { it.copy(members = chips.filter { c -> c.isMe } + chips.filterNot { c -> c.isMe }) }
    }

    private suspend fun membersOf(id: String): List<Member> = try {
        data.members(id)
    } catch (e: CancellationException) {
        throw e
    } catch (_: Throwable) {
        emptyList()
    }

    companion object {
        /** `search_photos`' default page (docs/API.md). */
        const val PAGE = 60
        private const val ALL_GROUPS = "all"
    }
}
