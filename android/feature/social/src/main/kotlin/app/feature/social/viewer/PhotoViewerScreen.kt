// Surface: photo.viewer — design/surfaces/photo.viewer.md
// References: references/auto/retro/press/tc-2023-07-retro-2b.jpg phone 2 (primary: header, photo, footer, hairline,
// comment rows, comment field), references/auto/retro/press/tc-2023-12-retro3.png phone 1 (black viewer in light mode),
// references/auto/retro/web/retro.app-j-welcome-iphone-full.png ("1 of N" pill, close circle), references/auto/retro/press/
// tc-2025-12-rewind-panels.png (native menu with red destructive items).
package app.feature.social.viewer

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.Canvas
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.unit.dp
import app.ui.foundation.DsMotion
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.paddingFromBaseline
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.layout
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.layout.SubcomposeLayout
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.min
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.data.model.Media
import app.data.model.Message
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.social.albums.AlbumPickerSheet
import app.feature.social.chat.FieldGlyph
import app.feature.social.chat.endInset
import app.feature.social.chat.glyphHit
import app.feature.social.chat.MessageField
import app.feature.social.chat.VoiceCapsule
import app.feature.social.chat.VoiceUi
import app.feature.social.chat.voiceStateOf
import app.feature.social.common.Formats
import app.feature.social.common.LocalSocialData
import app.feature.social.common.LocalSocialServices
import app.feature.social.common.MediaAppearance
import app.feature.social.common.PersonAvatar
import app.feature.social.common.photoModel
import app.feature.memory.tagging.TagRun
import app.feature.memory.tagging.TaggedPerson
import app.feature.social.common.PhotoSaveUi
import app.feature.social.common.RemotePhoto
import app.ui.foundation.reduceMotion
import app.feature.social.common.videoDurationMs
import app.feature.social.common.withVideoLabel
import app.ui.media.DualImage
import app.feature.social.common.SystemAppearance
import app.feature.social.common.announce
import app.feature.social.common.rememberPhotoSaver
import app.feature.social.common.stringRes
import app.feature.social.reactions.PhotoContextMenu
import app.feature.social.reactions.ReactionChip
import app.feature.social.reactions.ReactionPickerSheet
import app.feature.social.reactions.Reactor
import app.feature.social.reactions.ReactionsSheet
import app.ui.components.EmptyState
import app.ui.components.EmptyStateFill
import app.ui.components.Hairline
import app.ui.components.PlatformToast
import app.ui.components.PositionPill
import app.ui.components.ViewerTaps
import app.ui.foundation.FadeVisibility
import app.ui.foundation.GlyphInk
import app.ui.foundation.endAtLastBaseline
import app.ui.foundation.tapClickable
import app.ui.haptics.rememberHaptics
import app.ui.system.DsDropdownMenu
import app.ui.system.DsMenuItem
import app.ui.system.SystemAlertDialog
import app.ui.system.SystemTextFieldDialog
import app.ui.text.CapTop
import app.ui.text.TextRoles
import kotlinx.coroutines.launch

/** Where the viewer leads (photo.viewer.md → Navigation out). */
data class ViewerNav(
    val close: () -> Unit,
    val person: (userId: String, groupId: String) -> Unit,
    /** `camera.capture` replying to this photo (`create_post(p_reply_to_post_id)`, exactly this group). */
    val replyWithPhoto: (groupId: String, postId: String) -> Unit,
    val report: (groupId: String, postId: String) -> Unit,
    val block: (userId: String) -> Unit,
    /** `safety.report` for a selfie reaction (`report('selfie', <selfie_reactions.id>, …)`, viewer.selfiereaction §4). */
    val reportSelfie: (groupId: String, selfieId: String, userId: String) -> Unit = { _, _, _ -> },
)

/** What the menu's Favorite, Use as Cover, the album picker and the caption dialog do (set by [PhotoViewerScreen] from its view model). */
class ViewerMenuActions(
    val toggleFavorite: () -> Unit = {},
    val useAsCover: () -> Unit = {},
    val addedToAlbum: () -> Unit = {},
    /** The caption dialog's Save (`edit_caption`). */
    val saveCaption: (String) -> Unit = {},
)

/** Transient UI state of the viewer (menus, sheets, dialogs), hoisted for tests. */
class ViewerUiState(
    menu: Boolean = false,
    photoMenu: Boolean = false,
    confirmDelete: Boolean = false,
    picker: Boolean = false,
    reactions: Boolean = false,
    saveDenied: Boolean = false,
    draft: TextFieldValue? = null,
    selfieLayer: SelfieMode? = null,
    confirmRemoveSelfie: String? = null,
    albumPicker: Boolean = false,
    captionDraft: String? = null,
) {
    var menu by mutableStateOf(menu)

    /** The caption dialog's text while it is open (Edit Caption / Add a Caption); null = closed. */
    var captionDraft by mutableStateOf(captionDraft)

    /** "Add to Album": the album picker (`photo.viewer.layout.albumPicker`). */
    var albumPicker by mutableStateOf(albumPicker)

    /** Each opening of the picker (its view model's key). */
    var albumPickerSession by mutableStateOf(0)

    /** The menu's view-model actions (Favorite, Use as Cover, the picker's result). */
    var menuActions = ViewerMenuActions()
    var photoMenu by mutableStateOf(photoMenu)
    var confirmDelete by mutableStateOf(confirmDelete)
    var picker by mutableStateOf(picker)
    var reactions by mutableStateOf(reactions)
    var commentMenu by mutableStateOf<String?>(null)
    var confirmUnsend by mutableStateOf<String?>(null)
    val save = PhotoSaveUi(saveDenied)
    val fixedDraft = draft

    /** The selfie capture layer (`viewer.selfiereaction` §2): open in hold or tap mode, or closed (null). */
    var selfieLayer by mutableStateOf(selfieLayer)

    /** The hold that opened the layer in hold mode (the finger's position, its release). */
    val hold = SelfieHold()

    /** The selfie row (by person) whose long-press menu is open in the Reactions sheet. */
    var selfieMenu by mutableStateOf<String?>(null)

    /** The person whose selfie the remove confirmation is about (your own photo). */
    var confirmRemoveSelfie by mutableStateOf(confirmRemoveSelfie)

    /** Videos play with sound: off until the person turns it on, then on for every video until the viewer closes. */
    var videoSound by mutableStateOf(false)

    /** Each "Play" (the circle or the photo's TalkBack action) on a video without autoplay. */
    var videoPlayRequests by mutableStateOf(0)
}

