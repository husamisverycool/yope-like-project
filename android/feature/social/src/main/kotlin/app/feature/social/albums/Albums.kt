// Surfaces: albums.list (a group's saved albums) and albums.view (one album).
// Built from documented Yope components (S-14): references/auto/yope/frames/a-savannahclooney-7683341732695592206-t6.73-home-list.png
// (home list card), references/owner/yope-week-recap.jpg (header, pics grid),
// references/auto/yope/frames/a-yrrah-7434441926000037121-t33.73-group-menu-leave-report-2024.png (••• menu),
// references/auto/yope/frames/a-itsmthuyope-7644974799302823175-t45.23-new-group-empty.png (name sheet).
package app.feature.social.albums

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import app.data.error.ApiError
import app.data.error.DataError
import app.data.model.Album
import app.data.model.Media
import app.data.model.MemberRole
import app.data.model.Post
import app.data.model.Profile
import app.data.offline.DataState
import app.data.realtime.GroupEvent
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.social.common.Avatar
import app.feature.social.common.ConfirmationToast
import app.feature.social.common.EmptyState
import app.feature.social.common.Formats
import app.feature.social.common.Glyph
import app.feature.social.common.HeaderCircle
import app.feature.social.common.Line
import app.feature.social.common.LoadingHud
import app.feature.social.common.PillAction
import app.feature.social.common.RemotePhoto
import app.feature.social.common.Type
import app.feature.social.common.announce
import app.feature.social.common.rememberHaptics
import app.feature.social.common.stringRes
import app.feature.social.data.SocialData
import app.feature.social.data.cached
import app.feature.social.data.dataError
import app.feature.social.week.NameSheet
import app.ui.components.HeaderCircleFill
import kotlinx.coroutines.CancellationException
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

/** One album card: the album, its cover (first photo's thumbnail) and who saved it. */
@Serializable
data class AlbumCard(val album: Album, val coverPath: String?, val savedBy: String?)

data class AlbumsState(val phase: Phase = Phase.Loading, val cards: List<AlbumCard> = emptyList(), val offline: Boolean = false) {
    enum class Phase { Loading, Ready, Error, OfflineEmpty }
}

/** `albums.list`: the group's albums, newest first, cache-then-network; refetched on reconnect (albums are not realtime). */
class AlbumsViewModel(private val data: SocialData, private val groupId: String) : ViewModel() {
    private val _state = MutableStateFlow(AlbumsState())
    val state: StateFlow<AlbumsState> = _state.asStateFlow()

    init {
        load()
        viewModelScope.launch { data.online.distinctUntilChanged().drop(1).collect { if (it) load() } }
    }

    fun load() {
        viewModelScope.launch {
            data.cached("albums/$groupId", kotlinx.serialization.builtins.ListSerializer(AlbumCard.serializer())) { cards() }.collect { page -> apply(page) }
        }
    }

    private fun apply(page: DataState<List<AlbumCard>>) {
        val value = page.value
        _state.update {
            when {
                value != null -> it.copy(phase = AlbumsState.Phase.Ready, cards = value, offline = page.error == DataError.Network)
                page.refreshing -> if (it.cards.isEmpty()) it.copy(phase = AlbumsState.Phase.Loading) else it
                else -> it.copy(phase = if (page.error == DataError.Network) AlbumsState.Phase.OfflineEmpty else AlbumsState.Phase.Error)
            }
        }
    }

    private suspend fun cards(): List<AlbumCard> {
        val albums = data.albums(groupId)
        val first = albums.associate { a -> a.id to data.albumItems(a.id).minByOrNull { it.position }?.postId }
        val posts = data.posts(first.values.filterNotNull()).associateBy { it.id }
        val media = data.media(posts.values.map { it.mediaId }).associateBy { it.id }
        val people = data.profiles(albums.mapNotNull { it.createdBy }.distinct()).associateBy { it.id }
        return albums.sortedByDescending { it.createdAt }.map { a ->
            val post = first[a.id]?.let(posts::get)
            AlbumCard(a, post?.let { media[it.mediaId]?.imagePath(Media.Rendition.Thumb) }, a.createdBy?.let { people[it]?.firstName })
        }
    }
}

