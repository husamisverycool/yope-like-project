// Surface: chat.thread — design/surfaces/chat.thread.md (+ chat.composer, chat.voice, chat.reactions)
// References: references/auto/retro/press/tc-2023-07-retro-2b.jpg phone 2 (comment rows, comment field),
// references/auto/retro/press/engadget-2026-08-the-problem-with-friends-only-socials-1786385236.jpg (pushed "Messages" header),
// references/auto/retro/store/retro-store-01.png (photo card), references/auto/retro/press/tc-2024-04-journals-1.webp
// (dated section header), references/auto/imessage/apple-support/messages-not-delivered.png (failed line),
// references/auto/whatsapp/store/whatsapp-store-04.png (one header per run, summary under a message).
package app.feature.social.chat

import android.Manifest
import android.content.ClipData
import android.content.Intent
import android.net.Uri
import android.os.SystemClock
import android.provider.Settings
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.paddingFrom
import androidx.compose.foundation.layout.paddingFromBaseline
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.LastBaseline
import androidx.compose.ui.platform.ClipEntry
import androidx.compose.ui.platform.LocalClipboard
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.data.model.MessageKind
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.social.common.Formats
import app.feature.social.common.LocalApproximations
import app.feature.social.common.LocalSocialData
import app.feature.social.common.LocalSocialServices
import app.feature.social.common.PersonAvatar
import app.feature.social.common.PhotoSaveUi
import app.feature.social.common.RemotePhoto
import app.feature.social.common.photoModel
import app.ui.media.DualImage
import app.feature.social.common.SocialBlocked
import app.feature.social.common.announce
import app.feature.social.common.rememberPhotoSaver
import app.feature.social.common.stringRes
import app.feature.social.data.VoicePlayback
import app.feature.social.data.VoiceServices
import app.feature.social.reactions.PhotoContextMenu
import app.feature.social.reactions.ReactionChip
import app.feature.social.reactions.ReactionPickerSheet
import app.feature.social.reactions.Reactor
import app.feature.social.reactions.ReactionsSheet
import app.media.MediaPermission
import app.media.MediaPermissions
import app.ui.components.EmptyState
import app.ui.components.EmptyStateAction
import app.ui.components.EmptyStateFill
import app.ui.components.LoadingState
import app.ui.components.ActivityIndicator
import app.ui.components.PlatformToast
import app.ui.components.PushedHeader
import app.ui.components.SectionHeader
import app.ui.foundation.DsMotion
import app.ui.foundation.GlyphInk
import app.ui.foundation.PageRoles
import app.ui.foundation.endAtLastBaseline
import app.ui.foundation.tapClickable
import app.ui.haptics.rememberHaptics
import app.ui.permissions.findActivity
import app.ui.system.DsDropdownMenu
import app.ui.system.DsMenuItem
import app.ui.system.SystemAlertDialog
import app.ui.text.CapTop
import app.ui.text.TextRoles
import app.ui.text.capTopAt
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.ZoneId

/** Where the thread leads (design/surfaces/chat.thread.md → Navigation out). */
data class ChatNav(
    val back: () -> Unit,
    val photo: (postId: String) -> Unit,
    val member: (userId: String) -> Unit,
    val invite: () -> Unit,
    /** `camera.capture` for this group; [replyToPostId] when the reply bar quotes a photo. */
    val camera: (replyToPostId: String?) -> Unit,
    val reportMessage: (messageId: String, authorId: String) -> Unit,
    val reportPost: (postId: String) -> Unit,
)

/** Transient UI state of the thread (menus, sheets, dialogs, recording), hoisted for tests. */
class ChatUiState(
    menuFor: String? = null,
    pickerFor: String? = null,
    reactionsFor: String? = null,
    confirmUnsend: String? = null,
    confirmDeletePhoto: String? = null,
    micDenied: Boolean = false,
    recording: Recording? = null,
    draft: TextFieldValue? = null,
) {
    /** The message whose context menu is open. */
    var menuFor by mutableStateOf(menuFor)
    var pickerFor by mutableStateOf(pickerFor)
    var reactionsFor by mutableStateOf(reactionsFor)
    var confirmUnsend by mutableStateOf(confirmUnsend)
    var confirmDeletePhoto by mutableStateOf(confirmDeletePhoto)
    var micDenied by mutableStateOf(micDenied)
    /** Voice recording in progress (`chat.voice.layout.recording`), null when idle. */
    var recording by mutableStateOf(recording)
    /** Fixed draft for snapshots; null = the view model's draft. */
    val fixedDraft = draft
    val save = PhotoSaveUi()
    val micDrag = MicDrag()
}

/** How often the recording timer re-reads the clock (the label changes once a second). */
private const val TIMER_TICK_MS = 200L

