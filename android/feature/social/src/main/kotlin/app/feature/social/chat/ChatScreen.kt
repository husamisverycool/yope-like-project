// Surface: chat.thread — the group chat (photos, text, replies to photos, voice messages).
// References: references/auto/yope/store/yope-store-05.png (primary; coordinates in
// references/auto/yope/frames/b-derot-store-05-rot-1.68.png),
// references/auto/yope/frames/b-yopeapp-7591560669967682847-t49.50-reply-to-photo.png (reply quote, caption box),
// references/auto/yope/frames/a-itsmthuyope-7644974799302823175-t51.23-group-created-empty-state.png (empty state),
// references/auto/locket/store/locket-store-04.png (reaction cluster).
package app.feature.social.chat

import android.Manifest
import android.os.SystemClock
import androidx.activity.compose.BackHandler
import androidx.compose.material.icons.rounded.ErrorOutline
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.mutableLongStateOf
import app.feature.social.common.InkGlyph
import app.feature.social.reactions.FlightLayer
import app.feature.social.reactions.LocalReactionFlights
import app.feature.social.reactions.ReactionFlights
import kotlinx.coroutines.delay
import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
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
import androidx.compose.foundation.layout.paddingFromBaseline
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.Layout
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
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.data.model.Media
import app.data.model.MessageKind
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.designsystem.rememberReduceMotion
import app.feature.social.common.ActivityIndicator
import app.feature.social.common.Avatar
import app.feature.social.common.EmptyState
import app.feature.social.common.Formats
import app.feature.social.common.Glyph
import app.feature.social.common.HeaderCircle
import app.ui.components.HeaderCircleFill
import app.ui.components.PermissionCard
import app.feature.social.common.Line
import app.feature.social.common.LoadingHud
import app.feature.social.common.SocialBlocked
import app.feature.social.common.shows
import app.feature.social.common.LocalSocialData
import app.feature.social.common.LocalSocialServices
import app.feature.social.common.PillAction
import app.feature.social.common.RemotePhoto
import app.feature.social.common.Type
import app.feature.social.common.announce
import app.feature.social.common.rememberHaptics
import app.feature.social.common.stringRes
import app.feature.social.data.VoicePlayback
import app.feature.social.data.VoiceServices
import app.feature.social.reactions.ActivitySheet
import app.feature.social.reactions.EmojiRain
import app.feature.social.reactions.ReactionCluster
import app.feature.social.reactions.ReactionPickerSheet
import app.media.MediaPermission
import app.media.MediaPermissions
import app.media.PermissionState
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.launch
import kotlin.math.max

/** Where the thread leads (design/surfaces/chat.thread.md → Navigation out). */
data class ChatNav(
    val back: () -> Unit,
    val groupInfo: () -> Unit,
    val recap: (recapId: String) -> Unit,
    val photo: (postId: String) -> Unit,
    val member: (userId: String) -> Unit,
    val invite: () -> Unit,
    val camera: () -> Unit,
    val report: (messageId: String, authorId: String) -> Unit,
)

/** Transient UI state of the thread (menus, sheets, dialogs, motion), hoisted for tests. */
class ChatUiState(
    menuFor: String? = null,
    pickerFor: String? = null,
    activityFor: String? = null,
    confirmDelete: String? = null,
    showMicCard: Boolean = false,
) {
    var menuFor by mutableStateOf(menuFor)
    var pickerFor by mutableStateOf(pickerFor)
    var activityFor by mutableStateOf(activityFor)
    var confirmDelete by mutableStateOf(confirmDelete)
    var showMicCard by mutableStateOf(showMicCard)
    var rain by mutableStateOf<Pair<String, Int>?>(null)
    /** Voice recording in progress (`chat.voice.layout.recording`), null when idle. */
    var recording by mutableStateOf<Recording?>(null)
}

/** Playback key of the paused recording's preview (not a storage path). */
private const val DRAFT_KEY = "draft"

/** How often the recording timer re-reads the clock. */
private const val TIMER_TICK_MS = 200L

/** Cap height of the platform font (Roboto: 1456 / 2048 em), to place a cap top from a baseline. */
private const val PLATFORM_CAP_HEIGHT_EM = 0.711f

