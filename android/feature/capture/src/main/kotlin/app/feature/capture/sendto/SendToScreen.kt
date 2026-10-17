// Surface: camera.sendto — Retro's "Postcard" composer and its "Add a Message" sheet.
// References: references/auto/retro/store/retro-store-03.png (ST-03: header, photo frame, "Add a message" pill,
// label + rows, 60-pt white capsule); references/auto/retro/press/tc-2023-12-retro3.png phones 2–3 (disabled
// capsule #4D4D4D, "Add a Message" sheet with the 250 counter). Decisions: MERGE_DECISIONS RC-5 … RC-8.
package app.feature.capture.sendto

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import androidx.compose.animation.Crossfade
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.paddingFrom
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.painter.BitmapPainter
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.FirstBaseline
import androidx.compose.ui.layout.LastBaseline
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.invisibleToUser
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import app.data.model.Group
import app.data.model.MediaKind
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.capture.data.CapturedMedia
import app.feature.capture.ui.MediaEmptyState
import app.feature.capture.ui.MediaSheetHeader
import app.feature.capture.ui.OnMedia
import app.feature.capture.ui.SheetTitleText
import app.feature.capture.ui.VoiceGestures
import app.feature.capture.ui.bottomClearance
import app.ui.components.ActivityIndicator
import app.ui.components.Avatar
import app.ui.components.CheckCircle
import app.ui.components.CircleButtonStyle
import app.ui.components.CircleIconButton
import app.ui.components.EmptyStateAction
import app.ui.components.Hairline
import app.ui.components.HeaderTextButton
import app.ui.components.MediaPill
import app.ui.components.MediaPillStyle
import app.ui.components.PrimaryButton
import app.ui.components.VideoTileMarker
import app.ui.components.stripTileShape
import app.ui.foundation.DsMotion
import app.ui.foundation.FadeVisibility
import app.ui.foundation.PageRoles
import app.ui.foundation.tickToggleable
import app.ui.system.DsBottomSheet
import app.ui.system.DsDropdownMenu
import app.ui.system.DsMenuItem
import app.ui.system.SystemAlertDialog
import app.ui.text.CapTop
import app.ui.text.TextRoles
import java.io.File
import kotlin.math.max

/** Everything the stateless screen needs besides the view model's state. */
data class SendToChrome(
    /** The capture as an image (photo, or a video's frame). */
    val preview: ImageBitmap?,
    /** Signed cover URLs (or painters) by group id (rows show `icon.global.group` without one). */
    val covers: Map<String, Any?> = emptyMap(),
    /** Several photos: the selection strip's tiles, in the order picked (a video's frame); null until decoded. */
    val thumbnails: List<ImageBitmap?> = emptyList(),
)

/** The voice note's callbacks (`chat.voice.layout.recording` / `.locked`, `camera.sendto.layout.messageField`). */
data class VoiceActions(
    /** The voice capsule's press and hold: down, lift, slide left, slide up. */
    val gestures: VoiceGestures = VoiceGestures.None,
    /** TalkBack: start a hands-free recording, or keep the running one. */
    val onA11yToggle: () -> Unit = {},
    /** "Delete recording" from the note's menu. */
    val onDelete: () -> Unit = {},
    /** The voice capsule's send glyph (locked / paused): the recording becomes the note. */
    val onKeep: () -> Unit = {},
    val onPause: () -> Unit = {},
    val onResume: () -> Unit = {},
    /** Paused: play / pause the draft. */
    val onPreview: () -> Unit = {},
    /** Paused: the trash glyph. */
    val onDiscard: () -> Unit = {},
    /** The attached note's play / pause. */
    val onToggleNote: () -> Unit = {},
)

/**
 * The send-to screen (stateless). Full height on `color.global.backgroundDeep` in both appearances; the
 * content between the header and the bottom capsule scrolls. [messageSheetOpen] shows the "Add a Message"
 * sheet (follows the appearance).
 */
