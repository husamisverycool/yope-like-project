package app.feature.memory.birthday

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.data.model.Media
import app.data.model.Post
import app.data.model.TributeContribution
import app.designsystem.generated.Tokens
import app.feature.memory.common.EffectQueue
import app.feature.memory.common.Failure
import app.feature.memory.common.MemoryBackend
import app.feature.memory.common.aspectRatio
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

/** What the request screen shows about the request (never shown to the honoree). */
data class RequestInfo(
    val requestId: String,
    val groupId: String,
    val groupName: String,
    /** Honoree's first name. */
    val honoreeName: String,
    val honoreeAvatarUrl: String?,
    val birthdayDate: LocalDate,
    val dueAt: Instant,
)

/** The member's own contribution (the only one anybody can read). */
data class OwnContribution(val postId: String, val photoUrl: String?, val aspectRatio: Float, val line: String)

/** One eligible photo (posted by you or self-tagged), for the step 1 grid. */
data class EligiblePhoto(val postId: String, val thumbUrl: String?, val displayUrl: String?, val aspectRatio: Float, val date: LocalDate)

sealed interface RequestState {
    data object Loading : RequestState
    data object Offline : RequestState
    data object Failed : RequestState

    /** request_not_found: honoree opted out, left, a block — or you are the honoree. */
    data object NotFound : RequestState

    data class Ready(
        val info: RequestInfo,
        val contribution: OwnContribution?,
        /** tribute_closed or due_at passed: button and prompts give way to the closed message. */
        val closed: Boolean,
        val withdrawing: Boolean = false,
    ) : RequestState
}

/** Pages of the destination: the request, then the three contribute steps (nested navigation). */
enum class RequestPage(val route: String) { Request("request"), Photo("photo"), Message("message"), Done("done") }

sealed interface PhotosState {
    data object Loading : PhotosState
    data object Empty : PhotosState
    data class Failed(val offline: Boolean) : PhotosState
    data class Loaded(val photos: List<EligiblePhoto>) : PhotosState
}

data class ContributeState(
    val photos: PhotosState = PhotosState.Loading,
    val selected: String? = null,
    val line: String = "",
    val sending: Boolean = false,
    val inline: Inline? = null,
    /** tribute_closed while contributing: the step content gives way to the closed message. */
    val closed: Boolean = false,
) {
    enum class Inline { NotEligible, Error, Offline }

    val selectedPhoto: EligiblePhoto? get() = (photos as? PhotosState.Loaded)?.photos?.firstOrNull { it.postId == selected }
    val canSubmit: Boolean get() = selected != null && line.isNotBlank() && !sending
}

data class BirthdayFlowState(
    val request: RequestState = RequestState.Loading,
    val page: RequestPage = RequestPage.Request,
    val contribute: ContributeState = ContributeState(),
)

/**
 * `birthday.request` + `birthday.contribute` (design/surfaces/birthday.request.md,
 * birthday.contribute.md). One private request per member: no reminders, no "you haven't
 * contributed" state, nobody else's contribution. Photos: only ones you posted or are in.
 */