@Composable
fun ChatScreen(vm: ChatViewModel, focusMessageId: String?, nav: ChatNav, ui: ChatUiState = remember { ChatUiState() }) {
    val state by vm.state.collectAsStateWithLifecycle()
    val context = LocalContext.current
    val view = LocalView.current
    val haptics = rememberHaptics()
    val reduceMotion by rememberReduceMotion()
    val services = LocalSocialServices.current
    val voice = remember { services.voice(context) }
    DisposableEffect(voice) { onDispose { voice.release() } }
    val playback by voice.playback.collectAsStateWithLifecycle()
    val levels by voice.levels.collectAsStateWithLifecycle()
    val data = LocalSocialData.current
    val scope = rememberCoroutineScope()
    var rainKey by remember { mutableIntStateOf(0) }

    val sendFailed = stringRes(R.string.chat_thread_sendfailed)
    val reactionFailed = stringRes(R.string.chat_reactions_error)
    val recordFailed = stringRes(R.string.chat_voice_error_record)
    val playFailed = stringRes(R.string.chat_voice_error_play)
    val labels = rowLabels()
    LaunchedEffect(vm) {
        vm.effects.collect { effect ->
            when (effect) {
                ChatEffect.Sent -> haptics.play(Tokens.Haptics.globalSend)
                ChatEffect.SendFailed -> { haptics.play(Tokens.Haptics.globalError); announce(view, sendFailed) }
                ChatEffect.ReactionFailed -> { haptics.play(Tokens.Haptics.globalError); announce(view, reactionFailed) }
                ChatEffect.DeleteFailed -> haptics.play(Tokens.Haptics.globalError)
                ChatEffect.RecordFailed -> { haptics.play(Tokens.Haptics.globalError); announce(view, recordFailed) }
                is ChatEffect.Rain -> if (!reduceMotion) ui.rain = effect.emoji to ++rainKey
                is ChatEffect.Incoming -> announce(view, labels.of(effect.row))
            }
        }
    }

    val micLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        ui.showMicCard = !granted
    }
    // Recording (`chat.voice.layout.recording`): hold to record, lift to send, slide left to cancel,
    // slide up to lock; locked: pause keeps a draft to play, send sends. No haptics (mic in use).
    val startRecording: () -> Boolean = start@{
        if (ui.recording != null) return@start false
        if (!MediaPermissions.isGranted(context, MediaPermission.Microphone)) {
            if (context.findActivity() != null) MediaPermissions.markRequested(context, MediaPermission.Microphone)
            micLauncher.launch(Manifest.permission.RECORD_AUDIO)
            return@start false
        }
        ui.showMicCard = false
        if (runCatching { voice.startRecording() }.isFailure) {
            vm.recordFailed()
            return@start false
        }
        ui.recording = Recording.Holding(SystemClock.elapsedRealtime())
        true
    }
    val sendRecording: () -> Unit = {
        when (val r = ui.recording) {
            is Recording.Draft -> {
                if (playback.key == DRAFT_KEY) voice.pause()
                vm.sendVoice(r.voice.file, r.voice.durationMs)
            }
            null -> Unit
            else -> {
                val note = runCatching { voice.stopRecording() }.getOrNull()
                if (note != null) vm.sendVoice(note.file, note.durationMs) else vm.recordFailed()
            }
        }
        ui.recording = null
    }
    val cancelRecording: () -> Unit = {
        when (val r = ui.recording) {
            is Recording.Draft -> {
                if (playback.key == DRAFT_KEY) voice.pause()
                r.voice.file.delete()
            }
            null -> Unit
            else -> runCatching { voice.cancelRecording() }
        }
        ui.recording = null
    }
    BackHandler(enabled = ui.recording != null, onBack = cancelRecording)
    DisposableEffect(Unit) { onDispose { if (ui.recording != null) cancelRecording() } }
    var now by remember { mutableLongStateOf(SystemClock.elapsedRealtime()) }
    LaunchedEffect(ui.recording) {
        while (ui.recording is Recording.Holding || ui.recording is Recording.Locked) {
            now = SystemClock.elapsedRealtime()
            delay(TIMER_TICK_MS)
        }
    }
    val recorder = VoiceControls(
        recording = ui.recording,
        elapsedMs = when (val r = ui.recording) {
            is Recording.Holding -> now - r.startedAt
            is Recording.Locked -> now - r.startedAt
            else -> 0L
        }.coerceAtLeast(0L),
        draftPlaying = playback.key == DRAFT_KEY && playback.isPlaying,
        draftProgress = if (playback.key == DRAFT_KEY) playback.progress else 0f,
        onHoldStart = startRecording,
        onHoldEnd = sendRecording,
        onCancel = cancelRecording,
        onLock = { (ui.recording as? Recording.Holding)?.let { ui.recording = Recording.Locked(it.startedAt) } },
        onStartLocked = { if (startRecording()) (ui.recording as? Recording.Holding)?.let { ui.recording = Recording.Locked(it.startedAt) } },
        onPause = {
            val held = levels
            val note = runCatching { voice.stopRecording() }.getOrNull()
            ui.recording = note?.let { Recording.Draft(it, held) }
            if (note == null) vm.recordFailed()
        },
        onPlayDraft = {
            val r = ui.recording as? Recording.Draft
            if (r != null) {
                if (playback.key == DRAFT_KEY && playback.isPlaying) voice.pause() else voice.play(DRAFT_KEY, Uri.fromFile(r.voice.file).toString())
            }
        },
        onSend = sendRecording,
    )
    val onMicCard = {
        val activity = context.findActivity()
        val permanently = activity != null && MediaPermissions.state(activity, MediaPermission.Microphone) == PermissionState.PermanentlyDenied
        if (permanently) context.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", context.packageName, null)))
        else micLauncher.launch(Manifest.permission.RECORD_AUDIO)
    }
    val onPlay: (String) -> Unit = { path ->
        if (playback.key == path && playback.isPlaying) voice.pause()
        else scope.launch {
            val url = runCatching { data.signedUrls(listOf(path))[path] }.getOrNull()
            if (url != null) voice.play(path, url) else announce(view, playFailed)
        }
    }

    ChatContent(
        state = state,
        ui = ui,
        nav = nav,
        focusMessageId = focusMessageId,
        voice = voice,
        playback = playback,
        recorder = recorder,
        onDraft = vm::setDraft,
        onSend = vm::send,
        onRetry = vm::retry,
        onLoadOlder = vm::loadOlder,
        onReact = vm::react,
        onUnreact = vm::unreact,
        onRetrySend = vm::retrySend,
        onDelete = { id -> haptics.play(Tokens.Haptics.globalWarning); vm.deleteMessage(id) },
        onMicCard = onMicCard,
        onPlay = onPlay,
    )
}