@Composable
fun ChatScreen(vm: ChatViewModel, focusMessageId: String?, nav: ChatNav, ui: ChatUiState = remember { ChatUiState() }) {
    val state by vm.state.collectAsStateWithLifecycle()
    val context = LocalContext.current
    val view = LocalView.current
    val haptics = rememberHaptics()
    val services = LocalSocialServices.current
    val voice = remember { services.voice(context) }
    DisposableEffect(voice) { onDispose { voice.release() } }
    val playback by voice.playback.collectAsStateWithLifecycle()
    val data = LocalSocialData.current
    val scope = rememberCoroutineScope()
    val labels = rowLabels()

    val sendFailed = stringRes(R.string.chat_thread_sendfailed)
    val reactionFailed = stringRes(R.string.chat_reactions_error)
    val recordFailed = stringRes(R.string.chat_voice_error_record)
    val deleted = stringRes(R.string.photo_viewer_toast_deleted)
    val deleteFailed = stringRes(R.string.photo_viewer_error_delete)
    LaunchedEffect(vm) {
        vm.effects.collect { effect ->
            when (effect) {
                ChatEffect.Sent -> haptics.perform(Tokens.Haptics.globalSend)
                ChatEffect.SendFailed -> { haptics.perform(Tokens.Haptics.globalError); announce(view, sendFailed) }
                ChatEffect.ReactionFailed -> { haptics.perform(Tokens.Haptics.globalError); PlatformToast.show(context, reactionFailed) }
                ChatEffect.DeleteFailed -> { haptics.perform(Tokens.Haptics.globalError); PlatformToast.show(context, deleteFailed) }
                ChatEffect.PhotoDeleted -> PlatformToast.show(context, deleted)
                ChatEffect.RecordFailed -> { haptics.perform(Tokens.Haptics.globalError); PlatformToast.show(context, recordFailed) }
                is ChatEffect.Incoming -> announce(view, labels.of(effect.row))
            }
        }
    }

    val micLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted -> ui.micDenied = !granted }
    // Recording (`chat.voice.layout.recording`): hold to record, lift to send, slide left to cancel, slide up to
    // lock; locked: trash discards, send sends. No haptics while the microphone is in use.
    val startRecording: () -> Boolean = start@{
        if (ui.recording != null) return@start false
        if (!MediaPermissions.isGranted(context, MediaPermission.Microphone)) {
            if (context.findActivity() != null) MediaPermissions.markRequested(context, MediaPermission.Microphone)
            micLauncher.launch(Manifest.permission.RECORD_AUDIO)
            return@start false
        }
        if (runCatching { voice.startRecording() }.isFailure) {
            vm.recordFailed()
            return@start false
        }
        ui.recording = Recording.Holding(SystemClock.elapsedRealtime())
        true
    }
    val sendRecording: () -> Unit = {
        if (ui.recording != null) {
            val note = runCatching { voice.stopRecording() }.getOrNull()
            if (note != null) vm.sendVoice(note.file, note.durationMs) else vm.recordFailed()
        }
        ui.recording = null
    }
    val cancelRecording: () -> Unit = {
        if (ui.recording != null) runCatching { voice.cancelRecording() }
        ui.recording = null
    }
    BackHandler(enabled = ui.recording != null, onBack = cancelRecording)
    DisposableEffect(Unit) { onDispose { if (ui.recording != null) cancelRecording() } }
    var now by remember { mutableLongStateOf(SystemClock.elapsedRealtime()) }
    LaunchedEffect(ui.recording) {
        while (ui.recording != null) {
            now = SystemClock.elapsedRealtime()
            delay(TIMER_TICK_MS)
        }
    }
    val recorder = RecorderControls(
        elapsedMs = ui.recording?.let { (now - it.startedAt).coerceAtLeast(0L) } ?: 0L,
        gesture = MicGesture(
            onHoldStart = startRecording,
            onRelease = sendRecording,
            onCancel = cancelRecording,
            onLock = { ui.recording?.let { ui.recording = Recording.Locked(it.startedAt) } },
        ),
        onStartLocked = { if (startRecording()) ui.recording?.let { ui.recording = Recording.Locked(it.startedAt) } },
        onSend = sendRecording,
        onDiscard = cancelRecording,
    )

    var loadingKey by remember { mutableStateOf<String?>(null) }
    var failedKeys by remember { mutableStateOf(emptySet<String>()) }
    LaunchedEffect(playback.key, playback.isPlaying) { if (playback.isPlaying && playback.key == loadingKey) loadingKey = null }
    val onPlay: (String) -> Unit = { path ->
        haptics.tap()
        if (playback.key == path && playback.isPlaying) voice.pause()
        else scope.launch {
            failedKeys = failedKeys - path
            loadingKey = path
            val url = runCatching { data.signedUrls(listOf(path))[path] }.getOrNull()
            if (url != null) voice.play(path, url) else { loadingKey = null; failedKeys = failedKeys + path }
        }
    }
    val savedText = stringRes(R.string.photo_viewer_toast_saved)
    val saveFailed = stringRes(R.string.photo_viewer_error_save)
    val savePhoto = rememberPhotoSaver(ui.save) { ok ->
        if (ok) { haptics.perform(Tokens.Haptics.globalSuccess); PlatformToast.show(context, savedText) }
        else { haptics.perform(Tokens.Haptics.globalError); PlatformToast.show(context, saveFailed) }
    }
    val clipboard = LocalClipboard.current
    val copied = stringRes(R.string.chat_thread_toast_copied)

    ChatContent(
        state = state,
        ui = ui,
        nav = nav,
        focusMessageId = focusMessageId,
        voice = VoiceUi(playback, loadingKey, failedKeys, onPlay),
        recorder = recorder,
        onDraft = vm::setDraft,
        onSend = vm::send,
        onRetry = vm::retry,
        onLoadOlder = vm::loadOlder,
        onReact = vm::react,
        onUnreact = vm::unreact,
        onRetrySend = vm::retrySend,
        onReply = vm::startReply,
        onCancelReply = vm::cancelReply,
        onCopy = { text ->
            scope.launch { clipboard.setClipEntry(ClipEntry(ClipData.newPlainText(text, text))) }
            PlatformToast.show(context, copied)
        },
        // A photo leaves the app only when it is your own (owner decision 12).
        onSave = { row -> if (row.mine) row.media?.originalPath?.let(savePhoto) },
        onUnsend = { id -> haptics.perform(Tokens.Haptics.globalWarning); vm.deleteMessage(id) },
        onDeletePhoto = { postId -> haptics.perform(Tokens.Haptics.globalWarning); vm.deletePhoto(postId) },
        onOpenMicSettings = {
            ui.micDenied = false
            context.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", context.packageName, null)))
        },
    )
}