@Composable
fun PhotoViewerScreen(vm: PhotoViewerViewModel, nav: ViewerNav, ui: ViewerUiState = remember { ViewerUiState() }) {
    val state by vm.state.collectAsStateWithLifecycle()
    val context = LocalContext.current
    val view = androidx.compose.ui.platform.LocalView.current
    val haptics = rememberHaptics()
    val services = LocalSocialServices.current
    val voice = remember { services.voice(context) }
    DisposableEffect(voice) { onDispose { voice.release() } }
    val playback by voice.playback.collectAsStateWithLifecycle()
    val data = LocalSocialData.current
    val scope = rememberCoroutineScope()

    val texts = ViewerTexts(
        sendFailed = stringRes(R.string.chat_thread_sendfailed),
        reactionFailed = stringRes(R.string.chat_reactions_error),
        deleted = stringRes(R.string.photo_viewer_toast_deleted),
        deleteFailed = stringRes(R.string.photo_viewer_error_delete),
        saved = stringRes(R.string.photo_viewer_toast_saved),
        saveFailed = stringRes(R.string.photo_viewer_error_save),
        selfieSent = stringRes(R.string.viewer_selfiereaction_a11y_sent),
        selfieFailed = stringRes(R.string.viewer_selfiereaction_error),
        favoriteFailed = stringRes(R.string.photo_viewer_error_favorite),
        coverSet = stringRes(R.string.week_edit_toast_saved),
        coverNotReady = stringRes(R.string.photo_viewer_error_covernotready),
        coverFailed = stringRes(R.string.photo_viewer_error_cover),
        addedToAlbum = stringRes(R.string.week_edit_toast_albumsaved),
        captionFailed = stringRes(R.string.photo_viewer_error_caption),
    )
    ui.menuActions = remember(vm) {
        ViewerMenuActions(
            toggleFavorite = vm::toggleFavorite,
            useAsCover = vm::useAsCover,
            addedToAlbum = vm::addedToAlbum,
            saveCaption = { text -> vm.saveCaption(text) },
        )
    }
    LaunchedEffect(vm) {
        vm.effects.collect { effect ->
            when (effect) {
                ViewerEffect.Sent -> haptics.perform(Tokens.Haptics.globalSend)
                ViewerEffect.SendFailed -> { haptics.perform(Tokens.Haptics.globalError); announce(view, texts.sendFailed) }
                ViewerEffect.ReactionFailed -> { haptics.perform(Tokens.Haptics.globalError); PlatformToast.show(context, texts.reactionFailed) }
                ViewerEffect.Deleted -> PlatformToast.show(context, texts.deleted)
                ViewerEffect.DeleteFailed -> { haptics.perform(Tokens.Haptics.globalError); PlatformToast.show(context, texts.deleteFailed) }
                ViewerEffect.Saved -> { haptics.perform(Tokens.Haptics.globalSuccess); PlatformToast.show(context, texts.saved) }
                ViewerEffect.SaveFailed -> { haptics.perform(Tokens.Haptics.globalError); PlatformToast.show(context, texts.saveFailed) }
                // Sent: no haptic (owner decision 15), an announcement; failed: the face left the stack, Android toast.
                ViewerEffect.SelfieSent -> announce(view, texts.selfieSent)
                ViewerEffect.SelfieFailed -> { haptics.perform(Tokens.Haptics.globalError); PlatformToast.show(context, texts.selfieFailed) }
                ViewerEffect.FavoriteFailed -> { haptics.perform(Tokens.Haptics.globalError); PlatformToast.show(context, texts.favoriteFailed) }
                ViewerEffect.CoverSet -> { haptics.perform(Tokens.Haptics.globalSuccess); PlatformToast.show(context, texts.coverSet) }
                ViewerEffect.CoverNotReady -> { haptics.perform(Tokens.Haptics.globalError); PlatformToast.show(context, texts.coverNotReady) }
                ViewerEffect.CoverFailed -> { haptics.perform(Tokens.Haptics.globalError); PlatformToast.show(context, texts.coverFailed) }
                ViewerEffect.AddedToAlbum -> { haptics.perform(Tokens.Haptics.globalSuccess); PlatformToast.show(context, texts.addedToAlbum) }
                ViewerEffect.CaptionFailed -> { haptics.perform(Tokens.Haptics.globalError); PlatformToast.show(context, texts.captionFailed) }
            }
        }
    }
    LaunchedEffect(state.closed) { if (state.closed) nav.close() }
    val save = rememberPhotoSaver(ui.save) { ok -> vm.saved(ok) }

    var loadingKey by remember { mutableStateOf<String?>(null) }
    var failedKeys by remember { mutableStateOf(emptySet<String>()) }
    var computedLevels by remember { mutableStateOf(emptyMap<String, List<Int>>()) }
    LaunchedEffect(playback.key, playback.isPlaying) { if (playback.isPlaying && playback.key == loadingKey) loadingKey = null }
    val onPlay: (String, Boolean) -> Unit = { path, needsLevels ->
        haptics.tap()
        if (playback.key == path && playback.isPlaying) voice.pause()
        else scope.launch {
            failedKeys = failedKeys - path
            loadingKey = path
            val url = runCatching { data.signedUrls(listOf(path))[path] }.getOrNull()
            if (url != null) {
                voice.play(path, url)
                // A note stored without levels: its waveform is computed from the file (C-36 fallback).
                if (needsLevels && path !in computedLevels) voice.levels(path, url)?.let { computedLevels = computedLevels + (path to it) }
            } else {
                loadingKey = null
                failedKeys = failedKeys + path
            }
        }
    }

    val viewerPlayback = rememberViewerPlayback()
    CompositionLocalProvider(LocalViewerPlayback provides viewerPlayback) {
        PhotoViewerContent(
            state = state,
            ui = ui,
            nav = nav,
            voice = VoiceUi(playback, loadingKey, failedKeys, computedLevels, onPlay),
            onNext = { haptics.tap(); vm.next() },
            onPrevious = { haptics.tap(); vm.previous() },
            onRetry = vm::retryLoad,
            onDraft = vm::setDraft,
            onSend = vm::sendReply,
            onReact = vm::react,
            onUnreact = vm::unreact,
            onPhotoGone = vm::markGone,
            // Any photo you can see saves to your own library (owner decision 28).
            onSave = { state.current?.media?.originalPath?.let(save) },
            onDelete = { haptics.perform(Tokens.Haptics.globalWarning); vm.deleteEverywhere() },
            onUnsendComment = { id -> haptics.perform(Tokens.Haptics.globalWarning); vm.unsendComment(id) },
            onSendSelfie = vm::sendSelfie,
            onSelfieFailed = { haptics.perform(Tokens.Haptics.globalError); PlatformToast.show(context, texts.selfieFailed) },
            onRemoveSelfie = vm::removeSelfie,
        )
    }
}

private class ViewerTexts(
    val sendFailed: String,
    val reactionFailed: String,
    val deleted: String,
    val deleteFailed: String,
    val saved: String,
    val saveFailed: String,
    val selfieSent: String,
    val selfieFailed: String,
    val favoriteFailed: String,
    val coverSet: String,
    val coverNotReady: String,
    val coverFailed: String,
    val addedToAlbum: String,
    val captionFailed: String,
)

