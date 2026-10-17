// Surfaces: photo.viewer (the album picker, `photo.viewer.layout.albumPicker`) and albums.view (the add sheet,
// `albums.view.layout.add`) — albums anyone in the group can add to (owner decision 34, research #10).
// Specs: design/surfaces/photo.viewer.md "Album picker", design/surfaces/albums.view.md "Add sheet".
// References: references/auto/retro/store/editorial/retro-appstore-story-1854931006-week3-albums.png (album rows),
// references/auto/retro/press/tc-2025-12-rewind-panels.png (Rewind "Add to Album"); the pick grid is week.edit's
// (design/surfaces/week.edit.md, `week.edit.layout.selectionMark`).
package app.feature.social.albums

import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
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
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.toggleableState
import androidx.compose.ui.state.ToggleableState
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.social.common.Formats
import app.feature.social.common.LocalSocialData
import app.feature.social.common.RemotePhoto
import app.feature.social.common.stringRes
import app.feature.social.common.withVideoLabel
import app.feature.social.walls.ErrorLine
import app.feature.social.week.SelectionCheck
import app.ui.components.CircleButtonStyle
import app.ui.components.CircleIconButton
import app.ui.components.EmptyState
import app.ui.components.FormTextField
import app.ui.components.PlatformToast
import app.ui.components.PrimaryButton
import app.ui.components.PrimaryButtonSize
import app.ui.components.ThumbnailRow
import app.ui.components.ThumbnailRowSpacing
import app.ui.components.VideoTileMarker
import app.ui.foundation.DsMotion
import app.ui.foundation.tapClickable
import app.ui.haptics.rememberHaptics
import app.ui.system.DsBottomSheet
import app.ui.text.TextRoles

/** The C-29 sheet header: the C-11 close circle at the leading margin and the centred title (`sheetTitle`). */
@Composable
private fun LeadingCloseHeader(title: String, onClose: () -> Unit) {
    Box(
        Modifier.fillMaxWidth().heightIn(min = Tokens.Sizes.globalMinTouchTargetAndroid).padding(horizontal = Tokens.Sizes.globalScreenMargin),
        contentAlignment = Alignment.Center,
    ) {
        CircleIconButton(Tokens.Icons.globalClose, stringRes(R.string.photo_viewer_a11y_close), onClose, Modifier.align(Alignment.CenterStart), style = CircleButtonStyle.OnPage)
        Text(title, style = TextRoles.sheetTitle, color = Tokens.Colors.globalTextPrimary, modifier = Modifier.semantics { heading() })
    }
}

// MARK: photo.viewer album picker

/**
 * The album picker (C-29 sheet): "Add to Album"; `size.global.titleToContent` below, the "New Album" row (an empty cover)
 * then the group's albums as `albums.list`'s C-15 rows, newest first. A row adds the photo; "New Album" opens week.edit's
 * name sheet and saves a new album holding it. Failures keep the sheet open (`week.edit.error.save`).
 */
@Composable
fun AlbumPickerSheet(groupId: String, postId: String, onDone: () -> Unit, onDismiss: () -> Unit, session: Int = 0) {
    val data = LocalSocialData.current
    val albums = viewModel(key = "albums:$groupId:$session") { AlbumsViewModel(data, groupId) }
    // Each opening gets its own view model (a finished one would close the next at once).
    val vm = viewModel(key = "albumPicker:$postId:$session") { AlbumPickerViewModel(data, groupId, postId) }
    val list by albums.state.collectAsStateWithLifecycle()
    val state by vm.state.collectAsStateWithLifecycle()
    val context = LocalContext.current
    val haptics = rememberHaptics()
    val failed = stringRes(R.string.week_edit_error_save)
    val done by rememberUpdatedState(onDone)
    LaunchedEffect(state.done) { if (state.done) done() }
    LaunchedEffect(vm) {
        vm.effects.collect {
            haptics.perform(Tokens.Haptics.globalError)
            PlatformToast.show(context, failed)
        }
    }
    DsBottomSheet(onDismissRequest = onDismiss) {
        AlbumPickerContent(list, onClose = onDismiss, onNew = vm::startNaming, onAlbum = vm::add, onRetry = albums::load)
    }
    if (state.naming) {
        DsBottomSheet(onDismissRequest = vm::cancelNaming) {
            NewAlbumSheetContent(state, vm::setName, vm::create, vm::cancelNaming)
        }
    }
}

