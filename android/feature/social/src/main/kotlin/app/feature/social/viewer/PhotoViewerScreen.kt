// Surface: photo.viewer — full photo: caption, voice note, reactions, reply, "i'm in this", delete, report, save.
// References: references/auto/yope/frames/b-yopeapp-7591560669967682847-t57.07-photo-viewer.png (primary),
// references/auto/yope/frames/b-yopeapp-7591560669967682847-t57.20-viewer-swipe-start.png (swipe),
// references/auto/locket/store/locket-store-08.png (quick reactions), references/auto/locket/store/locket-store-04.png (cluster),
// references/auto/yope/frames/a-yrrah-7434441926000037121-t33.73-group-menu-leave-report-2024.png (••• menu).
package app.feature.social.viewer

import android.Manifest
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.PagerState
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.FirstBaseline
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.layout.layout
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.withStyle
import androidx.compose.foundation.text.BasicText
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.data.media.StoragePaths
import app.data.model.Media
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.designsystem.rememberReduceMotion
import app.feature.social.chat.CapsuleField
import app.feature.social.chat.CircleButton
import app.feature.social.chat.VoiceBubble
import app.feature.social.common.Avatar
import app.feature.social.common.ConfirmationToast
import app.feature.social.common.EmptyState
import app.feature.social.common.Formats
import app.feature.social.common.Glyph
import app.feature.social.common.InkGlyph
import app.feature.social.common.Line
import app.feature.social.common.LocalApproximations
import app.feature.social.common.LocalPhotoOverride
import app.feature.social.common.LocalSocialData
import app.feature.social.common.LocalSocialServices
import app.feature.social.common.RemotePhoto
import app.feature.social.common.Type
import app.feature.social.common.announce
import app.feature.social.common.rememberHaptics
import app.feature.social.common.stringRes
import app.feature.social.data.VoicePlayback
import app.feature.social.data.VoiceServices
import app.feature.social.reactions.ActivitySheet
import app.feature.social.reactions.EmojiCatalog
import app.feature.social.reactions.EmojiGlyph
import app.feature.social.reactions.EmojiRain
import app.feature.social.reactions.ReactionCluster
import app.feature.social.reactions.ReactionPickerSheet
import app.ui.components.PermissionCard
import coil3.SingletonImageLoader
import coil3.request.ImageRequest
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.launch

/** Where the viewer leads. */
data class ViewerNav(
    val close: () -> Unit,
    /** The sender overlay: `walls.member`, or `walls.mine` for your own photo. */
    val person: (userId: String, mine: Boolean) -> Unit,
    /** Reply to the photo with a photo (`camera.capture`, `create_post` `p_reply_to_post_id`). */
    val replyWithPhoto: (groupId: String, postId: String) -> Unit,
    val report: (groupId: String, postId: String) -> Unit,
    val block: (userId: String) -> Unit,
)

/** Transient UI state of the viewer, hoisted for tests. */
class ViewerUiState(menu: Boolean = false, confirmDelete: Boolean = false, picker: Boolean = false, saveDenied: Boolean = false, coach: Boolean? = null) {
    var menu by mutableStateOf(menu)
    var confirmDelete by mutableStateOf(confirmDelete)
    var picker by mutableStateOf(picker)
    var activity by mutableStateOf(false)
    var saveDenied by mutableStateOf(saveDenied)
    var toast by mutableStateOf<String?>(null)
    var rain by mutableStateOf<Pair<String, Int>?>(null)
    /** Null = follow the per-account memory. */
    var coach by mutableStateOf(coach)
}