/** Labels of rows, for announcements and semantics. */
class RowLabels(
    private val message: (String, String) -> String,
    private val messageMine: (String) -> String,
    private val voice: (String, String) -> String,
    private val voiceMine: (String) -> String,
    private val photo: (String, String) -> String,
    private val photoMine: (String) -> String,
) {
    fun of(row: ChatRow): String {
        val name = row.author?.firstName.orEmpty()
        return when (row.kind) {
            MessageKind.Text -> if (row.mine) messageMine(row.message.body.orEmpty()) else message(name, row.message.body.orEmpty())
            MessageKind.Voice -> {
                val d = Formats.spokenDuration(row.message.voiceDurationMs ?: 0)
                if (row.mine) voiceMine(d) else voice(name, d)
            }
            MessageKind.Photo -> {
                val t = Formats.overlayTime(row.message.createdAt)
                if (row.mine) photoMine(t) else photo(name, t)
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
        )
    }
}

/** The thread without its view model (snapshots render this with fixed states). */
@Composable
fun ChatContent(
    state: ChatState,
    ui: ChatUiState,
    nav: ChatNav,
    focusMessageId: String?,
    voice: VoiceServices?,
    playback: VoicePlayback,
    recorder: VoiceControls,
    onDraft: (String) -> Unit,
    onSend: () -> Unit,
    onRetry: () -> Unit,
    onLoadOlder: () -> Unit,
    onReact: (postId: String, emoji: String) -> Unit,
    onUnreact: (postId: String, emoji: String) -> Unit,
    onRetrySend: (messageId: String) -> Unit,
    onDelete: (messageId: String) -> Unit,
    onMicCard: () -> Unit,
    onPlay: (path: String) -> Unit,
    listState: LazyListState = rememberLazyListState(),
    flights: ReactionFlights = remember { ReactionFlights() },
) {
    val activityAllowed = shows(SocialBlocked.activitySheet)
    val reduceMotion by rememberReduceMotion()
    CompositionLocalProvider(LocalReactionFlights provides flights) {
    Box(Modifier.fillMaxSize().background(Tokens.Colors.globalBackground).testTag("chat.thread")) {
        // Emoji rain: behind the messages, in front of the background (chat.reactions.md §4).
        ui.rain?.let { (emoji, key) -> EmojiRain(emoji, key, onFinished = { if (ui.rain?.second == key) ui.rain = null }) }
        Column(Modifier.fillMaxSize().imePadding().navigationBarsPadding()) {
            Box(Modifier.weight(1f).fillMaxWidth()) {
                val top = WindowInsets.statusBars.asPaddingValues().calculateTopPadding() + Tokens.Sizes.globalHeaderButton
                when {
                    state.phase == ChatState.Phase.Loading -> LoadingHud()
                    state.phase == ChatState.Phase.Error -> CenteredState {
                        EmptyState(stringRes(R.string.chat_thread_error_title), stringRes(R.string.chat_thread_error_detail), PillAction(stringRes(R.string.chat_thread_error_retry), null, onRetry))
                    }
                    state.phase == ChatState.Phase.OfflineEmpty -> CenteredState {
                        EmptyState(stringRes(R.string.chat_thread_offline_title), stringRes(R.string.chat_thread_offline_detail), null)
                    }
                    state.isEmpty -> CenteredState {
                        val title = if (state.iAmCreator) stringRes(R.string.chat_thread_empty_titlecreator) else stringRes(R.string.chat_thread_empty_titlemember, state.creatorName.orEmpty())
                        val detail = state.addedNames.takeIf { it.isNotEmpty() }?.let { stringRes(R.string.chat_thread_empty_detail, it.joinToString(", ")) }
                        EmptyState(title, detail, PillAction(stringRes(R.string.chat_thread_empty_invite), Tokens.Icons.globalLink, nav.invite))
                    }
                    else -> MessageList(state, ui, nav, focusMessageId, voice, playback, onLoadOlder, onPlay, onRetrySend, PaddingValues(top = top), listState)
                }
            }
            if (ui.showMicCard) {
                PermissionCard(
                    stringRes(R.string.chat_voice_permission_title),
                    stringRes(R.string.chat_voice_permission_detail),
                    stringRes(R.string.chat_voice_permission_button),
                    onMicCard,
                    Modifier.padding(horizontal = Tokens.Sizes.onboardingPermissionContactsSizeCardMarginH),
                )
            }
            ComposerRow(state.draft, onDraft, onSend, nav.camera, recorder, Modifier.padding(bottom = Tokens.Sizes.chatComposerDimensionBottomInset))
        }
        Header(state, nav)
        FlightLayer(flights)
    }
    }

    // Sheets and dialogs.
    ui.pickerFor?.let { postId ->
        val row = state.rows.firstOrNull { it.post?.id == postId }
        val mine = row?.reactions.orEmpty().filter { it.userId == state.me }.map { it.emoji }.toSet()
        ReactionPickerSheet(
            mine = mine,
            onPick = { emoji, from ->
                ui.pickerFor = null
                // The flight joins the cluster's leading end only for an emoji not in it yet (a repeat adds no sticker).
                if (!reduceMotion && row?.reactions.orEmpty().none { it.emoji == emoji }) flights.launch(postId, emoji, from)
                onReact(postId, emoji)
            },
            onUnreact = { emoji -> ui.pickerFor = null; onUnreact(postId, emoji) },
            onDismiss = { ui.pickerFor = null },
        )
    }
    if (activityAllowed) ui.activityFor?.let { postId ->
        val row = state.rows.firstOrNull { it.post?.id == postId }
        if (row != null) {
            val nameOf: (String) -> String = { id -> state.nameOf(id).orEmpty() }
            ActivitySheet(row.reactions, state.me, nameOf, row.author?.firstName.orEmpty(), onDismiss = { ui.activityFor = null })
        }
    }
    ui.confirmDelete?.let { id ->
        AlertDialog(
            onDismissRequest = { ui.confirmDelete = null },
            title = { Text(stringRes(R.string.chat_thread_deletemessage_title)) },
            text = { Text(stringRes(R.string.chat_thread_deletemessage_message)) },
            confirmButton = { TextButton(onClick = { ui.confirmDelete = null; onDelete(id) }) { Text(stringRes(R.string.photo_viewer_delete_confirm)) } },
            dismissButton = { TextButton(onClick = { ui.confirmDelete = null }) { Text(stringRes(R.string.photo_viewer_delete_cancel)) } },
        )
    }
}

@Composable
private fun CenteredState(content: @Composable () -> Unit) {
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { content() }
}

/** Header floating over the list: ‹ circle · group capsule · film-strip circle (only with a ready recap). */
@Composable
private fun Header(state: ChatState, nav: ChatNav) {
    val group = state.group
    Row(
        Modifier.fillMaxWidth().windowInsetsPadding(WindowInsets.statusBars).padding(horizontal = Tokens.Sizes.globalHeaderInset),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        HeaderCircle(Tokens.Icons.globalBack, stringRes(R.string.chat_thread_a11y_back), HeaderCircleFill.Control, nav.back)
        Spacer(Modifier.width(Tokens.Sizes.globalHeaderGap))
        Box(Modifier.weight(1f), contentAlignment = Alignment.CenterStart) {
            if (group != null) GroupCapsule(group.name, group.coverPath, nav.groupInfo)
        }
        val recap = state.recapId
        if (recap != null) {
            Spacer(Modifier.width(Tokens.Sizes.globalHeaderGap))
            HeaderCircle(Tokens.Icons.globalRecap, stringRes(R.string.chat_thread_a11y_recap), HeaderCircleFill.Control, { nav.recap(recap) })
        }
    }
}

/**
 * The group capsule (`chat.thread.dimension.headerCapsuleHeight`): group avatar · name · ›. Its
 * insides follow groups.screen's header, which gives no padding: the avatar sits concentric with
 * the capsule's rounded end and the items are `size.global.headerGap` apart (approximation).
 */
@Composable
private fun GroupCapsule(name: String, coverPath: String?, onClick: () -> Unit) {
    val height = Tokens.Sizes.chatThreadDimensionHeaderCapsuleHeight
    val inset = (height - Tokens.Sizes.globalAvatarHeader) / 2
    val label = stringRes(R.string.chat_thread_a11y_groupcapsule, name)
    Row(
        Modifier
            .height(height)
            .clip(CircleShape)
            .background(Tokens.Colors.globalControl)
            .clickable(role = Role.Button, onClick = onClick)
            .clearAndSetSemantics { contentDescription = label; role = Role.Button }
            .padding(horizontal = inset),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalHeaderGap),
    ) {
        Avatar(coverPath, Tokens.Sizes.globalAvatarHeader, fallbackIcon = Tokens.Icons.globalGroup)
        Line(name, Type.headerTitle(), Tokens.Colors.globalTextPrimary, Modifier.weight(1f, fill = false))
        Glyph(Tokens.Icons.globalChevron, Tokens.Colors.globalTextSecondary)
    }
}