@Composable
fun SendToScreen(
    state: SendToViewModel.UiState,
    chrome: SendToChrome,
    onClose: () -> Unit,
    onSave: () -> Unit,
    onCaption: (String) -> Unit,
    onToggle: (String) -> Unit,
    onSend: () -> Unit,
    onCreateGroup: () -> Unit,
    onRetryGroups: () -> Unit,
    onConfirmDiscard: () -> Unit,
    onDismissAlert: () -> Unit,
    onRetrySend: () -> Unit,
    modifier: Modifier = Modifier,
    videoPreview: (@Composable () -> Unit)? = null,
    voice: VoiceActions = VoiceActions(),
    /** Earlier callers' clock (the recorder now reports its elapsed time in [voiceLive]). */
    @Suppress("UNUSED_PARAMETER") now: () -> Long = android.os.SystemClock::elapsedRealtime,
    voiceLive: VoiceLive = VoiceLive(),
    messageSheetOpen: Boolean = false,
    onMessageSheet: (Boolean) -> Unit = {},
) {
    val sending = state.sending
    Column(
        modifier
            .fillMaxSize()
            .background(Tokens.Colors.globalBackgroundDeep)
            .windowInsetsPadding(WindowInsets.statusBars)
            .testTag("camera.sendto"),
    ) {
        MediaSheetHeader(
            leading = {
                CircleIconButton(Tokens.Icons.globalDownload, stringResource(R.string.camera_sendto_a11y_save), onSave, Modifier.testTag("sendto.save"), style = CircleButtonStyle.OnMedia, enabled = !sending)
            },
            trailing = {
                CircleIconButton(Tokens.Icons.globalClose, stringResource(R.string.camera_sendto_a11y_close), onClose, Modifier.testTag("sendto.close"), style = CircleButtonStyle.OnMedia, enabled = !sending)
            },
        ) { centre ->
            Crossfade(sending, animationSpec = app.ui.foundation.DsMotion.crossfade(), label = "sendtoTitle") { busy ->
                SheetTitleText(
                    stringResource(if (busy) R.string.camera_sendto_sending else R.string.camera_sendto_title),
                    capMiddle = centre,
                    color = Tokens.Colors.globalTextOnMedia,
                    modifier = Modifier.testTag("sendto.title"),
                )
            }
        }
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState())) {
            Spacer(Modifier.height(Dp(Tokens.Layouts.CameraSendtoLayoutPreview.topBelowHeaderCircle)))
            Preview(state, chrome, videoPreview, voice, voiceLive, sending, onOpenMessage = { onMessageSheet(true) })
            if (state.showsSelection) {
                // Several photos: the selection strip a section gap below the photo; the groups label keeps its gap below it.
                Spacer(Modifier.height(Tokens.Sizes.globalSectionGap))
                SelectionStrip(state.selection, chrome.thumbnails)
            }
            GroupsSection(state, chrome.covers, onToggle, onCreateGroup, onRetryGroups)
        }
        // C-05 on media, pinned: 20 from the sides, its bottom `camera.sendto.size.sendButtonBottom` above the screen bottom.
        OnMedia {
            PrimaryButton(
                text = stringResource(R.string.camera_sendto_send),
                onClick = onSend,
                enabled = state.sendEnabled || sending,
                loading = sending,
                onMedia = true,
                modifier = Modifier
                    .padding(horizontal = Tokens.Sizes.globalButtonMarginH)
                    .padding(top = Tokens.Sizes.globalScreenMargin, bottom = bottomClearance(Tokens.Sizes.cameraSendtoSizeSendButtonBottom))
                    .testTag("sendto.send"),
            )
        }
    }

    if (messageSheetOpen) {
        MessageSheet(state.caption, onCaption, onDone = { onMessageSheet(false) })
    }
    when (val alert = state.alert) {
        SendToViewModel.Alert.Discard -> SystemAlertDialog(
            title = stringResource(R.string.camera_sendto_discard_title),
            text = stringResource(R.string.camera_sendto_discard_message),
            confirmLabel = stringResource(R.string.camera_sendto_discard_confirm),
            onConfirm = onConfirmDiscard,
            dismissLabel = stringResource(R.string.camera_sendto_cancel),
            onDismiss = onDismissAlert,
            destructive = true,
        )
        is SendToViewModel.Alert.SendFailed -> SystemAlertDialog(
            title = stringResource(R.string.camera_sendto_error_sendfailed),
            text = stringResource(if (alert.offline) R.string.camera_sendto_error_offline else R.string.camera_sendto_error_generic),
            confirmLabel = stringResource(R.string.camera_sendto_error_retry),
            onConfirm = onRetrySend,
            dismissLabel = stringResource(R.string.camera_sendto_cancel),
            onDismiss = onDismissAlert,
        )
        null -> Unit
    }
}

