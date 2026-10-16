package app.feature.social.week

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.data.error.ApiError
import app.data.error.DataError
import app.data.model.Group
import app.data.model.Media
import app.data.model.Post
import app.data.model.Profile
import app.data.model.RenderStatus
import app.data.model.WeeklyRecap
import app.data.offline.DataState
import app.data.realtime.GroupEvent
import app.feature.social.common.Formats
import app.feature.social.data.SocialData
import app.feature.social.data.cached
import app.feature.social.data.dataError
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
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
import java.time.LocalDate
import java.time.ZoneId

/** A photo tile of the week screens. */
data class WeekPhoto(val post: Post, val thumbPath: String?, val authorName: String?)

/**
 * Recaps being edited, shared by `week.edit` and `week.recap` so the recap screen shows an edit at
 * once (optimistic) and goes back if `update_recap` fails.
 */
object RecapEdits {
    val pending = MutableStateFlow<Map<String, WeeklyRecap>>(emptyMap())
    fun set(recap: WeeklyRecap) = pending.update { it + (recap.id to recap) }
    fun clear(recapId: String) = pending.update { it - recapId }
}

/** What the week screens load for one recap / week (cached for offline). */
@Serializable
internal data class WeekPayload(
    val group: Group? = null,
    val recap: WeeklyRecap? = null,
    val weekPostIds: List<String> = emptyList(),
    val posts: List<Post> = emptyList(),
    val media: List<Media> = emptyList(),
    val profiles: List<Profile> = emptyList(),
)

/** Loads a recap (or the newest ready one) with its week's posts, media and authors. */
internal suspend fun loadWeek(data: SocialData, groupId: String, recapId: String?, weekStart: LocalDate?): WeekPayload {
    val group = data.group(groupId)
    val recap = when {
        recapId != null -> data.recap(recapId)
        weekStart != null -> null
        else -> data.recaps(groupId).firstOrNull { it.status == RenderStatus.Ready }
    }
    val start = recap?.weekStart ?: weekStart ?: return WeekPayload(group = group)
    val week = data.historyWeeks(groupId, start.plusDays(Formats.DAYS_IN_WEEK), 1).firstOrNull { it.weekStart == start }
    val ids = (recap?.items.orEmpty() + week?.postIds.orEmpty()).distinct()
    val posts = data.posts(ids)
    val media = data.media(posts.map { it.mediaId })
    val profiles = data.profiles((posts.map { it.authorId } + listOfNotNull(recap?.editedBy)).distinct())
    return WeekPayload(group, recap, week?.postIds.orEmpty(), posts, media, profiles)
}

data class RecapState(
    val phase: Phase = Phase.Loading,
    val group: Group? = null,
    val recap: WeeklyRecap? = null,
    /** The recap's items in recap order (hidden / deleted ones dropped). */
    val card: List<WeekPhoto> = emptyList(),
    /** Every visible post of the week, chronological. */
    val pics: List<WeekPhoto> = emptyList(),
    val offline: Boolean = false,
    /** Who last edited the recap's text (`weekly_recaps.edited_by`), for the note's attribution. */
    val editor: Profile? = null,
) {
    enum class Phase { Loading, Ready, Pending, Empty, Error, OfflineEmpty }

    val zone: ZoneId get() = group?.timeZone?.let { runCatching { ZoneId.of(it) }.getOrNull() } ?: ZoneId.systemDefault()
}

/** `week.recap`: one recap ([recapId]) or the group's newest ready one. */
class RecapViewModel(private val data: SocialData, private val groupId: String, private val recapId: String?) : ViewModel() {
    private val _state = MutableStateFlow(RecapState())
    val state: StateFlow<RecapState> = _state.asStateFlow()
    private var payload: WeekPayload? = null
    private val removed = HashSet<String>()
    private var loadJob: Job? = null

    init {
        load()
        viewModelScope.launch { data.events(groupId).collect(::onEvent) }
        viewModelScope.launch { data.online.distinctUntilChanged().drop(1).collect { if (it) load() } }
        viewModelScope.launch { RecapEdits.pending.collect { publish() } }
    }

