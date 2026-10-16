// Surface: week.edit — design/surfaces/week.edit.md
// References: references/auto/retro/video/ig-DDbA_F7x-j7-composer-f130-147-f188-197.png ("Add to Your Week": Cancel /
// title / Update, chosen-photos strip, grey header line, 4-column grid), references/auto/retro/press/tc-2023-12-retro3.png
// phones 2–3 ("Add Message" pill, "Add a Message" modal with Done and counter), references/auto/retro/apk/
// retro-android-2026.10.1150-strings.txt ("New Album", "Name your album", "Create Album").
@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)

package app.feature.social.week

import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectDragGesturesAfterLongPress
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.paddingFrom
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Icon
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
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.LastBaseline
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.zIndex
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.social.common.BuildApproximations
import app.feature.social.common.Formats
import app.feature.social.common.LocalApproximations
import app.feature.social.common.RemotePhoto
import app.feature.social.common.SocialBlocked
import app.feature.social.common.namedHaptic
import app.feature.social.common.photoModel
import app.feature.social.common.stringRes
import app.ui.components.ActivityIndicator
import app.ui.components.CircleButtonStyle
import app.ui.components.CircleIconButton
import app.ui.components.DayTile
import app.ui.components.DayTileView
import app.ui.components.FormTextField
import app.ui.components.HeaderTextButton
import app.ui.components.OutlineCta
import app.ui.components.Capsule
import app.ui.components.CapsuleStyle
import app.ui.components.PlatformToast
import app.ui.components.PrimaryButton
import app.ui.components.PrimaryButtonSize
import app.ui.components.stripTileShape
import app.ui.foundation.DsMotion
import app.ui.foundation.PageRoles
import app.ui.foundation.reduceMotion
import app.ui.foundation.tapClickable
import app.ui.haptics.rememberHaptics
import app.ui.system.DsBottomSheet
import app.ui.system.SheetHeader
import app.ui.system.SheetTextAction
import app.ui.system.SystemAlertDialog
import app.ui.text.TextRoles
import java.time.ZoneId

/**
 * `week.edit` as a page sheet (C-29) over its opener: the recap editor, or — from `week.recap`'s pill or a
 * `week.history` week menu ([WeekEditViewModel] `albumOnly`) — the album sheet alone. [onClose] pops the route.
 */
@Composable
fun WeekEditSheet(vm: WeekEditViewModel, onClose: () -> Unit) {
    val state by vm.state.collectAsStateWithLifecycle()
    val context = LocalContext.current
    val haptics = rememberHaptics()
    val saved = stringRes(R.string.week_edit_toast_saved)
    val albumSaved = stringRes(R.string.week_edit_toast_albumsaved)
    val failed = stringRes(R.string.week_edit_error_save)
    val latest by rememberUpdatedState(state)
    LaunchedEffect(vm) {
        vm.effects.collect { effect ->
            when (effect) {
                EditEffect.Saved -> { haptics.perform(Tokens.Haptics.globalSuccess); PlatformToast.show(context, saved) }
                EditEffect.AlbumSaved -> { haptics.perform(Tokens.Haptics.globalSuccess); PlatformToast.show(context, albumSaved) }
                EditEffect.Failed -> {
                    haptics.perform(Tokens.Haptics.globalError)
                    if (latest.error == EditError.Save || latest.albumError == EditError.Save) PlatformToast.show(context, failed)
                }
                EditEffect.Close -> onClose()
            }
        }
    }
    var confirmDiscard by remember { mutableStateOf(false) }
    val cancel = { if (state.dirty) confirmDiscard = true else onClose() }
    if (!state.albumSheet || !vm.albumOnly) {
        DsBottomSheet(onDismissRequest = cancel) {
            WeekEditContent(
                state = state,
                onCancel = cancel,
                onSave = vm::save,
                onToggle = vm::toggle,
                onMove = vm::move,
                onMessage = vm::openMessage,
                onAlbum = vm::openAlbumSheet,
            )
        }
    }
    if (state.messageSheet) {
        DsBottomSheet(onDismissRequest = vm::closeMessage) { MessageSheetContent(state.text, vm::setText, vm::closeMessage) }
    }
    if (state.albumSheet) {
        DsBottomSheet(onDismissRequest = vm::closeAlbumSheet) { AlbumSheetContent(state, vm::setAlbumName, vm::saveAlbum, vm::closeAlbumSheet) }
    }
    if (confirmDiscard) {
        SystemAlertDialog(
            title = stringRes(R.string.week_edit_lostchanges_title),
            text = stringRes(R.string.week_edit_lostchanges_message),
            confirmLabel = stringRes(R.string.week_edit_lostchanges_confirm),
            onConfirm = { confirmDiscard = false; onClose() },
            dismissLabel = stringRes(R.string.photo_viewer_delete_cancel),
            onDismiss = { confirmDiscard = false },
            destructive = true,
        )
    }
}