class BirthdayRequestViewModel(
    private val groupId: String,
    private val requestId: String,
    private val backend: MemoryBackend,
    private val clock: Clock = Clock.systemUTC(),
) : ViewModel() {
    private val _state = MutableStateFlow(BirthdayFlowState())
    val state: StateFlow<BirthdayFlowState> = _state.asStateFlow()
    private val queue = EffectQueue()
    val effects = queue.effects
    private var load: Job? = null
    private var zone: ZoneId = ZoneId.of("UTC")

    init {
        retry()
        viewModelScope.launch { backend.postDeletions(groupId).collect(::onPostDeleted) }
    }

    fun retry() {
        load?.cancel()
        _state.update { it.copy(request = RequestState.Loading) }
        load = viewModelScope.launch {
            if (!backend.isOnline()) {
                _state.update { it.copy(request = RequestState.Offline) }
                return@launch
            }
            val result = attempt { loadRequest() }
            _state.update { s ->
                s.copy(
                    request = result.getOrElse { e ->
                        when (failureOf(e)) {
                            Failure.Offline -> RequestState.Offline
                            Failure.NotFound -> RequestState.NotFound
                            else -> RequestState.Failed
                        }
                    },
                )
            }
        }
    }

    private suspend fun loadRequest(): RequestState {
        val request = backend.request(requestId) ?: return RequestState.NotFound
        // RLS already hides a request from its honoree (docs/API.md §5.16); never show it to them.
        if (request.honoreeId == backend.currentUserId) return RequestState.NotFound
        val group = backend.group(request.groupId)
        zone = group?.timeZone?.let { runCatching { ZoneId.of(it) }.getOrNull() } ?: zone
        val honoree = backend.profiles(listOf(request.honoreeId)).firstOrNull()
        val own = backend.myContribution(requestId)
        val avatarUrl = honoree?.avatarPath?.let { backend.signedUrls(listOf(it))[it] }
        return RequestState.Ready(
            info = RequestInfo(
                requestId = request.id,
                groupId = request.groupId,
                groupName = group?.name.orEmpty(),
                honoreeName = honoree?.firstName.orEmpty(),
                honoreeAvatarUrl = avatarUrl,
                birthdayDate = request.birthdayDate,
                dueAt = request.dueAt,
            ),
            contribution = own?.let { contributionView(it) },
            closed = !request.isOpen(clock.instant()),
        )
    }

    private suspend fun contributionView(c: TributeContribution): OwnContribution? {
        val post = backend.posts(listOf(c.postId)).firstOrNull() ?: return null
        val media = backend.media(listOf(post.mediaId)).firstOrNull() ?: return null
        val path = media.imagePath(Media.Rendition.Display)
        return OwnContribution(c.postId, backend.signedUrls(listOf(path))[path], media.aspectRatio(), c.line)
    }

    // ---- request page --------------------------------------------------------------------------

    /** "Add Your Photo" (or "Retake" on the own block): step 1, current photo preselected. */
    fun startContribution() {
        val ready = _state.value.request as? RequestState.Ready ?: return
        if (ready.closed) return
        _state.update {
            it.copy(
                page = RequestPage.Photo,
                contribute = it.contribute.copy(
                    selected = ready.contribution?.postId ?: it.contribute.selected,
                    line = ready.contribution?.line ?: it.contribute.line,
                    inline = null,
                    closed = false,
                ),
            )
        }
        if (_state.value.contribute.photos !is PhotosState.Loaded) loadPhotos()
    }

    /** "Remove": direct DELETE of the own row before due_at, no confirmation. */
    fun withdraw() {
        val ready = _state.value.request as? RequestState.Ready ?: return
        if (ready.contribution == null || ready.withdrawing) return
        _state.update { it.copy(request = ready.copy(withdrawing = true)) }
        viewModelScope.launch {
            attempt { backend.withdraw(requestId) }
                .onSuccess {
                    queue.haptic(Tokens.Haptics.globalSuccess)
                    updateReady { it.copy(contribution = null, withdrawing = false) }
                    _state.update { it.copy(contribute = ContributeState(photos = it.contribute.photos)) }
                }
                .onFailure { e ->
                    queue.haptic(Tokens.Haptics.globalError)
                    updateReady { it.copy(withdrawing = false, closed = it.closed || failureOf(e) == Failure.Closed) }
                }
        }
    }

    // ---- contribute steps ----------------------------------------------------------------------

    fun loadPhotos() {
        _state.update { it.copy(contribute = it.contribute.copy(photos = PhotosState.Loading)) }
        viewModelScope.launch {
            if (!backend.isOnline()) {
                setPhotos(PhotosState.Failed(offline = true))
                return@launch
            }
            attempt { eligiblePhotos() }
                .onSuccess { photos -> setPhotos(if (photos.isEmpty()) PhotosState.Empty else PhotosState.Loaded(photos)) }
                .onFailure { e -> setPhotos(PhotosState.Failed(offline = failureOf(e) == Failure.Offline)) }
        }
    }

    private suspend fun eligiblePhotos(): List<EligiblePhoto> {
        val posts: List<Post> = backend.eligiblePosts(groupId)
        val media = backend.media(posts.map { it.mediaId }).associateBy { it.id }
        val paths = media.values.flatMap { listOf(it.imagePath(Media.Rendition.Thumb), it.imagePath(Media.Rendition.Display)) }
        val urls = backend.signedUrls(paths.toSet())
        return posts.mapNotNull { post ->
            val m = media[post.mediaId] ?: return@mapNotNull null
            EligiblePhoto(
                post.id,
                urls[m.imagePath(Media.Rendition.Thumb)],
                urls[m.imagePath(Media.Rendition.Display)],
                m.aspectRatio(),
                post.createdAt.atZone(zone).toLocalDate(),
            )
        }
    }

    private fun setPhotos(photos: PhotosState) = _state.update { s ->
        val keep = (photos as? PhotosState.Loaded)?.photos?.any { it.postId == s.contribute.selected } == true
        s.copy(contribute = s.contribute.copy(photos = photos, selected = if (keep) s.contribute.selected else null))
    }

    /** Single choice; tapping another photo moves the check. */
    fun select(postId: String) {
        if (_state.value.contribute.selected == postId) return
        queue.haptic(Tokens.Haptics.globalSelect)
        _state.update { it.copy(contribute = it.contribute.copy(selected = postId, inline = null)) }
    }

    /** "Use Photo" → step 2. */
    fun usePhoto() {
        if (_state.value.contribute.selectedPhoto == null) return
        _state.update { it.copy(page = RequestPage.Message, contribute = it.contribute.copy(inline = null)) }
    }

    /** The one line; up to the API bound (280, `layout.birthday.contribute.lineMax` BLOCKED), no counter. */
    fun setLine(text: String) = _state.update { it.copy(contribute = it.contribute.copy(line = text.take(LINE_API_BOUND), inline = null)) }

    /** "Submit" (or "try again" after an error): `contribute_tribute` with the trimmed line. */
    fun submit() {
        val c = _state.value.contribute
        val photo = c.selectedPhoto ?: return
        if (!c.canSubmit) return
        if (!backend.isOnline()) {
            _state.update { it.copy(contribute = it.contribute.copy(inline = ContributeState.Inline.Offline)) }
            return
        }
        _state.update { it.copy(contribute = it.contribute.copy(sending = true, inline = null)) }
        viewModelScope.launch {
            attempt { backend.contribute(requestId, photo.postId, c.line.trim()) }
                .onSuccess { saved ->
                    queue.haptic(Tokens.Haptics.globalSend)
                    updateReady { it.copy(contribution = OwnContribution(photo.postId, photo.displayUrl, photo.aspectRatio, saved.line)) }
                    _state.update { it.copy(page = RequestPage.Done, contribute = it.contribute.copy(sending = false)) }
                }
                .onFailure { e ->
                    queue.haptic(Tokens.Haptics.globalError)
                    when (failureOf(e)) {
                        Failure.NotEligible -> _state.update {
                            it.copy(page = RequestPage.Photo, contribute = it.contribute.copy(sending = false, inline = ContributeState.Inline.NotEligible))
                        }
                        Failure.Closed -> {
                            updateReady { it.copy(closed = true) }
                            _state.update { it.copy(contribute = it.contribute.copy(sending = false, closed = true)) }
                        }
                        Failure.Offline -> _state.update { it.copy(contribute = it.contribute.copy(sending = false, inline = ContributeState.Inline.Offline)) }
                        Failure.NotFound -> {
                            // post_not_found: the photo is gone; request_not_found: the request is.
                            onPostDeleted(photo.postId)
                            _state.update { it.copy(contribute = it.contribute.copy(sending = false)) }
                        }
                        else -> _state.update { it.copy(contribute = it.contribute.copy(sending = false, inline = ContributeState.Inline.Error)) }
                    }
                }
        }
    }

    /** "Retake": back to step 1, selection kept. */
    fun retake() = _state.update { it.copy(page = RequestPage.Photo) }

    /** "Done": back to the request, which now shows the own block. */
    fun done() = _state.update { it.copy(page = RequestPage.Request, contribute = it.contribute.copy(inline = null)) }

    /** Back / close: one page back; from the request, close the screen. */
    fun back() {
        when (_state.value.page) {
            RequestPage.Request -> queue.close()
            RequestPage.Photo, RequestPage.Done -> _state.update { it.copy(page = RequestPage.Request) }
            RequestPage.Message -> _state.update { it.copy(page = RequestPage.Photo) }
        }
    }

    /** `post_deleted`: drop the cell; the chosen photo sends you back to step 1; a contributed one is gone. */
    fun onPostDeleted(postId: String) {
        _state.update { s ->
            val c = s.contribute
            val photos = when (val p = c.photos) {
                is PhotosState.Loaded -> p.photos.filterNot { it.postId == postId }.let { if (it.isEmpty()) PhotosState.Empty else PhotosState.Loaded(it) }
                else -> p
            }
            val wasSelected = c.selected == postId
            s.copy(
                page = if (wasSelected && s.page == RequestPage.Message) RequestPage.Photo else s.page,
                contribute = c.copy(photos = photos, selected = if (wasSelected) null else c.selected),
            )
        }
        updateReady { if (it.contribution?.postId == postId) it.copy(contribution = null) else it }
    }

    private fun updateReady(transform: (RequestState.Ready) -> RequestState.Ready) = _state.update { s ->
        val ready = s.request as? RequestState.Ready ?: return@update s
        s.copy(request = transform(ready))
    }

    companion object {
        /** docs/API.md `contribute_tribute`: `p_line` is 1-280 characters (integrity bound). */
        const val LINE_API_BOUND = 280
    }
}