/**
 * Several photos (camera.sendto.md "Several photos"): the selection as a C-17 strip — Retro's composer shows its selected
 * media in the week-strip tile style (VID-COMP) — tiles `size.global.stripTileWidth` × `.stripTileHeight`,
 * `size.global.stripGap` apart with the page showing through, only the strip's outer corners rounded ([stripTileShape],
 * `radius.global.card`), from the leading `size.global.screenMargin`; each tile the photo aspect-fill (a video's frame with
 * the video marker), `color.global.controlOnDeep` until decoded. No number anywhere (tenet 2): TalkBack reads the strip
 * as one element, `camera.sendto.a11y.selection`.
 */
@Composable
private fun SelectionStrip(items: List<CapturedMedia>, thumbnails: List<ImageBitmap?>) {
    val label = stringResource(R.string.camera_sendto_a11y_selection)
    LazyRow(
        modifier = Modifier
            .fillMaxWidth()
            .clearAndSetSemantics { contentDescription = label }
            .testTag("sendto.selection"),
        contentPadding = PaddingValues(start = Tokens.Sizes.globalScreenMargin),
        horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalStripGap),
    ) {
        itemsIndexed(items, key = { _, item -> item.file.path }) { index, item ->
            Box(
                Modifier
                    .size(Tokens.Sizes.globalStripTileWidth, Tokens.Sizes.globalStripTileHeight)
                    .clip(stripTileShape(index, items.size))
                    .background(Tokens.Colors.globalControlOnDeep),
            ) {
                thumbnails.getOrNull(index)?.let { Image(BitmapPainter(it), null, Modifier.fillMaxSize(), contentScale = ContentScale.Crop) }
                if (item.kind == MediaKind.Video) item.durationMs?.let { VideoTileMarker(it.toLong()) }
            }
        }
    }
}

/**
 * The photo frame (`camera.sendto.layout.preview`): 297.6 wide, centred, native aspect up to 422.8 tall,
 * aspect-fill, corners 8.5; on it, centred, its bottom 20.5 above the photo bottom, the message pill (C-09 dark,
 * `icon.global.edit`) and, `size.global.pillGap` after it, the voice capsule. While a voice note records the recording
 * capsule takes the pill's place (chat.voice); locked or paused it spans the photo's width less `size.global.pillGap` on
 * each side, the voice capsule and the gap (its waveform takes what is left). A kept note is the note capsule (C-36
 * waveform) `size.global.pillGap` above the pair (`camera.sendto.layout.messageField` `.note`).
 */