/**
 * The editor (`week.edit.layout.composition`): native toolbar Cancel / "Edit Recap" / Update (system tint, C-08); the
 * chosen-photos strip (C-17, recap order; touch and hold to reorder — `week.edit.layout.reorder`); the action row
 * (C-06 outline capsules of equal widths: `icon.global.edit` + "Add a message" / "Edit message", "Save as Album");
 * the header line "Photos taken in Week 27" (`listSubtitle`, secondary); the 4-column grid of the week's photos
 * (square cells, `size.global.stripGap`), tap toggles in / out of the recap. Blocks `size.global.sectionGap` apart.
 */
@Composable
fun WeekEditContent(
    state: EditState,
    onCancel: () -> Unit,
    onSave: () -> Unit,
    onToggle: (String) -> Unit,
    onMove: (String, Int) -> Unit,
    onMessage: () -> Unit,
    onAlbum: () -> Unit,
) {
    val haptics = rememberHaptics()
    val margin = Tokens.Sizes.globalScreenMargin
    val gap = Tokens.Sizes.globalStripGap
    Column(Modifier.fillMaxWidth().testTag("week.edit")) {
        Box(Modifier.fillMaxWidth()) {
            SheetHeader(
                stringRes(R.string.week_edit_title),
                leading = SheetTextAction(stringRes(R.string.week_edit_cancel), onCancel),
                trailing = if (state.saving) null else SheetTextAction(stringRes(R.string.week_edit_save), onSave, enabled = state.phase == EditState.Phase.Ready),
            )
            if (state.saving) ActivityIndicator(stringRes(R.string.week_history_a11y_loading), Modifier.align(Alignment.CenterEnd).padding(end = margin).size(Tokens.Sizes.globalIcon))
        }
        when (state.phase) {
            EditState.Phase.NotReady, EditState.Phase.Error -> Box(Modifier.fillMaxWidth().padding(vertical = Tokens.Sizes.globalButtonHeight), contentAlignment = Alignment.Center) {
                Text(
                    stringRes(if (state.phase == EditState.Phase.NotReady) R.string.week_edit_error_notready else R.string.week_edit_error_save),
                    style = TextRoles.body,
                    color = PageRoles.secondaryText(),
                    modifier = Modifier.padding(horizontal = margin),
                )
            }
            else -> LazyVerticalGrid(
                columns = GridCells.Fixed(Tokens.Counts.weekEditCountGridColumns),
                contentPadding = PaddingValues(start = margin, end = margin, bottom = Tokens.Sizes.globalSectionGap),
                horizontalArrangement = Arrangement.spacedBy(gap),
                verticalArrangement = Arrangement.spacedBy(gap),
            ) {
                item(key = "strip", span = { GridItemSpan(maxLineSpan) }) {
                    Box(Modifier.padding(top = Tokens.Sizes.globalSectionHeaderToContent)) {
                        ChosenStrip(state, onMove, Modifier.fillMaxWidth())
                    }
                }
                item(key = "actions", span = { GridItemSpan(maxLineSpan) }) {
                    Row(Modifier.fillMaxWidth().padding(top = Tokens.Sizes.globalSectionGap), horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalPillGap)) {
                        OutlineCta(
                            stringRes(if (state.text.isBlank()) R.string.week_edit_message_add else R.string.week_edit_message_edit),
                            onMessage,
                            Modifier.weight(1f),
                            icon = Tokens.Icons.globalEdit,
                        )
                        Capsule(stringRes(R.string.week_edit_saveasalbum), onAlbum, Modifier.weight(1f), style = CapsuleStyle.Outline)
                    }
                }
                item(key = "header", span = { GridItemSpan(maxLineSpan) }) {
                    val week = state.weekStart?.let(Formats::isoWeek)
                    Text(
                        week?.let { stringRes(R.string.week_edit_header, it) }.orEmpty(),
                        style = TextRoles.listSubtitle,
                        color = PageRoles.secondaryText(),
                        modifier = Modifier
                            .padding(top = Tokens.Sizes.globalSectionGap)
                            .paddingFrom(LastBaseline, after = Tokens.Sizes.globalSectionHeaderToContent - gap),
                    )
                }
                if (state.phase == EditState.Phase.Loading) {
                    items(PLACEHOLDER_CELLS) { Box(Modifier.aspectRatio(1f).background(Tokens.Colors.globalControl)) }
                } else {
                    items(state.photos, key = { it.post.id }) { photo ->
                        GridCell(photo, photo.post.id in state.checked, state, onToggle = {
                            haptics.perform(Tokens.Haptics.globalSelect)
                            onToggle(photo.post.id)
                        })
                    }
                }
            }
        }
    }
}