/** Vertical gap above [row] given the row before it (chat.thread → Message geometry). */
fun gapAbove(prev: ChatRow?, row: ChatRow): Dp = when {
    prev == null -> 0.dp
    prev.message.authorId != row.message.authorId -> Tokens.Sizes.chatThreadDimensionGapBetweenSenders
    prev.kind == MessageKind.Photo || row.kind == MessageKind.Photo -> Tokens.Sizes.chatThreadDimensionPhotoGap
    prev.kind == MessageKind.Text && row.kind == MessageKind.Voice -> Tokens.Sizes.chatThreadDimensionGapTextToVoice
    else -> Tokens.Sizes.chatThreadDimensionGapSameSender
}

@Composable
private fun MessageList(
    state: ChatState,
    ui: ChatUiState,
    nav: ChatNav,
    focusMessageId: String?,
    voice: VoiceServices?,
    playback: VoicePlayback,
    onLoadOlder: () -> Unit,
    onPlay: (String) -> Unit,
    onRetrySend: (String) -> Unit,
    padding: PaddingValues,
    listState: LazyListState,
) {
    val rows = state.rows
    val newestFirst = remember(rows) { rows.asReversed() }
    LaunchedEffect(listState, rows.size) {
        snapshotFlow { listState.layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: 0 }
            .distinctUntilChanged()
            .collect { last -> if (last >= newestFirst.size - LOAD_MORE_THRESHOLD) onLoadOlder() }
    }
    var focused by rememberSaveable { mutableStateOf(false) }
    LaunchedEffect(focusMessageId, rows.size) {
        if (focusMessageId != null && !focused) {
            val index = newestFirst.indexOfFirst { it.id == focusMessageId }
            if (index >= 0) {
                listState.scrollToItem(index)
                focused = true
            }
        }
    }
    LazyColumn(Modifier.fillMaxSize(), state = listState, reverseLayout = true, contentPadding = padding) {
        itemsIndexed(newestFirst, key = { _, row -> row.key }, contentType = { _, row -> row.kind }) { i, row ->
            val prev = newestFirst.getOrNull(i + 1)
            val next = newestFirst.getOrNull(i - 1)
            MessageRow(row, prev, next, state, ui, nav, voice, playback, onPlay, onRetrySend)
        }
        if (state.loadingOlder) item(key = "older") {
            Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) { ActivityIndicator() }
        }
    }
}