/** Playback of the thread's voice messages (one at a time). */
class VoiceUi(val playback: VoicePlayback, val loadingKey: String?, val failedKeys: Set<String>, val onPlay: (String) -> Unit) {
    fun stateOf(path: String?): VoiceState = voiceStateOf(path, playback.key, playback.isPlaying, playback.progress, loadingKey, failedKeys)
    fun elapsedOf(path: String?, durationMs: Long): Long = if (path != null && path == playback.key) (playback.progress * durationMs).toLong() else 0L

    companion object {
        val Idle = VoiceUi(VoicePlayback(null, false), null, emptySet()) {}
    }
}

/** The composer's recording controls. */
class RecorderControls(
    val elapsedMs: Long = 0L,
    val gesture: MicGesture = MicGesture({ false }, {}, {}, {}),
    val onStartLocked: () -> Unit = {},
    val onSend: () -> Unit = {},
    val onDiscard: () -> Unit = {},
)

/** Labels of rows, for announcements and semantics. */
class RowLabels(
    private val message: (String, String) -> String,
    private val messageMine: (String) -> String,
    private val voice: (String, String) -> String,
    private val voiceMine: (String) -> String,
    private val photo: (String, String) -> String,
    private val photoMine: (String) -> String,
    private val caption: (String) -> String,
) {
    fun of(row: ChatRow): String {
        val name = row.author?.firstName.orEmpty()
        return when (row.kind) {
            MessageKind.Text -> if (row.mine) messageMine(row.message.body.orEmpty()) else message(name, row.message.body.orEmpty())
            MessageKind.Voice -> {
                val d = Formats.spokenDuration((row.message.voiceDurationMs ?: 0).toLong())
                if (row.mine) voiceMine(d) else voice(name, d)
            }
            MessageKind.Photo -> {
                val t = Formats.shortTime(row.message.createdAt)
                val base = if (row.mine) photoMine(t) else photo(name, t)
                row.post?.caption?.takeIf { it.isNotBlank() }?.let { "$base, ${caption(it)}" } ?: base
            }
        }
    }
}

@Composable
fun rowLabels(): RowLabels {
    val r = LocalContext.current.resources
    return remember(r) {
        RowLabels(
            message = { n, m -> r.getString(R.string.chat_thread_a11y_message, n, m) },
            messageMine = { m -> r.getString(R.string.chat_thread_a11y_messagemine, m) },
            voice = { n, d -> r.getString(R.string.chat_voice_a11y_message, n, d) },
            voiceMine = { d -> r.getString(R.string.chat_voice_a11y_messagemine, d) },
            photo = { n, t -> r.getString(R.string.chat_thread_a11y_photo, n, t) },
            photoMine = { t -> r.getString(R.string.chat_thread_a11y_photomine, t) },
            caption = { c -> r.getString(R.string.chat_thread_a11y_caption, c) },
        )
    }
}

/** One element of the thread, oldest first (`chat.thread.layout.runs`). */
sealed interface ThreadItem {
    val key: String

    data class Divider(val date: LocalDate, val first: Boolean) : ThreadItem {
        override val key get() = "d:$date"
    }

    /** [startsRun]: avatar + name / time line; [afterDivider]: directly under a day divider. */
    data class Item(val row: ChatRow, val startsRun: Boolean, val afterDivider: Boolean) : ThreadItem {
        override val key get() = row.key
    }
}

/**
 * The thread's items: a day divider before the first message of each day, runs of one sender's consecutive
 * messages (`chat.thread.layout.runs`: another sender, a divider or a reply quote starts a new run).
 */
fun threadItems(rows: List<ChatRow>, zone: ZoneId = ZoneId.systemDefault()): List<ThreadItem> {
    val out = ArrayList<ThreadItem>()
    var day: LocalDate? = null
    var author: String? = null
    rows.forEach { row ->
        val d = row.message.createdAt.atZone(zone).toLocalDate()
        val divider = d != day
        if (divider) {
            out += ThreadItem.Divider(d, first = day == null)
            day = d
        }
        val starts = divider || row.message.authorId != author || row.quote != null
        out += ThreadItem.Item(row, starts, afterDivider = divider)
        author = row.message.authorId
    }
    return out
}

/** The thread without its view model (snapshots render this with fixed states). */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun ChatContent(
    state: ChatState,
    ui: ChatUiState,
    nav: ChatNav,
    focusMessageId: String?,
    voice: VoiceUi,
    recorder: RecorderControls,
    onDraft: (String) -> Unit,
    onSend: () -> Unit,
    onRetry: () -> Unit,
    onLoadOlder: () -> Unit,
    onReact: (postId: String, emoji: String) -> Unit,
    onUnreact: (postId: String, emoji: String) -> Unit,
    onRetrySend: (messageId: String) -> Unit,
    onReply: (ChatRow) -> Unit,
    onCancelReply: () -> Unit,
    onCopy: (String) -> Unit,
    onSave: (ChatRow) -> Unit,
    onUnsend: (messageId: String) -> Unit,
    onDeletePhoto: (postId: String) -> Unit,
    onOpenMicSettings: () -> Unit,
    listState: LazyListState = rememberLazyListState(),
    zone: ZoneId = ZoneId.systemDefault(),
    today: LocalDate = LocalDate.now(zone),
) {
    val page = PageRoles.page
    Column(
        Modifier
            .fillMaxSize()
            .background(page)
            .testTag("chat.thread")
            .statusBarsPadding()
            .navigationBarsPadding()
            .imePadding(),
    ) {
        PushedHeader(state.group?.name.orEmpty(), nav.back, stringRes(R.string.chat_thread_a11y_back))
        Box(Modifier.weight(1f).fillMaxWidth()) {
            when {
                state.phase == ChatState.Phase.Loading -> LoadingState(stringRes(R.string.week_history_a11y_loading))
                state.phase == ChatState.Phase.Error -> EmptyStateFill {
                    EmptyState(
                        stringRes(R.string.chat_thread_error_title),
                        stringRes(R.string.chat_thread_error_detail),
                        action = EmptyStateAction(stringRes(R.string.chat_thread_error_retry), onRetry),
                    )
                }
                state.phase == ChatState.Phase.OfflineEmpty -> EmptyStateFill {
                    EmptyState(stringRes(R.string.chat_thread_offline_title), stringRes(R.string.chat_thread_offline_detail))
                }
                state.isEmpty -> EmptyStateFill {
                    EmptyState(
                        stringRes(R.string.chat_thread_empty_title),
                        stringRes(R.string.chat_thread_empty_detail),
                        action = EmptyStateAction(stringRes(R.string.chat_thread_empty_invite), nav.invite),
                        icon = Tokens.Icons.globalChats,
                    )
                }
                else -> MessageList(state, ui, nav, focusMessageId, voice, onLoadOlder, onReact, onUnreact, onRetrySend, onReply, onCopy, onSave, listState, zone, today)
            }
        }
        ReplyBarLine(state.replyTo, onCancelReply)
        ComposerArea(state, ui, nav, recorder, onDraft, onSend)
    }

    ThreadDialogs(state, ui, onReact, onUnreact, onUnsend, onDeletePhoto, onOpenMicSettings)
}