/** The viewer without its view model (snapshots render this with fixed states). Dark in both appearances. */
@Composable
fun PhotoViewerContent(
    state: ViewerState,
    ui: ViewerUiState,
    nav: ViewerNav,
    voice: VoiceUi,
    onNext: () -> Unit,
    onPrevious: () -> Unit,
    onRetry: () -> Unit,
    onDraft: (String) -> Unit,
    onSend: () -> Unit,
    onReact: (String) -> Unit,
    onUnreact: (String) -> Unit,
    onPhotoGone: (String) -> Unit,
    onSave: () -> Unit,
    onDelete: () -> Unit,
    onUnsendComment: (String) -> Unit,
    onSendSelfie: (java.io.File) -> Unit = {},
    onSelfieFailed: () -> Unit = {},
    onRemoveSelfie: (String) -> Unit = {},
    /** Draws the capture layer instead of [SelfieCaptureRoute] (snapshots: a sample photo for the live preview). */
    selfieLayer: (@Composable (SelfieMode) -> Unit)? = null,
) {
    val context = LocalContext.current
    // No front camera: the selfie entry points are hidden (viewer.selfiereaction → States).
    val selfieAllowed = state.canReactWithSelfie && remember(context) { SelfieCameras.hasFrontCamera(context) }
    val photo = state.current
    LaunchedEffect(photo?.postId, photo?.gone, selfieAllowed) { if (photo?.gone == true || !selfieAllowed) ui.selfieLayer = null }
    MediaAppearance {
        Column(
            Modifier
                .fillMaxSize()
                .background(Tokens.Colors.globalBackgroundDeep)
                .testTag("photo.viewer")
                .statusBarsPadding(),
        ) {
            ViewerHeaderRow(state, nav, inert = ui.selfieLayer != null)
            Box(Modifier.weight(1f).fillMaxWidth()) {
                Column(Modifier.fillMaxSize().navigationBarsPadding().imePadding()) {
                    BoxWithConstraints(Modifier.weight(1f).fillMaxWidth()) {
                        val area = maxHeight
                        when {
                            photo == null -> Unit
                            photo.gone -> EmptyStateFill {
                                EmptyState(stringRes(R.string.photo_viewer_gone_title), stringRes(R.string.photo_viewer_gone_detail))
                            }
                            else -> Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
                                Spacer(Modifier.height(Tokens.Sizes.photoViewerDimensionHeaderToPhoto))
                                PhotoArea(photo, state, ui, nav, area, selfieAllowed, onNext, onPrevious, onRetry, onReact, onUnreact, onSave)
                                Footer(photo, state, ui, voice, selfieAllowed, onPhotoGone)
                                Comments(photo, state, ui, voice, onUnsendComment)
                                Spacer(Modifier.height(Tokens.Sizes.photoViewerDimensionCommentsToField))
                            }
                        }
                    }
                    if (photo?.gone != true) ReplyField(state, ui, nav, onDraft, onSend, onSave)
                }
                // viewer.selfiereaction §2: the capture layer from the photo's top (`photo.viewer.dimension.headerToPhoto` below
                // the header) to the bottom of the screen; in / out with the fade (`duration.global.fade`, `easing.global.standard`).
                var shownMode by remember { mutableStateOf(SelfieMode.Hold) }
                ui.selfieLayer?.let { shownMode = it }
                FadeVisibility(visible = ui.selfieLayer != null, modifier = Modifier.fillMaxSize().padding(top = Tokens.Sizes.photoViewerDimensionHeaderToPhoto)) {
                    if (selfieLayer != null) {
                        selfieLayer(shownMode)
                    } else {
                        SelfieCaptureRoute(
                            mode = shownMode,
                            hold = ui.hold,
                            onCaptured = onSendSelfie,
                            onFailed = onSelfieFailed,
                            onClose = { ui.selfieLayer = null },
                        )
                    }
                }
            }
        }
        ViewerDialogs(state, ui, nav, onReact, onUnreact, onDelete, onUnsendComment, onRemoveSelfie)
    }
}

/**
 * The header (fixed under the status bar): avatar `size.global.avatarHeader` at `photo.viewer.dimension.headerInset`;
 * `photo.viewer.dimension.headerAvatarToText` after it the name (`listTitle`, `color.global.textOnMedia`) over "Week 28"
 * (`photo.viewer.header.week`, or `.groupWeek` from a wall; `listSubtitle`, `color.global.textSecondary`), baselines
 * `photo.viewer.dimension.headerLinePitch` apart, centred on the avatar; trailing the C-22 position pill (more than one
 * photo), `size.global.pillGap`, the close circle whose right edge sits on `size.global.screenMargin`.
 */
@Composable
private fun ViewerHeaderRow(state: ViewerState, nav: ViewerNav, inert: Boolean = false) {
    val photo = state.current
    val post = photo?.post
    Box {
        Row(
            Modifier
                .fillMaxWidth()
                .padding(start = Tokens.Sizes.photoViewerDimensionHeaderInset, end = Tokens.Sizes.globalScreenMargin)
                // Under the selfie capture layer the header stays visible and inert (viewer.selfiereaction §2).
                .then(if (inert) Modifier.clearAndSetSemantics { } else Modifier),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Row(
                Modifier
                    .weight(1f)
                    .then(if (post != null) Modifier.tapClickable { nav.person(post.authorId, post.groupId) } else Modifier)
                    .semantics(mergeDescendants = true) { heading() },
                verticalAlignment = Alignment.CenterVertically,
            ) {
                ViewerAvatarRing(photo?.author?.avatarPath, state.index, state.photos.size, Modifier.testTag("viewer.avatar"))
                Spacer(Modifier.width(Tokens.Sizes.photoViewerDimensionHeaderAvatarToText))
                Column {
                    Text(photo?.author?.displayName.orEmpty(), style = TextRoles.listTitle, color = Tokens.Colors.globalTextOnMedia, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.endAtLastBaseline())
                    val week = photo?.weekNumber
                    if (week != null) {
                        val line = if (state.fromWall && photo.groupName != null) stringRes(R.string.photo_viewer_header_groupweek, photo.groupName, week)
                        else stringRes(R.string.photo_viewer_header_week, week)
                        Text(line, style = TextRoles.listSubtitle, color = Tokens.ColorsDark.globalTextSecondary, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.paddingFromBaseline(top = Tokens.Sizes.photoViewerDimensionHeaderLinePitch))
                    }
                }
            }
            if (state.photos.size > 1) {
                val position = stringRes(R.string.photo_viewer_position, state.index + 1, state.photos.size)
                PositionPill(position, position)
                Spacer(Modifier.width(Tokens.Sizes.globalPillGap))
            }
            CloseCircle(stringRes(R.string.photo_viewer_a11y_close), nav.close)
        }
        if (inert) Box(Modifier.matchParentSize().pointerInput(Unit) { awaitEachGesture { awaitFirstDown(pass = PointerEventPass.Initial).consume() } })
    }
}

/**
 * The header avatar with Retro's progress ring (`photo.viewer.layout.avatarRing`, TC-2B "3 of 4" → three quarters):
 * `size.global.avatarHeader` across the ring; a `color.global.textOnMedia` arc `strokeWidth` wide with round caps,
 * from 12 o'clock clockwise through ([index] + 1) ÷ [total] of the circle (one photo: the full circle); the photo
 * `gap` inside it. The arc changes with the page cross-fade. Decorative: the position pill names the position.
 */