@Composable
fun PhotoViewerScreen(vm: PhotoViewerViewModel, nav: ViewerNav, ui: ViewerUiState = remember { ViewerUiState() }) {
    val state by vm.state.collectAsStateWithLifecycle()
    val context = LocalContext.current
    val view = LocalView.current
    val haptics = rememberHaptics()
    val reduceMotion by rememberReduceMotion()
    val rainAllowed = app.feature.social.common.shows(app.feature.social.common.SocialBlocked.rainEasing != null)
    val services = LocalSocialServices.current
    val voice = remember { services.voice(context) }
    androidx.compose.runtime.DisposableEffect(voice) { onDispose { voice.release() } }
    val playback by voice.playback.collectAsStateWithLifecycle()
    val data = LocalSocialData.current
    val scope = rememberCoroutineScope()
    var rainKey by remember { mutableIntStateOf(0) }

    val texts = ViewerTexts(
        saved = stringRes(R.string.photo_viewer_toast_saved),
        deleted = stringRes(R.string.photo_viewer_toast_deleted),
        saveFailed = stringRes(R.string.photo_viewer_error_save),
        deleteFailed = stringRes(R.string.photo_viewer_error_delete),
        sendFailed = stringRes(R.string.chat_thread_sendfailed),
        reactionFailed = stringRes(R.string.chat_reactions_error),
        tagError = stringRes(R.string.tagging_error),
        tagNotFound = stringRes(R.string.tagging_notfound),
        tagOffline = stringRes(R.string.tagging_offline),
        playFailed = stringRes(R.string.chat_voice_error_play),
    )
    LaunchedEffect(vm) {
        vm.effects.collect { effect ->
            when (effect) {
                ViewerEffect.Sent -> haptics.play(Tokens.Haptics.globalSend)
                ViewerEffect.SendFailed -> { haptics.play(Tokens.Haptics.globalError); announce(view, texts.sendFailed) }
                is ViewerEffect.Rain -> if (rainAllowed && !reduceMotion) ui.rain = effect.emoji to ++rainKey
                ViewerEffect.ReactionFailed -> { haptics.play(Tokens.Haptics.globalError); announce(view, texts.reactionFailed) }
                ViewerEffect.Deleted -> ui.toast = texts.deleted
                ViewerEffect.DeleteFailed -> { haptics.play(Tokens.Haptics.globalError); announce(view, texts.deleteFailed) }
                ViewerEffect.Saved -> { haptics.play(Tokens.Haptics.globalSuccess); ui.toast = texts.saved }
                ViewerEffect.SaveFailed -> { haptics.play(Tokens.Haptics.globalError); announce(view, texts.saveFailed) }
                ViewerEffect.Tagged -> haptics.play(Tokens.Haptics.globalSelect)
                is ViewerEffect.TagFailed -> {
                    haptics.play(Tokens.Haptics.globalError)
                    announce(view, when (effect.reason) { TagFailure.Error -> texts.tagError; TagFailure.NotFound -> texts.tagNotFound; TagFailure.Offline -> texts.tagOffline })
                }
            }
        }
    }
    LaunchedEffect(state.closed) { if (state.closed) nav.close() }

    val gallery = services.gallery
    val save: () -> Unit = {
        scope.launch {
            val original = vm.originalBytes()
            if (original == null) vm.saved(false)
            else {
                val ext = original.second.substringAfterLast('.', "jpg").lowercase()
                val mime = runCatching { StoragePaths.contentTypeFor(ext) }.getOrDefault("image/jpeg")
                vm.saved(gallery.save(context, original.first, mime, ext))
            }
        }
    }
    val storageLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        ui.saveDenied = !granted
        if (granted) save()
    }
    val onSave: () -> Unit = {
        if (gallery.needsPermission(context)) storageLauncher.launch(Manifest.permission.WRITE_EXTERNAL_STORAGE) else save()
    }
    val onPlay: (String) -> Unit = { path ->
        if (playback.key == path && playback.isPlaying) voice.pause()
        else scope.launch {
            val url = runCatching { data.signedUrls(listOf(path))[path] }.getOrNull()
            if (url != null) voice.play(path, url) else announce(view, texts.playFailed)
        }
    }

    PhotoViewerContent(
        state = state,
        ui = ui,
        nav = nav,
        voice = voice,
        playback = playback,
        onSelect = vm::select,
        onDraft = vm::setDraft,
        onSend = vm::sendReply,
        onReact = vm::react,
        onTag = vm::toggleTag,
        onDelete = { haptics.play(Tokens.Haptics.globalWarning); vm.deleteEverywhere() },
        onSave = onSave,
        onRetry = vm::retryLoad,
        onPlay = onPlay,
    )
}