/** The bar above the field while replying: "Replying to {name}" and a bare close glyph at the trailing margin. */
@Composable
private fun ReplyBarLine(target: ReplyTarget?, onCancel: () -> Unit) {
    AnimatedVisibility(target != null, enter = DsMotion.fadeIn, exit = DsMotion.fadeOut) {
        val t = target ?: return@AnimatedVisibility
        val text = if (t.self) stringRes(R.string.chat_thread_reply_barself) else stringRes(R.string.chat_thread_reply_bar, t.name)
        val box = Tokens.Sizes.globalIcon
        val close = Tokens.Icons.globalClose
        val end = Tokens.Sizes.globalScreenMargin - GlyphInk.trailing(close, box) - (glyphHit - box) / 2
        Row(Modifier.fillMaxWidth().padding(start = Tokens.Sizes.globalScreenMargin), verticalAlignment = Alignment.CenterVertically) {
            Text(
                text,
                style = TextRoles.listSubtitle,
                color = PageRoles.secondaryText(),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f).paddingFrom(LastBaseline, after = Tokens.Sizes.globalSectionHeaderToContent),
            )
            BareGlyph(close, stringRes(R.string.chat_thread_a11y_cancelreply), PageRoles.secondaryText(), onCancel, Modifier.endInset(end))
        }
    }
}

/** The composer (C-13) pinned at the bottom with the lock circle over the mic while holding. */
@Composable
private fun ComposerArea(state: ChatState, ui: ChatUiState, nav: ChatNav, recorder: RecorderControls, onDraft: (String) -> Unit, onSend: () -> Unit) {
    var field by remember { mutableStateOf(ui.fixedDraft ?: TextFieldValue(state.draft)) }
    LaunchedEffect(state.draft) { if (ui.fixedDraft == null && state.draft != field.text) field = TextFieldValue(state.draft) }
    val me = state.me
    val myAvatar = state.rows.firstOrNull { it.message.authorId == me }?.author?.avatarPath ?: state.meAvatar
    val recording = ui.recording
    val mic = Tokens.Icons.globalMic
    val box = Tokens.Sizes.globalIcon
    // Mic glyph centre from the field's trailing edge (its ink `glyphInsetTrailing` from the edge).
    val micCentreFromEnd = Tokens.Sizes.chatComposerDimensionGlyphInsetTrailing - GlyphInk.trailing(mic, box) + box / 2
    val height = Tokens.Sizes.globalCommentFieldHeight
    BoxWithConstraints(Modifier.fillMaxWidth().padding(top = Tokens.Sizes.chatComposerDimensionBottomInset)) {
        val fieldWidth = maxWidth - Tokens.Sizes.globalScreenMargin * 2
        val cancel = fieldWidth / 2 - micCentreFromEnd
        val lock = height / 2 + Tokens.Sizes.globalPillGap + Tokens.Sizes.globalCircleButton / 2
        val glyphs = when (recording) {
            is Recording.Locked -> listOf(
                FieldGlyph(Tokens.Icons.globalTrash, stringRes(R.string.chat_voice_a11y_discard), Tokens.Colors.globalDestructive, recorder.onDiscard),
                FieldGlyph(Tokens.Icons.globalSend, stringRes(R.string.chat_composer_a11y_send), Tokens.Colors.globalTextPrimary, recorder.onSend),
            )
            else -> listOf(
                FieldGlyph(Tokens.Icons.globalCamera, stringRes(R.string.chat_composer_a11y_camera), PageRoles.secondaryText(), { nav.camera(state.replyTo?.postId) }),
                FieldGlyph(
                    mic,
                    stringRes(R.string.chat_composer_a11y_mic),
                    PageRoles.secondaryText(),
                    recorder.onStartLocked,
                    gesture = Modifier.micGesture(recorder.gesture, ui.micDrag, cancel, lock),
                    dragOffset = { ui.micDrag.offset },
                ),
            )
        }
        MessageField(
            value = field,
            onValueChange = {
                field = it
                onDraft(it.text)
            },
            placeholder = if (state.replyTo != null) stringRes(R.string.chat_composer_placeholderreply) else stringRes(R.string.chat_composer_placeholder),
            accessibilityLabel = stringRes(R.string.chat_composer_a11y_field),
            avatarPath = myAvatar,
            glyphs = glyphs,
            onSend = {
                onSend()
                field = TextFieldValue()
            },
            recording = recording?.let { r -> { RecordingContent(r, recorder.elapsedMs) } },
        )
        if (recording is Recording.Holding) {
            LockCircle(
                recorder.gesture.onLock,
                Modifier
                    .align(Alignment.BottomEnd)
                    .padding(end = Tokens.Sizes.globalScreenMargin + micCentreFromEnd - Tokens.Sizes.globalCircleButton / 2)
                    .offset(y = -(height + Tokens.Sizes.globalPillGap)),
            )
        }
    }
}