/** Grid rows drawn while loading (two rows of four C-17 placeholders, VID-COMP grey placeholders). */
private val PLACEHOLDER_CELLS: Int get() = Tokens.Counts.weekEditCountGridColumns * 2

/** One grid cell: the photo (square, aspect fill), its in / out mark (`week.edit.layout.selectionMark`, BLOCKED). */
@Composable
private fun GridCell(photo: WeekPhoto, checked: Boolean, state: EditState, onToggle: () -> Unit) {
    val zone = ZoneId.systemDefault()
    val day = photo.post.createdAt.atZone(zone).toLocalDate()
    val label = stringRes(R.string.week_history_a11y_tile, Formats.weekdayLong(day), Formats.spokenDate(day), photo.authorName.orEmpty())
    val value = stringRes(if (checked) R.string.week_edit_a11y_inrecap else R.string.week_edit_a11y_notinrecap)
    val mark = SocialBlocked.editSelectionMark || LocalApproximations.current
    Box(
        Modifier
            .aspectRatio(1f)
            .tapClickable(role = Role.Checkbox, onClick = onToggle)
            .clearAndSetSemantics {
                contentDescription = label
                stateDescription = value
                role = Role.Checkbox
            },
    ) {
        RemotePhoto(photo.thumbPath, null, Modifier.fillMaxSize())
        if (mark) {
            Icon(
                if (checked) Tokens.Icons.globalCheck else Tokens.Icons.globalUncheck,
                contentDescription = null,
                tint = Tokens.Colors.globalTextOnMedia,
                modifier = Modifier.align(Alignment.TopEnd).padding(BuildApproximations.SELECTION_MARK_INSET).size(Tokens.Sizes.globalCheckCircle),
            )
        }
    }
}

/**
 * The chosen-photos strip (C-17 photo tiles in recap order). Reorder (`week.edit.layout.reorder`, Apple / Google Photos):
 * touch and hold a tile, drag, release; the tile follows the finger, the others shift with `duration.global.stripInsert`
 * (`easing.global.standard`; snaps under Reduce Motion); haptics `week.edit.haptic.dragStart` / `.dragAlign`. The spec's
 * TalkBack "move earlier / later" actions have no copy keys yet (reported), so they are not offered. Empty strip
 * (nothing chosen): one placeholder tile.
 */
