// Surface: week.edit — reorder, remove, edit text; save the recap or a selection as a named album.
// Built from documented Yope components (S-13): references/auto/yope/frames/a-chuongxetank-7694968408424582452-t6.73-sendto-voice-tooltip.png
// (sheet header, check circles, lime button), references/auto/yope/frames/a-itsmthuyope-7644974799302823175-t45.23-new-group-empty.png
// (name sheet), references/owner/yope-week-recap.jpg (pics grid).
package app.feature.social.week

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGesturesAfterLongPress
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyGridState
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.grid.rememberLazyGridState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
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
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.animation.core.VisibilityThreshold
import androidx.compose.ui.zIndex
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.text.style.TextAlign
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.social.common.Formats
import app.feature.social.common.Glyph
import app.feature.social.common.HeaderCircle
import app.feature.social.common.Line
import app.feature.social.common.LoadingHud
import app.feature.social.common.RemotePhoto
import app.feature.social.common.SocialBlocked
import app.feature.social.common.Type
import app.feature.social.common.announce
import app.feature.social.common.rememberHaptics
import app.feature.social.common.shows
import app.feature.social.common.stringRes
import app.ui.components.FormTextField
import app.ui.components.HeaderCircleFill
import app.ui.components.PrimaryButton
import app.ui.components.PrimaryButtonSize

/**
 * The editor as a native sheet over `week.recap` (Android: `ModalBottomSheet(skipPartiallyExpanded =
 * true)`, `easing.global.native.sheet`: native sheets keep the system motion; `spring.global.sheetPresent` is for custom sheets). [onClose] pops the route.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun WeekEditSheet(vm: WeekEditViewModel, onClose: () -> Unit) {
    val state by vm.state.collectAsStateWithLifecycle()
    val haptics = rememberHaptics()
    val view = LocalView.current
    val saved = stringRes(R.string.week_edit_toast_saved)
    val albumSaved = stringRes(R.string.week_edit_toast_albumsaved)
    LaunchedEffect(vm) {
        vm.effects.collect { effect ->
            when (effect) {
                EditEffect.Saved -> { haptics.play(Tokens.Haptics.globalSuccess); announce(view, saved) }
                EditEffect.AlbumSaved -> { haptics.play(Tokens.Haptics.globalSuccess); announce(view, albumSaved) }
                EditEffect.Failed -> haptics.play(Tokens.Haptics.globalError)
                EditEffect.Close -> onClose()
            }
        }
    }
    val albumOnly = state.albumSheet && state.recap == null
    val sheet = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ModalBottomSheet(onDismissRequest = onClose, sheetState = sheet, containerColor = Tokens.Colors.globalBackgroundDeep) {
        if (albumOnly) {
            AlbumSheetContent(state, onName = vm::setAlbumName, onSave = vm::saveAlbum, onClose = onClose)
        } else {
            WeekEditContent(
                state = state,
                onClose = onClose,
                onToggle = { id -> haptics.play(Tokens.Haptics.globalSelect); vm.toggle(id) },
                onMove = vm::move,
                onText = vm::setText,
                onSave = vm::save,
                onSaveAsAlbum = vm::openAlbumSheet,
            )
        }
    }
    if (state.albumSheet && !albumOnly) {
        val albumState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
        ModalBottomSheet(onDismissRequest = vm::closeAlbumSheet, sheetState = albumState, containerColor = Tokens.Colors.globalBackgroundDeep) {
            AlbumSheetContent(state, onName = vm::setAlbumName, onSave = vm::saveAlbum, onClose = vm::closeAlbumSheet)
        }
    }
}

/** A sheet header: ✕ circle at the left (`color.global.controlOnDeep`), title centred (text role `sheetTitle`). */
@Composable
fun SheetHeader(title: String, closeLabel: String, onClose: () -> Unit, titleStyle: androidx.compose.ui.text.TextStyle = Type.sheetTitle()) {
    Box(Modifier.fillMaxWidth().padding(horizontal = Tokens.Sizes.globalHeaderInset).height(Tokens.Sizes.globalHeaderButton)) {
        HeaderCircle(Tokens.Icons.globalClose, closeLabel, HeaderCircleFill.OnDeep, onClose, Modifier.align(Alignment.CenterStart))
        Line(title, titleStyle, Tokens.Colors.globalTextPrimary, Modifier.align(Alignment.Center).padding(horizontal = Tokens.Sizes.globalHeaderButton).semantics { heading() })
    }
}