private const val LOAD_MORE_THRESHOLD = 5

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun MessageRow(
    row: ChatRow,
    prev: ChatRow?,
    next: ChatRow?,
    state: ChatState,
    ui: ChatUiState,
    nav: ChatNav,
    voice: VoiceServices?,
    playback: VoicePlayback,
    onPlay: (String) -> Unit,
    onRetrySend: (String) -> Unit,
) {
    val haptics = rememberHaptics()
    val activityAllowed = shows(SocialBlocked.activitySheet)
    val showAvatar = !row.mine && (next == null || next.message.authorId != row.message.authorId)
    val labels = rowLabels()
    val deleteLabel = stringRes(R.string.chat_thread_menu_delete)
    val reportLabel = stringRes(R.string.chat_thread_menu_report)
    val reactLabel = stringRes(R.string.chat_reactions_a11y_add)
    Column(Modifier.fillMaxWidth().padding(top = gapAbove(prev, row))) {
        if (row.kind == MessageKind.Photo) {
            val post = row.post
            val start = if (row.mine) Tokens.Sizes.chatThreadDimensionBubbleInsetTheirs else 0.dp
            Row(Modifier.fillMaxWidth().padding(start = start, end = Tokens.Sizes.chatThreadDimensionPhotoInsetTrailing), verticalAlignment = Alignment.Bottom) {
                if (!row.mine) AvatarColumn(row, showAvatar, nav)
                val quote = row.quote
                val photo: @Composable () -> Unit = {
                    PhotoMessage(
                        row = row,
                        label = labels.of(row),
                        onOpen = { post?.let { nav.photo(it.id) } },
                        onLongPress = {
                            if (post != null) {
                                haptics.playNamed(Tokens.Layouts.GlobalReaction.android)
                                ui.pickerFor = post.id
                            }
                        },
                        onCluster = if (activityAllowed && post != null) ({ ui.activityFor = post.id }) else null,
                        reactLabel = reactLabel,
                    )
                }
                Box(Modifier.weight(1f)) {
                    // A photo replying to a photo: the quote part attached above the photo message (S-7),
                    // overlapping by the photo's corner radius so the lime shows behind its top corners.
                    if (quote != null) Overlapped(Tokens.Radii.globalPhoto, alignStart = true, top = { QuotePart(quote, Tokens.Radii.chatThreadRadiusReplyQuote, onClick = { nav.photo(quote.postId) }) }, bottom = photo)
                    else photo()
                }
            }
            return@Column
        }
        // Text and voice: sender-aligned bubbles; long press → native menu.
        val actions = buildList {
            if (row.mine) add(CustomAccessibilityAction(deleteLabel) { ui.confirmDelete = row.id; true })
            else add(CustomAccessibilityAction(reportLabel) { nav.report(row.id, row.message.authorId); true })
        }
        val failedSpec = Tokens.Layouts.ChatThreadLayoutFailedMessage
        val retryLabel = stringRes(R.string.chat_thread_sendfailed)
        Row(
            Modifier.fillMaxWidth().padding(
                start = if (row.mine) Tokens.Sizes.chatThreadDimensionBubbleInsetTheirs else 0.dp,
                end = if (row.mine) Tokens.Sizes.chatThreadDimensionBubbleInsetMine else Tokens.Sizes.chatThreadDimensionPhotoInsetTrailing,
            ),
            horizontalArrangement = if (row.mine) Arrangement.End else Arrangement.Start,
            // A failed message's indicator is centred on its bubble (`chat.thread.layout.failedMessage`).
            verticalAlignment = if (row.failed) Alignment.CenterVertically else Alignment.Bottom,
        ) {
            if (!row.mine) AvatarColumn(row, showAvatar, nav)
            Box(
                Modifier
                    .weight(1f, fill = false)
                    .combinedClickable(
                        onClick = { if (row.failed) onRetrySend(row.id) },
                        onLongClick = {
                            haptics.playNamed(Tokens.Layouts.GlobalLongPressStart.android)
                            ui.menuFor = row.id
                        },
                    )
                    .semantics { customActions = actions },
            ) {
                when (row.kind) {
                    MessageKind.Voice -> {
                        val path = row.message.voicePath.orEmpty()
                        VoiceBubble(
                            path = path,
                            durationMs = row.message.voiceDurationMs ?: 0,
                            fill = if (row.mine) Tokens.Colors.chatVoiceColorBubble else Tokens.Colors.chatVoiceColorBubbleTheirs,
                            progress = if (playback.key == path) playback.progress else 0f,
                            label = labels.of(row),
                            playing = playback.key == path && playback.isPlaying,
                            voice = voice,
                            onToggle = { onPlay(path) },
                        )
                    }
                    else -> {
                        val quote = row.quote
                        val body = row.message.body.orEmpty()
                        val emojiOnly = if (quote == null) EmojiText.emojiOnly(body, Tokens.Counts.chatThreadCountEmojiOnlyMax) else null
                        when {
                            quote != null -> ReplyBubble(row, quote, labels.of(row), onQuote = { nav.photo(quote.postId) })
                            emojiOnly != null -> EmojiOnlyMessage(emojiOnly, Modifier.semantics { contentDescription = labels.of(row) })
                            else -> TextBubble(body, row.mine, Modifier.semantics { contentDescription = labels.of(row) })
                        }
                    }
                }
                DropdownMenu(expanded = ui.menuFor == row.id, onDismissRequest = { ui.menuFor = null }) {
                    if (row.mine) {
                        DropdownMenuItem(
                            text = { Text(deleteLabel, color = Tokens.Colors.globalSystemError) },
                            leadingIcon = { Glyph(Tokens.Icons.photoViewerIconDelete, Tokens.Colors.globalSystemError) },
                            onClick = { ui.menuFor = null; ui.confirmDelete = row.id },
                        )
                    } else {
                        DropdownMenuItem(
                            text = { Text(reportLabel, color = Tokens.Colors.globalSystemError) },
                            leadingIcon = { Glyph(Tokens.Icons.globalReport, Tokens.Colors.globalSystemError) },
                            onClick = { ui.menuFor = null; nav.report(row.id, row.message.authorId) },
                        )
                    }
                }
            }
            if (row.failed) {
                Spacer(Modifier.width(failedSpec.indicatorGap.dp))
                // `indicatorIconAndroid` (Rounded.ErrorOutline), its circle `indicatorSize` wide, `color.global.destructive`.
                Box(Modifier.clickable { onRetrySend(row.id) }.clearAndSetSemantics { }) {
                    InkGlyph(androidx.compose.material.icons.Icons.Rounded.ErrorOutline, Tokens.Colors.globalDestructive, inkWidth = failedSpec.indicatorSize.dp)
                }
            }
        }
        if (row.failed) {
            // `chat.thread.sendFailed` under the bubble, trailing-aligned with the message column, text role `caption`.
            Line(
                retryLabel,
                Type.caption(),
                Tokens.Colors.globalDestructive,
                Modifier
                    .align(Alignment.End)
                    .padding(top = failedSpec.labelGap.dp, end = Tokens.Sizes.chatThreadDimensionBubbleInsetMine)
                    .clickable(role = Role.Button) { onRetrySend(row.id) },
            )
        }
    }
}