    fun load() {
        loadJob?.cancel()
        loadJob = viewModelScope.launch {
            data.cached("recap/${recapId ?: "latest-$groupId"}", WeekPayload.serializer()) { loadWeek(data, groupId, recapId, null) }.collect { page ->
                val value = page.value
                when {
                    value != null -> {
                        payload = value
                        _state.update { it.copy(offline = page.error == DataError.Network) }
                        publish()
                    }
                    page.refreshing -> _state.update { it.copy(phase = RecapState.Phase.Loading) }
                    else -> {
                        val e = page.error
                        _state.update {
                            it.copy(
                                phase = when {
                                    e == DataError.Network -> RecapState.Phase.OfflineEmpty
                                    e is DataError.Api && e.code == ApiError.RecapNotFound -> RecapState.Phase.Empty
                                    else -> RecapState.Phase.Error
                                },
                            )
                        }
                    }
                }
            }
        }
    }

    internal fun onEvent(event: GroupEvent) {
        when (event) {
            is GroupEvent.PostDeleted -> {
                removed += event.postId
                publish()
            }
            is GroupEvent.Subscribed -> if (event.resumed) load()
            else -> Unit
        }
    }

    private fun publish() {
        val p = payload ?: return
        val recap = p.recap?.let { RecapEdits.pending.value[it.id] ?: it }
        val posts = p.posts.filter { it.id !in removed }.associateBy { it.id }
        val media = p.media.associateBy { it.id }
        val names = p.profiles.associate { it.id to it.firstName }
        fun photo(id: String) = posts[id]?.let { post -> WeekPhoto(post, media[post.mediaId]?.imagePath(Media.Rendition.Thumb), names[post.authorId]) }
        val phase = when {
            recap == null -> RecapState.Phase.Empty
            recap.status == RenderStatus.Pending -> RecapState.Phase.Pending
            recap.status == RenderStatus.Failed -> RecapState.Phase.Error
            else -> RecapState.Phase.Ready
        }
        _state.update {
            it.copy(
                phase = phase,
                group = p.group,
                recap = recap,
                card = recap?.items.orEmpty().mapNotNull(::photo),
                pics = p.weekPostIds.mapNotNull(::photo),
                editor = recap?.editedBy?.let { id -> p.profiles.firstOrNull { it.id == id } },
            )
        }
    }
}

data class EditState(
    val phase: Phase = Phase.Loading,
    val groupId: String = "",
    val recap: WeeklyRecap? = null,
    val weekStart: LocalDate? = null,
    /** Recap items first (recap order), then the week's other posts (time order). */
    val photos: List<WeekPhoto> = emptyList(),
    /** Checked post ids, in their order (the recap / album order). */
    val checked: List<String> = emptyList(),
    val text: String = "",
    val saving: Boolean = false,
    val error: EditError? = null,
    val albumSheet: Boolean = false,
    val albumName: String = "",
    val albumError: EditError? = null,
    /** The "Add a Message" sheet is open (`week.edit.layout.message`). */
    val messageSheet: Boolean = false,
    /** The recap as loaded: Cancel with changes asks first (`week.edit.lostChanges.*`). */
    val originalChecked: List<String> = emptyList(),
    val originalText: String = "",
) {
    enum class Phase { Loading, Ready, NotReady, Error }

    val dirty: Boolean get() = phase == Phase.Ready && (checked != originalChecked || text.trim() != originalText.trim())

    /** Checked photos in their order (the strip). */
    val strip: List<WeekPhoto> get() = photos.associateBy { it.post.id }.let { byId -> checked.mapNotNull(byId::get) }
}

enum class EditError { Save, AlbumName, NotReady }

sealed interface EditEffect {
    data object Saved : EditEffect
    data object AlbumSaved : EditEffect
    data object Failed : EditEffect
    data object Close : EditEffect
}

/**
 * `week.edit`: toggle photos in / out of the recap, reorder the checked ones, edit the text, save
 * (`update_recap`, optimistic on the recap screen), or save the checked photos as a named album
 * (`save_album`). [albumOnly] opens straight on the album sheet with the week's photos checked
 * (from `week.history`).
 */