@Composable
private fun ViewerAvatarRing(path: String?, index: Int, total: Int, modifier: Modifier = Modifier) {
    val ring = Tokens.Layouts.PhotoViewerLayoutAvatarRing
    val outer = Tokens.Sizes.globalAvatarHeader
    val stroke = ring.strokeWidth.dp
    val fraction = if (total <= 0) 1f else ((index + 1).toFloat() / total).coerceIn(0f, 1f)
    val sweep by animateFloatAsState(FULL_TURN * fraction, DsMotion.crossfade(), label = "ring")
    Box(modifier.size(outer), contentAlignment = Alignment.Center) {
        Canvas(Modifier.matchParentSize()) {
            val width = stroke.toPx()
            val inset = width / 2
            drawArc(
                color = Tokens.Colors.globalTextOnMedia,
                startAngle = TWELVE_O_CLOCK,
                sweepAngle = sweep,
                useCenter = false,
                topLeft = Offset(inset, inset),
                size = Size(size.width - width, size.height - width),
                style = Stroke(width = width, cap = StrokeCap.Round),
            )
        }
        PersonAvatar(path, outer - (stroke + ring.gap.dp) * 2)
    }
}

/** A full turn and the 12 o'clock start of a clockwise arc in Compose's angle system (0° = 3 o'clock, clockwise). */
private const val FULL_TURN = 360f // provenance-ok: geometry (a circle), not a design value
private const val TWELVE_O_CLOCK = -90f // provenance-ok: geometry (12 o'clock in Compose's arc angles), photo.viewer.layout.avatarRing start

/**
 * The viewer's close (C-11 on media at the measured size): `photo.viewer.dimension.closeCircle` in
 * `color.global.controlOnDeep`, `icon.global.close` with its ink `photo.viewer.dimension.closeGlyph` tall in
 * `color.global.textOnMedia`. Its touch target is expanded to `size.global.minTouchTarget.android` by the theme.
 */
@Composable
private fun CloseCircle(label: String, onClick: () -> Unit) {
    val icon = Tokens.Icons.globalClose
    val bounds = GlyphInk.bounds(icon)
    val box = Tokens.Sizes.photoViewerDimensionCloseGlyph * (icon.viewportHeight / bounds.height)
    Box(
        Modifier
            .size(Tokens.Sizes.photoViewerDimensionCloseCircle)
            .background(Tokens.Colors.globalControlOnDeep, CircleShape)
            .tapClickable(onClick = onClick)
            .clearAndSetSemantics {
                contentDescription = label
                role = Role.Button
            },
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, contentDescription = null, tint = Tokens.Colors.globalTextOnMedia, modifier = Modifier.size(box))
    }
}

/**
 * The photo (`photo.viewer.layout.photo`): full width, its own aspect, never cropped, square corners, scaled down and
 * letterboxed when taller than [area]; the thumbnail shows until the display rendition loads. Tap = advance (the
 * leading `photo.viewer.layout.backZone` — 20 % — goes back); long press = the context menu with the
 * quick-reaction row. TalkBack: label, hints and next / previous custom actions.
 */