/** The avatar column: `avatarInset` · avatar (only beside a run's last message) · `avatarGap`. Decorative; tap → walls.member. */
@Composable
private fun AvatarColumn(row: ChatRow, visible: Boolean, nav: ChatNav) {
    Spacer(Modifier.width(Tokens.Sizes.chatThreadDimensionAvatarInset))
    if (visible) {
        Avatar(
            row.author?.avatarPath,
            Tokens.Sizes.globalAvatarSmall,
            Modifier.clickable { nav.member(row.message.authorId) }.clearAndSetSemantics { },
        )
    } else {
        Spacer(Modifier.width(Tokens.Sizes.globalAvatarSmall))
    }
    Spacer(Modifier.width(Tokens.Sizes.chatThreadDimensionAvatarGap))
}

/**
 * A text bubble: fill per sender, `chat.thread.radius.bubble` corners, hairline rim shading from
 * the top rim colour to the bottom one; at least `chat.thread.dimension.bubbleHeight` tall, growing
 * with the text (the single-line top / bottom space is kept for more lines).
 */
@Composable
fun TextBubble(text: String, mine: Boolean, modifier: Modifier = Modifier, minWidth: Dp = 0.dp) {
    val shape = RoundedCornerShape(Tokens.Radii.chatThreadRadiusBubble)
    val fill = if (mine) Tokens.Colors.chatThreadColorBubbleMine else Tokens.Colors.chatThreadColorBubbleTheirs
    val rim = if (mine) Brush.verticalGradient(listOf(Tokens.Colors.chatThreadColorBubbleRimMineTop, Tokens.Colors.chatThreadColorBubbleRimMineBottom))
    else Brush.verticalGradient(listOf(Tokens.Colors.chatThreadColorBubbleRimTheirsTop, Tokens.Colors.chatThreadColorBubbleRimTheirsBottom))
    Box(
        modifier
            // `chat.thread.dimension.bubbleMaxWidth` (Apple Messages, G-1): longer text wraps.
            .widthIn(min = minWidth, max = maxOf(minWidth, Tokens.Sizes.chatThreadDimensionBubbleMaxWidth))
            .clip(shape)
            .background(fill)
            .border(Tokens.Sizes.chatThreadDimensionBubbleRim, rim, shape)
            .padding(horizontal = Tokens.Sizes.chatThreadDimensionBubblePaddingH),
    ) {
        CenteredLines(text, Type.body().copy(color = Tokens.Colors.globalTextPrimary), Tokens.Sizes.chatThreadDimensionBubbleHeight)
    }
}

/** Text centred in [minHeight]; with more lines, the space above the first and below the last line stays the single-line space. */
@Composable
private fun CenteredLines(text: String, style: TextStyle, minHeight: Dp) {
    val holder = remember { arrayOfNulls<TextLayoutResult>(1) }
    Layout(content = { BasicText(text, style = style, onTextLayout = { holder[0] = it }) }) { measurables, constraints ->
        val placeable = measurables.single().measure(constraints.copy(minHeight = 0, minWidth = 0))
        val min = minHeight.roundToPx()
        val line = holder[0]?.let { (it.getLineBottom(0) - it.getLineTop(0)).toInt() } ?: placeable.height
        val pad = max(0, (min - line) / 2)
        val height = max(min, placeable.height + 2 * pad).coerceIn(constraints.minHeight, constraints.maxHeight)
        val width = placeable.width.coerceIn(constraints.minWidth, constraints.maxWidth)
        layout(width, height) { placeable.place(0, (height - placeable.height) / 2) }
    }
}