/** Menus' and sheets' dialogs of the thread (native alerts, the picker and the Reactions sheet). */
@Composable
private fun ThreadDialogs(
    state: ChatState,
    ui: ChatUiState,
    onReact: (String, String) -> Unit,
    onUnreact: (String, String) -> Unit,
    onUnsend: (String) -> Unit,
    onDeletePhoto: (String) -> Unit,
    onOpenMicSettings: () -> Unit,
) {
    val me = state.me
    ui.pickerFor?.let { postId ->
        val mine = state.rows.firstOrNull { it.message.postId == postId }?.reactions.orEmpty().filter { it.userId == me }.map { it.emoji }.toSet()
        ReactionPickerSheet(mine, onPick = { e -> ui.pickerFor = null; onReact(postId, e) }, onUnreact = { e -> ui.pickerFor = null; onUnreact(postId, e) }, onDismiss = { ui.pickerFor = null })
    }
    ui.reactionsFor?.let { postId ->
        val entries = state.rows.firstOrNull { it.message.postId == postId }?.reactions.orEmpty()
        ReactionsSheet(
            entries = entries,
            me = me,
            person = { id -> reactor(state, id) },
            onUnreact = { e -> onUnreact(postId, e) },
            onDismiss = { ui.reactionsFor = null },
            newestFirst = SocialBlocked.reactionListOrder || LocalApproximations.current,
        )
    }
    ui.confirmUnsend?.let { id ->
        SystemAlertDialog(
            title = stringRes(R.string.chat_thread_deletemessage_title),
            text = stringRes(R.string.chat_thread_deletemessage_message),
            confirmLabel = stringRes(R.string.chat_thread_deletemessage_confirm),
            onConfirm = { ui.confirmUnsend = null; onUnsend(id) },
            dismissLabel = stringRes(R.string.photo_viewer_delete_cancel),
            onDismiss = { ui.confirmUnsend = null },
            destructive = true,
        )
    }
    ui.confirmDeletePhoto?.let { postId ->
        SystemAlertDialog(
            title = stringRes(R.string.photo_viewer_delete_title),
            text = stringRes(R.string.photo_viewer_delete_message),
            confirmLabel = stringRes(R.string.photo_viewer_delete_confirm),
            onConfirm = { ui.confirmDeletePhoto = null; onDeletePhoto(postId) },
            dismissLabel = stringRes(R.string.photo_viewer_delete_cancel),
            onDismiss = { ui.confirmDeletePhoto = null },
            destructive = true,
        )
    }
    if (ui.micDenied) {
        SystemAlertDialog(
            title = stringRes(R.string.chat_voice_permission_title),
            text = stringRes(R.string.chat_voice_permission_detail),
            confirmLabel = stringRes(R.string.chat_voice_permission_button),
            onConfirm = onOpenMicSettings,
            dismissLabel = stringRes(R.string.photo_viewer_delete_cancel),
            onDismiss = { ui.micDenied = false },
        )
    }
}

/** A person of the Reactions sheet, from the thread's profiles. */
private fun reactor(state: ChatState, userId: String): Reactor {
    val profile = state.profileOf(userId)
    return Reactor(userId, profile?.firstName.orEmpty(), profile?.avatarPath)
}

@Composable
private fun MessageList(
    state: ChatState,
    ui: ChatUiState,
    nav: ChatNav,
    focusMessageId: String?,
    voice: VoiceUi,
    onLoadOlder: () -> Unit,
    onReact: (String, String) -> Unit,
    onUnreact: (String, String) -> Unit,
    onRetrySend: (String) -> Unit,
    onReply: (ChatRow) -> Unit,
    onCopy: (String) -> Unit,
    onSave: (ChatRow) -> Unit,
    listState: LazyListState,
    zone: ZoneId,
    today: LocalDate,
) {
    val items = remember(state.rows, zone) { threadItems(state.rows, zone).asReversed() }
    val scope = rememberCoroutineScope()
    val todayText = stringRes(R.string.chat_thread_divider_today)
    val yesterdayText = stringRes(R.string.chat_thread_divider_yesterday)
    val labels = rowLabels()
    // Older pages load when the oldest loaded message comes into view.
    val nearTop by remember(items) { derivedStateOf { (listState.layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: 0) >= items.size - 2 } }
    LaunchedEffect(nearTop) { if (nearTop) onLoadOlder() }
    // The newest message stays in view: when one arrives while the bottom of the thread is showing, scroll to it.
    val newest = items.firstOrNull()?.key
    var shownNewest by remember { mutableStateOf<String?>(null) }
    LaunchedEffect(newest) {
        val previous = shownNewest
        shownNewest = newest
        if (newest != null && previous != null && previous != newest && listState.layoutInfo.visibleItemsInfo.any { it.key == previous }) listState.scrollToItem(0)
    }
    LaunchedEffect(focusMessageId, items.isNotEmpty()) {
        val i = items.indexOfFirst { it is ThreadItem.Item && it.row.id == focusMessageId }
        if (focusMessageId != null && i >= 0) listState.scrollToItem(i)
    }
    val scrollTo: (String) -> Unit = { id ->
        val i = items.indexOfFirst { it is ThreadItem.Item && it.row.id == id }
        if (i >= 0) scope.launch { listState.animateScrollToItem(i) }
    }
    LazyColumn(
        state = listState,
        reverseLayout = true,
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(bottom = Tokens.Sizes.photoViewerDimensionCommentsToField),
    ) {
        items(items, key = { it.key }, contentType = { it::class }) { item ->
            when (item) {
                // C-20 dated header: `size.global.sectionGap` above (the first one's cap top on the header's
                // `size.global.titleToContent`), `size.global.sectionHeaderToContent` below its baseline.
                is ThreadItem.Divider -> SectionHeader(
                    Formats.dayDivider(item.date, today, todayText, yesterdayText),
                    if (item.first) Modifier.capTopAt(0.dp, CapTop.height(TextRoles.sectionLabel)) else Modifier,
                    afterContent = !item.first,
                )
                is ThreadItem.Item -> MessageItem(
                    item,
                    state,
                    ui,
                    nav,
                    voice,
                    labels,
                    onReact,
                    onUnreact,
                    onRetrySend,
                    onReply,
                    onCopy,
                    onSave,
                    scrollTo,
                    Modifier.animateItem(fadeInSpec = tween(Tokens.Durations.chatThreadDurationEntry, easing = Tokens.Easings.chatThreadEasingEntry), placementSpec = null, fadeOutSpec = DsMotion.fade()),
                )
            }
        }
        if (state.loadingOlder) item(key = "older") {
            Box(Modifier.fillMaxWidth().padding(vertical = Tokens.Sizes.globalSectionHeaderToContent), contentAlignment = Alignment.Center) {
                ActivityIndicator(stringRes(R.string.week_history_a11y_loading))
            }
        }
    }
}

