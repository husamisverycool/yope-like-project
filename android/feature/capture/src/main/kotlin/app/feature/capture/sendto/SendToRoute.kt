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
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
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
import app.feature.capture.Blocked
import app.feature.capture.camera.rememberHourText
import app.feature.capture.data.CaptureDataProvider
import app.feature.capture.data.CaptureHandoff
import app.feature.capture.data.CaptureServices
import app.feature.capture.data.CapturedMedia
import app.feature.capture.data.SharedCapturePrefs
import app.feature.capture.ui.haptic
import app.model.SessionPromptGate
import app.ui.permissions.PermissionRationale
import app.ui.permissions.rememberPermissionRequest
import app.voice.VoiceRecorder
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

/** The send-to destination: view model, recorder, library save and navigation out. */
@Composable
fun SendToRoute(
    onClose: () -> Unit,
    onSent: () -> Unit,
    onCreateGroup: () -> Unit,
    onOpenPaywall: () -> Unit,
) {
    val context = LocalContext.current
    val view = LocalView.current
    val scope = rememberCoroutineScope()
    val vm: SendToViewModel = viewModel {
        SendToViewModel(
            data = CaptureDataProvider.get(context),
            handoff = CaptureHandoff.process,
            tracker = CaptureServices.tracker(context),
            prefs = SharedCapturePrefs(context),
            gate = SessionPromptGate.process,
            voiceRecorderAvailable = Blocked.voiceNoteRecorder,
            maxCaption = Blocked.captionMaxLength,
        )
    }
    val state by vm.ui.collectAsStateWithLifecycle()
    val media = state.media

    // No capture to send (process restarted): back to the camera.
    LaunchedEffect(media == null) { if (media == null) onClose() }

    val density = LocalDensity.current
    val targetPx = with(density) { Tokens.Layouts.CameraSendtoLayoutPreview.width.dp.roundToPx() }
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

    // Voice note (debug builds only while chat.voice.layout.recording is BLOCKED).
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
    val storage = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) media?.let { scope.launch { if (saveToLibrary(context, it)) view.haptic(Tokens.Haptics.globalSuccess) } }
    }

    LaunchedEffect(vm) {
        vm.event.collect { event ->
            when (event) {
                SendToViewModel.Event.Close -> onClose()
                SendToViewModel.Event.Sent -> {
                    // Optimistic: queued = sent (uploads.enqueue works offline and resumes); a later
                    // failure shows the error toast with haptic.global.error.
                    view.haptic(Tokens.Haptics.globalSend)
                    onSent()
                }
                SendToViewModel.Event.OpenPaywall -> onOpenPaywall()
                SendToViewModel.Event.CreateGroup -> onCreateGroup()
                is SendToViewModel.Event.SaveToLibrary -> {
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q &&
                        androidx.core.content.ContextCompat.checkSelfPermission(context, Manifest.permission.WRITE_EXTERNAL_STORAGE) != android.content.pm.PackageManager.PERMISSION_GRANTED
                    ) {
                        storage.launch(Manifest.permission.WRITE_EXTERNAL_STORAGE)
                    } else {
                        // haptic.global.success: the save completed (its toast's duration is BLOCKED).
                        if (saveToLibrary(context, event.media)) view.haptic(Tokens.Haptics.globalSuccess)
                    }
                }
            }
        }
    }

    SendToScreen(
        state = state,
        chrome = SendToChrome(preview = preview, hourText = rememberHourText(), covers = covers),
        onClose = vm::close,
        onSave = vm::save,
        onCaption = vm::onCaption,
        onMic = { finishVoice(recorder, vm) },
        onVoiceCoachClose = vm::dismissVoiceCoach,
        onToggle = vm::toggle,
        onSend = vm::send,
        onCreateGroup = vm::createGroup,
        onRetryGroups = vm::loadGroups,
        videoPreview = media?.takeIf { it.kind == MediaKind.Video }?.let { m -> { VideoLoop(m.file) } },
        voiceGestures = remember(recorder, vm) {
            object : VoiceGestures {
                override fun down() {
                    // The first use asks for the microphone; recording starts on the next hold.
                    if (androidx.core.content.ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) == android.content.pm.PackageManager.PERMISSION_GRANTED) {
                        startVoice(context, recorder, vm)
                    } else {
                        microphone.launch()
                    }
                }

                override fun release() = finishVoice(recorder, vm)

                override fun cancel() {
                    recorder.cancel()
                    vm.onVoiceRecording(false)
                }

                override fun lock() = vm.onVoiceLocked()
            }
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

/** The capture's video, muted, looping, centre-cropped into the card (Yope's speaker glyph not built). */
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