/** Header of the album screens: ‹ circle, centred title (`week.recap.fontSize.title`), optional trailing circle. */
@Composable
private fun AlbumHeader(title: String, onBack: () -> Unit, trailing: (@Composable () -> Unit)? = null) {
    Box(Modifier.fillMaxWidth().windowInsetsPadding(WindowInsets.statusBars).padding(horizontal = Tokens.Sizes.globalHeaderInset).height(Tokens.Sizes.globalHeaderButton)) {
        HeaderCircle(Tokens.Icons.globalBack, stringRes(R.string.chat_thread_a11y_back), HeaderCircleFill.OnDeep, onBack, Modifier.align(Alignment.CenterStart))
        Line(
            title,
            Type.style(Tokens.FontSizes.weekRecapFontSizeTitle, Tokens.FontWeights.weekRecapFontWeightTitle),
            Tokens.Colors.globalTextPrimary,
            Modifier.align(Alignment.Center).padding(horizontal = Tokens.Sizes.globalHeaderButton + Tokens.Sizes.globalHeaderGap).semantics { heading() },
        )
        if (trailing != null) Box(Modifier.align(Alignment.CenterEnd)) { trailing() }
    }
}

@Composable
fun AlbumsListScreen(vm: AlbumsViewModel, onBack: () -> Unit, onAlbum: (String) -> Unit, onViewRecap: () -> Unit) {
    val state by vm.state.collectAsStateWithLifecycle()
    AlbumsListContent(state, onBack, onAlbum, onViewRecap, vm::load)
}

/**
 * albums.list: cards (`albums.list.dimension.cardHeight`, `.color.card`, `radius.global.card`)
 * stacked `size.global.listGap` apart with `size.global.screenMargin` margins; cover circle
 * (`size.global.avatarList`) at `.coverInset`, name (`listTitle`) over "saved by {name}" (`listSubtitle`).
 */
@Composable
fun AlbumsListContent(state: AlbumsState, onBack: () -> Unit, onAlbum: (String) -> Unit, onViewRecap: () -> Unit, onRetry: () -> Unit) {
    Column(Modifier.fillMaxSize().background(Tokens.Colors.globalBackgroundDeep).testTag("albums.list")) {
        AlbumHeader(stringRes(R.string.albums_list_title), onBack)
        Box(Modifier.weight(1f).fillMaxWidth()) {
            when {
                state.phase == AlbumsState.Phase.Loading -> LoadingHud()
                state.phase == AlbumsState.Phase.Error -> Centered { EmptyState(stringRes(R.string.albums_list_error_title), stringRes(R.string.chat_thread_error_detail), PillAction(stringRes(R.string.chat_thread_error_retry), null, onRetry)) }
                state.phase == AlbumsState.Phase.OfflineEmpty -> Centered { EmptyState(stringRes(R.string.chat_thread_offline_title), stringRes(R.string.chat_thread_offline_detail), null) }
                state.cards.isEmpty() -> Centered { EmptyState(stringRes(R.string.albums_list_empty_title), stringRes(R.string.albums_list_empty_detail), PillAction(stringRes(R.string.albums_list_empty_action), null, onViewRecap)) }
                else -> LazyColumn(
                    Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(start = Tokens.Sizes.globalScreenMargin, end = Tokens.Sizes.globalScreenMargin, bottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()),
                    verticalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalListGap),
                ) {
                    items(state.cards, key = { it.album.id }) { card -> AlbumCardRow(card) { onAlbum(card.album.id) } }
                }
            }
        }
    }
}

@Composable
private fun Centered(content: @Composable () -> Unit) = Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { content() }

@Composable
private fun AlbumCardRow(card: AlbumCard, onClick: () -> Unit) {
    val subtitle = stringRes(R.string.albums_list_row_subtitle, card.savedBy.orEmpty())
    val label = "${card.album.name}, $subtitle"
    Row(
        Modifier
            .fillMaxWidth()
            .heightIn(min = Tokens.Sizes.albumsListDimensionCardHeight)
            .clip(RoundedCornerShape(Tokens.Radii.globalCard))
            .background(Tokens.Colors.albumsListColorCard)
            .clickable(role = Role.Button, onClick = onClick)
            .clearAndSetSemantics { contentDescription = label; role = Role.Button }
            .padding(start = Tokens.Sizes.albumsListDimensionCoverInset),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Avatar(card.coverPath, Tokens.Sizes.globalAvatarList, fallbackIcon = Tokens.Icons.globalGallery)
        Spacer(Modifier.width(Tokens.Sizes.albumsListDimensionCoverToTitle))
        Column(Modifier.weight(1f).padding(end = Tokens.Sizes.albumsListDimensionCoverInset)) {
            Line(card.album.name, Type.listTitle(), Tokens.Colors.globalTextPrimary)
            Line(subtitle, Type.listSubtitle(), Tokens.Colors.globalTextSecondary)
        }
    }
}