/** One message in the thread (C-16 comment row form; `chat.thread.layout.runs`). */
@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun MessageItem(
    item: ThreadItem.Item,
    state: ChatState,
    ui: ChatUiState,
    nav: ChatNav,
    voice: VoiceUi,
    labels: RowLabels,
    onReact: (String, String) -> Unit,
    onUnreact: (String, String) -> Unit,
    onRetrySend: (String) -> Unit,
    onReply: (ChatRow) -> Unit,
    onCopy: (String) -> Unit,
    onSave: (ChatRow) -> Unit,
    scrollTo: (String) -> Unit,
    modifier: Modifier,
) {
    val row = item.row
    val top: Dp = when {
        item.afterDivider -> 0.dp
        item.startsRun -> Tokens.Sizes.globalListGap
        else -> Tokens.Sizes.chatThreadDimensionItemGap
    }
    val avatar = Tokens.Sizes.globalAvatarComment
    val gap = Tokens.Sizes.chatThreadDimensionRowAvatarToText
    Row(modifier.fillMaxWidth().padding(top = top).padding(horizontal = Tokens.Sizes.globalScreenMargin), verticalAlignment = Alignment.Top) {
        if (item.startsRun) {
            PersonAvatar(
                row.author?.avatarPath,
                avatar,
                Modifier.tapClickable { nav.member(row.message.authorId) }.clearAndSetSemantics { },
            )
        } else {
            Spacer(Modifier.width(avatar))
        }
        Spacer(Modifier.width(gap))
        Column(Modifier.weight(1f)) {
            if (item.startsRun) RunHeader(row, textNext = row.kind == MessageKind.Text && row.quote == null) { nav.member(row.message.authorId) }
            row.quote?.let { q ->
                if (item.startsRun) Spacer(Modifier.height(Tokens.Sizes.chatThreadDimensionItemGap))
                QuoteView(q, nav, scrollTo)
            }
            // Right under the name line the first text's baseline sits `chat.thread.dimension.rowLinePitch` below the
            // name's; after a quote the item follows at `chat.thread.dimension.itemGap` (the quote's own spacer).
            val afterName = item.startsRun && row.quote == null
            MessageBody(row, afterName, state, ui, nav, voice, labels, onReact, onUnreact, onRetrySend, onReply, onCopy, onSave)
            if (row.mine && (row.pending || row.failed)) StatusLine(row, onRetrySend)
        }
    }
}

/** The run's first line: the sender's name (`listTitle`) and, one space after it, the time (`caption`, secondary). */
@Composable
private fun RunHeader(row: ChatRow, textNext: Boolean, onClick: () -> Unit) {
    val secondary = PageRoles.secondaryText()
    Text(
        buildAnnotatedString {
            withStyle(TextRoles.listTitle.toSpanStyle().copy(color = Tokens.Colors.globalTextPrimary)) { append(row.author?.firstName.orEmpty()) }
            append(' ')
            withStyle(TextRoles.caption.toSpanStyle().copy(color = secondary)) { append(Formats.shortTime(row.message.createdAt)) }
        },
        style = TextRoles.listTitle,
        maxLines = 1,
        overflow = TextOverflow.Ellipsis,
        modifier = Modifier
            .tapClickable(onClick = onClick)
            .clearAndSetSemantics { }
            .then(if (textNext) Modifier.endAtLastBaseline() else Modifier),
    )
}