private class ViewerTexts(
    val saved: String,
    val deleted: String,
    val saveFailed: String,
    val deleteFailed: String,
    val sendFailed: String,
    val reactionFailed: String,
    val tagError: String,
    val tagNotFound: String,
    val tagOffline: String,
    val playFailed: String,
)

/** The viewer without its view model (snapshots). */
@Composable
fun PhotoViewerContent(
    state: ViewerState,
    ui: ViewerUiState,
    nav: ViewerNav,
    voice: VoiceServices?,
    playback: VoicePlayback,
    onSelect: (Int) -> Unit,
    onDraft: (String) -> Unit,
    onSend: () -> Unit,
    onReact: (String) -> Unit,
    onTag: () -> Unit,
    onDelete: () -> Unit,
    onSave: () -> Unit,
    onRetry: () -> Unit,
    onPlay: (String) -> Unit,
) {
    val activityAllowed = app.feature.social.common.shows(app.feature.social.common.SocialBlocked.activitySheet)
    val pager = rememberPagerState(initialPage = state.index) { state.photos.size }
    // Keep the pager on the view model's photo when the list grows around it or a photo is removed.
    LaunchedEffect(state.index, state.photos.size) { if (pager.currentPage != state.index && state.index in state.photos.indices) pager.scrollToPage(state.index) }
    LaunchedEffect(pager) { snapshotFlow { pager.settledPage }.distinctUntilChanged().collect(onSelect) }
    PrefetchNeighbours(state)
    val current = state.current

    Box(Modifier.fillMaxSize().background(Tokens.Colors.photoViewerColorBackground).testTag("photo.viewer")) {
        // Emoji rain: behind the photo, in front of the background (S-9).
        ui.rain?.let { (emoji, key) -> EmojiRain(emoji, key, onFinished = { if (ui.rain?.second == key) ui.rain = null }) }
        Column(Modifier.fillMaxSize().imePadding().navigationBarsPadding()) {
            // Page gap is BLOCKED (`photo.viewer.dimension.pageGap`): none until it is known.
            HorizontalPager(
                state = pager,
                modifier = Modifier.weight(1f).fillMaxWidth(),
                pageSpacing = app.feature.social.common.SocialBlocked.viewerPageGap ?: 0.dp,
                key = { i -> state.photos.getOrNull(i)?.postId ?: i },
            ) { page ->
                val photo = state.photos.getOrNull(page)
                if (photo != null) ViewerPage(photo, state, ui, nav, voice, playback, onTag, onRetry, onPlay, onSave, onDelete)
            }
            if (ui.saveDenied) {
                PermissionCard(
                    stringRes(R.string.photo_viewer_permission_title),
                    stringRes(R.string.photo_viewer_permission_detail),
                    stringRes(R.string.photo_viewer_permission_button),
                    onSave,
                    Modifier.padding(horizontal = Tokens.Sizes.onboardingPermissionContactsSizeCardMarginH),
                )
            }
            if (current?.post != null && !current.gone) {
                ReplyRow(
                    draft = state.draft,
                    groupName = current.groupName.orEmpty(),
                    onDraft = onDraft,
                    onSend = onSend,
                    onReact = onReact,
                    onPicker = { ui.picker = true },
                    onCamera = { nav.replyWithPhoto(current.post.groupId, current.post.id) },
                )
            }
        }
        ViewerHeader(state, ui, nav, onSave)
        ConfirmationToast(ui.toast) { ui.toast = null }
    }

    if (ui.picker) ReactionPickerSheet(onPick = { emoji -> ui.picker = false; onReact(emoji) }, onDismiss = { ui.picker = false })
    if (activityAllowed && ui.activity && current?.post != null) {
        val me = state.me
        ActivitySheet(current.reactions, me, { id -> if (id == current.post.authorId) current.author?.firstName.orEmpty() else "" }, current.author?.firstName.orEmpty(), onDismiss = { ui.activity = false })
    }
    if (ui.confirmDelete) {
        AlertDialog(
            onDismissRequest = { ui.confirmDelete = false },
            title = { Text(stringRes(R.string.photo_viewer_delete_title)) },
            text = { Text(stringRes(R.string.photo_viewer_delete_message)) },
            confirmButton = { TextButton(onClick = { ui.confirmDelete = false; onDelete() }) { Text(stringRes(R.string.photo_viewer_delete_confirm), color = Tokens.Colors.globalSystemError) } },
            dismissButton = { TextButton(onClick = { ui.confirmDelete = false }) { Text(stringRes(R.string.photo_viewer_delete_cancel)) } },
        )
    }
}

