// Surfaces: albums.list, albums.view — design/surfaces/albums.list.md, albums.view.md
// References: references/auto/retro/store/editorial/retro-appstore-story-1854931006-week3-albums.png (pushed "Albums",
// search field, rows with 3:4 covers), references/auto/retro/press/tc-2024-04-journals-1.webp phones 2–3 (rows "daniel …";
// album sheet: cover, serif name, meta, capsules, 3-column grid with rounded outer corners),
// references/auto/retro/web/retro.app-42b38811bebcd07d.css (grid outer radius .75rem, 2-px gaps).
@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)

package app.feature.social.albums

import androidx.compose.foundation.background
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
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.paddingFromBaseline
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.itemsIndexed
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.social.common.Formats
import app.feature.social.common.RemotePhoto
import app.feature.social.common.photoModel
import app.feature.social.common.stringRes
import app.feature.social.walls.ErrorLine
import app.ui.components.Capsule
import app.ui.components.CapsuleStyle
import app.ui.components.CircleButtonStyle
import app.ui.components.CircleIconButton
import app.ui.components.EmptyState
import app.ui.components.EmptyStateAction
import app.ui.components.EmptyStateFill
import app.ui.components.FormTextField
import app.ui.components.IconCapsule
import app.ui.components.PlatformToast
import app.ui.components.PrimaryButton
import app.ui.components.PrimaryButtonSize
import app.ui.components.PushedHeader
import app.ui.components.SearchField
import app.ui.components.ThumbnailRow
import app.ui.components.ThumbnailRowSpacing
import app.ui.components.subtitleWithActor
import app.ui.foundation.PageRoles
import app.ui.foundation.endAtLastBaseline
import app.ui.foundation.tapClickable
import app.ui.haptics.rememberHaptics
import app.ui.system.DsBottomSheet
import app.ui.system.DsDropdownMenu
import app.ui.system.DsMenuItem
import app.ui.system.SystemAlertDialog
import app.ui.text.CapTop
import app.ui.text.TextRoles
import app.ui.text.capTopAt

@Composable
fun AlbumsListScreen(vm: AlbumsViewModel, onBack: () -> Unit, onAlbum: (String) -> Unit, onViewRecaps: () -> Unit) {
    val state by vm.state.collectAsStateWithLifecycle()
    AlbumsListContent(state, onBack, onAlbum, onViewRecaps, onRetry = vm::load, onQuery = vm::setQuery)
}

/**
 * `albums.list` (Retro's Albums list): C-02 "Albums"; the C-12 search field `size.global.titleToContent` below the title
 * baseline (when the group has albums); C-15 rows newest first, the first `size.global.titleToContent` below the field,
 * `size.global.listGap` apart — cover thumbnail, album name (`listTitle`, up to two lines) over "{name} created the album"
 * (the name semibold; yours "you created the album"). No stack, no "+" (RS-21).
 */