/** The quote above a reply (`chat.thread.layout.replyQuote`). */
@Composable
private fun QuoteView(quote: Quote, nav: ChatNav, scrollTo: (String) -> Unit) {
    val secondary = PageRoles.secondaryText()
    when (quote) {
        is Quote.Photo -> {
            val label = stringRes(R.string.chat_thread_a11y_replyquote, quote.posterName.orEmpty())
            Row(
                Modifier
                    .tapClickable { nav.photo(quote.postId) }
                    .clearAndSetSemantics {
                        contentDescription = label
                        role = Role.Button
                    },
                verticalAlignment = Alignment.CenterVertically,
            ) {
                RemotePhoto(
                    quote.thumbPath,
                    null,
                    Modifier.size(Tokens.Sizes.globalRowThumbWidth, Tokens.Sizes.globalRowThumbHeight).clip(RoundedCornerShape(Tokens.Radii.globalThumbnail)),
                )
                Spacer(Modifier.width(Tokens.Sizes.globalRowThumbGap))
                Column {
                    Text(stringRes(R.string.chat_thread_reply_posttitle, quote.posterName.orEmpty()), style = TextRoles.listTitle, color = Tokens.Colors.globalTextPrimary, maxLines = 1)
                    quote.weekNumber?.let { Text(stringRes(R.string.chat_thread_reply_postweek, it), style = TextRoles.listSubtitle, color = secondary, maxLines = 1) }
                }
            }
        }
        is Quote.Text -> {
            val body = when {
                quote.attachment -> stringRes(R.string.chat_thread_reply_defaultattachment)
                quote.text == null -> stringRes(R.string.chat_thread_reply_defaulttext)
                else -> quote.text
            }
            Text(
                buildAnnotatedString {
                    withStyle(SpanStyle(fontWeight = Tokens.FontWeights.fontWeightGlobalListTitle)) { append(quote.senderName.orEmpty()) }
                    append(' ')
                    append(body)
                },
                style = TextRoles.listSubtitle,
                color = secondary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.tapClickable { scrollTo(quote.messageId) },
            )
        }
    }
    Spacer(Modifier.height(Tokens.Sizes.chatThreadDimensionItemGap))
}

/** Whether [text] is 1…`chat.thread.count.emojiOnlyMax` emoji and nothing else. */
fun isEmojiOnly(text: String): Boolean {
    val t = text.trim()
    if (t.isEmpty()) return false
    val emoji = app.feature.social.common.EmojiNames.inText(t)
    if (emoji.isEmpty() || emoji.size > Tokens.Counts.chatThreadCountEmojiOnlyMax) return false
    return emoji.joinToString("") == t.filterNot { it.isWhitespace() || it.code == ZWJ }
}

private const val ZWJ = 0x200D

/** The message's content with its long-press menu (C-29) and TalkBack actions. */
@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun MessageBody(
    row: ChatRow,
    afterName: Boolean,
    state: ChatState,
    ui: ChatUiState,
    nav: ChatNav,
    voice: VoiceUi,
    labels: RowLabels,
    onReact: (String, String) -> Unit,
    onUnreact: (String, String) -> Unit,
    onRetrySend: (String) -> Unit,
    onReply: (ChatRow) -> Unit,
    onCopy: (String) -> Unit,
    onSave: (ChatRow) -> Unit,
) {
    val menu = menuItems(row, ui, nav, onRetrySend, onReply, onCopy, onSave)
    val label = labels.of(row)
    val actions = menu.map { m -> CustomAccessibilityAction(m.text) { m.onClick(); true } }
    val failedText = stringRes(R.string.chat_thread_sendfailed)
    val open = ui.menuFor == row.key
    val tap: () -> Unit = {
        when {
            row.failed -> onRetrySend(row.id)
            row.kind == MessageKind.Photo -> row.message.postId?.let(nav.photo)
            row.kind == MessageKind.Voice -> row.message.voicePath?.let(voice.onPlay)
        }
    }
    val semantics = Modifier.clearAndSetSemantics {
        contentDescription = label
        role = Role.Button
        if (row.failed) stateDescription = failedText
        customActions = actions
    }
    Box {
        when (row.kind) {
            MessageKind.Text -> {
                val body = row.message.body.orEmpty()
                val big = isEmojiOnly(body)
                Text(
                    body,
                    style = if (big) TextRoles.body.copy(fontSize = Tokens.FontSizes.globalHeaderTitle, lineHeight = Tokens.LineHeights.globalHeaderTitle)
                    else TextRoles.body.copy(lineHeight = Tokens.Sizes.chatThreadDimensionRowLinePitch.value.sp),
                    color = Tokens.Colors.globalTextPrimary,
                    modifier = Modifier
                        .then(if (afterName && !big) Modifier.paddingFromBaseline(top = Tokens.Sizes.chatThreadDimensionRowLinePitch) else if (afterName) Modifier.padding(top = Tokens.Sizes.chatThreadDimensionItemGap) else Modifier)
                        .combinedClickable(onClick = tap, onLongClick = { ui.menuFor = row.key })
                        .then(semantics),
                )
            }
            MessageKind.Voice -> {
                val path = row.message.voicePath
                val duration = (row.message.voiceDurationMs ?: 0).toLong()
                if (afterName) Spacer(Modifier.height(Tokens.Sizes.chatThreadDimensionItemGap))
                Box(Modifier.combinedClickable(onClick = tap, onLongClick = { ui.menuFor = row.key }).then(semantics)) {
                    VoiceCapsule(duration, voice.elapsedOf(path, duration), voice.stateOf(path), label, onClick = tap)
                }
            }
            MessageKind.Photo -> PhotoMessage(row, afterName, ui, nav, voice, labels, semantics, tap)
        }
        if (row.kind == MessageKind.Photo) {
            val mine = row.reactions.filter { it.userId == state.me }.map { it.emoji }.toSet()
            val postId = row.message.postId.orEmpty()
            PhotoContextMenu(
                expanded = open,
                onDismiss = { ui.menuFor = null },
                mine = mine,
                onReact = { e -> onReact(postId, e) },
                onUnreact = { e -> onUnreact(postId, e) },
                onAddReaction = { ui.pickerFor = postId },
                items = menu,
            )
        } else {
            DsDropdownMenu(open, { ui.menuFor = null }, menu)
        }
    }
}

/**
 * The context-menu items of a message (chat.thread.md → Context menu; Sentence case, destructive last). Save is on your own
 * photo messages only (owner decision 12).
 */