data class AlbumViewState(
    val phase: Phase = Phase.Loading,
    val album: Album? = null,
    val photos: List<AlbumPhoto> = emptyList(),
    val canDelete: Boolean = false,
    val offline: Boolean = false,
    val renaming: Boolean = false,
    val renameName: String = "",
    val renameError: RenameError? = null,
    val busy: Boolean = false,
) {
    enum class Phase { Loading, Ready, NotFound, Error, OfflineEmpty }
}

enum class RenameError { Empty, Save }

data class AlbumPhoto(val post: Post, val thumbPath: String?, val authorName: String?)

sealed interface AlbumEffect {
    data object Renamed : AlbumEffect
    data object Deleted : AlbumEffect
    data object Failed : AlbumEffect
}

@Serializable
internal data class AlbumPayload(val album: Album? = null, val posts: List<Post> = emptyList(), val media: List<Media> = emptyList(), val profiles: List<Profile> = emptyList(), val canDelete: Boolean = false)

/**
 * `albums.view`: the album's items in `position` order, rename (optimistic: the title changes at
 * once and goes back if `rename_album` fails) and delete (creator or admin; `delete_album`).
 * `post_deleted` drops tiles.
 */
class AlbumViewModel(private val data: SocialData, private val groupId: String, private val albumId: String) : ViewModel() {
    private val _state = MutableStateFlow(AlbumViewState())
    val state: StateFlow<AlbumViewState> = _state.asStateFlow()
    private val _effects = MutableSharedFlow<AlbumEffect>(extraBufferCapacity = 8, onBufferOverflow = BufferOverflow.DROP_OLDEST)
    val effects: SharedFlow<AlbumEffect> = _effects.asSharedFlow()
    private var payload: AlbumPayload? = null
    private val removed = HashSet<String>()

    init {
        load()
        viewModelScope.launch { data.events(groupId).collect(::onEvent) }
        viewModelScope.launch { data.online.distinctUntilChanged().drop(1).collect { if (it) load() } }
    }

    fun load() {
        viewModelScope.launch {
            data.cached("album/$albumId", AlbumPayload.serializer()) { payload() }.collect { page ->
                val p = page.value
                when {
                    p != null -> publish(p, page.error == DataError.Network)
                    page.refreshing -> _state.update { if (it.album == null) it.copy(phase = AlbumViewState.Phase.Loading) else it }
                    else -> {
                        val e = page.error
                        _state.update {
                            it.copy(
                                phase = when {
                                    e == DataError.Network -> AlbumViewState.Phase.OfflineEmpty
                                    e is DataError.Api && e.code == ApiError.AlbumNotFound -> AlbumViewState.Phase.NotFound
                                    else -> AlbumViewState.Phase.Error
                                },
                            )
                        }
                    }
                }
            }
        }
    }

    private suspend fun payload(): AlbumPayload {
        val album = data.albums(groupId).firstOrNull { it.id == albumId } ?: return AlbumPayload()
        val items = data.albumItems(albumId).sortedBy { it.position }
        val posts = data.posts(items.map { it.postId })
        val media = data.media(posts.map { it.mediaId })
        val profiles = data.profiles(posts.map { it.authorId }.distinct())
        val me = data.currentUserId()
        val admin = runCatching { data.members(groupId) }.getOrDefault(emptyList()).any { it.member.userId == me && it.member.role == MemberRole.Admin }
        return AlbumPayload(album, posts, media, profiles, canDelete = admin || (me != null && album.createdBy == me))
    }

    private fun publish(p: AlbumPayload, offline: Boolean) {
        payload = p
        val album = p.album
        if (album == null) {
            _state.update { it.copy(phase = AlbumViewState.Phase.NotFound, album = null, photos = emptyList()) }
            return
        }
        val media = p.media.associateBy { it.id }
        val names = p.profiles.associate { it.id to it.firstName }
        val photos = p.posts.filter { it.id !in removed }.map { AlbumPhoto(it, media[it.mediaId]?.imagePath(Media.Rendition.Thumb), names[it.authorId]) }
        _state.update { it.copy(phase = AlbumViewState.Phase.Ready, album = it.album?.takeIf { a -> a.id == album.id && it.busy } ?: album, photos = photos, canDelete = p.canDelete, offline = offline) }
    }

