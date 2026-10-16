package app.feature.capture.sendto

import android.Manifest
import android.content.ContentValues
import android.content.Context
import android.graphics.Matrix
import android.media.MediaMetadataRetriever
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.view.TextureView
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.common.VideoSize
import androidx.media3.exoplayer.ExoPlayer
import app.data.model.MediaKind
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.capture.data.CaptureDataProvider
import app.feature.capture.data.CaptureHandoff
import app.feature.capture.data.CapturedMedia
import app.feature.capture.ui.VoiceGestures
import app.ui.components.PlatformToast
import app.ui.haptics.rememberHaptics
import androidx.activity.compose.BackHandler
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.unit.Dp
import app.model.SessionPromptGate
import app.ui.permissions.PermissionRationale
import app.ui.permissions.rememberPermissionRequest
import app.voice.VoiceRecorder
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

/** The send-to destination: view model, recorder, library save, toasts and navigation out. */
@Composable
fun SendToRoute(
    onClose: () -> Unit,
    onSent: () -> Unit,
    onCreateGroup: () -> Unit,
    onOpenPaywall: () -> Unit,
) {
    val context = LocalContext.current
    val haptics = rememberHaptics()
    val scope = rememberCoroutineScope()
    val vm: SendToViewModel = viewModel {
        SendToViewModel(
            data = CaptureDataProvider.get(context),
            handoff = CaptureHandoff.process,
            gate = SessionPromptGate.process,
            voiceRecorderAvailable = context.packageManager.hasSystemFeature(android.content.pm.PackageManager.FEATURE_MICROPHONE),
            maxCaption = Tokens.Counts.cameraSendtoSizeCaptionMaxLength,
        )
    }
    val state by vm.ui.collectAsStateWithLifecycle()
    val media = state.media
    var messageSheet by rememberSaveable { mutableStateOf(false) }

    // No capture to send (process restarted): back to the camera.
    LaunchedEffect(media == null) { if (media == null) onClose() }

    val density = LocalDensity.current
    val targetPx = with(density) { Dp(Tokens.Layouts.CameraSendtoLayoutPreview.width).roundToPx() }
    val preview by produceState<ImageBitmap?>(initialValue = null, media) {
        value = media?.let { m -> withContext(Dispatchers.IO) { if (m.kind == MediaKind.Video) videoFrame(m.file) else decodePreview(m.file, targetPx) } }
    }
    val covers by produceState<Map<String, Any?>>(initialValue = emptyMap(), state.visibleGroups.map { it.id }) {
        val paths = state.visibleGroups.mapNotNull { g -> g.coverPath?.let { g.id to it } }
        if (paths.isNotEmpty()) {
            val urls = runCatching { CaptureDataProvider.get(context).signedUrls(paths.map { it.second }) }.getOrDefault(emptyMap())
            value = paths.mapNotNull { (id, path) -> urls[path]?.let { id to it } }.toMap()
        }
    }

    // Voice note with the chat.voice recorder; the microphone is asked here at first use.
    val recorder = remember { VoiceRecorder(context.applicationContext) }
    DisposableEffect(recorder) { onDispose { recorder.release() } }
    val microphone = rememberPermissionRequest(
        permission = Manifest.permission.RECORD_AUDIO,
        rationale = PermissionRationale(
            title = stringResource(R.string.system_permissions_rationale_microphone_title),
            message = null, // system.permissions.rationale.microphone.message uses {app_name} (BLOCKED)
            notNow = stringResource(R.string.system_permissions_rationale_notnow),
            continueLabel = stringResource(R.string.system_permissions_rationale_continue),
            openSettings = stringResource(R.string.system_permissions_opensettings),
        ),
        onResult = { },
    )
    val savedText = stringResource(R.string.camera_sendto_toast_saved)
    val postedMany = stringResource(R.string.camera_sendto_toast_postedmany)
    val save: (CapturedMedia) -> Unit = { m ->
        scope.launch {
            // Android confirms with the platform toast (C-26).
            if (saveToLibrary(context, m)) PlatformToast.show(context, savedText)
        }
    }
    val storage = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) media?.let(save)
    }

    LaunchedEffect(vm) {
        vm.event.collect { event ->
            when (event) {
                SendToViewModel.Event.Close -> onClose()
                is SendToViewModel.Event.Sent -> {
                    haptics.perform(Tokens.Haptics.globalSend)
                    val text = event.groupNames.singleOrNull()?.let { context.getString(R.string.camera_sendto_toast_postedone, it) } ?: postedMany
                    PlatformToast.show(context, text)
                    onSent()
                }
                SendToViewModel.Event.Failed -> haptics.perform(Tokens.Haptics.globalError)
                SendToViewModel.Event.OpenPaywall -> onOpenPaywall()
                SendToViewModel.Event.CreateGroup -> onCreateGroup()
                is SendToViewModel.Event.SaveToLibrary -> {
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q &&
                        androidx.core.content.ContextCompat.checkSelfPermission(context, Manifest.permission.WRITE_EXTERNAL_STORAGE) != android.content.pm.PackageManager.PERMISSION_GRANTED
                    ) {
                        storage.launch(Manifest.permission.WRITE_EXTERNAL_STORAGE)
                    } else {
                        save(event.media)
                    }
                }
            }
        }
    }
    // Back = the close circle (asks first when something would be lost).
    BackHandler(enabled = !messageSheet) { vm.close() }

    val hasMic = { androidx.core.content.ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) == android.content.pm.PackageManager.PERMISSION_GRANTED }
    SendToScreen(
        state = state,
        chrome = SendToChrome(preview = preview, covers = covers),
        onClose = vm::close,
        onSave = vm::save,
        onCaption = vm::onCaption,
        onToggle = vm::toggle,
        onSend = vm::send,
        onCreateGroup = vm::createGroup,
        onRetryGroups = vm::loadGroups,
        onConfirmDiscard = vm::confirmDiscard,
        onDismissAlert = vm::dismissAlert,
        onRetrySend = vm::retry,
        videoPreview = media?.takeIf { it.kind == MediaKind.Video }?.let { m -> { VideoLoop(m.file) } },
        messageSheetOpen = messageSheet,
        onMessageSheet = { messageSheet = it },
        voice = remember(recorder, vm) {
            VoiceActions(
                gestures = object : VoiceGestures {
                    override fun down() {
                        // The first use asks for the microphone; recording starts on the next hold.
                        if (hasMic()) startVoice(context, recorder, vm) else microphone.launch()
                    }

                    override fun release() = finishVoice(recorder, vm)

                    override fun cancel() {
                        recorder.cancel()
                        vm.onVoiceRecording(false)
                    }
                },
                onA11yToggle = {
                    when {
                        recorder.isRecording -> finishVoice(recorder, vm)
                        hasMic() -> startVoice(context, recorder, vm)
                        else -> microphone.launch()
                    }
                },
                onDelete = vm::deleteVoice,
            )
        },
    )
}