@Composable
private fun menuItems(row: ChatRow, ui: ChatUiState, nav: ChatNav, onRetrySend: (String) -> Unit, onReply: (ChatRow) -> Unit, onCopy: (String) -> Unit, onSave: (ChatRow) -> Unit): List<DsMenuItem> {
    val reply = stringRes(R.string.chat_thread_menu_reply)
    val copy = stringRes(R.string.chat_thread_menu_copy)
    val save = stringRes(R.string.chat_thread_menu_save)
    val report = stringRes(R.string.chat_thread_menu_report)
    val unsend = stringRes(R.string.chat_thread_menu_delete)
    val deletePhoto = stringRes(R.string.chat_thread_menu_deletephoto)
    val retry = stringRes(R.string.chat_thread_menu_retry)
    return buildList {
        if (row.failed) {
            add(DsMenuItem(retry, { onRetrySend(row.id) }))
            add(DsMenuItem(unsend, { ui.confirmUnsend = row.id }, destructive = true))
            return@buildList
        }
        if (!row.pending) add(DsMenuItem(reply, { onReply(row) }))
        when (row.kind) {
            MessageKind.Text -> add(DsMenuItem(copy, { onCopy(row.message.body.orEmpty()) }))
            MessageKind.Photo -> if (row.mine) add(DsMenuItem(save, { onSave(row) }))
            MessageKind.Voice -> Unit
        }
        if (row.pending) return@buildList
        when {
            row.kind == MessageKind.Photo && row.mine -> add(DsMenuItem(deletePhoto, { ui.confirmDeletePhoto = row.message.postId }, destructive = true))
            row.kind == MessageKind.Photo -> add(DsMenuItem(report, { row.message.postId?.let(nav.reportPost) }, destructive = true))
            row.mine -> add(DsMenuItem(unsend, { ui.confirmUnsend = row.id }, destructive = true))
            else -> add(DsMenuItem(report, { nav.reportMessage(row.id, row.message.authorId) }, destructive = true))
        }
    }
}

/**
 * A photo message: the C-18 photo card (`chat.thread.layout.photoFit`: `size.global.friendCardWidth` ×
 * `.friendCardHeight`, `radius.global.card`, aspect fill), the reaction chip `chat.reactions.dimension.chipTop`
 * under it, then the caption (text item) and the voice note (capsule), `chat.thread.dimension.itemGap` apart.
 */
@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun PhotoMessage(row: ChatRow, afterHeader: Boolean, ui: ChatUiState, nav: ChatNav, voice: VoiceUi, labels: RowLabels, semantics: Modifier, tap: () -> Unit) {
    val media = row.media
    if (afterHeader) Spacer(Modifier.height(Tokens.Sizes.chatThreadDimensionItemGap))
    // A post with a front photo is core:ui daily.dualimage: the card's width and corners, its own 3:4 height
    // (`daily.dualimage.layout.composition`) in place of the 2:3 card frame.
    val front = media?.frontImagePath(app.data.model.Media.Rendition.Display)
    Column {
        Box(
            Modifier
                .then(
                    if (front != null) Modifier.width(Tokens.Sizes.globalFriendCardWidth)
                    else Modifier.size(Tokens.Sizes.globalFriendCardWidth, Tokens.Sizes.globalFriendCardHeight),
                )
                .clip(RoundedCornerShape(Tokens.Radii.globalCard))
                .combinedClickable(onClick = tap, onLongClick = { ui.menuFor = row.key })
                .then(semantics),
        ) {
            if (front != null) {
                DualImage(
                    main = photoModel(media.imagePath(app.data.model.Media.Rendition.Display)),
                    inset = photoModel(front),
                    contentDescription = null,
                    modifier = Modifier.fillMaxWidth(),
                    cornerRadius = Tokens.Radii.globalCard,
                    loadingFill = Tokens.Colors.globalControl,
                )
            } else {
                RemotePhoto(media?.imagePath(app.data.model.Media.Rendition.Display), null, Modifier.fillMaxSize(), fallbackPath = media?.imagePath(app.data.model.Media.Rendition.Thumb))
            }
        }
        if (row.reactions.isNotEmpty()) {
            Spacer(Modifier.height(Tokens.Sizes.chatReactionsDimensionChipTop))
            ReactionChip(row.reactions, onClick = { ui.reactionsFor = row.message.postId })
        }
        row.post?.caption?.takeIf { it.isNotBlank() }?.let { caption ->
            Spacer(Modifier.height(Tokens.Sizes.chatThreadDimensionItemGap))
            Text(caption, style = TextRoles.body, color = Tokens.Colors.globalTextPrimary, modifier = Modifier.clearAndSetSemantics { })
        }
        val post = row.post
        val notePath = post?.voicePath
        if (post != null && notePath != null) {
            val duration = (post.voiceDurationMs ?: 0).toLong()
            val voiceLabel = if (row.mine) stringRes(R.string.chat_voice_a11y_messagemine, Formats.spokenDuration(duration))
            else stringRes(R.string.chat_voice_a11y_message, row.author?.firstName.orEmpty(), Formats.spokenDuration(duration))
            Spacer(Modifier.height(Tokens.Sizes.chatThreadDimensionItemGap))
            VoiceCapsule(duration, voice.elapsedOf(notePath, duration), voice.stateOf(notePath), voiceLabel, onClick = { voice.onPlay(notePath) })
        }
    }
}

/** The in-flight / failed line under your own message (`chat.thread.layout.failedMessage`); failed: tap sends again. */
@Composable
private fun StatusLine(row: ChatRow, onRetrySend: (String) -> Unit) {
    val failed = row.failed
    Text(
        if (failed) stringRes(R.string.chat_thread_sendfailed) else stringRes(R.string.chat_thread_sending),
        style = TextRoles.caption,
        color = if (failed) Tokens.Colors.globalDestructive else PageRoles.secondaryText(),
        maxLines = 1,
        modifier = Modifier
            .padding(top = Tokens.Sizes.chatThreadDimensionItemGap)
            .then(if (failed) Modifier.tapClickable { onRetrySend(row.id) } else Modifier),
    )
}