/** Starts loading the neighbouring photos' display images so a swipe lands on a drawn photo. */
@Composable
private fun PrefetchNeighbours(state: ViewerState) {
    if (LocalPhotoOverride.current != null) return
    val context = LocalContext.current
    val data = LocalSocialData.current
    val paths = listOf(state.index - 1, state.index + 1).mapNotNull { state.photos.getOrNull(it)?.media?.imagePath(Media.Rendition.Display) }
    LaunchedEffect(paths) {
        val urls = runCatching { data.signedUrls(paths) }.getOrDefault(emptyMap())
        val loader = SingletonImageLoader.get(context)
        urls.values.forEach { url -> loader.enqueue(ImageRequest.Builder(context).data(url).build()) }
    }
}

/**
 * Header row centred `photo.viewer.dimension.headerCenterY` below the top safe-area inset: bare ✕
 * (`closeGlyph` ink height, centre `closeCenterX`), the two-line title, bare ••• (`moreGlyphWidth`,
 * centre `moreCenterTrailing` from the right) opening the native menu.
 */
@Composable
private fun ViewerHeader(state: ViewerState, ui: ViewerUiState, nav: ViewerNav, onSave: () -> Unit) {
    val current = state.current
    val touch = Tokens.Sizes.globalMinTouchTargetAndroid
    val rowHeight = Tokens.Sizes.photoViewerDimensionHeaderCenterY * 2
    val closeLabel = stringRes(R.string.photo_viewer_a11y_close)
    val moreLabel = stringRes(R.string.photo_viewer_a11y_more)
    Box(Modifier.fillMaxWidth().windowInsetsPadding(WindowInsets.statusBars).height(rowHeight)) {
        Box(
            Modifier
                .align(Alignment.CenterStart)
                .offset(x = Tokens.Sizes.photoViewerDimensionCloseCenterX - touch / 2)
                .size(touch)
                .clickable(role = Role.Button, onClick = nav.close)
                .clearAndSetSemantics { contentDescription = closeLabel; role = Role.Button },
            contentAlignment = Alignment.Center,
        ) { InkGlyph(Tokens.Icons.globalClose, Tokens.Colors.globalTextPrimary, inkHeight = Tokens.Sizes.photoViewerDimensionCloseGlyph) }
        if (current?.post != null && !current.gone) {
            ViewerTitle(
                sender = if (state.mine) stringRes(R.string.photo_viewer_title_you) else current.author?.firstName.orEmpty(),
                group = current.groupName.orEmpty(),
                date = Formats.viewerDate(current.post.createdAt),
                modifier = Modifier.align(Alignment.Center).padding(horizontal = touch + Tokens.Sizes.photoViewerDimensionCloseCenterX),
            )
            Box(
                Modifier
                    .align(Alignment.CenterEnd)
                    .offset(x = -(Tokens.Sizes.photoViewerDimensionMoreCenterTrailing - touch / 2))
                    .size(touch),
            ) {
                Box(
                    Modifier.fillMaxSize().clickable(role = Role.Button) { ui.menu = true }.clearAndSetSemantics { contentDescription = moreLabel; role = Role.Button },
                    contentAlignment = Alignment.Center,
                ) { InkGlyph(Tokens.Icons.globalMore, Tokens.Colors.globalTextPrimary, inkWidth = Tokens.Sizes.photoViewerDimensionMoreGlyphWidth) }
                ViewerMenu(state, ui, nav, onSave)
            }
        }
    }
}

/**
 * Line 1: [you | first name] + "sent to" + group (text role `headerTitle`; names
 * `color.global.textPrimary`, "sent to" `color.global.textSecondary`; the group name truncates);
 * line 2: the date (`listSubtitle`, `color.global.textSecondary`) with its baseline
 * `photo.viewer.dimension.titleToDate` below line 1's. Read as one header element.
 */