private fun startVoice(context: Context, recorder: VoiceRecorder, vm: SendToViewModel) {
    if (recorder.isRecording) return
    val file = File(CaptureHandoff.dir(context), "voice-${System.currentTimeMillis()}.m4a")
    try {
        recorder.start(file, samplingIntervalMs = VOICE_LEVEL_SAMPLING_MS)
        vm.onVoiceRecording(true, startedAt = android.os.SystemClock.elapsedRealtime())
    } catch (_: Exception) {
        file.delete()
        vm.onVoiceRecording(false)
    }
}

/** Stops the recording and keeps the note for the post (replacing an earlier one). */
private fun finishVoice(recorder: VoiceRecorder, vm: SendToViewModel) {
    if (!recorder.isRecording) {
        vm.onVoiceRecording(false)
        return
    }
    val note = recorder.stop()
    vm.onVoiceNote(note?.let { VoiceNoteFile(it.file, it.durationMs.toInt()) }?.takeIf { it.durationMs > 0 })
}

/** Waveform resolution of core:voice (no waveform is drawn here; transport value, not design). */
private const val VOICE_LEVEL_SAMPLING_MS = 100L // provenance-ok: recorder level sampling interval, nothing is drawn from it

/** The capture's video, muted, looping, centre-cropped into the photo frame (camera.sendto → preview). */
@Composable
private fun VideoLoop(file: File) {
    val context = LocalContext.current
    val player = remember(file) {
        ExoPlayer.Builder(context.applicationContext).build().apply {
            volume = 0f
            repeatMode = Player.REPEAT_MODE_ONE
            setMediaItem(MediaItem.fromUri(android.net.Uri.fromFile(file)))
            prepare()
            playWhenReady = true
        }
    }
    DisposableEffect(player) { onDispose { player.release() } }
    var videoSize by remember { mutableStateOf(VideoSize.UNKNOWN) }
    DisposableEffect(player) {
        val listener = object : Player.Listener {
            override fun onVideoSizeChanged(size: VideoSize) {
                videoSize = size
            }
        }
        player.addListener(listener)
        onDispose { player.removeListener(listener) }
    }
    AndroidView(
        factory = { ctx -> TextureView(ctx).also { player.setVideoTextureView(it) } },
        update = { tv -> centerCrop(tv, videoSize) },
        modifier = androidx.compose.ui.Modifier,
    )
}