/**
 * An emoji-only message (1…`chat.thread.count.emojiOnlyMax` emoji, Messages + WhatsApp rule, G-2):
 * no bubble, each emoji `chat.thread.dimension.emojiOnlyGlyph` wide; more emoji are a text bubble.
 */
@Composable
private fun EmojiOnlyMessage(emoji: List<String>, modifier: Modifier = Modifier) {
    Row(modifier) { emoji.forEach { e -> app.feature.social.reactions.EmojiGlyph(e, Tokens.Sizes.chatThreadDimensionEmojiOnlyGlyph) } }
}

/** Emoji-only detection by grapheme (user-perceived character). */
object EmojiText {
    /** The emoji of [text] when it holds only 1…[max] emoji (whitespace ignored), else null. */
    fun emojiOnly(text: String, max: Int): List<String>? {
        val t = text.filterNot { it.isWhitespace() }
        if (t.isEmpty()) return null
        val it = java.text.BreakIterator.getCharacterInstance()
        it.setText(t)
        val out = ArrayList<String>()
        var start = it.first()
        var end = it.next()
        while (end != java.text.BreakIterator.DONE) {
            val g = t.substring(start, end)
            if (!isEmoji(g)) return null
            out += g
            if (out.size > max) return null
            start = end
            end = it.next()
        }
        return out
    }

    private fun isEmoji(grapheme: String): Boolean {
        val first = grapheme.codePointAt(0)
        return Character.getType(first) == Character.OTHER_SYMBOL.toInt() || first in REGIONAL_INDICATORS || grapheme.contains(VS16)
    }

    private val REGIONAL_INDICATORS = 0x1F1E6..0x1F1FF
    private const val VS16 = '\uFE0F'
}

/**
 * The lime quote part of a reply to a photo (S5-r): quote bar, the poster's first name, "pic",
 * square thumbnail; top corners [topRadius], at least `chat.thread.dimension.replyWidth` wide.
 */
@Composable
fun QuotePart(quote: Quote, topRadius: Dp, onClick: () -> Unit, modifier: Modifier = Modifier) {
    val density = LocalDensity.current
    val capHeight = with(density) { Tokens.FontSizes.chatThreadFontSizeReplyName.toDp() } * PLATFORM_CAP_HEIGHT_EM
    val nameStyle = Type.style(Tokens.FontSizes.chatThreadFontSizeReplyName, Tokens.FontWeights.chatThreadFontWeightReplyName)
    val labelStyle = Type.style(Tokens.FontSizes.chatThreadFontSizeReplyLabel, Tokens.FontWeights.chatThreadFontWeightReplyLabel)
    val textEnd = Tokens.Sizes.chatThreadDimensionReplyThumb + Tokens.Sizes.chatThreadDimensionReplyThumbInsetTrailing + Tokens.Sizes.chatThreadDimensionReplyTextInset
    val label = stringRes(R.string.chat_thread_a11y_replyquote, quote.posterName.orEmpty())
    Box(
        modifier
            .widthIn(min = Tokens.Sizes.chatThreadDimensionReplyWidth)
            .height(Tokens.Sizes.chatThreadDimensionReplyQuoteHeight)
            .clip(RoundedCornerShape(topStart = topRadius, topEnd = topRadius))
            .background(Tokens.Colors.globalAccent)
            .clickable(role = Role.Button, onClick = onClick)
            .clearAndSetSemantics { contentDescription = label; role = Role.Button },
    ) {
        Box(
            Modifier
                .offset(x = Tokens.Sizes.chatThreadDimensionReplyQuoteBarInset, y = Tokens.Sizes.chatThreadDimensionReplyNameCapTop)
                .width(Tokens.Sizes.chatThreadDimensionReplyQuoteBar)
                .height(Tokens.Sizes.chatThreadDimensionReplyLabelBaseline - Tokens.Sizes.chatThreadDimensionReplyNameCapTop)
                .background(Tokens.Colors.globalOnAccent),
        )
        Line(
            quote.posterName.orEmpty(),
            nameStyle,
            Tokens.Colors.globalOnAccent,
            Modifier.padding(start = Tokens.Sizes.chatThreadDimensionReplyTextInset, end = textEnd)
                .paddingFromBaseline(top = Tokens.Sizes.chatThreadDimensionReplyNameCapTop + capHeight),
        )
        Line(
            stringRes(R.string.chat_thread_reply_photolabel),
            labelStyle,
            Tokens.Colors.globalOnAccent,
            Modifier.padding(start = Tokens.Sizes.chatThreadDimensionReplyTextInset, end = textEnd)
                .paddingFromBaseline(top = Tokens.Sizes.chatThreadDimensionReplyLabelBaseline),
        )
        RemotePhoto(
            quote.thumbPath,
            null,
            Modifier
                .align(Alignment.TopEnd)
                .padding(top = Tokens.Sizes.chatThreadDimensionReplyThumbInsetTop, end = Tokens.Sizes.chatThreadDimensionReplyThumbInsetTrailing)
                .size(Tokens.Sizes.chatThreadDimensionReplyThumb)
                .clip(RoundedCornerShape(Tokens.Radii.chatThreadRadiusReplyThumb)),
        )
    }
}