@Composable
private fun ChosenStrip(state: EditState, onMove: (String, Int) -> Unit, modifier: Modifier) {
    val haptics = rememberHaptics()
    val reduce = reduceMotion()
    val listState = rememberLazyListState()
    val zone = ZoneId.systemDefault()
    val strip = state.strip
    var dragging by remember { mutableStateOf<String?>(null) }
    var pointer by remember { mutableStateOf(Offset.Zero) }
    var grab by remember { mutableStateOf(Offset.Zero) }
    val checked by rememberUpdatedState(state.checked)
    val tiles: List<DayTile> = if (state.phase == EditState.Phase.Loading) List(Tokens.Counts.weekEditCountGridColumns) { DayTile.Placeholder("loading-$it") }
    else if (strip.isEmpty()) listOf(DayTile.Placeholder("empty"))
    else strip.map { p ->
        val day = p.post.createdAt.atZone(zone).toLocalDate()
        DayTile.Photo(p.post.id, photoModel(p.thumbPath), Formats.weekdayShort(day), stringRes(R.string.week_history_a11y_tile, Formats.weekdayLong(day), Formats.spokenDate(day), p.authorName.orEmpty()))
    }
    fun itemAt(x: Float) = listState.layoutInfo.visibleItemsInfo.firstOrNull { x >= it.offset && x < it.offset + it.size }
    val dragStart = namedHaptic(Tokens.Layouts.WeekEditHapticDragStart.android, noneBelow34 = true)
    val dragAlign = namedHaptic(Tokens.Layouts.WeekEditHapticDragAlign.android)
    LazyRow(
        state = listState,
        modifier = modifier.pointerInput(Unit) {
            detectDragGesturesAfterLongPress(
                onDragStart = { offset ->
                    val item = itemAt(offset.x)
                    val id = item?.key as? String
                    if (item != null && id != null && id in checked) {
                        dragging = id
                        pointer = offset
                        grab = Offset(offset.x - item.offset, offset.y)
                        haptics.perform(dragStart)
                    }
                },
                onDrag = { change, delta ->
                    val id = dragging ?: return@detectDragGesturesAfterLongPress
                    change.consume()
                    pointer += delta
                    val target = itemAt(pointer.x)?.key as? String ?: return@detectDragGesturesAfterLongPress
                    val to = checked.indexOf(target)
                    if (target != id && to >= 0) {
                        onMove(id, to)
                        haptics.perform(dragAlign)
                    }
                },
                onDragEnd = { dragging = null },
                onDragCancel = { dragging = null },
            )
        },
        horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalStripGap),
    ) {
        itemsIndexed(tiles, key = { _, t -> t.key }) { index, tile ->
            val id = tile.key as? String
            val lifted = id != null && dragging == id
            DayTileView(
                tile,
                stripTileShape(index, tiles.size),
                Modifier
                    .then(
                        if (lifted) Modifier.zIndex(1f).graphicsLayer {
                            val info = listState.layoutInfo.visibleItemsInfo.firstOrNull { it.key == id }
                            if (info != null) translationX = pointer.x - grab.x - info.offset
                        } else Modifier.animateItem(fadeInSpec = DsMotion.fade(), placementSpec = DsMotion.movement(DsMotion.stripInsert(), reduce), fadeOutSpec = DsMotion.fade()),
                    ),
            )
        }
    }
}

/**
 * The message sheet (`week.edit.layout.message`, Retro's "Add a Message"): centred title (`sheetTitle`), trailing "Done"
 * (C-08, `textButton`, `color.global.textPrimary`); the text from `size.global.screenMargin` in text role `placeholder`;
 * the counter "58/2000" (`body`, tabular digits, secondary) at the trailing margin above the keyboard.
 */