/** The picker's content (snapshot-free; semantics tests render it with fixed states). */
@Composable
fun AlbumPickerContent(list: AlbumsState, onClose: () -> Unit, onNew: () -> Unit, onAlbum: (String) -> Unit, onRetry: () -> Unit) {
    Column(Modifier.fillMaxWidth().testTag("photo.viewer.albumPicker")) {
        LeadingCloseHeader(stringRes(R.string.photo_viewer_menu_addtoalbum), onClose)
        LazyColumn(
            Modifier.fillMaxWidth(),
            contentPadding = PaddingValues(top = Tokens.Sizes.globalTitleToContent, bottom = Tokens.Sizes.globalSectionGap),
            verticalArrangement = ThumbnailRowSpacing,
        ) {
            item(key = "new") {
                val title = stringRes(R.string.week_edit_album_title)
                ThumbnailRow(title = title, subtitle = null, thumbnail = null, onClick = onNew, contentDescription = title)
            }
            when (list.phase) {
                AlbumsState.Phase.Loading -> items(PICKER_LOADING_ROWS) {
                    Box(
                        Modifier
                            .padding(start = Tokens.Sizes.globalScreenMargin)
                            .size(Tokens.Sizes.globalRowThumbWidth, Tokens.Sizes.globalRowThumbHeight)
                            .clip(RoundedCornerShape(Tokens.Radii.globalThumbnail))
                            .background(Tokens.Colors.globalControl),
                    )
                }
                AlbumsState.Phase.Error, AlbumsState.Phase.OfflineEmpty -> item(key = "error") {
                    ErrorLine(stringRes(R.string.albums_list_error_title), onRetry)
                }
                AlbumsState.Phase.Ready -> items(list.cards, key = { it.album.id }) { card -> AlbumRow(card) { onAlbum(card.album.id) } }
            }
        }
    }
}

/** Rows drawn while the albums load (`photo.viewer` → album picker: "three C-28 placeholder rows"). */
private const val PICKER_LOADING_ROWS = 3

/**
 * week.edit's album name sheet (C-29) for a new album holding this photo: "New Album", the C-12 field ("Name your album")
 * with its inline error "Name missing", the C-05 primary capsule "Create Album", disabled while the name is empty.
 */
@Composable
fun NewAlbumSheetContent(state: AlbumPickerState, onName: (String) -> Unit, onCreate: () -> Unit, onClose: () -> Unit) {
    var field by remember { mutableStateOf(TextFieldValue(state.name)) }
    Column(Modifier.fillMaxWidth().imePadding().testTag("photo.viewer.newAlbum")) {
        LeadingCloseHeader(stringRes(R.string.week_edit_album_title), onClose)
        Spacer(Modifier.height(Tokens.Sizes.globalTitleToContent))
        FormTextField(
            value = field,
            onValueChange = {
                field = it
                onName(it.text)
            },
            placeholder = stringRes(R.string.week_edit_album_nameplaceholder),
            accessibilityLabel = stringRes(R.string.week_edit_album_nameplaceholder),
            modifier = Modifier.padding(horizontal = Tokens.Sizes.globalScreenMargin),
            error = if (state.nameMissing) stringRes(R.string.week_edit_error_albumname) else null,
        )
        Spacer(Modifier.height(Tokens.Sizes.globalSectionGap))
        PrimaryButton(
            stringRes(R.string.week_edit_album_create),
            onCreate,
            Modifier.padding(horizontal = Tokens.Sizes.globalButtonMarginHSheet),
            enabled = field.text.isNotBlank(),
            size = PrimaryButtonSize.Sheet,
            loading = state.saving,
        )
        Spacer(Modifier.height(Tokens.Sizes.globalButtonMarginHSheet))
    }
}

// MARK: albums.view add sheet

/**
 * "Add Photos" (C-29 sheet): the group's photos the album lacks in week.edit's pick grid (`week.edit.count.gridColumns`
 * square cells, `size.global.stripGap` gaps, the pick mark `week.edit.layout.selectionMark`); the C-05 "Add" capsule at
 * the bottom, disabled until a photo is picked.
 */
@Composable
fun AlbumAddSheet(vm: AlbumAddViewModel, onDone: () -> Unit, onClose: () -> Unit) {
    val state by vm.state.collectAsStateWithLifecycle()
    val context = LocalContext.current
    val haptics = rememberHaptics()
    val failed = stringRes(R.string.week_edit_error_save)
    val done by rememberUpdatedState(onDone)
    LaunchedEffect(state.done) { if (state.done) done() }
    LaunchedEffect(vm) {
        vm.effects.collect {
            haptics.perform(Tokens.Haptics.globalError)
            PlatformToast.show(context, failed)
        }
    }
    DsBottomSheet(onDismissRequest = onClose) {
        AlbumAddContent(state, onToggle = { haptics.perform(Tokens.Haptics.globalSelect); vm.toggle(it) }, onAdd = vm::add, onRetry = vm::load, onClose = onClose)
    }
}