@Composable
fun AlbumsListContent(state: AlbumsState, onBack: () -> Unit, onAlbum: (String) -> Unit, onViewRecaps: () -> Unit, onRetry: () -> Unit, onQuery: (String) -> Unit) {
    var query by remember { mutableStateOf(TextFieldValue(state.query)) }
    val bottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    val hasAlbums = state.cards.isNotEmpty()
    Column(Modifier.fillMaxSize().background(PageRoles.page).statusBarsPadding().testTag("albums.list")) {
        PushedHeader(
            stringRes(R.string.albums_list_title),
            onBack,
            stringRes(R.string.chat_thread_a11y_back),
            below = if (hasAlbums) ({
                SearchField(
                    value = query,
                    onValueChange = {
                        query = it
                        onQuery(it.text)
                    },
                    placeholder = stringRes(R.string.albums_list_search),
                    accessibilityLabel = stringRes(R.string.albums_list_search),
                )
            }) else null,
        )
        when {
            state.phase == AlbumsState.Phase.Loading -> Column(Modifier.padding(top = Tokens.Sizes.globalTitleToContent), verticalArrangement = ThumbnailRowSpacing) {
                repeat(LOADING_ROWS) {
                    Box(
                        Modifier
                            .padding(start = Tokens.Sizes.globalScreenMargin)
                            .size(Tokens.Sizes.globalRowThumbWidth, Tokens.Sizes.globalRowThumbHeight)
                            .clip(RoundedCornerShape(Tokens.Radii.globalThumbnail))
                            .background(Tokens.Colors.globalControl),
                    )
                }
            }
            (state.phase == AlbumsState.Phase.Error || state.phase == AlbumsState.Phase.OfflineEmpty) && !hasAlbums -> ErrorLine(stringRes(R.string.albums_list_error_title), onRetry)
            !hasAlbums -> EmptyStateFill(Modifier.weight(1f).padding(bottom = bottom)) {
                EmptyState(
                    stringRes(R.string.albums_list_empty_title),
                    stringRes(R.string.albums_list_empty_detail),
                    action = EmptyStateAction(stringRes(R.string.albums_list_empty_action), onViewRecaps),
                    icon = Tokens.Icons.globalAlbums,
                )
            }
            state.shown.isEmpty() -> Box(Modifier.fillMaxWidth().padding(top = Tokens.Sizes.globalTitleToContent), contentAlignment = Alignment.TopCenter) {
                EmptyState(stringRes(R.string.albums_list_search_empty), null)
            }
            else -> LazyColumn(
                Modifier.fillMaxSize(),
                contentPadding = PaddingValues(top = Tokens.Sizes.globalTitleToContent, bottom = bottom + Tokens.Sizes.globalSectionGap),
                verticalArrangement = ThumbnailRowSpacing,
            ) {
                items(state.shown, key = { it.album.id }) { card -> AlbumRow(card) { onAlbum(card.album.id) } }
            }
        }
    }
}

/** Rows drawn while loading (`albums.list` → loading: "three C-15 rows"). */
private const val LOADING_ROWS = 3

/** The context line of an album (`albums.list.row.subtitle` / `.subtitleMine`), the creator's name semibold. */
@Composable
private fun albumSubtitle(name: String?, mine: Boolean): androidx.compose.ui.text.AnnotatedString =
    if (mine) subtitleWithActor(stringRes(R.string.albums_list_row_subtitlemine), "")
    else subtitleWithActor(stringRes(R.string.albums_list_row_subtitle, name.orEmpty()), name.orEmpty())

@Composable
private fun AlbumRow(card: AlbumCard, onClick: () -> Unit) {
    val subtitle = albumSubtitle(card.savedBy, card.mine)
    ThumbnailRow(
        title = card.album.name,
        subtitle = subtitle,
        thumbnail = photoModel(card.coverPath),
        onClick = onClick,
        contentDescription = card.album.name + ", " + subtitle.text,
    )
}

/** Transient UI state of the album sheet (menu, rename sheet, delete alert). */
class AlbumUiState(menu: Boolean = false, confirmDelete: Boolean = false) {
    var menu by mutableStateOf(menu)
    var confirmDelete by mutableStateOf(confirmDelete)
}