/** The editor's contents (snapshots render this directly). */
@Composable
fun WeekEditContent(
    state: EditState,
    onClose: () -> Unit,
    onToggle: (String) -> Unit,
    onMove: (String, Int) -> Unit,
    onText: (String) -> Unit,
    onSave: () -> Unit,
    onSaveAsAlbum: () -> Unit,
    gridState: LazyGridState = rememberLazyGridState(),
) {
    val pair = shows(SocialBlocked.saveAsAlbumPair)
    Box(Modifier.fillMaxSize().background(Tokens.Colors.globalBackgroundDeep).testTag("week.edit")) {
        Column(Modifier.fillMaxSize().imePadding()) {
            SheetHeader(stringRes(R.string.week_edit_title), stringRes(R.string.week_edit_a11y_close), onClose)
            when (state.phase) {
                EditState.Phase.Loading -> Box(Modifier.weight(1f)) { LoadingHud() }
                EditState.Phase.NotReady, EditState.Phase.Error -> Box(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
                    Line(
                        stringRes(if (state.phase == EditState.Phase.NotReady) R.string.week_edit_error_notready else R.string.week_edit_error_save),
                        Type.emptyTitle(),
                        Tokens.Colors.globalTextPrimary,
                        maxLines = Int.MAX_VALUE,
                        align = TextAlign.Center,
                    )
                }
                EditState.Phase.Ready -> {
                    EditGrid(state, onToggle, onMove, onText, gridState, Modifier.weight(1f))
                    if (state.error == EditError.Save) {
                        Line(
                            stringRes(R.string.week_edit_error_save),
                            Type.listSubtitle(),
                            Tokens.Colors.globalTextSecondary,
                            Modifier.fillMaxWidth().padding(horizontal = Tokens.Sizes.globalButtonMarginHSheet),
                            maxLines = Int.MAX_VALUE,
                            align = TextAlign.Center,
                        )
                    }
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .windowInsetsPadding(WindowInsets.navigationBars)
                            .padding(start = Tokens.Sizes.globalButtonMarginHSheet, end = Tokens.Sizes.globalButtonMarginHSheet, bottom = Tokens.Sizes.cameraSendtoSizeSendButtonBottom),
                        horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalHeaderGap),
                    ) {
                        if (pair) DarkButton(stringRes(R.string.week_edit_saveasalbum), enabled = state.checked.isNotEmpty(), onClick = onSaveAsAlbum, modifier = Modifier.weight(1f))
                        PrimaryButton(stringRes(R.string.week_edit_save), onSave, Modifier.weight(1f), size = PrimaryButtonSize.Sheet, loading = state.saving)
                    }
                }
            }
        }
        if (state.saving && state.phase == EditState.Phase.Ready) LoadingHud()
    }
}

/**
 * Yope's dark secondary button of the "more friends" + "send" pair. week.edit names
 * `camera.sendto` pair tokens that do not exist (the pair was not measured): until they do
 * ([SocialBlocked.saveAsAlbumPair]) it shows only in development builds, with the primary button's
 * geometry and the dark control role on black (`color.global.controlOnDeep`).
 */