/**
 * Reply to a photo with text: the quote part, then the sender's text bubble overlapping the quote's
 * bottom by its own corner radius so the lime shows behind its top corners (S5-r; the overlap is
 * not measured: `chat.thread.radius.bubble`).
 */
@Composable
private fun ReplyBubble(row: ChatRow, quote: Quote, label: String, onQuote: () -> Unit) {
    Overlapped(
        overlap = Tokens.Radii.chatThreadRadiusBubble,
        alignStart = false,
        top = { QuotePart(quote, Tokens.Radii.chatThreadRadiusReplyQuote, onQuote) },
        bottom = { TextBubble(row.message.body.orEmpty(), row.mine, Modifier.semantics { contentDescription = label }, minWidth = Tokens.Sizes.chatThreadDimensionReplyWidth) },
    )
}

/**
 * [top] stacked over [bottom], [bottom] moved up by [overlap]. With [alignStart] the top part keeps
 * its own width at the start; otherwise it takes [bottom]'s width.
 */
@Composable
private fun Overlapped(overlap: Dp, alignStart: Boolean, top: @Composable () -> Unit, bottom: @Composable () -> Unit) {
    Layout(content = { top(); bottom() }) { measurables, constraints ->
        val loose = constraints.copy(minWidth = 0, minHeight = 0)
        val lower = measurables[1].measure(loose)
        val upper = if (alignStart) measurables[0].measure(loose) else measurables[0].measure(Constraints.fixedWidth(lower.width))
        val o = overlap.roundToPx()
        val width = max(lower.width, upper.width)
        val height = upper.height - o + lower.height
        layout(width, height) {
            upper.place(0, 0)
            lower.place(0, upper.height - o)
        }
    }
}

/**
 * A photo message: `chat.thread.dimension.photoWidth` × `.photoHeight` frame scaled to the column
 * (aspect fill, `radius.global.photo`), the time centred, the caption box (`color.global.scrim`,
 * `chat.thread.radius.caption`), and the reaction cluster bottom-left. Tap → viewer; long press →
 * reaction picker.
 */
@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun PhotoMessage(
    row: ChatRow,
    label: String,
    onOpen: () -> Unit,
    onLongPress: () -> Unit,
    onCluster: (() -> Unit)?,
    reactLabel: String,
) {
    val shape = RoundedCornerShape(Tokens.Radii.globalPhoto)
    val caption = row.post?.caption?.takeIf { it.isNotBlank() }
    val captionLabel = caption?.let { stringRes(R.string.chat_thread_a11y_caption, it) }
    BoxWithConstraints(Modifier.fillMaxWidth()) {
        val height = maxWidth * (Tokens.Sizes.chatThreadDimensionPhotoHeight / Tokens.Sizes.chatThreadDimensionPhotoWidth)
        Box(
            Modifier
                .width(maxWidth)
                .height(height)
                .clip(shape)
                .combinedClickable(onClick = onOpen, onLongClick = onLongPress)
                // One element (the platform merge): photo label, then caption, then the cluster's emoji names.
                .semantics(mergeDescendants = true) {
                    role = Role.Button
                    customActions = listOf(CustomAccessibilityAction(reactLabel) { onLongPress(); true })
                },
        ) {
            val media = row.media
            RemotePhoto(media?.imagePath(Media.Rendition.Display), label, Modifier.fillMaxSize(), ContentScale.Crop, fallbackPath = media?.imagePath(Media.Rendition.Thumb))
            Line(Formats.overlayTime(row.message.createdAt), Type.overlayTime(), Tokens.Colors.globalTextPrimary, Modifier.align(Alignment.Center).clearAndSetSemantics { })
            if (caption != null) {
                Box(
                    Modifier
                        .align(Alignment.BottomCenter)
                        // Centred (S-8); kept clear of the cluster's first sticker on both sides (caption + cluster overlap not observed).
                        .padding(
                            bottom = Tokens.Sizes.chatThreadDimensionCaptionInsetBottom,
                            start = Tokens.Sizes.chatReactionsDimensionClusterInsetLeading + Tokens.Sizes.chatReactionsDimensionClusterEmoji,
                            end = Tokens.Sizes.chatReactionsDimensionClusterInsetLeading + Tokens.Sizes.chatReactionsDimensionClusterEmoji,
                        )
                        .heightIn(min = Tokens.Sizes.chatThreadDimensionCaptionHeight)
                        .background(Tokens.Colors.globalScrim, RoundedCornerShape(Tokens.Radii.chatThreadRadiusCaption))
                        .padding(horizontal = Tokens.Sizes.chatThreadDimensionCaptionPaddingH)
                        .clearAndSetSemantics { if (captionLabel != null) contentDescription = captionLabel },
                    contentAlignment = Alignment.Center,
                ) {
                    Line(caption, Type.style(Tokens.FontSizes.chatThreadFontSizeCaption, Tokens.FontWeights.chatThreadFontWeightCaption), Tokens.Colors.globalTextPrimary)
                }
            }
            ReactionCluster(
                row.reactions,
                onCluster,
                Modifier.align(Alignment.BottomStart).padding(start = Tokens.Sizes.chatReactionsDimensionClusterInsetLeading, bottom = Tokens.Sizes.chatReactionsDimensionClusterInsetBottom),
                postId = row.post?.id,
            )
        }
    }
}

/** The activity hosting [this] context, if any. */
tailrec fun Context.findActivity(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.findActivity()
    else -> null
}