@Composable
fun MessageSheetContent(text: String, onText: (String) -> Unit, onDone: () -> Unit) {
    var field by remember { mutableStateOf(TextFieldValue(text)) }
    val margin = Tokens.Sizes.globalScreenMargin
    val secondary = PageRoles.secondaryText()
    val messageLabel = stringRes(R.string.week_edit_message_title)
    Column(Modifier.fillMaxWidth().imePadding()) {
        Box(Modifier.fillMaxWidth().heightIn(min = Tokens.Sizes.globalMinTouchTargetAndroid).padding(horizontal = margin), contentAlignment = Alignment.Center) {
            Text(stringRes(R.string.week_edit_message_title), style = TextRoles.sheetTitle, color = Tokens.Colors.globalTextPrimary, modifier = Modifier.semantics { heading() })
            HeaderTextButton(stringRes(R.string.week_edit_message_done), onDone, Modifier.align(Alignment.CenterEnd))
        }
        val style = TextRoles.placeholder.copy(color = Tokens.Colors.globalTextPrimary)
        BasicTextField(
            value = field,
            onValueChange = {
                field = it
                onText(it.text)
            },
            textStyle = style,
            cursorBrush = SolidColor(Tokens.Colors.globalSystemPrimary),
            keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences),
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = Tokens.Sizes.globalFriendCardWidth)
                .padding(horizontal = margin, vertical = Tokens.Sizes.globalSectionHeaderToContent)
                .semantics { contentDescription = messageLabel },
            decorationBox = { inner ->
                Box {
                    if (field.text.isEmpty()) Text(stringRes(R.string.week_edit_textplaceholder), style = style.copy(color = secondary))
                    inner()
                }
            },
        )
        Text(
            stringRes(R.string.week_edit_message_counter, field.text.length, WeekEditViewModel.TEXT_LIMIT),
            style = TextRoles.body.copy(fontFeatureSettings = app.feature.social.chat.TABULAR_DIGITS),
            color = secondary,
            modifier = Modifier.align(Alignment.End).padding(horizontal = margin, vertical = Tokens.Sizes.globalSectionHeaderToContent),
        )
    }
}

/**
 * The album sheet (C-29): C-11 close circle at the leading margin and the centred "New Album" (`sheetTitle`); the C-12
 * field ("Name your album") `size.global.titleToContent` below with its inline error "Name missing"; the C-05 primary
 * capsule "Create Album" (sheet size, `size.global.buttonMarginHSheet`) at the bottom above the keyboard, disabled while
 * the name or the selection is empty.
 */
@Composable
fun AlbumSheetContent(state: EditState, onName: (String) -> Unit, onCreate: () -> Unit, onClose: () -> Unit) {
    var field by remember { mutableStateOf(TextFieldValue(state.albumName)) }
    val margin = Tokens.Sizes.globalScreenMargin
    Column(Modifier.fillMaxWidth().imePadding().testTag("week.edit.album")) {
        Box(Modifier.fillMaxWidth().heightIn(min = Tokens.Sizes.globalMinTouchTargetAndroid).padding(horizontal = margin), contentAlignment = Alignment.Center) {
            CircleIconButton(Tokens.Icons.globalClose, stringRes(R.string.week_recap_a11y_close), onClose, Modifier.align(Alignment.CenterStart), style = CircleButtonStyle.OnPage)
            Text(stringRes(R.string.week_edit_album_title), style = TextRoles.sheetTitle, color = Tokens.Colors.globalTextPrimary, modifier = Modifier.semantics { heading() })
        }
        Spacer(Modifier.height(Tokens.Sizes.globalTitleToContent))
        FormTextField(
            value = field,
            onValueChange = {
                field = it
                onName(it.text)
            },
            placeholder = stringRes(R.string.week_edit_album_nameplaceholder),
            accessibilityLabel = stringRes(R.string.week_edit_album_nameplaceholder),
            modifier = Modifier.padding(horizontal = margin),
            error = if (state.albumError == EditError.AlbumName) stringRes(R.string.week_edit_error_albumname) else null,
        )
        Spacer(Modifier.height(Tokens.Sizes.globalSectionGap))
        PrimaryButton(
            stringRes(R.string.week_edit_album_create),
            onCreate,
            Modifier.padding(horizontal = Tokens.Sizes.globalButtonMarginHSheet),
            enabled = state.albumName.isNotEmpty() && state.checked.isNotEmpty(),
            size = PrimaryButtonSize.Sheet,
            loading = state.saving,
        )
        Spacer(Modifier.height(Tokens.Sizes.globalButtonMarginHSheet))
    }
}