@Composable
private fun ViewerTitle(sender: String, group: String, date: String, modifier: Modifier = Modifier) {
    val sentTo = stringRes(R.string.photo_viewer_title_sentto)
    val line1 = buildAnnotatedString {
        withStyle(SpanStyle(color = Tokens.Colors.globalTextPrimary)) { append(sender) }
        append(' ')
        withStyle(SpanStyle(color = Tokens.Colors.globalTextSecondary)) { append(sentTo) }
        append(' ')
        withStyle(SpanStyle(color = Tokens.Colors.globalTextPrimary)) { append(group) }
    }
    val gap = Tokens.Sizes.photoViewerDimensionTitleToDate
    val titleStyle = Type.headerTitle()
    val dateStyle = Type.listSubtitle()
    Layout(
        // Read as one header element (the platform merge of both lines).
        modifier = modifier.semantics(mergeDescendants = true) { heading() },
        content = {
            BasicText(line1, style = titleStyle, maxLines = 1, overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis)
            Line(date, dateStyle, Tokens.Colors.globalTextSecondary)
        },
    ) { measurables, constraints ->
        val loose = constraints.copy(minWidth = 0, minHeight = 0)
        val top = measurables[0].measure(loose)
        val bottom = measurables[1].measure(loose)
        val topBaseline = top[FirstBaseline]
        val bottomBaseline = bottom[FirstBaseline]
        val bottomY = topBaseline + gap.roundToPx() - bottomBaseline
        val width = maxOf(top.width, bottom.width)
        val height = maxOf(top.height, bottomY + bottom.height)
        layout(width, height) {
            top.place((width - top.width) / 2, 0)
            bottom.place((width - bottom.width) / 2, bottomY)
        }
    }
}

/** The native ••• menu (`photo.viewer.layout.menu`): save; delete (yours) or report + block {name} (others'). */
@Composable
private fun ViewerMenu(state: ViewerState, ui: ViewerUiState, nav: ViewerNav, onSave: () -> Unit) {
    val current = state.current ?: return
    val post = current.post ?: return
    DropdownMenu(expanded = ui.menu, onDismissRequest = { ui.menu = false }) {
        DropdownMenuItem(
            text = { Text(stringRes(R.string.photo_viewer_menu_save)) },
            leadingIcon = { Glyph(Tokens.Icons.globalDownload, Tokens.Colors.globalSystemOnSurface) },
            onClick = { ui.menu = false; onSave() },
        )
        if (state.mine) {
            DropdownMenuItem(
                text = { Text(stringRes(R.string.photo_viewer_menu_delete), color = Tokens.Colors.globalSystemError) },
                leadingIcon = { Glyph(Tokens.Icons.photoViewerIconDelete, Tokens.Colors.globalSystemError) },
                onClick = { ui.menu = false; ui.confirmDelete = true },
            )
        } else {
            DropdownMenuItem(
                text = { Text(stringRes(R.string.photo_viewer_menu_report), color = Tokens.Colors.globalSystemError) },
                leadingIcon = { Glyph(Tokens.Icons.globalReport, Tokens.Colors.globalSystemError) },
                onClick = { ui.menu = false; nav.report(post.groupId, post.id) },
            )
            DropdownMenuItem(
                text = { Text(stringRes(R.string.photo_viewer_menu_block, current.author?.firstName.orEmpty()), color = Tokens.Colors.globalSystemError) },
                onClick = { ui.menu = false; nav.block(post.authorId) },
            )
        }
    }
}