@Composable
private fun PhotoArea(
    photo: ViewerPhoto,
    state: ViewerState,
    ui: ViewerUiState,
    nav: ViewerNav,
    area: Dp,
    selfieAllowed: Boolean,
    onNext: () -> Unit,
    onPrevious: () -> Unit,
    onRetry: () -> Unit,
    onReact: (String) -> Unit,
    onUnreact: (String) -> Unit,
    onSave: () -> Unit,
) {
    val media = photo.media
    val front = media?.frontImagePath(Media.Rendition.Display)
    // A dual capture is daily.dualimage (3:4, `daily.dualimage.layout.composition`); a single photo keeps its own aspect.
    val aspect = if (front != null) {
        Tokens.Layouts.DailyDualimageLayoutComposition.mainAspect
    } else {
        media?.let { m -> if ((m.width ?: 0) > 0 && (m.height ?: 0) > 0) m.width!!.toFloat() / m.height!! else null }
    }
    val next by rememberUpdatedState(onNext)
    val previous by rememberUpdatedState(onPrevious)
    // `photo.viewer.layout.backZone` (Retro's viewer): a tap in the leading 20 % of the photo goes back.
    val backZone = Tokens.Layouts.PhotoViewerLayoutBackZone.fraction
    val rtl = LocalLayoutDirection.current == LayoutDirection.Rtl
    val date = photo.post?.let { Formats.viewerDate(it.createdAt, photo.zone ?: java.time.ZoneId.systemDefault()) }.orEmpty()
    val photoLabel = if (state.mine) stringRes(R.string.photo_viewer_a11y_photomine, date) else stringRes(R.string.photo_viewer_a11y_photo, photo.author?.firstName.orEmpty(), date)
    val label = withVideoLabel(LocalContext.current, photoLabel, media?.videoDurationMs)
    // photo.viewer.layout.livePhoto: touch and hold plays the motion (the menu stays on the field's "•••").
    val live = media?.isLivePhoto == true && front == null
    var holding by remember(photo.postId) { mutableStateOf(false) }
    var playOnce by remember(photo.postId) { mutableStateOf(false) }
    val viewerPlayback = LocalViewerPlayback.current
    LaunchedEffect(viewerPlayback?.ended, playOnce) { if (playOnce && viewerPlayback?.ended == true) playOnce = false }
    val playLabel = stringRes(R.string.photo_viewer_a11y_play)
    val autoplay = !reduceMotion()
    val video = media?.isVideo == true
    val waitsForPlay = video && videoWaitsForPlay(autoplay)
    val soundLabel = stringRes(if (ui.videoSound) R.string.photo_viewer_a11y_mute else R.string.photo_viewer_a11y_unmute)
    val caption = photo.post?.caption?.takeIf { it.isNotBlank() }?.let { stringRes(R.string.chat_thread_a11y_caption, it) }
    val nextLabel = stringRes(R.string.photo_viewer_a11y_next)
    val previousLabel = stringRes(R.string.photo_viewer_a11y_previous)
    val hint = stringRes(R.string.photo_viewer_a11y_advancehint) + ". " + stringRes(R.string.photo_viewer_a11y_backhint)
    val menuItems = viewerMenuItems(state, ui, nav, onSave)
    // viewer.selfiereaction §1: the context menu's single-pointer entry (tap mode), also a custom action on the photo.
    val selfieAction = stringRes(R.string.viewer_selfiereaction_a11y_action)
    val selfieItem = if (selfieAllowed) DsMenuItem(stringRes(R.string.viewer_selfiereaction_menu_react), { ui.selfieLayer = SelfieMode.Tap }, icon = Tokens.Icons.globalCamera) else null
    val faces = stackFaces(photo.selfies)
    val stackLabel = selfieStackLabel(faces) { id -> photo.people[id]?.firstName.orEmpty() }
    BoxWithConstraints(Modifier.fillMaxWidth()) {
        val natural = if (aspect != null) maxWidth / aspect else maxWidth / DEFAULT_ASPECT
        val height = min(natural, area)
        // A letterboxed photo: the stack sits on the visible image's edges (`viewer.selfiereaction.layout.stack` anchor).
        val visibleWidth = if (aspect != null) min(maxWidth, height * aspect) else maxWidth
        val letterbox = (maxWidth - visibleWidth) / 2
        Box(
            Modifier
                .fillMaxWidth()
                .height(height)
                .testTag("viewer.photo")
                .pointerInput(backZone, rtl, live) {
                    detectTapGestures(
                        onTap = { offset -> if (ViewerTaps.isPrevious(offset.x, size.width.toFloat(), backZone, rtl)) previous() else next() },
                        onLongPress = { if (live) holding = true else ui.photoMenu = true },
                        onPress = {
                            tryAwaitRelease()
                            holding = false
                        },
                    )
                }
                .clearAndSetSemantics {
                    contentDescription = listOfNotNull(label, caption, hint).joinToString(", ")
                    customActions = listOf(
                        CustomAccessibilityAction(nextLabel) { next(); true },
                        CustomAccessibilityAction(previousLabel) { previous(); true },
                    ) + listOfNotNull(if (live) CustomAccessibilityAction(playLabel) { playOnce = true; true } else null) +
                        listOfNotNull(
                            if (waitsForPlay) CustomAccessibilityAction(playLabel) { ui.videoSound = true; ui.videoPlayRequests++; true } else null,
                            if (video && !waitsForPlay) CustomAccessibilityAction(soundLabel) { ui.videoSound = !ui.videoSound; true } else null,
                        ) +
                        listOfNotNull(selfieItem?.let { CustomAccessibilityAction(selfieAction) { it.onClick(); true } }) +
                        menuItems.map { m -> CustomAccessibilityAction(m.text) { m.onClick(); true } }
                },
            contentAlignment = Alignment.Center,
        ) {
            if (photo.loadFailed) {
                Text(
                    stringRes(R.string.photo_viewer_error_load),
                    style = TextRoles.body,
                    color = Tokens.ColorsDark.globalTextSecondary,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.tapClickable(onClick = onRetry).padding(horizontal = Tokens.Sizes.globalScreenMargin),
                )
            } else if (front != null) {
                // core:ui daily.dualimage with the viewer's square corners on media black; the photo's semantics stay on this box.
                DualImage(
                    main = photoModel(media.imagePath(Media.Rendition.Display)),
                    inset = photoModel(front),
                    contentDescription = null,
                    cornerRadius = Tokens.Radii.globalPhoto,
                    loadingFill = Tokens.Colors.globalBackgroundDeep,
                )
            } else {
                RemotePhoto(
                    media?.imagePath(Media.Rendition.Display),
                    null,
                    Modifier.fillMaxSize(),
                    contentScale = ContentScale.Fit,
                    fallbackPath = media?.imagePath(Media.Rendition.Thumb),
                    placeholder = Tokens.Colors.globalBackgroundDeep,
                )
                if (media?.isVideo == true) {
                    ViewerVideo(
                        media, active = ui.selfieLayer == null, autoplay = autoplay, sound = ui.videoSound, onSound = { ui.videoSound = it },
                        playRequest = ui.videoPlayRequests, onPlay = { ui.videoPlayRequests++ }, letterbox = letterbox,
                    )
                } else if (live) {
                    ViewerLiveMotion(media!!, holding = holding || playOnce, letterbox = letterbox)
                }
            }
            val mine = photo.reactions.filter { it.userId == state.me }.map { it.emoji }.toSet()
            PhotoContextMenu(
                expanded = ui.photoMenu,
                onDismiss = { ui.photoMenu = false },
                mine = mine,
                onReact = onReact,
                onUnreact = onUnreact,
                onAddReaction = { ui.picker = true },
                items = listOfNotNull(selfieItem) + menuItems,
            )
        }
        // The faces over the photo's bottom-leading corner, `size.global.screenMargin` in from both edges; a sibling of the
        // photo so a tap on it never advances and TalkBack reads it after the photo.
        SelfieStack(
            faces = faces,
            label = stackLabel,
            onClick = { ui.reactions = true },
            modifier = Modifier
                .align(Alignment.BottomStart)
                .padding(start = (maxWidth - visibleWidth) / 2 + Tokens.Sizes.globalScreenMargin, bottom = Tokens.Sizes.globalScreenMargin),
        )
    }
}

/** Until the media's size is known the frame takes a 3:4 box (the strip tiles' shape, `size.global.stripTileWidth` ÷ `.stripTileHeight`). */
private val DEFAULT_ASPECT: Float get() = Tokens.Sizes.globalStripTileWidth / Tokens.Sizes.globalStripTileHeight

/**
 * The viewer's menu (`photo.viewer.layout.menu`): on your own photo first Edit Caption (Add a Caption without one; owner
 * decision 34), then save on every photo (owner decision 28: any member saves any photo they can see), Favorite /
 * Unfavorite (private, Apple Photos), Add to Album, Use as Cover (group admins), then delete (yours) or report + block
 * {name} (others').
 */
@Composable
private fun viewerMenuItems(state: ViewerState, ui: ViewerUiState, nav: ViewerNav, onSave: () -> Unit): List<DsMenuItem> {
    val caption = stringRes(if (state.hasCaption) R.string.photo_viewer_menu_editcaption else R.string.photo_viewer_menu_addcaption)
    val save = stringRes(R.string.photo_viewer_menu_save)
    val favorite = stringRes(R.string.photo_viewer_menu_favorite)
    val unfavorite = stringRes(R.string.photo_viewer_menu_unfavorite)
    val addToAlbum = stringRes(R.string.photo_viewer_menu_addtoalbum)
    val useAsCover = stringRes(R.string.photo_viewer_menu_useascover)
    val delete = stringRes(R.string.photo_viewer_menu_delete)
    val report = stringRes(R.string.photo_viewer_menu_report)
    val block = stringRes(R.string.photo_viewer_menu_block, state.current?.author?.firstName.orEmpty())
    val actions = ui.menuActions
    return buildList {
        if (state.canEditCaption) add(DsMenuItem(caption, { ui.captionDraft = state.current?.post?.caption.orEmpty() }, icon = Tokens.Icons.globalEdit))
        if (state.current?.media != null) add(DsMenuItem(save, onSave, icon = Tokens.Icons.globalDownload))
        if (state.current?.post != null && state.current?.gone != true) {
            if (state.favorite) add(DsMenuItem(unfavorite, actions.toggleFavorite, icon = Tokens.Icons.globalUnfavorite))
            else add(DsMenuItem(favorite, actions.toggleFavorite, icon = Tokens.Icons.globalFavorite))
            add(DsMenuItem(addToAlbum, { ui.albumPickerSession++; ui.albumPicker = true }, icon = Tokens.Icons.globalAlbums))
        }
        if (state.canUseAsCover) add(DsMenuItem(useAsCover, actions.useAsCover, icon = Tokens.Icons.globalCover))
        if (state.mine) {
            add(DsMenuItem(delete, { ui.confirmDelete = true }, icon = Tokens.Icons.globalTrash, destructive = true))
        } else state.current?.post?.let { post ->
            add(DsMenuItem(report, { nav.report(post.groupId, post.id) }, icon = Tokens.Icons.globalReport, destructive = true))
            add(DsMenuItem(block, { nav.block(post.authorId) }))
        }
    }
}