/** `albums.view` as a page sheet (C-29) over `albums.list`. */
@Composable
fun AlbumViewSheet(vm: AlbumViewModel, onClose: () -> Unit, onPhoto: (String) -> Unit) {
    val state by vm.state.collectAsStateWithLifecycle()
    val context = LocalContext.current
    val haptics = rememberHaptics()
    val renamed = stringRes(R.string.albums_view_toast_renamed)
    val deleted = stringRes(R.string.albums_view_toast_deleted)
    val failed = stringRes(R.string.week_edit_error_save)
    val latest by rememberUpdatedState(state)
    LaunchedEffect(vm) {
        vm.effects.collect { effect ->
            when (effect) {
                AlbumEffect.Renamed -> { haptics.perform(Tokens.Haptics.globalSuccess); PlatformToast.show(context, renamed) }
                AlbumEffect.Deleted -> { PlatformToast.show(context, deleted); onClose() }
                AlbumEffect.Failed -> {
                    haptics.perform(Tokens.Haptics.globalError)
                    if (latest.renameError != RenameError.Empty) PlatformToast.show(context, failed)
                }
            }
        }
    }
    val ui = remember { AlbumUiState() }
    DsBottomSheet(onDismissRequest = onClose) {
        AlbumViewContent(state, ui, onPhoto, onRename = vm::startRename, onRetry = vm::load)
    }
    if (state.renaming) {
        DsBottomSheet(onDismissRequest = vm::cancelRename) { RenameSheetContent(state, vm::setRenameName, vm::rename, vm::cancelRename) }
    }
    if (ui.confirmDelete) {
        SystemAlertDialog(
            title = stringRes(R.string.albums_view_delete_title),
            text = stringRes(R.string.albums_view_delete_message),
            confirmLabel = stringRes(R.string.albums_view_delete_confirm),
            onConfirm = {
                ui.confirmDelete = false
                haptics.perform(Tokens.Haptics.globalWarning)
                vm.delete()
            },
            dismissLabel = stringRes(R.string.photo_viewer_delete_cancel),
            onDismiss = { ui.confirmDelete = false },
            destructive = true,
        )
    }
}

/**
 * The album sheet's content (`albums.view`): the cover centred `albums.view.dimension.coverTop` below the sheet top
 * (`.coverWidth` × `.coverHeight`, `radius.global.thumbnail`; its shadow `albums.view.shadow.cover` is BLOCKED → flat);
 * the name (`displayMedium` serif, ≤ 2 lines) cap top `.coverToTitle` below; the meta baseline `.titleToMeta` below the
 * name's; the action row `.metaToActions` below — "Rename" filling it and, for the creator and admins, the "•••" icon
 * capsule (menu: "Delete Album", red); the grid `walls.mine.dimension.actionsToWeeks` below: 3 columns of 4:5 cells
 * (`albums.view.aspectRatio.gridCell`), `size.global.stripGap` gaps, outer corners `albums.view.radius.grid`.
 */
@Composable
fun AlbumViewContent(state: AlbumViewState, ui: AlbumUiState, onPhoto: (String) -> Unit, onRename: () -> Unit, onRetry: () -> Unit) {
    val margin = Tokens.Sizes.globalScreenMargin
    val gap = Tokens.Sizes.globalStripGap
    val columns = Tokens.Counts.albumsViewCountGridColumns
    val album = state.album
    if (state.phase == AlbumViewState.Phase.NotFound) {
        Box(Modifier.fillMaxWidth().padding(vertical = Tokens.Sizes.albumsViewDimensionCoverHeight / 2), contentAlignment = Alignment.Center) {
            EmptyState(stringRes(R.string.albums_view_notfound), null)
        }
        return
    }
    val photos = state.photos
    LazyVerticalGrid(
        columns = GridCells.Fixed(columns),
        modifier = Modifier.fillMaxWidth().testTag("albums.view"),
        contentPadding = PaddingValues(start = margin, end = margin, bottom = Tokens.Sizes.globalSectionGap),
        horizontalArrangement = Arrangement.spacedBy(gap),
        verticalArrangement = Arrangement.spacedBy(gap),
    ) {
        item(key = "head", span = { GridItemSpan(maxLineSpan) }) {
            AlbumHead(state, ui, onPhoto, onRename)
        }
        when {
            state.phase == AlbumViewState.Phase.Loading -> itemsIndexed(List(columns * 2) { it }, key = { _, i -> "loading-$i" }) { i, _ ->
                Box(Modifier.aspectRatio(Tokens.AspectRatios.albumsViewAspectRatioGridCell).clip(gridCellShape(i, columns * 2, columns)).background(Tokens.Colors.globalControl))
            }
            state.phase == AlbumViewState.Phase.Error || state.phase == AlbumViewState.Phase.OfflineEmpty -> item(key = "error", span = { GridItemSpan(maxLineSpan) }) {
                // The grid already sits inside `size.global.screenMargin`: the list-error line without its own margin.
                Text(
                    stringRes(R.string.albums_list_error_title),
                    style = TextRoles.body,
                    color = PageRoles.secondaryText(),
                    modifier = Modifier.fillMaxWidth().tapClickable(onClick = onRetry),
                )
            }
            photos.isEmpty() && album != null -> item(key = "empty", span = { GridItemSpan(maxLineSpan) }) {
                Box(Modifier.fillMaxWidth().padding(vertical = Tokens.Sizes.globalSectionGap), contentAlignment = Alignment.Center) {
                    EmptyState(stringRes(R.string.albums_view_empty_title), stringRes(R.string.albums_view_empty_detail))
                }
            }
            else -> itemsIndexed(photos, key = { _, p -> p.post.id }) { i, p ->
                val date = Formats.viewerDate(p.post.createdAt)
                val label = stringRes(R.string.photo_viewer_a11y_photo, p.authorName.orEmpty(), date)
                RemotePhoto(
                    p.thumbPath,
                    null,
                    Modifier
                        .aspectRatio(Tokens.AspectRatios.albumsViewAspectRatioGridCell)
                        .clip(gridCellShape(i, photos.size, columns))
                        .tapClickable { onPhoto(p.post.id) }
                        .clearAndSetSemantics {
                            contentDescription = label
                            role = Role.Button
                        },
                )
            }
        }
    }
}