@Composable
private fun Preview(
    state: SendToViewModel.UiState,
    chrome: SendToChrome,
    videoPreview: (@Composable () -> Unit)?,
    voice: VoiceActions,
    live: VoiceLive,
    sending: Boolean,
    onOpenMessage: () -> Unit,
) {
    val spec = Tokens.Layouts.CameraSendtoLayoutPreview
    val field = Tokens.Layouts.CameraSendtoLayoutMessageField
    val media = state.media
    val bitmap = chrome.preview
    val aspect = when {
        media?.width != null && media.height != null && media.height > 0 -> media.width.toFloat() / media.height
        bitmap != null && bitmap.height > 0 -> bitmap.width.toFloat() / bitmap.height
        else -> Tokens.Layouts.CameraCaptureLayoutViewfinder.aspect
    }
    val width = Dp(spec.width)
    val height = minOf(width / aspect, Dp(spec.maxHeight))
    Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
        Box(
            Modifier
                .size(width, height)
                .clip(RoundedCornerShape(Dp(spec.cornerRadius)))
                .background(Tokens.Colors.globalControlOnDeep)
                .testTag("sendto.preview"),
        ) {
            // Own photo: decorative for TalkBack.
            Box(Modifier.fillMaxSize().semantics { invisibleToUser() }) {
                when {
                    videoPreview != null -> videoPreview()
                    bitmap != null -> Image(BitmapPainter(bitmap), null, Modifier.fillMaxSize(), contentScale = ContentScale.Crop)
                }
            }
            val gap = Tokens.Sizes.globalPillGap
            val phase = state.voicePhase
            val note = state.voice
            val play = live.play
            val notePlaying = note != null && play.file == note.file && play.isPlaying
            val noteProgress = if (note != null && play.file == note.file) play.progress else null
            // Paused: anything playing that is not the note is the draft's preview.
            val draftPlay = phase == VoicePhase.Paused && play.file != null && play.file != note?.file
            var slidePx by remember { mutableFloatStateOf(0f) }
            Column(
                Modifier.align(Alignment.BottomCenter).padding(bottom = Dp(field.bottomInset)),
                verticalArrangement = Arrangement.spacedBy(gap),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                // The last note stays drawn while it fades out.
                var shownNote by remember { mutableStateOf(note) }
                if (note != null) shownNote = note
                FadeVisibility(note != null) {
                    var menu by remember { mutableStateOf(false) }
                    Box {
                        shownNote?.let {
                            SendToNoteCapsule(
                                note = it,
                                playing = notePlaying,
                                progress = noteProgress,
                                enabled = !sending,
                                onToggle = voice.onToggleNote,
                                onMenu = { menu = true },
                                onDelete = voice.onDelete,
                            )
                        }
                        DsDropdownMenu(
                            expanded = menu,
                            onDismissRequest = { menu = false },
                            items = listOf(DsMenuItem(stringResource(R.string.chat_voice_a11y_discard), voice.onDelete, Tokens.Icons.globalTrash, destructive = true)),
                        )
                    }
                }
                Row(horizontalArrangement = Arrangement.spacedBy(gap), verticalAlignment = Alignment.CenterVertically) {
                    Crossfade(phase == VoicePhase.Idle, animationSpec = DsMotion.fade(), label = "voiceRow") { idle ->
                        if (idle) {
                            Crossfade(state.caption.isBlank(), animationSpec = DsMotion.crossfade(), label = "messagePill") { empty ->
                                MediaPill(
                                    text = stringResource(if (empty) R.string.camera_sendto_message_add else R.string.camera_sendto_message_edit),
                                    onClick = { if (!sending) onOpenMessage() },
                                    style = MediaPillStyle.Dark,
                                    icon = Tokens.Icons.globalEdit,
                                    modifier = Modifier.testTag("sendto.message"),
                                )
                            }
                        } else {
                            val fills = phase == VoicePhase.Locked || phase == VoicePhase.Paused
                            SendToRecordingCapsule(
                                phase = phase,
                                live = live,
                                previewing = draftPlay && play.isPlaying,
                                previewProgress = if (draftPlay) play.progress else null,
                                slidePx = slidePx,
                                onPause = voice.onPause,
                                onResume = voice.onResume,
                                onPreview = voice.onPreview,
                                onDiscard = voice.onDiscard,
                                modifier = if (fills) Modifier.width(width - gap * 2 - Tokens.Sizes.globalIconPillWidth - gap) else Modifier,
                            )
                        }
                    }
                    if (state.micAvailable) {
                        SendToVoiceCapsule(
                            phase = phase,
                            // The recording capsule can take the photo's width less the voice capsule and the gap; sliding
                            // left past half of it cancels (chat.voice "slide left").
                            rowWidth = width - Tokens.Sizes.globalIconPillWidth - gap,
                            enabled = !sending,
                            gestures = voice.gestures,
                            onSlide = { slidePx = it },
                            onKeep = voice.onKeep,
                            onA11y = voice.onA11yToggle,
                        )
                    }
                }
            }
        }
    }
}

/**
 * The groups block (`camera.sendto.layout.recipientRow`): the label (text role `meta`, `color.global.textSecondary`)
 * 35.2 below the photo at the margin, then one C-16 row per group with C-32 hairlines between; or the loading /
 * empty / failed block in the rows area.
 */