@Composable
private fun DarkButton(text: String, enabled: Boolean, onClick: () -> Unit, modifier: Modifier = Modifier) {
    val shape = RoundedCornerShape(Tokens.Radii.globalButton)
    Box(
        modifier
            .heightIn(min = Tokens.Sizes.globalButtonHeightSheet)
            .clip(shape)
            .background(Tokens.Colors.globalControlOnDeep, shape)
            .clickable(enabled = enabled, role = Role.Button, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Line(text, Type.button(), if (enabled) Tokens.Colors.globalTextPrimary else Tokens.Colors.globalTextSecondary)
    }
}

/**
 * The week's photos in the pics grid with Yope's selection circle at each tile's top-right corner
 * (inset `size.global.listGap`, approximation), then the recap text field (position BLOCKED:
 * under the grid, the spec's approximation). Reorder (`week.edit.layout.reorder`, Apple / Google
 * Photos, G-16): touch and hold a checked tile, drag it, release to drop; the tile follows the
 * finger and the other tiles move to show the drop position (the platform's item placement
 * animation; none under Reduce Motion). Haptics `week.edit.haptic.dragStart` / `.dragAlign`.
 */
@OptIn(androidx.compose.foundation.ExperimentalFoundationApi::class)
@Composable
private fun EditGrid(
    state: EditState,
    onToggle: (String) -> Unit,
    onMove: (String, Int) -> Unit,
    onText: (String) -> Unit,
    gridState: LazyGridState,
    modifier: Modifier,
) {
    val haptics = rememberHaptics()
    val reduceMotion by app.designsystem.rememberReduceMotion()
    var dragging by remember { mutableStateOf<String?>(null) }
    // The finger in grid coordinates, and where it holds the dragged tile.
    var pointer by remember { mutableStateOf(Offset.Zero) }
    var grab by remember { mutableStateOf(Offset.Zero) }
    val inRecap = stringRes(R.string.week_edit_a11y_inrecap)
    val notInRecap = stringRes(R.string.week_edit_a11y_notinrecap)
    val checked by androidx.compose.runtime.rememberUpdatedState(state.checked)
    fun itemAt(offset: Offset) = gridState.layoutInfo.visibleItemsInfo.firstOrNull { item ->
        val o = item.offset
        val s = item.size
        offset.x >= o.x && offset.x < o.x + s.width && offset.y >= o.y && offset.y < o.y + s.height
    }
    LazyVerticalGrid(
        columns = GridCells.Fixed(Tokens.Counts.weekRecapCountPicsColumns),
        state = gridState,
        modifier = modifier
            .fillMaxWidth()
            .pointerInput(Unit) {
                detectDragGesturesAfterLongPress(
                    onDragStart = { offset ->
                        val item = itemAt(offset)
                        val id = item?.key as? String
                        if (item != null && id != null && id in checked) {
                            dragging = id
                            pointer = offset
                            grab = offset - Offset(item.offset.x.toFloat(), item.offset.y.toFloat())
                            haptics.playNamed(Tokens.Layouts.WeekEditHapticDragStart.android)
                        }
                    },
                    onDrag = { change, delta ->
                        val id = dragging ?: return@detectDragGesturesAfterLongPress
                        change.consume()
                        pointer += delta
                        val target = itemAt(pointer)?.key as? String ?: return@detectDragGesturesAfterLongPress
                        val to = checked.indexOf(target)
                        if (target != id && to >= 0) {
                            onMove(id, to)
                            haptics.playNamed(Tokens.Layouts.WeekEditHapticDragAlign.android)
                        }
                    },
                    onDragEnd = { dragging = null },
                    onDragCancel = { dragging = null },
                )
            },
        horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.weekRecapDimensionPicsGap),
        verticalArrangement = Arrangement.spacedBy(Tokens.Sizes.weekRecapDimensionPicsGap),
    ) {
        items(state.photos, key = { it.post.id }) { photo ->
            val id = photo.post.id
            val isChecked = id in state.checked
            val label = stringRes(R.string.photo_viewer_a11y_photo, photo.authorName.orEmpty(), Formats.viewerDate(photo.post.createdAt))
            val lifted = dragging == id
            Box(
                Modifier
                    .then(
                        if (lifted) Modifier.zIndex(1f).graphicsLayer {
                            val info = gridState.layoutInfo.visibleItemsInfo.firstOrNull { it.key == id }
                            if (info != null) {
                                translationX = pointer.x - grab.x - info.offset.x
                                translationY = pointer.y - grab.y - info.offset.y
                            }
                        } else Modifier.animateItem(fadeInSpec = null, fadeOutSpec = null, placementSpec = if (reduceMotion) null else androidx.compose.animation.core.spring(visibilityThreshold = androidx.compose.ui.unit.IntOffset.VisibilityThreshold)),
                    )
                    .fillMaxWidth()
                    .aspectRatio(Tokens.AspectRatios.weekRecapAspectRatioPicsTile)
                    .clickable(role = Role.Checkbox) { onToggle(id) }
                    .clearAndSetSemantics {
                        contentDescription = label
                        stateDescription = if (isChecked) inRecap else notInRecap
                        role = Role.Checkbox
                    },
            ) {
                RemotePhoto(photo.thumbPath, null, Modifier.fillMaxSize())
                Glyph(
                    if (isChecked) Tokens.Icons.globalCheck else Tokens.Icons.globalUncheck,
                    if (isChecked) Tokens.Colors.globalSelection else Tokens.Colors.globalTextPrimary,
                    Modifier.align(Alignment.TopEnd).padding(Tokens.Sizes.globalListGap),
                    size = Tokens.Sizes.globalCheckCircle,
                )
            }
        }
        item(key = "text", span = { GridItemSpan(maxLineSpan) }) {
            RecapTextField(state.text, onText)
        }
    }
}

/**
 * The recap text (≤ 2000, `weekly_recaps.text`): multi-line field `groups.create.color.field`,
 * `radius.global.field`, min height `size.global.fieldHeight`, side margin
 * `size.global.buttonMarginH`, text role `body`, placeholder `week.edit.textPlaceholder`. Inner
 * inset = `radius.global.field` (as core:ui FormTextField; not measured).
 */