/** Cover, name, meta and capsules above the grid. */
@Composable
private fun AlbumHead(state: AlbumViewState, ui: AlbumUiState, onPhoto: (String) -> Unit, onRename: () -> Unit) {
    val album = state.album
    val first = state.photos.firstOrNull()
    val name = album?.name.orEmpty()
    val coverLabel = stringRes(R.string.albums_view_a11y_cover, name)
    val titleStyle = TextRoles.albumTitle
    Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
        Spacer(Modifier.height(Tokens.Sizes.albumsViewDimensionCoverTop))
        RemotePhoto(
            first?.thumbPath,
            null,
            Modifier
                .size(Tokens.Sizes.albumsViewDimensionCoverWidth, Tokens.Sizes.albumsViewDimensionCoverHeight)
                .clip(RoundedCornerShape(Tokens.Radii.globalThumbnail))
                .then(if (first != null) Modifier.tapClickable { onPhoto(first.post.id) } else Modifier)
                .clearAndSetSemantics {
                    contentDescription = coverLabel
                    if (first != null) role = Role.Button
                },
        )
        if (album != null) {
            Text(
                name,
                style = titleStyle,
                color = Tokens.Colors.globalTextPrimary,
                textAlign = TextAlign.Center,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.capTopAt(Tokens.Sizes.albumsViewDimensionCoverToTitle, CapTop.height(titleStyle)).endAtLastBaseline().semantics { heading() },
            )
            val subtitle = if (state.mine) stringRes(R.string.albums_list_row_subtitlemine) else stringRes(R.string.albums_list_row_subtitle, state.creatorName.orEmpty())
            Text(
                subtitle,
                style = TextRoles.listSubtitle,
                color = PageRoles.secondaryText(),
                textAlign = TextAlign.Center,
                modifier = Modifier.paddingFromBaseline(top = Tokens.Sizes.albumsViewDimensionTitleToMeta).endAtLastBaseline(),
            )
            Row(Modifier.fillMaxWidth().padding(top = Tokens.Sizes.albumsViewDimensionMetaToActions), horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalPillGap)) {
                Capsule(stringRes(R.string.albums_view_menu_rename), onRename, Modifier.weight(1f), style = CapsuleStyle.Outline)
                if (state.canDelete) {
                    Box {
                        IconCapsule(Tokens.Icons.globalMore, stringRes(R.string.albums_view_a11y_more), { ui.menu = true })
                        DsDropdownMenu(ui.menu, { ui.menu = false }, listOf(DsMenuItem(stringRes(R.string.albums_view_menu_delete), { ui.confirmDelete = true }, destructive = true)))
                    }
                }
            }
        }
        Spacer(Modifier.height(Tokens.Sizes.wallsMineDimensionActionsToWeeks - Tokens.Sizes.globalStripGap))
    }
}