/**
 * The footer inside `size.global.screenMargin`: first baseline `photo.viewer.dimension.footerFirstBaseline` below the
 * photo, lines `photo.viewer.dimension.footerLinePitch` apart — the caption (`listTitle`, `color.global.textOnMedia`),
 * the date (`photo.viewer.layout.dateFormat`, `listSubtitle`, secondary) + " · " + the tag run, the voice note
 * (capsule on `color.global.controlOnDeep`, top one pitch below the date line's baseline). Trailing on the first line:
 * the reaction chip and the add-reaction glyph at the margin.
 */
@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun Footer(photo: ViewerPhoto, state: ViewerState, ui: ViewerUiState, voice: VoiceUi, selfieAllowed: Boolean, onPhotoGone: (String) -> Unit) {
    val post = photo.post ?: return
    val pitch = Tokens.Sizes.photoViewerDimensionFooterLinePitch
    val caption = post.caption?.takeIf { it.isNotBlank() }
    val day = Formats.viewerDate(post.createdAt, photo.zone ?: java.time.ZoneId.systemDefault())
    // "{date} · Edited" once the caption was changed (`caption_edited_at`, `chat.thread.edited`; Retro's ' · ' separator).
    val edited = stringRes(R.string.chat_thread_edited)
    val date = if (post.captionEditedAt != null) day + SEPARATOR + edited else day
    // The memory group's tag run (tagging.md A) gets the tags of the viewer's `post_tags` read, in tag order.
    val tagged = if (photo.loaded) photo.tagged.map { id -> TaggedPerson(id, photo.people[id]?.firstName.orEmpty(), photoModel(photo.people[id]?.avatarPath)) } else null
    val me = state.me?.let { id -> TaggedPerson(id, photo.people[id]?.firstName.orEmpty(), photoModel(photo.people[id]?.avatarPath)) }
    // The trailing reaction slot is centred on the first line: that line stops at the slot. The date line under a
    // caption runs the full width unless the chip (taller than a line) reaches down into it; the add glyph's ink does not.
    val chipShown = photo.reactions.isNotEmpty()
    SubcomposeLayout(Modifier.fillMaxWidth().padding(horizontal = Tokens.Sizes.globalScreenMargin)) { constraints ->
        val loose = constraints.copy(minWidth = 0, minHeight = 0)
        val slot = subcompose(FooterPart.Slot) {
            // Trailing reaction slot, centred on the first line (its baseline less half the cap height).
            val firstLine = if (caption != null) TextRoles.listTitle else TextRoles.listSubtitle
            Row(
                Modifier.centredAt(Tokens.Sizes.photoViewerDimensionFooterFirstBaseline - CapTop.height(firstLine) / 2),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                ReactionChip(photo.reactions, onClick = { ui.reactions = true }, onMedia = true)
                AddReactionGlyph(ui, selfieAllowed) { ui.picker = true }
            }
        }.map { it.measure(loose) }
        val slotWidth = slot.maxOfOrNull { it.width } ?: 0
        val firstLineEnd = Modifier.padding(end = slotWidth.toDp())
        val text = subcompose(FooterPart.Text) {
            Column(Modifier.fillMaxWidth()) {
                if (caption != null) {
                    Text(
                        caption,
                        style = TextRoles.listTitle,
                        color = Tokens.Colors.globalTextOnMedia,
                        modifier = firstLineEnd.paddingFromBaseline(top = Tokens.Sizes.photoViewerDimensionFooterFirstBaseline).endAtLastBaseline().clearAndSetSemantics { },
                    )
                }
                Row(
                    (if (caption == null || chipShown) firstLineEnd else Modifier)
                        .paddingFromBaseline(top = if (caption != null) pitch else Tokens.Sizes.photoViewerDimensionFooterFirstBaseline)
                        .endAtLastBaseline(),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(date, style = TextRoles.listSubtitle, color = Tokens.ColorsDark.globalTextSecondary, maxLines = 1)
                    Text(SEPARATOR, style = TextRoles.listSubtitle, color = Tokens.ColorsDark.globalTextSecondary, maxLines = 1, modifier = Modifier.clearAndSetSemantics { })
                    TagRun(post.id, people = tagged, me = me, onPhotoGone = { onPhotoGone(post.id) })
                }
                val notePath = post.voicePath
                if (notePath != null) {
                    val duration = (post.voiceDurationMs ?: 0).toLong()
                    val voiceLabel = if (state.mine) stringRes(R.string.chat_voice_a11y_messagemine, Formats.spokenDuration(duration))
                    else stringRes(R.string.chat_voice_a11y_message, photo.author?.firstName.orEmpty(), Formats.spokenDuration(duration))
                    Spacer(Modifier.height(pitch))
                    VoiceCapsule(
                        duration,
                        voice.elapsedOf(notePath, duration),
                        voice.stateOf(notePath),
                        voiceLabel,
                        onClick = { voice.play(notePath, post.voiceLevels) },
                        onMedia = true,
                        levels = voice.levelsOf(notePath, post.voiceLevels),
                        progress = voice.progressOf(notePath),
                    )
                }
            }
        }.map { it.measure(loose) }
        val height = maxOf(text.maxOfOrNull { it.height } ?: 0, slot.maxOfOrNull { it.height } ?: 0)
        layout(constraints.maxWidth, height) {
            text.forEach { it.place(0, 0) }
            slot.forEach { it.place(constraints.maxWidth - it.width, 0) }
        }
    }
}

private enum class FooterPart { Slot, Text }

/** Places the element with its vertical centre [y] below the top of its slot (may start above the slot). */
private fun Modifier.centredAt(y: Dp): Modifier = layout { measurable, constraints ->
    val placeable = measurable.measure(constraints.copy(minHeight = 0))
    val top = (y.toPx() - placeable.height / 2f).toInt()
    layout(placeable.width, (top + placeable.height).coerceAtLeast(0)) { placeable.place(0, top) }
}

private const val SEPARATOR = " · " // provenance-ok: Retro's footer separator (media_viewer_footer_tagged_users_divider " · with "), punctuation between two data runs

/**
 * `chat.reactions.icon.add` (`size.global.icon`, `color.global.textSecondary`) with its ink on the margin; hit
 * `size.global.headerButton`. Tap → the emoji picker; with [selfie], touch and hold opens the selfie capture layer in hold
 * mode with the finger still down (`viewer.selfiereaction` §1, `haptic.global.longPressStart`) and TalkBack gets the
 * single-pointer custom action `viewer.selfiereaction.a11y.action` (tap mode).
 */