@Composable
private fun RecapTextField(text: String, onText: (String) -> Unit) {
    val shape = RoundedCornerShape(Tokens.Radii.globalField)
    val placeholder = stringRes(R.string.week_edit_textplaceholder)
    BasicTextField(
        value = text,
        onValueChange = onText,
        textStyle = Type.body().copy(color = Tokens.Colors.globalTextPrimary),
        cursorBrush = SolidColor(Tokens.Colors.globalTextPrimary),
        modifier = Modifier
            .padding(horizontal = Tokens.Sizes.globalButtonMarginH, vertical = Tokens.Sizes.globalButtonMarginH)
            .fillMaxWidth()
            .heightIn(min = Tokens.Sizes.globalFieldHeight)
            .clip(shape)
            .background(Tokens.Colors.groupsCreateColorField, shape)
            .semantics { contentDescription = placeholder },
        decorationBox = { inner ->
            Box(Modifier.padding(Tokens.Radii.globalField), contentAlignment = Alignment.CenterStart) {
                if (text.isEmpty()) Line(placeholder, Type.body(), Tokens.Colors.globalTextSecondary, Modifier.clearAndSetSemantics { })
                inner()
            }
        },
    )
}

/**
 * Yope's "new group" name sheet: ✕ + title (`groups.create.fontSize.title` / `.fontWeight.title`),
 * `groups.create.size.titleToContent`, the name field (core:ui FormTextField: `groups.create` field
 * tokens), `groups.create.size.fieldToButton`, the lime button (`size.global.buttonHeight`,
 * `size.global.buttonMarginH`), disabled while the name is empty or nothing is checked.
 */
@Composable
fun NameSheet(
    title: String,
    name: String,
    placeholder: String,
    error: String?,
    enabled: Boolean,
    saving: Boolean,
    onName: (String) -> Unit,
    onSave: () -> Unit,
    onClose: () -> Unit,
) {
    var field by remember { mutableStateOf(TextFieldValue(name)) }
    if (field.text != name) field = field.copy(text = name)
    Column(Modifier.fillMaxWidth().background(Tokens.Colors.globalBackgroundDeep).imePadding().windowInsetsPadding(WindowInsets.navigationBars)) {
        SheetHeader(title, stringRes(R.string.week_edit_a11y_close), onClose, Type.style(Tokens.FontSizes.groupsCreateFontSizeTitle, Tokens.FontWeights.groupsCreateFontWeightTitle))
        Spacer(Modifier.height(Tokens.Sizes.groupsCreateSizeTitleToContent))
        FormTextField(
            value = field,
            onValueChange = { field = it; onName(it.text) },
            placeholder = placeholder,
            accessibilityLabel = placeholder,
            modifier = Modifier.padding(horizontal = Tokens.Sizes.globalButtonMarginH).fillMaxWidth(),
        )
        if (error != null) {
            Line(error, Type.listSubtitle(), Tokens.Colors.globalTextSecondary, Modifier.fillMaxWidth().padding(horizontal = Tokens.Sizes.globalButtonMarginH), maxLines = Int.MAX_VALUE, align = TextAlign.Center)
        }
        Spacer(Modifier.height(Tokens.Sizes.groupsCreateSizeFieldToButton))
        PrimaryButton(
            stringRes(R.string.week_edit_save),
            onSave,
            Modifier.padding(horizontal = Tokens.Sizes.globalButtonMarginH),
            enabled = enabled && name.isNotEmpty(),
            size = PrimaryButtonSize.Form,
            loading = saving,
        )
        Spacer(Modifier.height(Tokens.Sizes.groupsCreateSizeFieldToButton))
    }
}

/** "Save as album": the name sheet titled `week.edit.album.title`; the album gets the checked photos in order. */
@Composable
fun AlbumSheetContent(state: EditState, onName: (String) -> Unit, onSave: () -> Unit, onClose: () -> Unit) {
    Box(Modifier.testTag("week.edit.album")) {
        NameSheet(
            title = stringRes(R.string.week_edit_album_title),
            name = state.albumName,
            placeholder = stringRes(R.string.week_edit_album_nameplaceholder),
            error = when (state.albumError) {
                EditError.AlbumName -> stringRes(R.string.week_edit_error_albumname)
                EditError.Save -> stringRes(R.string.week_edit_error_save)
                else -> null
            },
            enabled = state.checked.isNotEmpty() && state.phase == EditState.Phase.Ready,
            saving = state.saving,
            onName = onName,
            onSave = onSave,
            onClose = onClose,
        )
    }
}