/**
 * The album grid's outer contour (`albums.view.radius.grid`, retro.app's corner classes): the first row's end cells round
 * their top corners; the last row's first cell its bottom-leading and its last cell its bottom-trailing corner; when the
 * last row is short, the trailing cell of the row above also rounds its bottom-trailing corner. Inner corners stay square.
 */
fun gridCellShape(index: Int, count: Int, columns: Int, radius: Dp = Tokens.Radii.albumsViewRadiusGrid): Shape {
    if (count <= 0) return RectangleShape
    val row = index / columns
    val col = index % columns
    val lastRow = (count - 1) / columns
    val lastInRow = minOf((row + 1) * columns, count) - 1
    val topStart = row == 0 && col == 0
    val topEnd = row == 0 && index == lastInRow
    val bottomStart = row == lastRow && col == 0
    val bottomEnd = (row == lastRow && index == count - 1) || (row == lastRow - 1 && col == columns - 1 && count % columns != 0)
    if (!topStart && !topEnd && !bottomStart && !bottomEnd) return RectangleShape
    val zero = Tokens.Radii.globalPhoto
    return RoundedCornerShape(
        topStart = if (topStart) radius else zero,
        topEnd = if (topEnd) radius else zero,
        bottomStart = if (bottomStart) radius else zero,
        bottomEnd = if (bottomEnd) radius else zero,
    )
}

/**
 * The rename sheet (C-29): C-11 close circle + the centred `albums.view.rename.title`; the C-12 field prefilled with the
 * name `size.global.titleToContent` below (inline error "Name missing"); the C-05 primary capsule "Save", disabled while
 * empty.
 */
@Composable
fun RenameSheetContent(state: AlbumViewState, onName: (String) -> Unit, onSave: () -> Unit, onClose: () -> Unit) {
    var field by remember { mutableStateOf(TextFieldValue(state.renameName)) }
    val margin = Tokens.Sizes.globalScreenMargin
    Column(Modifier.fillMaxWidth().imePadding().testTag("albums.view.rename")) {
        Box(Modifier.fillMaxWidth().heightIn(min = Tokens.Sizes.globalMinTouchTargetAndroid).padding(horizontal = margin), contentAlignment = Alignment.Center) {
            CircleIconButton(Tokens.Icons.globalClose, stringRes(R.string.week_recap_a11y_close), onClose, Modifier.align(Alignment.CenterStart), style = CircleButtonStyle.OnPage)
            Text(stringRes(R.string.albums_view_rename_title), style = TextRoles.sheetTitle, color = Tokens.Colors.globalTextPrimary, modifier = Modifier.semantics { heading() })
        }
        Spacer(Modifier.height(Tokens.Sizes.globalTitleToContent))
        FormTextField(
            value = field,
            onValueChange = {
                field = it
                onName(it.text)
            },
            placeholder = stringRes(R.string.week_edit_album_nameplaceholder),
            accessibilityLabel = stringRes(R.string.albums_view_rename_title),
            modifier = Modifier.padding(horizontal = margin),
            error = if (state.renameError == RenameError.Empty) stringRes(R.string.week_edit_error_albumname) else null,
        )
        Spacer(Modifier.height(Tokens.Sizes.globalSectionGap))
        PrimaryButton(
            stringRes(R.string.albums_view_rename_save),
            onSave,
            Modifier.padding(horizontal = Tokens.Sizes.globalButtonMarginHSheet),
            enabled = field.text.isNotEmpty(),
            size = PrimaryButtonSize.Sheet,
            loading = state.busy,
        )
        Spacer(Modifier.height(Tokens.Sizes.globalButtonMarginHSheet))
    }
}