@Composable
private fun GroupsSection(
    state: SendToViewModel.UiState,
    covers: Map<String, Any?>,
    onToggle: (String) -> Unit,
    onCreateGroup: () -> Unit,
    onRetryGroups: () -> Unit,
) {
    val row = Tokens.Layouts.CameraSendtoLayoutRecipientRow
    val labelStyle = TextRoles.meta
    Text(
        stringResource(R.string.camera_sendto_groupslabel),
        style = labelStyle,
        color = Tokens.ColorsDark.globalTextSecondary,
        modifier = Modifier
            .padding(horizontal = Tokens.Sizes.globalScreenMargin)
            // "35.2 pt below the photo" (ST-03, to the label's cap top).
            .paddingFrom(FirstBaseline, before = Dp(GROUPS_LABEL_BELOW_PHOTO) + CapTop.height(labelStyle))
            .semantics { heading() }
            .testTag("sendto.label"),
    )
    val rowsArea = Modifier.fillMaxWidth().padding(vertical = Dp(row.padding))
    when (val groups = state.groups) {
        SendToViewModel.Groups.Loading -> Box(rowsArea, contentAlignment = Alignment.Center) {
            ActivityIndicator(stringResource(R.string.global_a11y_loading), onMedia = true)
        }
        SendToViewModel.Groups.Empty -> Box(rowsArea, contentAlignment = Alignment.Center) {
            MediaEmptyState(
                title = stringResource(R.string.camera_sendto_empty_title),
                detail = stringResource(R.string.camera_sendto_empty_detail),
                action = EmptyStateAction(stringResource(R.string.camera_sendto_empty_button), onCreateGroup, Tokens.Icons.globalAdd),
                icon = Tokens.Icons.globalGroup,
            )
        }
        is SendToViewModel.Groups.Failed -> Box(rowsArea, contentAlignment = Alignment.Center) {
            MediaEmptyState(
                title = stringResource(if (groups.offline) R.string.camera_sendto_error_offline else R.string.camera_sendto_error_generic),
                detail = null,
                action = EmptyStateAction(stringResource(R.string.camera_sendto_error_retry), onRetryGroups),
                icon = null,
            )
        }
        is SendToViewModel.Groups.Loaded -> Column {
            state.visibleGroups.forEachIndexed { index, group ->
                if (index > 0) Hairline(Modifier.padding(horizontal = Tokens.Sizes.globalScreenMargin), onMedia = true)
                GroupRow(
                    group,
                    covers[group.id],
                    selected = group.id in state.selected,
                    enabled = !state.sending && state.replyGroupId == null,
                    closesAt = state.shownInvitation(group.id)?.closesAt,
                ) { onToggle(group.id) }
            }
        }
    }
}

/** "35.2 pt below the photo" (`camera.sendto.layout.recipientRow.label`: the number lives only in the token's text). */
private const val GROUPS_LABEL_BELOW_PHOTO = 35.2f // provenance-ok: camera.sendto.layout.recipientRow.label "35.2 pt below the preview bottom" (no numeric field — reported)

/**
 * One group row (C-16 on media): cover in a `size.global.avatarPicker` circle (no cover: `icon.global.group` on
 * `color.global.controlOnDeep`), the name `size.global.cardNameGap` after it (text role `listTitle`,
 * `color.global.textOnMedia`), the check circle (`size.global.checkCircle`) with its ink at the trailing margin;
 * 16 above and below the avatar (`camera.sendto.layout.recipientRow.padding`). The row toggles as a checkbox
 * (`haptic.global.select`); the check cross-fades.
 */