@Composable
private fun AddReactionGlyph(ui: ViewerUiState, selfie: Boolean, onClick: () -> Unit) {
    val icon = Tokens.Icons.chatReactionsIconAdd
    val box = Tokens.Sizes.globalIcon
    val hit = glyphHit
    val label = stringRes(R.string.chat_reactions_a11y_add)
    val action = stringRes(R.string.viewer_selfiereaction_a11y_action)
    val haptics = rememberHaptics()
    Box(
        Modifier
            .endInset(-(GlyphInk.trailing(icon, box) + (hit - box) / 2))
            .size(hit)
            .selfieHoldGesture(selfie, ui.hold) {
                haptics.longPress()
                ui.selfieLayer = SelfieMode.Hold
            }
            .tapClickable(onClick = onClick)
            .clearAndSetSemantics {
                contentDescription = label
                role = Role.Button
                if (selfie) customActions = listOf(CustomAccessibilityAction(action) { ui.selfieLayer = SelfieMode.Tap; true })
            },
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, contentDescription = null, tint = Tokens.ColorsDark.globalTextSecondary, modifier = Modifier.size(box))
    }
}

/**
 * Comments (`photo.viewer.layout.comments`): the divider (C-32 on media) `photo.viewer.dimension.footerToDivider` below
 * the footer, then the replies as thread rows (avatar `size.global.avatarComment`, text
 * `chat.thread.dimension.rowAvatarToText` after it, "name time", the text a `chat.thread.dimension.rowLinePitch` below)
 * in `color.global.textOnMedia`, the first `photo.viewer.dimension.dividerToComments` below the divider, rows
 * `size.global.listGap` apart. None → no divider.
 */