@Composable
fun AlbumAddContent(state: AlbumAddState, onToggle: (String) -> Unit, onAdd: () -> Unit, onRetry: () -> Unit, onClose: () -> Unit) {
    val margin = Tokens.Sizes.globalScreenMargin
    val gap = Tokens.Sizes.globalStripGap
    val columns = Tokens.Counts.weekEditCountGridColumns
    Column(Modifier.fillMaxWidth().testTag("albums.view.add")) {
        LeadingCloseHeader(stringRes(R.string.albums_view_menu_add), onClose)
        Box(Modifier.weight(1f, fill = false)) {
            when (state.phase) {
                AlbumAddState.Phase.Error, AlbumAddState.Phase.OfflineEmpty ->
                    ErrorLine(stringRes(R.string.albums_list_error_title), onRetry, Modifier.padding(top = Tokens.Sizes.globalTitleToContent))
                AlbumAddState.Phase.Empty -> Box(Modifier.fillMaxWidth().padding(vertical = Tokens.Sizes.globalSectionGap), contentAlignment = Alignment.Center) {
                    EmptyState(stringRes(R.string.albums_view_add_empty), null)
                }
                else -> LazyVerticalGrid(
                    columns = GridCells.Fixed(columns),
                    modifier = Modifier.fillMaxWidth(),
                    contentPadding = PaddingValues(start = margin, end = margin, top = Tokens.Sizes.globalTitleToContent, bottom = Tokens.Sizes.globalSectionGap),
                    horizontalArrangement = Arrangement.spacedBy(gap),
                    verticalArrangement = Arrangement.spacedBy(gap),
                ) {
                    if (state.phase == AlbumAddState.Phase.Loading) {
                        items(columns * 2) { Box(Modifier.aspectRatio(1f).background(Tokens.Colors.globalControl)) }
                    } else {
                        items(state.photos, key = { it.post.id }) { photo -> PickCell(photo, photo.post.id in state.picked) { onToggle(photo.post.id) } }
                    }
                }
            }
        }
        PrimaryButton(
            stringRes(R.string.albums_view_add_confirm),
            onAdd,
            Modifier.padding(horizontal = Tokens.Sizes.globalButtonMarginHSheet),
            enabled = state.canAdd,
            size = PrimaryButtonSize.Sheet,
            loading = state.saving,
        )
        Spacer(Modifier.height(Tokens.Sizes.globalButtonMarginHSheet))
    }
}

/** A photo of the add grid with week.edit's pick mark; TalkBack: a checkbox labelled with the photo. */
@Composable
private fun PickCell(photo: AlbumPhoto, checked: Boolean, onToggle: () -> Unit) {
    val label = withVideoLabel(LocalContext.current, stringRes(R.string.photo_viewer_a11y_photo, photo.authorName.orEmpty(), Formats.viewerDate(photo.post.createdAt)), photo.videoDurationMs)
    val mark = Tokens.Layouts.WeekEditLayoutSelectionMark
    BoxWithConstraints(
        Modifier
            .aspectRatio(1f)
            .tapClickable(role = Role.Checkbox, onClick = onToggle)
            .clearAndSetSemantics {
                contentDescription = label
                role = Role.Checkbox
                toggleableState = ToggleableState(checked)
            },
    ) {
        val cell = maxWidth
        val inset by animateDpAsState(if (checked) cell * mark.selectedInsetRatio else 0.dp, DsMotion.crossfade(), label = "inset")
        val corner by animateDpAsState(if (checked) cell * mark.selectedCornerRatio else 0.dp, DsMotion.crossfade(), label = "corner")
        val shown by animateFloatAsState(if (checked) 1f else 0f, DsMotion.crossfade(), label = "mark")
        Box(Modifier.fillMaxSize().graphicsLayer { alpha = shown }.background(Tokens.Colors.globalControl))
        RemotePhoto(photo.thumbPath, null, Modifier.fillMaxSize().padding(inset).clip(RoundedCornerShape(corner)))
        photo.videoDurationMs?.let { VideoTileMarker(it) }
        if (shown > 0f) SelectionCheck(Modifier.graphicsLayer { alpha = shown }.offset(cell * mark.markCentreRatio - Tokens.Sizes.globalCheckCircle / 2, cell * mark.markCentreRatio - Tokens.Sizes.globalCheckCircle / 2))
    }
}