@Composable
private fun GroupRow(group: Group, cover: Any?, selected: Boolean, enabled: Boolean, closesAt: java.time.Instant? = null, onToggle: () -> Unit) {
    val padding = Dp(Tokens.Layouts.CameraSendtoLayoutRecipientRow.padding)
    // The group's open daily invitation (migration 0035): its countdown under the name until `closes_at`, then nothing.
    val seconds = app.ui.format.InvitationCountdown.rememberSeconds(closesAt)
    Row(
        Modifier
            .fillMaxWidth()
            .tickToggleable(value = selected, enabled = enabled, role = Role.Checkbox) { onToggle() }
            .semantics(mergeDescendants = true) {
                if (seconds != null) stateDescription = app.ui.format.InvitationCountdown.spoken(seconds)
            }
            .padding(horizontal = Tokens.Sizes.globalScreenMargin, vertical = padding)
            .testTag("sendto.row.${group.id}"),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        OnMedia { Avatar(cover, Tokens.Sizes.globalAvatarPicker, fallbackIcon = Tokens.Icons.globalGroup) }
        Spacer(Modifier.width(Tokens.Sizes.globalCardNameGap))
        Column(Modifier.weight(1f)) {
            Text(
                group.name,
                style = TextRoles.listTitle,
                color = Tokens.Colors.globalTextOnMedia,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            if (seconds != null) {
                app.ui.format.InvitationCountdownText(seconds, Tokens.ColorsDark.globalTextSecondary, Modifier.semantics { invisibleToUser() })
            }
        }
        Spacer(Modifier.width(Tokens.Sizes.globalCardNameGap))
        Crossfade(selected, animationSpec = app.ui.foundation.DsMotion.crossfade(), label = "check") { on -> OnMedia { CheckCircle(on) } }
    }
}

/**
 * The "Add a Message" sheet (`camera.sendto.layout.messageSheet`): a native page sheet that follows the
 * appearance; centred title (`sheetTitle`) with the trailing "Done" (C-08, `textButton`, `color.global.textPrimary`);
 * the multi-line field from 22 in (text role `placeholder`, typed `color.global.textPrimary`, placeholder in
 * secondary text); the counter "58/250" (`camera.sendto.fontSize.counter`, monospaced digits, secondary text)
 * trailing 20.7 from the edge and 22 above the keyboard. Swipe down keeps the text as "Done" does.
 */
@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
private fun MessageSheet(text: String, onText: (String) -> Unit, onDone: () -> Unit) {
    val sheet = Tokens.Layouts.CameraSendtoLayoutMessageSheet
    val max = Tokens.Counts.cameraSendtoSizeCaptionMaxLength
    val focus = remember { FocusRequester() }
    DsBottomSheet(onDismissRequest = onDone) {
        // A page sheet: the field takes the height; the counter sits 22 above the keyboard.
        Column(Modifier.fillMaxSize().imePadding()) {
            Box(
                Modifier
                    .fillMaxWidth()
                    .padding(horizontal = Tokens.Sizes.globalScreenMargin),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    stringResource(R.string.camera_sendto_message_title),
                    style = TextRoles.sheetTitle,
                    color = Tokens.Colors.globalTextPrimary,
                    modifier = Modifier.semantics { heading() },
                )
                HeaderTextButton(stringResource(R.string.camera_sendto_message_done), onDone, Modifier.align(Alignment.CenterEnd).testTag("sendto.message.done"))
            }
            val placeholder = stringResource(R.string.camera_sendto_caption_placeholder)
            BasicTextField(
                value = text,
                onValueChange = onText,
                textStyle = TextRoles.placeholder.copy(color = Tokens.Colors.globalTextPrimary),
                cursorBrush = SolidColor(Tokens.Colors.globalTextPrimary),
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f)
                    .padding(PaddingValues(horizontal = Dp(sheet.textInset), vertical = Tokens.Sizes.globalScreenMargin))
                    .focusRequester(focus)
                    .testTag("sendto.message.field"),
                decorationBox = { inner ->
                    Box {
                        if (text.isEmpty()) Text(placeholder, style = TextRoles.placeholder, color = PageRoles.secondaryText())
                        inner()
                    }
                },
            )
            Text(
                stringResource(R.string.camera_sendto_message_counter, text.length, max),
                style = TextRoles.placeholder.copy(fontSize = Tokens.FontSizes.cameraSendtoFontSizeCounter, fontFamily = FontFamily.Monospace),
                color = PageRoles.secondaryText(),
                modifier = Modifier
                    .align(Alignment.End)
                    .padding(end = Dp(sheet.counterTrailingInset))
                    .paddingFrom(LastBaseline, after = Dp(sheet.counterAboveKeyboard)),
            )
        }
    }
    LaunchedEffect(Unit) { runCatching { focus.requestFocus() } }
}

/** Decodes [file] for the preview at about [targetPx] wide, EXIF orientation applied. */
internal fun decodePreview(file: File, targetPx: Int): ImageBitmap? {
    val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
    BitmapFactory.decodeFile(file.path, bounds)
    if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
    var sample = 1
    while (minOf(bounds.outWidth, bounds.outHeight) / (sample * 2) >= max(1, targetPx)) sample *= 2
    val bitmap: Bitmap = BitmapFactory.decodeFile(file.path, BitmapFactory.Options().apply { inSampleSize = sample }) ?: return null
    val rotation = app.feature.capture.data.exifRotation(file)
    val rotated = if (rotation == 0) bitmap else {
        val m = android.graphics.Matrix().apply { postRotate(rotation.toFloat()) }
        Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, m, true)
    }
    return rotated.asImageBitmap()
}