class WeekEditViewModel(
    private val data: SocialData,
    private val groupId: String,
    private val recapId: String?,
    private val weekStart: LocalDate?,
    val albumOnly: Boolean,
) : ViewModel() {
    private val _state = MutableStateFlow(EditState(groupId = groupId, albumSheet = albumOnly))
    val state: StateFlow<EditState> = _state.asStateFlow()
    private val _effects = MutableSharedFlow<EditEffect>(extraBufferCapacity = 8, onBufferOverflow = BufferOverflow.DROP_OLDEST)
    val effects: SharedFlow<EditEffect> = _effects.asSharedFlow()

    init {
        load()
    }

    fun load() {
        _state.update { it.copy(phase = EditState.Phase.Loading) }
        viewModelScope.launch {
            try {
                val p = loadWeek(data, groupId, recapId, weekStart)
                val recap = p.recap
                if (recapId != null && recap == null) {
                    _state.update { it.copy(phase = EditState.Phase.Error) }
                    return@launch
                }
                if (recap != null && recap.status != RenderStatus.Ready && !albumOnly) {
                    _state.update { it.copy(phase = EditState.Phase.NotReady, error = EditError.NotReady) }
                    return@launch
                }
                val posts = p.posts.associateBy { it.id }
                val media = p.media.associateBy { it.id }
                val names = p.profiles.associate { it.id to it.firstName }
                fun photo(id: String) = posts[id]?.let { post -> WeekPhoto(post, media[post.mediaId]?.imagePath(Media.Rendition.Thumb), names[post.authorId]) }
                val recapItems = recap?.items.orEmpty().filter { it in posts }
                val others = p.weekPostIds.filter { it !in recapItems && it in posts }
                // The grid: every visible post of the week in time order (the strip keeps the recap's order).
                val photos = (recapItems + others).mapNotNull(::photo).sortedBy { it.post.createdAt }
                // The album sheet alone: a recap's items (from week.recap) or the whole week (from week.history).
                val initial = if (albumOnly && recap == null) photos.map { ph -> ph.post.id } else recapItems
                _state.update {
                    it.copy(
                        phase = EditState.Phase.Ready,
                        recap = recap,
                        weekStart = recap?.weekStart ?: weekStart,
                        photos = photos,
                        checked = initial,
                        text = recap?.text.orEmpty(),
                        originalChecked = initial,
                        originalText = recap?.text.orEmpty(),
                    )
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Throwable) {
                val error = e.dataError()
                val notReady = error is DataError.Api && error.code == ApiError.RecapNotReady
                _state.update { it.copy(phase = if (notReady) EditState.Phase.NotReady else EditState.Phase.Error, error = if (notReady) EditError.NotReady else null) }
            }
        }
    }

    fun openMessage() = _state.update { it.copy(messageSheet = true) }

    fun closeMessage() = _state.update { it.copy(messageSheet = false) }

    /** In / out of the recap (or the album selection). A newly checked photo goes last. */
    fun toggle(postId: String) = _state.update { s ->
        s.copy(checked = if (postId in s.checked) s.checked - postId else s.checked + postId, error = null)
    }

    /** Reorder among the checked photos (`week.edit.layout.reorder`: touch and hold, drag, drop). */
    fun move(postId: String, toIndex: Int) = _state.update { s ->
        val from = s.checked.indexOf(postId)
        if (from < 0) return@update s
        val list = s.checked.toMutableList()
        list.removeAt(from)
        list.add(toIndex.coerceIn(0, list.size), postId)
        s.copy(checked = list)
    }

    /** The recap text, at most [TEXT_LIMIT] characters (`weekly_recaps.text`, `week.edit.layout.message` limit). */
    fun setText(text: String) = _state.update { it.copy(text = text.take(TEXT_LIMIT), error = null) }

    companion object {
        /** `week.edit.layout.message` → limit: "2000 characters (weekly_recaps.text)". */
        val TEXT_LIMIT: Int = Regex("([0-9]+) characters").find(app.designsystem.generated.Tokens.Layouts.WeekEditLayoutMessage.limit)?.groupValues?.get(1)?.toInt() ?: Int.MAX_VALUE
    }

    /** `update_recap` with the checked ids in order and the text; the recap screen shows the edit at once. */
    fun save() {
        val s = _state.value
        val recap = s.recap ?: return
        if (s.saving) return
        val items = s.checked
        val text = s.text.trim()
        RecapEdits.set(recap.copy(items = items, text = text.ifEmpty { null }))
        _state.update { it.copy(saving = true, error = null) }
        viewModelScope.launch {
            try {
                val saved = data.updateRecap(recap.id, items, text)
                RecapEdits.set(saved)
                _state.update { it.copy(saving = false, recap = saved) }
                _effects.emit(EditEffect.Saved)
                _effects.emit(EditEffect.Close)
            } catch (e: CancellationException) {
                throw e
            } catch (_: Throwable) {
                RecapEdits.clear(recap.id)
                _state.update { it.copy(saving = false, error = EditError.Save) }
                _effects.emit(EditEffect.Failed)
            }
        }
    }

    fun openAlbumSheet() = _state.update { it.copy(albumSheet = true, albumError = null) }

    fun closeAlbumSheet() {
        if (albumOnly) _effects.tryEmit(EditEffect.Close) else _state.update { it.copy(albumSheet = false, albumError = null) }
    }

    fun setAlbumName(name: String) = _state.update { it.copy(albumName = name, albumError = null) }

    /** `save_album(group, name, checked ids in order)`. */
    fun saveAlbum() {
        val s = _state.value
        if (s.saving || s.checked.isEmpty()) return
        val name = s.albumName.trim()
        if (name.isEmpty()) {
            _state.update { it.copy(albumError = EditError.AlbumName) }
            _effects.tryEmit(EditEffect.Failed)
            return
        }
        _state.update { it.copy(saving = true, albumError = null) }
        viewModelScope.launch {
            try {
                data.saveAlbum(groupId, name, s.checked)
                _state.update { it.copy(saving = false, albumSheet = false, albumName = "") }
                _effects.emit(EditEffect.AlbumSaved)
                if (albumOnly) _effects.emit(EditEffect.Close)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Throwable) {
                val error = e.dataError()
                val invalidName = error is DataError.Api && error.code == ApiError.InvalidName
                _state.update { it.copy(saving = false, albumError = if (invalidName) EditError.AlbumName else EditError.Save) }
                _effects.emit(EditEffect.Failed)
            }
        }
    }
}

/** One week section of `week.history`. */
data class HistoryWeekUi(
    val weekStart: LocalDate,
    val photos: List<WeekPhoto>,
    /** The ready recap of that week, for "View recap". */
    val recapId: String?,
    val isCurrent: Boolean,
)

data class HistoryState(
    val phase: Phase = Phase.Loading,
    val group: Group? = null,
    val weeks: List<HistoryWeekUi> = emptyList(),
    val offline: Boolean = false,
    val loadingMore: Boolean = false,
    val endReached: Boolean = false,
    val refreshing: Boolean = false,
) {
    enum class Phase { Loading, Ready, Error }

    val zone: ZoneId get() = group?.timeZone?.let { runCatching { ZoneId.of(it) }.getOrNull() } ?: ZoneId.systemDefault()
    /** True when the group has no photos at all. */
    val isEmpty: Boolean get() = phase == Phase.Ready && weeks.all { it.photos.isEmpty() }
}

/**
 * `week.history`: `group_history_weeks` newest first, cache-then-network, pages of [PAGE]; the
 * current week is synthesised when it has no posts. Realtime: deletions drop tiles; new posts join
 * the current week.
 */
class HistoryViewModel(private val data: SocialData, private val groupId: String, private val today: (ZoneId) -> LocalDate = { LocalDate.now(it) }) : ViewModel() {
    private val _state = MutableStateFlow(HistoryState())
    val state: StateFlow<HistoryState> = _state.asStateFlow()
    private var weeks: List<app.data.model.HistoryWeek> = emptyList()
    private val posts = LinkedHashMap<String, Post>()
    private val media = LinkedHashMap<String, Media>()
    private val names = HashMap<String, String?>()
    private var recaps: Map<LocalDate, String> = emptyMap()
    private var group: Group? = null

    init {
        viewModelScope.launch { start() }
        viewModelScope.launch { data.events(groupId).collect(::onEvent) }
    }

    private suspend fun start() {
        group = runCatching { data.group(groupId) }.getOrNull()
        data.observeHistory(groupId).collect { page -> apply(page) }
    }

    private suspend fun apply(page: DataState<List<app.data.model.HistoryWeek>>) {
        val value = page.value
        when {
            value != null -> {
                weeks = value
                runCatching { hydrate(value) }
                _state.update { it.copy(phase = HistoryState.Phase.Ready, offline = page.error == DataError.Network, endReached = page.source == DataState.Source.Network && value.size < PAGE) }
                publish()
            }
            page.refreshing -> if (weeks.isEmpty()) _state.update { it.copy(phase = HistoryState.Phase.Loading) }
            else -> _state.update { it.copy(phase = if (weeks.isEmpty()) HistoryState.Phase.Error else HistoryState.Phase.Ready, offline = page.error == DataError.Network) }
        }
    }

    /** Pull to refresh. */
    fun refresh() {
        _state.update { it.copy(refreshing = true) }
        viewModelScope.launch {
            try {
                if (group == null) group = data.group(groupId)
                val page = data.historyWeeks(groupId, null, PAGE)
                weeks = page
                hydrate(page)
                _state.update { it.copy(phase = HistoryState.Phase.Ready, refreshing = false, offline = false, endReached = page.size < PAGE) }
                publish()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Throwable) {
                _state.update { it.copy(refreshing = false, offline = e.dataError() == DataError.Network, phase = if (weeks.isEmpty()) HistoryState.Phase.Error else HistoryState.Phase.Ready) }
            }
        }
    }

    fun loadMore() {
        val s = _state.value
        if (s.loadingMore || s.endReached || weeks.isEmpty()) return
        _state.update { it.copy(loadingMore = true) }
        viewModelScope.launch {
            try {
                val page = data.historyWeeks(groupId, weeks.last().weekStart, PAGE)
                weeks = (weeks + page).distinctBy { it.weekStart }
                hydrate(page)
                _state.update { it.copy(loadingMore = false, endReached = page.size < PAGE) }
                publish()
            } catch (e: CancellationException) {
                throw e
            } catch (_: Throwable) {
                _state.update { it.copy(loadingMore = false) }
            }
        }
    }

    private suspend fun hydrate(batch: List<app.data.model.HistoryWeek>) {
        val ids = batch.flatMap { it.postIds }.filter { it !in posts }
        if (ids.isNotEmpty()) data.posts(ids).forEach { posts[it.id] = it }
        val mediaIds = posts.values.map { it.mediaId }.filter { it !in media }
        if (mediaIds.isNotEmpty()) data.media(mediaIds).forEach { media[it.id] = it }
        val people = posts.values.map { it.authorId }.filter { it !in names }.distinct()
        if (people.isNotEmpty()) data.profiles(people).forEach { names[it.id] = it.firstName }
        recaps = runCatching { data.recaps(groupId) }.getOrDefault(emptyList()).filter { it.status == RenderStatus.Ready }.associate { it.weekStart to it.id }
    }

    internal fun onEvent(event: GroupEvent) {
        when (event) {
            is GroupEvent.PostDeleted -> {
                weeks = weeks.map { w -> w.copy(postIds = w.postIds - event.postId) }
                posts.remove(event.postId)
                publish()
            }
            is GroupEvent.PostInserted -> viewModelScope.launch {
                val post = event.post
                posts[post.id] = post
                if (post.mediaId !in media) runCatching { data.media(listOf(post.mediaId)) }.getOrNull()?.forEach { media[it.id] = it }
                if (post.authorId !in names) runCatching { data.profiles(listOf(post.authorId)) }.getOrNull()?.forEach { names[it.id] = it.firstName }
                val start = Formats.weekStartOf(post.createdAt.atZone(_state.value.zone).toLocalDate())
                weeks = if (weeks.any { it.weekStart == start }) weeks.map { w -> if (w.weekStart == start && post.id !in w.postIds) w.copy(postIds = w.postIds + post.id) else w }
                else (listOf(app.data.model.HistoryWeek(start, listOf(post.id))) + weeks).sortedByDescending { it.weekStart }
                publish()
            }
            is GroupEvent.Subscribed -> if (event.resumed) refresh()
            else -> Unit
        }
    }

    private fun publish() {
        val zone = group?.timeZone?.let { runCatching { ZoneId.of(it) }.getOrNull() } ?: ZoneId.systemDefault()
        val current = Formats.weekStartOf(today(zone))
        val list = weeks.map { w ->
            HistoryWeekUi(
                weekStart = w.weekStart,
                photos = w.postIds.mapNotNull { id -> posts[id]?.let { p -> WeekPhoto(p, media[p.mediaId]?.imagePath(Media.Rendition.Thumb), names[p.authorId]) } },
                recapId = recaps[w.weekStart],
                isCurrent = w.weekStart == current,
            )
        }.filter { it.photos.isNotEmpty() || it.isCurrent }
        val withCurrent = if (list.none { it.isCurrent }) listOf(HistoryWeekUi(current, emptyList(), recaps[current], true)) + list else list
        _state.update { it.copy(group = group, weeks = withCurrent) }
    }

    companion object {
        const val PAGE = 8
    }
}

/** A card of the recap list: the recap and its cover (the first item's thumbnail). */
data class RecapCardUi(val recap: WeeklyRecap, val coverPath: String?)

/** What the recap list loads (cached for offline). */
@Serializable
internal data class RecapListPayload(val group: Group? = null, val recaps: List<WeeklyRecap> = emptyList(), val posts: List<Post> = emptyList(), val media: List<Media> = emptyList())

data class RecapListState(
    val phase: Phase = Phase.Loading,
    val group: Group? = null,
    val cards: List<RecapCardUi> = emptyList(),
    val offline: Boolean = false,
) {
    enum class Phase { Loading, Ready, Empty, Error, OfflineEmpty }

    val zone: ZoneId get() = group?.timeZone?.let { runCatching { ZoneId.of(it) }.getOrNull() } ?: ZoneId.systemDefault()
}

/** `week.recap` list (`week.recap.layout.list`): the group's ready and pending recaps, newest first, with their covers. */
class RecapListViewModel(private val data: SocialData, private val groupId: String) : ViewModel() {
    private val _state = MutableStateFlow(RecapListState())
    val state: StateFlow<RecapListState> = _state.asStateFlow()
    private var job: Job? = null

    init {
        load()
        viewModelScope.launch { data.online.distinctUntilChanged().drop(1).collect { if (it) load() } }
        viewModelScope.launch { RecapEdits.pending.collect { publish() } }
    }

    private var payload: RecapListPayload? = null

    fun load() {
        job?.cancel()
        job = viewModelScope.launch {
            data.cached("recaps/$groupId", RecapListPayload.serializer()) {
                val group = data.group(groupId)
                val recaps = data.recaps(groupId).filter { it.status != RenderStatus.Failed }.sortedByDescending { it.weekStart }
                val posts = data.posts(recaps.mapNotNull { it.items.firstOrNull() })
                val media = data.media(posts.map { it.mediaId })
                RecapListPayload(group, recaps, posts, media)
            }.collect { page ->
                val value = page.value
                when {
                    value != null -> {
                        payload = value
                        _state.update { it.copy(offline = page.error == DataError.Network) }
                        publish()
                    }
                    page.refreshing -> _state.update { it.copy(phase = RecapListState.Phase.Loading) }
                    else -> _state.update { it.copy(phase = if (page.error == DataError.Network) RecapListState.Phase.OfflineEmpty else RecapListState.Phase.Error) }
                }
            }
        }
    }

    fun retry() {
        _state.update { it.copy(phase = RecapListState.Phase.Loading) }
        load()
    }

    private fun publish() {
        val p = payload ?: return
        val posts = p.posts.associateBy { it.id }
        val media = p.media.associateBy { it.id }
        val cards = p.recaps.map { r0 ->
            val r = RecapEdits.pending.value[r0.id] ?: r0
            val cover = r.items.firstOrNull()?.let(posts::get)?.let { media[it.mediaId] }?.imagePath(Media.Rendition.Thumb)
            RecapCardUi(r, cover)
        }
        _state.update { it.copy(phase = if (cards.isEmpty()) RecapListState.Phase.Empty else RecapListState.Phase.Ready, group = p.group, cards = cards) }
    }
}