@Composable
private fun ViewerPage(
    photo: ViewerPhoto,
    state: ViewerState,
    ui: ViewerUiState,
    nav: ViewerNav,
    voice: VoiceServices?,
    playback: VoicePlayback,
    onTag: () -> Unit,
    onRetry: () -> Unit,
    onPlay: (String) -> Unit,
    onSave: () -> Unit,
    onDelete: () -> Unit,
) {
    val top = WindowInsets.statusBars.asPaddingValues().calculateTopPadding() + Tokens.Sizes.photoViewerDimensionPhotoTop
    if (photo.gone) {
        Box(Modifier.fillMaxSize().padding(top = top), contentAlignment = Alignment.Center) {
            EmptyState(stringRes(R.string.photo_viewer_gone_title), stringRes(R.string.photo_viewer_gone_detail), null)
        }
        return
    }
    val post = photo.post
    val voicePath = post?.voicePath
    BoxWithConstraints(Modifier.fillMaxSize()) {
        val voiceSpace = if (voicePath != null) Tokens.Sizes.globalScreenMargin + Tokens.Sizes.chatVoiceDimensionHeight else 0.dp
        val available = (maxHeight - top - voiceSpace).coerceAtLeast(0.dp)
        val media = photo.media
        val aspect = media?.let { m -> if ((m.width ?: 0) > 0 && (m.height ?: 0) > 0) m.width!!.toFloat() / m.height!! else null }
        // Full width at the photo's own aspect; a photo taller than the space is scaled down to fit, centred (approximation).
        val (w, h) = when {
            aspect == null -> maxWidth to available
            maxWidth / aspect <= available -> maxWidth to maxWidth / aspect
            else -> available * aspect to available
        }
        Column(Modifier.fillMaxSize().padding(top = top), horizontalAlignment = Alignment.CenterHorizontally) {
            PhotoFrame(photo, state, ui, nav, w, h, if (aspect == null) ContentScale.Fit else ContentScale.Crop, onTag, onRetry, onSave, onDelete)
            val voiceMs = post?.voiceDurationMs
            if (voicePath != null && voiceMs != null) {
                Spacer(Modifier.height(Tokens.Sizes.globalScreenMargin))
                Box(Modifier.fillMaxWidth().padding(start = Tokens.Sizes.globalScreenMargin)) {
                    val mine = post.authorId == state.me
                    VoiceBubble(
                        path = voicePath,
                        durationMs = voiceMs,
                        fill = if (mine) Tokens.Colors.chatVoiceColorBubble else app.feature.social.common.SocialBlocked.voiceBubbleTheirs,
                        progress = if (playback.key == voicePath) playback.progress else 0f,
                        label = if (mine) stringRes(R.string.chat_voice_a11y_messagemine, Formats.spokenDuration(voiceMs))
                        else stringRes(R.string.chat_voice_a11y_message, photo.author?.firstName.orEmpty(), Formats.spokenDuration(voiceMs)),
                        playing = playback.key == voicePath && playback.isPlaying,
                        voice = voice,
                        onToggle = { onPlay(voicePath) },
                    )
                }
            }
        }
    }
}