private fun centerCrop(view: TextureView, size: VideoSize) {
    if (size.width <= 0 || size.height <= 0 || view.width <= 0 || view.height <= 0) return
    val vw = view.width.toFloat()
    val vh = view.height.toFloat()
    val videoAspect = size.width * size.pixelWidthHeightRatio / size.height
    val viewAspect = vw / vh
    val m = Matrix()
    if (videoAspect > viewAspect) m.setScale(videoAspect / viewAspect, 1f, vw / 2, vh / 2) else m.setScale(1f, viewAspect / videoAspect, vw / 2, vh / 2)
    view.setTransform(m)
}

private fun videoFrame(file: File): ImageBitmap? {
    val retriever = MediaMetadataRetriever()
    return try {
        retriever.setDataSource(file.absolutePath)
        retriever.frameAtTime?.asImageBitmap()
    } catch (_: RuntimeException) {
        null
    } finally {
        retriever.release()
    }
}

/** Saves the capture to the shared library (MediaStore; add-only). Returns whether it was saved. */
internal suspend fun saveToLibrary(context: Context, media: CapturedMedia): Boolean = withContext(Dispatchers.IO) {
    val video = media.kind == MediaKind.Video
    val collection = if (video) MediaStore.Video.Media.EXTERNAL_CONTENT_URI else MediaStore.Images.Media.EXTERNAL_CONTENT_URI
    val values = ContentValues().apply {
        put(MediaStore.MediaColumns.DISPLAY_NAME, media.file.name)
        put(MediaStore.MediaColumns.MIME_TYPE, if (video) "video/mp4" else "image/jpeg")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            put(MediaStore.MediaColumns.RELATIVE_PATH, if (video) Environment.DIRECTORY_MOVIES else Environment.DIRECTORY_PICTURES)
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
    }
    val resolver = context.contentResolver
    val uri = runCatching { resolver.insert(collection, values) }.getOrNull() ?: return@withContext false
    try {
        resolver.openOutputStream(uri)?.use { out -> media.file.inputStream().use { it.copyTo(out) } } ?: error("no stream")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            resolver.update(uri, ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) }, null, null)
        }
        true
    } catch (_: Exception) {
        runCatching { resolver.delete(uri, null, null) }
        false
    }
}