    internal fun onEvent(event: GroupEvent) {
        if (event is GroupEvent.PostDeleted) {
            removed += event.postId
            payload?.let { publish(it, _state.value.offline) }
        }
    }

    fun startRename() = _state.update { it.copy(renaming = true, renameName = it.album?.name.orEmpty(), renameError = null) }
    fun cancelRename() = _state.update { it.copy(renaming = false, renameError = null) }
    fun setRenameName(name: String) = _state.update { it.copy(renameName = name, renameError = null) }

    fun rename() {
        val s = _state.value
        val album = s.album ?: return
        val name = s.renameName.trim()
        if (name.isEmpty()) {
            _state.update { it.copy(renameError = RenameError.Empty) }
            _effects.tryEmit(AlbumEffect.Failed)
            return
        }
        // Optimistic: the title changes at once.
        _state.update { it.copy(album = album.copy(name = name), renaming = false, busy = true) }
        viewModelScope.launch {
            try {
                val renamed = data.renameAlbum(album.id, name)
                _state.update { it.copy(album = renamed, busy = false) }
                _effects.emit(AlbumEffect.Renamed)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Throwable) {
                val invalid = e.dataError().let { it is DataError.Api && it.code == ApiError.InvalidName }
                _state.update { it.copy(album = album, busy = false, renaming = true, renameName = name, renameError = if (invalid) RenameError.Empty else RenameError.Save) }
                _effects.emit(AlbumEffect.Failed)
            }
        }
    }