@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun Comments(photo: ViewerPhoto, state: ViewerState, ui: ViewerUiState, voice: VoiceUi, onUnsendComment: (String) -> Unit) {
    if (photo.comments.isEmpty()) return
    Spacer(Modifier.height(Tokens.Sizes.photoViewerDimensionFooterToDivider))
    Hairline(Modifier.padding(horizontal = Tokens.Sizes.globalScreenMargin).testTag("viewer.divider"), onMedia = true)
    Spacer(Modifier.height(Tokens.Sizes.photoViewerDimensionDividerToComments))
    Column(verticalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalListGap)) {
        photo.comments.forEach { m -> CommentLine(m, photo, state, ui, voice, onUnsendComment) }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun CommentLine(m: Message, photo: ViewerPhoto, state: ViewerState, ui: ViewerUiState, voice: VoiceUi, onUnsendComment: (String) -> Unit) {
    val author = photo.people[m.authorId]
    val mine = m.authorId == state.me
    val isVoice = m.kind == app.data.model.MessageKind.Voice && m.voicePath != null
    val duration = (m.voiceDurationMs ?: 0).toLong()
    val label = when {
        isVoice && mine -> stringRes(R.string.chat_voice_a11y_messagemine, Formats.spokenDuration(duration))
        isVoice -> stringRes(R.string.chat_voice_a11y_message, author?.firstName.orEmpty(), Formats.spokenDuration(duration))
        mine -> stringRes(R.string.chat_thread_a11y_messagemine, m.body.orEmpty())
        else -> stringRes(R.string.chat_thread_a11y_message, author?.firstName.orEmpty(), m.body.orEmpty())
    }
    val items = commentMenu(m, mine, ui)
    Box {
        Row(
            Modifier
                .fillMaxWidth()
                .combinedClickable(onClick = { if (isVoice) m.voicePath?.let { voice.play(it, m.voiceLevels) } }, onLongClick = { ui.commentMenu = m.id })
                .clearAndSetSemantics {
                    contentDescription = label
                    customActions = items.map { i -> CustomAccessibilityAction(i.text) { i.onClick(); true } }
                }
                .padding(horizontal = Tokens.Sizes.globalScreenMargin),
            verticalAlignment = Alignment.Top,
        ) {
            PersonAvatar(author?.avatarPath, Tokens.Sizes.globalAvatarComment)
            Spacer(Modifier.width(Tokens.Sizes.chatThreadDimensionRowAvatarToText))
            Column(Modifier.weight(1f)) {
                Text(
                    buildAnnotatedString {
                        withStyle(TextRoles.listTitle.toSpanStyle().copy(color = Tokens.Colors.globalTextOnMedia)) { append(author?.firstName.orEmpty()) }
                        append(' ')
                        withStyle(TextRoles.caption.toSpanStyle().copy(color = Tokens.ColorsDark.globalTextSecondary)) { append(Formats.shortTime(m.createdAt)) }
                    },
                    style = TextRoles.listTitle,
                    maxLines = 1,
                    modifier = Modifier.endAtLastBaseline(),
                )
                if (isVoice) {
                    // A voice reply: the voice capsule on media with its waveform (chat.voice.md, C-36).
                    val path = m.voicePath
                    Spacer(Modifier.height(Tokens.Sizes.chatThreadDimensionItemGap))
                    VoiceCapsule(
                        duration, voice.elapsedOf(path, duration), voice.stateOf(path), label,
                        onClick = { path?.let { voice.play(it, m.voiceLevels) } },
                        onMedia = true,
                        levels = voice.levelsOf(path, m.voiceLevels),
                        progress = voice.progressOf(path),
                    )
                } else {
                    Text(
                        m.body.orEmpty(),
                        style = TextRoles.body.copy(lineHeight = Tokens.Sizes.chatThreadDimensionRowLinePitch.value.sp),
                        color = Tokens.Colors.globalTextOnMedia,
                        modifier = Modifier.paddingFromBaseline(top = Tokens.Sizes.chatThreadDimensionRowLinePitch),
                    )
                }
            }
        }
        SystemAppearance { DsDropdownMenu(ui.commentMenu == m.id, { ui.commentMenu = null }, items) }
    }
}

/** A comment's long-press menu: the thread's message items that apply here (Copy; Report Message or Unsend). */
@Composable
private fun commentMenu(m: Message, mine: Boolean, ui: ViewerUiState): List<DsMenuItem> {
    val clipboard = androidx.compose.ui.platform.LocalClipboard.current
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    val copied = stringRes(R.string.chat_thread_toast_copied)
    val copy = stringRes(R.string.chat_thread_menu_copy)
    val unsend = stringRes(R.string.chat_thread_menu_delete)
    return buildList {
        // Copy is for text; a voice reply has none (chat.thread's voice menu has no Copy either).
        if (m.kind != app.data.model.MessageKind.Voice) add(
            DsMenuItem(copy, {
                val body = m.body.orEmpty()
                scope.launch { clipboard.setClipEntry(androidx.compose.ui.platform.ClipEntry(android.content.ClipData.newPlainText(body, body))) }
                PlatformToast.show(context, copied)
            }),
        )
        if (mine) add(DsMenuItem(unsend, { ui.confirmUnsend = m.id }, destructive = true))
    }
}

/** The reply field (C-13 on media): placeholder `photo.viewer.reply.placeholder`; camera, then "•••" (menu). */
@Composable
private fun ReplyField(state: ViewerState, ui: ViewerUiState, nav: ViewerNav, onDraft: (String) -> Unit, onSend: () -> Unit, onSave: () -> Unit) {
    var field by remember { mutableStateOf(ui.fixedDraft ?: TextFieldValue(state.draft)) }
    LaunchedEffect(state.draft) { if (ui.fixedDraft == null && state.draft != field.text) field = TextFieldValue(state.draft) }
    val post = state.current?.post
    val me = state.me
    val myAvatar = me?.let { id -> state.photos.firstNotNullOfOrNull { it.people[id] }?.avatarPath }
    val items = viewerMenuItems(state, ui, nav, onSave)
    MessageField(
        value = field,
        onValueChange = {
            field = it
            onDraft(it.text)
        },
        placeholder = stringRes(R.string.photo_viewer_reply_placeholder),
        accessibilityLabel = stringRes(R.string.photo_viewer_reply_placeholder),
        avatarPath = myAvatar,
        glyphs = listOf(
            FieldGlyph(Tokens.Icons.globalCamera, stringRes(R.string.chat_composer_a11y_camera), Tokens.ColorsDark.globalTextSecondary, { post?.let { nav.replyWithPhoto(it.groupId, it.id) } }),
            FieldGlyph(
                Tokens.Icons.globalMore,
                stringRes(R.string.photo_viewer_a11y_more),
                Tokens.ColorsDark.globalTextSecondary,
                { ui.menu = true },
                anchor = { SystemAppearance { DsDropdownMenu(ui.menu, { ui.menu = false }, items) } },
            ),
        ),
        onSend = {
            onSend()
            field = TextFieldValue()
        },
        onMedia = true,
    )
}

/** Sheets and alerts over the viewer (system appearance). */
@Composable
private fun ViewerDialogs(
    state: ViewerState,
    ui: ViewerUiState,
    nav: ViewerNav,
    onReact: (String) -> Unit,
    onUnreact: (String) -> Unit,
    onDelete: () -> Unit,
    onUnsendComment: (String) -> Unit,
    onRemoveSelfie: (String) -> Unit,
) {
    val photo = state.current ?: return
    val haptics = rememberHaptics()
    SystemAppearance {
        val mine = photo.reactions.filter { it.userId == state.me }.map { it.emoji }.toSet()
        if (ui.picker) {
            ReactionPickerSheet(mine, onPick = { e -> ui.picker = false; onReact(e) }, onUnreact = { e -> ui.picker = false; onUnreact(e) }, onDismiss = { ui.picker = false })
        }
        if (ui.reactions) {
            val post = photo.post
            ReactionsSheet(
                entries = photo.reactions,
                me = state.me,
                person = { id -> photo.people[id].let { Reactor(id, it?.firstName.orEmpty(), it?.avatarPath) } },
                onUnreact = onUnreact,
                onDismiss = { ui.reactions = false; ui.selfieMenu = null },
                others = selfieSheetRows(
                    selfies = photo.selfies,
                    me = state.me,
                    myPhoto = state.mine,
                    firstName = { id -> photo.people[id]?.firstName.orEmpty() },
                    menuOpen = ui.selfieMenu,
                    onMenu = { ui.selfieMenu = it },
                    onRemoveMine = { state.me?.let(onRemoveSelfie) },
                    onAskRemove = { userId -> ui.confirmRemoveSelfie = userId },
                    onReport = { entry -> if (post != null && entry.id != null) nav.reportSelfie(post.groupId, entry.id, entry.userId) },
                ),
            )
        }
        ui.confirmRemoveSelfie?.let { userId ->
            // viewer.selfiereaction → remove confirmation (C-29 native alert, `photo.viewer.layout.deleteConfirm` form).
            SystemAlertDialog(
                title = stringRes(R.string.viewer_selfiereaction_remove_title, photo.people[userId]?.firstName.orEmpty()),
                text = stringRes(R.string.viewer_selfiereaction_remove_message),
                confirmLabel = stringRes(R.string.viewer_selfiereaction_remove_confirm),
                onConfirm = {
                    ui.confirmRemoveSelfie = null
                    haptics.perform(Tokens.Haptics.globalWarning)
                    onRemoveSelfie(userId)
                },
                dismissLabel = stringRes(R.string.photo_viewer_delete_cancel),
                onDismiss = { ui.confirmRemoveSelfie = null },
                destructive = true,
            )
        }
        if (ui.confirmDelete) {
            SystemAlertDialog(
                title = stringRes(R.string.photo_viewer_delete_title),
                text = stringRes(R.string.photo_viewer_delete_message),
                confirmLabel = stringRes(R.string.photo_viewer_delete_confirm),
                onConfirm = { ui.confirmDelete = false; onDelete() },
                dismissLabel = stringRes(R.string.photo_viewer_delete_cancel),
                onDismiss = { ui.confirmDelete = false },
                destructive = true,
            )
        }
        // `photo.viewer.layout.editCaption`: the platform alert with one text field; Save → edit_caption (blank removes it).
        ui.captionDraft?.let { draft ->
            SystemTextFieldDialog(
                title = stringRes(if (state.hasCaption) R.string.photo_viewer_menu_editcaption else R.string.photo_viewer_menu_addcaption),
                value = draft,
                onValueChange = { ui.captionDraft = it.take(PhotoViewerViewModel.CAPTION_MAX) },
                placeholder = stringRes(R.string.photo_viewer_caption_placeholder),
                confirmLabel = stringRes(R.string.photo_viewer_caption_save),
                onConfirm = {
                    ui.captionDraft = null
                    ui.menuActions.saveCaption(draft)
                },
                dismissLabel = stringRes(R.string.photo_viewer_delete_cancel),
                onDismiss = { ui.captionDraft = null },
                modifier = Modifier.testTag("photo.viewer.caption"),
            )
        }
        val albumPost = photo.post
        if (ui.albumPicker && albumPost != null) {
            AlbumPickerSheet(
                groupId = albumPost.groupId,
                postId = albumPost.id,
                onDone = { ui.albumPicker = false; ui.menuActions.addedToAlbum() },
                onDismiss = { ui.albumPicker = false },
                session = ui.albumPickerSession,
            )
        }
        ui.confirmUnsend?.let { id ->
            SystemAlertDialog(
                title = stringRes(R.string.chat_thread_deletemessage_title),
                text = stringRes(R.string.chat_thread_deletemessage_message),
                confirmLabel = stringRes(R.string.chat_thread_deletemessage_confirm),
                onConfirm = { ui.confirmUnsend = null; onUnsendComment(id) },
                dismissLabel = stringRes(R.string.photo_viewer_delete_cancel),
                onDismiss = { ui.confirmUnsend = null },
                destructive = true,
            )
        }
    }
}