@Composable
private fun PhotoFrame(
    photo: ViewerPhoto,
    state: ViewerState,
    ui: ViewerUiState,
    nav: ViewerNav,
    width: Dp,
    height: Dp,
    scale: ContentScale,
    onTag: () -> Unit,
    onRetry: () -> Unit,
    onSave: () -> Unit,
    onDelete: () -> Unit,
) {
    val activityAllowed = app.feature.social.common.shows(app.feature.social.common.SocialBlocked.activitySheet)
    val context = LocalContext.current
    val post = photo.post
    val media = photo.media
    val mine = post != null && post.authorId == state.me
    val name = if (mine) stringRes(R.string.photo_viewer_title_you) else photo.author?.firstName.orEmpty()
    val date = post?.let { Formats.viewerDate(it.createdAt) }.orEmpty()
    val caption = post?.caption?.takeIf { it.isNotBlank() }
    val label = if (mine) stringRes(R.string.photo_viewer_a11y_photomine, date) else stringRes(R.string.photo_viewer_a11y_photo, name, date)
    val captionLabel = caption?.let { stringRes(R.string.chat_thread_a11y_caption, it) }
    val actions = buildList {
        add(CustomAccessibilityAction(stringRes(R.string.photo_viewer_menu_save)) { onSave(); true })
        if (mine) add(CustomAccessibilityAction(stringRes(R.string.photo_viewer_menu_delete)) { ui.confirmDelete = true; true })
        else if (post != null) {
            add(CustomAccessibilityAction(stringRes(R.string.photo_viewer_menu_report)) { nav.report(post.groupId, post.id); true })
            add(CustomAccessibilityAction(stringRes(R.string.photo_viewer_menu_block, name)) { nav.block(post.authorId); true })
        }
    }
    Box(
        Modifier
            .size(width, height)
            .clip(RoundedCornerShape(Tokens.Radii.globalPhoto))
            // The photo, its caption and its reactions are one element (platform merge); sender and toggle stay separate controls.
            .semantics(mergeDescendants = true) { customActions = actions },
    ) {
        RemotePhoto(media?.imagePath(Media.Rendition.Display), label, Modifier.fillMaxSize(), scale, fallbackPath = media?.imagePath(Media.Rendition.Thumb))
        if (photo.loadFailed) {
            Box(Modifier.fillMaxSize().clickable(onClick = onRetry), contentAlignment = Alignment.Center) {
                Line(stringRes(R.string.photo_viewer_error_load), Type.style(Tokens.FontSizes.globalEmptyDetail), Tokens.Colors.globalTextSecondary)
            }
        }
        if (post == null) return@Box
        // Sender overlay (top-left).
        Row(
            Modifier
                .padding(start = Tokens.Sizes.photoViewerDimensionSenderInsetLeading, top = Tokens.Sizes.photoViewerDimensionSenderInsetTop)
                .clickable(role = Role.Button) { nav.person(post.authorId, mine) }
                .semantics(mergeDescendants = true) { contentDescription = name; role = Role.Button },
            verticalAlignment = Alignment.Top,
        ) {
            Avatar(photo.author?.avatarPath, Tokens.Sizes.photoViewerDimensionSenderAvatar)
            Spacer(Modifier.width(Tokens.Sizes.photoViewerDimensionSenderNameGap))
            Line(name, Type.headerTitle(), Tokens.Colors.globalTextPrimary, Modifier.clearAndSetSemantics { })
        }
        // "i'm in this" toggle (top-right slot) and its first-use coach.
        var toggleWidth by remember { mutableIntStateOf(0) }
        val density = LocalDensity.current
        val showCoach = photo.tagged != null && !mine && (ui.coach ?: !TagCoachMemory.seen(context, state.me))
        Layout(
            modifier = Modifier.align(Alignment.TopEnd).padding(end = Tokens.Sizes.photoViewerDimensionActionTrailing),
            content = {
                if (photo.tagged != null) {
                    TagToggle(
                        on = photo.tagged,
                        pending = photo.tagPending,
                        onToggle = {
                            ui.coach = false
                            TagCoachMemory.markSeen(context, state.me)
                            onTag()
                        },
                        modifier = Modifier.onSizeChanged { toggleWidth = it.width },
                    )
                    if (showCoach) {
                        TagCoach(
                            targetWidth = with(density) { toggleWidth.toDp() },
                            onDismiss = {
                                ui.coach = false
                                TagCoachMemory.markSeen(context, state.me)
                            },
                        )
                    }
                }
            },
        ) { measurables, constraints ->
            // The toggle's vertical centre sits `actionCenterTop` below the photo's top edge; the coach hangs under it.
            val loose = constraints.copy(minWidth = 0, minHeight = 0)
            val toggle = measurables.getOrNull(0)?.measure(loose)
            val coach = measurables.getOrNull(1)?.measure(loose)
            if (toggle == null) return@Layout layout(0, 0) {}
            val width = maxOf(toggle.width, coach?.width ?: 0)
            val y = (Tokens.Sizes.photoViewerDimensionActionCenterTop.roundToPx() - toggle.height / 2).coerceAtLeast(0)
            layout(width, y + toggle.height + (coach?.height ?: 0)) {
                toggle.place(width - toggle.width, y)
                coach?.place(width - coach.width, y + toggle.height)
            }
        }
        // Caption (bottom-centre; its color.global.scrim box fill is BLOCKED and not drawn).
        if (caption != null) {
            val scrim = app.feature.social.common.SocialBlocked.scrim
            Box(
                Modifier
                    .align(Alignment.BottomCenter)
                    .padding(
                        bottom = Tokens.Sizes.chatThreadDimensionCaptionInsetBottom,
                        start = Tokens.Sizes.chatReactionsDimensionClusterInsetLeading + Tokens.Sizes.chatReactionsDimensionClusterEmoji,
                        end = Tokens.Sizes.chatReactionsDimensionClusterInsetLeading + Tokens.Sizes.chatReactionsDimensionClusterEmoji,
                    )
                    .heightIn(min = Tokens.Sizes.chatThreadDimensionCaptionHeight)
                    .let { if (scrim != null) it.background(scrim, RoundedCornerShape(Tokens.Radii.chatThreadRadiusCaption)) else it }
                    .padding(horizontal = Tokens.Sizes.chatThreadDimensionCaptionPaddingH)
                    .clearAndSetSemantics { if (captionLabel != null) contentDescription = captionLabel },
                contentAlignment = Alignment.Center,
            ) {
                Line(
                    caption,
                    Type.style(Tokens.FontSizes.chatThreadFontSizeCaption, Tokens.FontWeights.chatThreadFontWeightCaption),
                    Tokens.Colors.globalTextPrimary,
                    maxLines = Int.MAX_VALUE,
                    align = androidx.compose.ui.text.style.TextAlign.Center,
                )
            }
        }
        ReactionCluster(
            photo.reactions,
            if (activityAllowed) ({ ui.activity = true }) else null,
            Modifier.align(Alignment.BottomStart).padding(start = Tokens.Sizes.chatReactionsDimensionClusterInsetLeading, bottom = Tokens.Sizes.chatReactionsDimensionClusterInsetBottom),
        )
    }
}