    fun delete() {
        val album = _state.value.album ?: return
        _state.update { it.copy(busy = true) }
        viewModelScope.launch {
            try {
                data.deleteAlbum(album.id)
                _state.update { it.copy(busy = false) }
                _effects.emit(AlbumEffect.Deleted)
            } catch (e: CancellationException) {
                throw e
            } catch (_: Throwable) {
                _state.update { it.copy(busy = false) }
                _effects.emit(AlbumEffect.Failed)
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AlbumViewScreen(vm: AlbumViewModel, onBack: () -> Unit, onPhoto: (String) -> Unit) {
    val state by vm.state.collectAsStateWithLifecycle()
    val haptics = rememberHaptics()
    val view = LocalView.current
    var toast by remember { mutableStateOf<String?>(null) }
    val renamed = stringRes(R.string.albums_view_toast_renamed)
    val deleted = stringRes(R.string.albums_view_toast_deleted)
    val failed = stringRes(R.string.week_edit_error_save)
    LaunchedEffect(vm) {
        vm.effects.collect { e ->
            when (e) {
                AlbumEffect.Renamed -> { haptics.play(Tokens.Haptics.globalSuccess); toast = renamed }
                AlbumEffect.Deleted -> { announce(view, deleted); onBack() }
                AlbumEffect.Failed -> { haptics.play(Tokens.Haptics.globalError); if (!state.renaming) announce(view, failed) }
            }
        }
    }
    AlbumViewContent(
        state = state,
        onBack = onBack,
        onPhoto = onPhoto,
        onRetry = vm::load,
        onRename = vm::startRename,
        onDelete = { haptics.play(Tokens.Haptics.globalWarning); vm.delete() },
    )
    if (state.renaming) {
        val sheet = rememberModalBottomSheetState(skipPartiallyExpanded = true)
        ModalBottomSheet(onDismissRequest = vm::cancelRename, sheetState = sheet, containerColor = Tokens.Colors.globalBackgroundDeep) {
            RenameSheetContent(state, vm::setRenameName, vm::rename, vm::cancelRename)
        }
    }
    ConfirmationToast(toast) { toast = null }
}

/** The rename sheet: Yope's name sheet titled `albums.view.rename.title`, field prefilled. */
@Composable
fun RenameSheetContent(state: AlbumViewState, onName: (String) -> Unit, onSave: () -> Unit, onClose: () -> Unit) {
    NameSheet(
        title = stringRes(R.string.albums_view_rename_title),
        name = state.renameName,
        placeholder = stringRes(R.string.week_edit_album_nameplaceholder),
        error = when (state.renameError) {
            RenameError.Empty -> stringRes(R.string.week_edit_error_albumname)
            RenameError.Save -> stringRes(R.string.week_edit_error_save)
            null -> null
        },
        enabled = true,
        saving = state.busy,
        onName = onName,
        onSave = onSave,
        onClose = onClose,
    )
}

/**
 * albums.view: ‹ · album name · ••• circle (native menu: rename; delete album for its creator and
 * group admins, with the platform confirmation), and the album's photos in the week pics grid.
 */
@Composable
fun AlbumViewContent(
    state: AlbumViewState,
    onBack: () -> Unit,
    onPhoto: (String) -> Unit,
    onRetry: () -> Unit,
    onRename: () -> Unit,
    onDelete: () -> Unit,
    menuOpen: Boolean = false,
    confirmOpen: Boolean = false,
) {
    var menu by remember { mutableStateOf(menuOpen) }
    var confirm by remember { mutableStateOf(confirmOpen) }
    Column(Modifier.fillMaxSize().background(Tokens.Colors.globalBackground).testTag("albums.view")) {
        AlbumHeader(state.album?.name.orEmpty(), onBack, trailing = if (state.album == null) null else ({
            Box {
                HeaderCircle(Tokens.Icons.globalMore, stringRes(R.string.photo_viewer_a11y_more), HeaderCircleFill.OnDeep, { menu = true })
                DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                    DropdownMenuItem(
                        text = { Text(stringRes(R.string.albums_view_menu_rename)) },
                        leadingIcon = { Glyph(Tokens.Icons.globalEdit, Tokens.Colors.globalSystemOnSurface) },
                        onClick = { menu = false; onRename() },
                    )
                    if (state.canDelete) {
                        DropdownMenuItem(
                            text = { Text(stringRes(R.string.albums_view_menu_delete), color = Tokens.Colors.globalSystemError) },
                            leadingIcon = { Glyph(Tokens.Icons.photoViewerIconDelete, Tokens.Colors.globalSystemError) },
                            onClick = { menu = false; confirm = true },
                        )
                    }
                }
            }
        }))
        Box(Modifier.weight(1f).fillMaxWidth()) {
            when {
                state.phase == AlbumViewState.Phase.Loading -> LoadingHud()
                state.phase == AlbumViewState.Phase.NotFound -> Centered { EmptyState(stringRes(R.string.albums_view_empty_title), null, null) }
                state.phase == AlbumViewState.Phase.Error -> Centered { EmptyState(stringRes(R.string.albums_list_error_title), stringRes(R.string.chat_thread_error_detail), PillAction(stringRes(R.string.chat_thread_error_retry), null, onRetry)) }
                state.phase == AlbumViewState.Phase.OfflineEmpty -> Centered { EmptyState(stringRes(R.string.chat_thread_offline_title), stringRes(R.string.chat_thread_offline_detail), null) }
                state.photos.isEmpty() -> Centered { EmptyState(stringRes(R.string.albums_view_empty_title), stringRes(R.string.albums_view_empty_detail), null) }
                else -> LazyVerticalGrid(
                    columns = GridCells.Fixed(Tokens.Counts.weekRecapCountPicsColumns),
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(bottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()),
                    horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.weekRecapDimensionPicsGap),
                    verticalArrangement = Arrangement.spacedBy(Tokens.Sizes.weekRecapDimensionPicsGap),
                ) {
                    items(state.photos, key = { it.post.id }) { photo ->
                        val label = stringRes(R.string.photo_viewer_a11y_photo, photo.authorName.orEmpty(), Formats.viewerDate(photo.post.createdAt))
                        RemotePhoto(
                            photo.thumbPath,
                            null,
                            Modifier.fillMaxWidth().aspectRatio(Tokens.AspectRatios.weekRecapAspectRatioPicsTile)
                                .clickable(role = Role.Button) { onPhoto(photo.post.id) }
                                .clearAndSetSemantics { contentDescription = label; role = Role.Button },
                        )
                    }
                }
            }
            if (state.busy && !state.renaming) LoadingHud()
        }
    }
    if (confirm) {
        AlertDialog(
            onDismissRequest = { confirm = false },
            title = { Text(stringRes(R.string.albums_view_delete_title)) },
            text = { Text(stringRes(R.string.albums_view_delete_message)) },
            confirmButton = { TextButton(onClick = { confirm = false; onDelete() }) { Text(stringRes(R.string.albums_view_delete_confirm), color = Tokens.Colors.globalSystemError) } },
            dismissButton = { TextButton(onClick = { confirm = false }) { Text(stringRes(R.string.photo_viewer_delete_cancel)) } },
        )
    }
}