/**
 * The reply row (rides on the keyboard): the composer field with placeholder
 * `photo.viewer.reply.placeholder`, Locket's quick reactions 🔥 💖 and the add-reaction glyph inside
 * its right end (`chat.reactions.layout.quickReactions`), then the camera circle.
 */
@Composable
private fun ReplyRow(
    draft: String,
    groupName: String,
    onDraft: (String) -> Unit,
    onSend: () -> Unit,
    onReact: (String) -> Unit,
    onPicker: () -> Unit,
    onCamera: () -> Unit,
) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.Bottom) {
        Spacer(Modifier.width(Tokens.Sizes.chatComposerDimensionInsetLeading))
        CapsuleField(
            value = draft,
            onValueChange = onDraft,
            placeholder = stringRes(R.string.photo_viewer_reply_placeholder, groupName),
            label = stringRes(R.string.chat_composer_a11y_field),
            onSend = onSend,
            modifier = Modifier.weight(1f),
            trailing = { QuickReactions(onReact, onPicker) },
        )
        Spacer(Modifier.width(Tokens.Sizes.chatComposerDimensionGapFieldButton))
        CircleButton(
            size = Tokens.Sizes.chatComposerDimensionSideButton,
            fill = Tokens.Colors.globalControlRaised,
            icon = Tokens.Icons.globalCamera,
            tint = Tokens.Colors.globalTextPrimary,
            glyphInkHeight = null,
            label = stringRes(R.string.chat_composer_a11y_camera),
            onClick = onCamera,
        )
        Spacer(Modifier.width(Tokens.Sizes.chatComposerDimensionInsetTrailing))
    }
}

/**
 * 🔥 💖 + add glyph. Their size and spacing inside the field are not measured: the emoji take the
 * field's text size (text role `body`), `size.global.headerGap` apart, ending
 * `chat.composer.dimension.fieldPaddingLeading` from the field's end (approximation).
 */
@Composable
private fun QuickReactions(onReact: (String) -> Unit, onPicker: () -> Unit) {
    val density = LocalDensity.current
    val emojiWidth = with(density) { Tokens.FontSizes.globalBody.toDp() }
    Row(
        Modifier.padding(end = Tokens.Sizes.chatComposerDimensionFieldPaddingLeading),
        horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalHeaderGap),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        EmojiCatalog.quick.forEach { emoji ->
            val label = stringRes(R.string.chat_reactions_a11y_quick, app.feature.social.common.EmojiNames.name(emoji))
            Box(Modifier.clickable(role = Role.Button) { onReact(emoji) }.clearAndSetSemantics { contentDescription = label; role = Role.Button }) {
                EmojiGlyph(emoji, emojiWidth)
            }
        }
        val add = stringRes(R.string.chat_reactions_a11y_add)
        Box(Modifier.clickable(role = Role.Button, onClick = onPicker).clearAndSetSemantics { contentDescription = add; role = Role.Button }) {
            Glyph(Tokens.Icons.chatReactionsIconAdd, Tokens.Colors.globalTextSecondary)
        }
    }
}
