// Surface: camera.trim — design/surfaces/camera.trim.md (`camera.trim.layout.screen`).
// A library video longer than `camera.capture.duration.videoMax` is trimmed before send-to. Android has no system trimmer:
// the media surface (C-29 header, Material 3 range slider, C-28 loading) with Retro's editor wording
// (references/auto/retro/apk/retro-android-2026.10.1150-strings.txt video_editor_*); iOS uses the system trimmer.
// The clip is written on the device with Media3 Transformer.
package app.feature.capture.camera

import android.content.Context
import android.net.Uri
import android.view.TextureView
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.paddingFromBaseline
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.RangeSlider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.viewinterop.AndroidView
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.VideoSize
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.transformer.Composition
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.Transformer
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.capture.ui.OnMedia
import app.ui.components.BusyOverlay
import app.ui.foundation.tapClickable
import app.ui.haptics.rememberHaptics
import app.ui.system.SheetHeader
import app.ui.system.SheetTextAction
import app.ui.text.TextRoles
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import java.io.File
import java.time.LocalTime
import java.time.format.DateTimeFormatter
import kotlin.coroutines.resume

/** A picked video waiting for the trimmer. */
data class TrimRequest(val file: File, val durationMs: Long)

/** The longest video a post may hold: `camera.capture.duration.videoMax` (the server's `app_config.video_max_ms`). */
object VideoLimit {
    val maxMs: Long get() = Tokens.Durations.cameraCaptureDurationVideoMax.toLong()

    /** One second: the step of Retro's trim actions ("Start one second earlier") and the shortest clip. */
    const val STEP_MS = 1_000L // provenance-ok: one second, the unit of the editor's steps (camera.trim.a11y.*)

    /** Longer than the limit in the whole seconds the apps show ("0:10" = 10,000–10,999 ms), as `create_post` counts. */
    fun isTooLong(durationMs: Long): Boolean = (durationMs / STEP_MS) * STEP_MS > maxMs
}

/** The chosen range (ms): at most [VideoLimit.maxMs], at least one second (or the whole video when shorter). */
@Stable
class TrimRange(val durationMs: Long, start: Long = 0L, end: Long = minOf(durationMs, VideoLimit.maxMs)) {
    var startMs by mutableLongStateOf(start)
        private set
    var endMs by mutableLongStateOf(end)
        private set

    private val minSpan get() = minOf(VideoLimit.STEP_MS, durationMs)

    /** The slider moved: the other end follows so the range stays between one second and the limit. */
    fun update(start: Long, end: Long) {
        val movedStart = start != startMs
        var s = start.coerceIn(0, durationMs)
        var e = end.coerceIn(0, durationMs)
        if (movedStart) {
            s = s.coerceAtMost(durationMs - minSpan)
            if (e - s > VideoLimit.maxMs) e = s + VideoLimit.maxMs
            if (e - s < minSpan) e = s + minSpan
        } else {
            e = e.coerceAtLeast(minSpan)
            if (e - s > VideoLimit.maxMs) s = e - VideoLimit.maxMs
            if (e - s < minSpan) s = e - minSpan
        }
        startMs = s
        endMs = e
    }

    fun shiftStart(byMs: Long) = update(startMs + byMs, endMs)
    fun shiftEnd(byMs: Long) = update(startMs, endMs + byMs)
}

/** The limit in words for `camera.capture.videoTooLong.message` ("10 seconds"; the platform's measure format). */
object TrimWords {
    fun limit(context: Context): String {
        val locale = context.resources.configuration.locales[0]
        return android.icu.text.MeasureFormat.getInstance(locale, android.icu.text.MeasureFormat.FormatWidth.WIDE)
            .format(android.icu.util.Measure(VideoLimit.maxMs / VideoLimit.STEP_MS, android.icu.util.MeasureUnit.SECOND))
    }
}

/** "m:ss" (`chat.voice.layout.durationFormat`), whole seconds. */
internal fun trimTime(ms: Long): String =
    DateTimeFormatter.ofPattern(Tokens.Layouts.ChatVoiceLayoutDurationFormat.pattern).format(LocalTime.ofSecondOfDay((ms / VideoLimit.STEP_MS).coerceAtLeast(0)))

/**
 * The trimmer over the camera: the video loops the chosen range; Done writes the clip to [target] and hands it back;
 * Cancel / back returns to the camera; a clip that cannot be written comes back as [onFinish] (null, failed = true).
 */
@Composable
fun VideoTrimRoute(request: TrimRequest, target: File, onFinish: (trimmed: File?, failed: Boolean) -> Unit) {
    val context = LocalContext.current
    val range = remember(request) { TrimRange(request.durationMs) }
    val scope = rememberCoroutineScope()
    var busy by remember { mutableStateOf(false) }
    var failedToLoad by remember { mutableStateOf(false) }
    var attempt by remember { mutableStateOf(0) }
    var playing by remember { mutableStateOf(true) }
    var videoSize by remember { mutableStateOf(VideoSize.UNKNOWN) }
    val player = remember(request, attempt) {
        ExoPlayer.Builder(context.applicationContext).build().apply {
            setMediaItem(MediaItem.fromUri(Uri.fromFile(request.file)))
            prepare()
        }
    }
    DisposableEffect(player) {
        val listener = object : Player.Listener {
            override fun onPlayerError(error: PlaybackException) { failedToLoad = true }
            override fun onVideoSizeChanged(size: VideoSize) { videoSize = size }
        }
        player.addListener(listener)
        onDispose {
            player.removeListener(listener)
            player.release()
        }
    }
    // The chosen range plays in a loop (a preview, as the system trimmers do).
    LaunchedEffect(player, playing) {
        player.playWhenReady = playing && !busy
        while (isActive) {
            val position = player.currentPosition
            if (position < range.startMs || position >= range.endMs) player.seekTo(range.startMs)
            delay(PREVIEW_POLL_MS)
        }
    }
    BackHandler(enabled = !busy) { onFinish(null, false) }
    VideoTrimContent(
        range = range,
        aspect = if (videoSize.width > 0 && videoSize.height > 0) videoSize.width * videoSize.pixelWidthHeightRatio / videoSize.height else null,
        playing = playing,
        busy = busy,
        failedToLoad = failedToLoad,
        onTogglePlay = { playing = !playing },
        onRangeChanged = { start, end ->
            val moved = start != range.startMs
            range.update(start, end)
            player.seekTo(if (moved) range.startMs else (range.endMs - VideoLimit.STEP_MS).coerceAtLeast(range.startMs))
        },
        onRetry = { failedToLoad = false; attempt++ },
        onCancel = { onFinish(null, false) },
        onDone = {
            busy = true
            player.pause()
            scope.launch {
                val ok = VideoClipper.clip(context, request.file, range.startMs, range.endMs, target)
                busy = false
                if (ok) onFinish(target, false) else { target.delete(); onFinish(null, true) }
            }
        },
        video = { modifier ->
            AndroidView(
                factory = { ctx -> TextureView(ctx).also { player.setVideoTextureView(it) } },
                update = { player.setVideoTextureView(it) },
                modifier = modifier,
            )
        },
    )
}

private const val PREVIEW_POLL_MS = 50L // provenance-ok: how often the loop checks the range end (not a design value)

/**
 * The trimmer without its player (snapshots draw a still): media surface (`color.global.backgroundDeep`, dark
 * appearance); C-29 header Cancel · "Trim Video" · Done; the video aspect-fit in the remaining space (tap = play /
 * pause); `size.global.screenMargin` below it the Material 3 range slider inside the margins; the range line
 * (`camera.trim.range`, `listSubtitle`, `color.global.textSecondary`) `size.global.sectionHeaderToContent` below.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun VideoTrimContent(
    range: TrimRange,
    aspect: Float?,
    playing: Boolean,
    busy: Boolean,
    failedToLoad: Boolean,
    onTogglePlay: () -> Unit,
    onRangeChanged: (start: Long, end: Long) -> Unit,
    onRetry: () -> Unit,
    onCancel: () -> Unit,
    onDone: () -> Unit,
    video: @Composable (Modifier) -> Unit,
) {
    val haptics = rememberHaptics()
    val play = stringResource(R.string.camera_trim_a11y_play)
    val pause = stringResource(R.string.camera_trim_a11y_pause)
    val timeline = stringResource(R.string.camera_trim_a11y_timeline)
    val startEarlier = stringResource(R.string.camera_trim_a11y_startearlier)
    val startLater = stringResource(R.string.camera_trim_a11y_startlater)
    val endEarlier = stringResource(R.string.camera_trim_a11y_endearlier)
    val endLater = stringResource(R.string.camera_trim_a11y_endlater)
    val step = VideoLimit.STEP_MS
    OnMedia {
        Column(
            Modifier
                .fillMaxSize()
                .background(Tokens.Colors.globalBackgroundDeep)
                // Over the camera: every touch stays on the trimmer.
                .pointerInput(Unit) { awaitPointerEventScope { while (true) awaitPointerEvent() } }
                .statusBarsPadding()
                .navigationBarsPadding()
                .testTag("camera.trim"),
        ) {
            SheetHeader(
                title = stringResource(R.string.camera_trim_title),
                leading = SheetTextAction(stringResource(R.string.camera_trim_cancel), onCancel, enabled = !busy),
                trailing = SheetTextAction(stringResource(R.string.camera_trim_done), onDone, enabled = !busy && !failedToLoad),
            )
            Box(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
                if (failedToLoad) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.padding(horizontal = Tokens.Sizes.globalScreenMargin)) {
                        Text(stringResource(R.string.camera_trim_error_load), style = TextRoles.body, color = Tokens.Colors.globalTextSecondary, textAlign = TextAlign.Center)
                        Text(
                            stringResource(R.string.camera_trim_error_retry),
                            style = TextRoles.textButton,
                            color = androidx.compose.material3.MaterialTheme.colorScheme.primary,
                            modifier = Modifier.paddingFromBaseline(top = Tokens.Sizes.globalSectionHeaderToContent).tapClickable(onClick = onRetry),
                        )
                    }
                } else {
                    val box = if (aspect != null) Modifier.aspectRatio(aspect, matchHeightConstraintsFirst = aspect < 1f) else Modifier.fillMaxSize()
                    Box(
                        box.tapClickable(onClickLabel = if (playing) pause else play, onClick = onTogglePlay),
                    ) { video(Modifier.fillMaxSize()) }
                    BusyOverlay(busy, stringResource(R.string.camera_trim_a11y_busy))
                }
            }
            Spacer(Modifier.height(Tokens.Sizes.globalScreenMargin))
            RangeSlider(
                value = range.startMs.toFloat()..range.endMs.toFloat(),
                onValueChange = { values ->
                    val start = values.start.toLong()
                    val end = values.endInclusive.toLong()
                    // `haptic.global.select`: one tick per whole second the range passes (Retro: "video trim").
                    if (start / step != range.startMs / step || end / step != range.endMs / step) haptics.tick()
                    onRangeChanged(start, end)
                },
                valueRange = 0f..range.durationMs.toFloat(),
                enabled = !busy && !failedToLoad,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = Tokens.Sizes.globalScreenMargin)
                    .semantics {
                        contentDescription = timeline
                        customActions = listOf(
                            CustomAccessibilityAction(startEarlier) { onRangeChanged(range.startMs - step, range.endMs); true },
                            CustomAccessibilityAction(startLater) { onRangeChanged(range.startMs + step, range.endMs); true },
                            CustomAccessibilityAction(endEarlier) { onRangeChanged(range.startMs, range.endMs - step); true },
                            CustomAccessibilityAction(endLater) { onRangeChanged(range.startMs, range.endMs + step); true },
                        )
                    },
            )
            Text(
                stringResource(R.string.camera_trim_range, trimTime(range.startMs), trimTime(range.endMs), trimTime(range.endMs - range.startMs)),
                style = TextRoles.listSubtitle,
                color = Tokens.Colors.globalTextSecondary,
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = Tokens.Sizes.globalScreenMargin)
                    .paddingFromBaseline(top = Tokens.Sizes.globalSectionHeaderToContent, bottom = Tokens.Sizes.globalScreenMargin),
            )
        }
    }
}

/** Media3 Transformer: the [startMs]…[endMs] part of [source] as an MP4 at [target]; false when it cannot be written. */
object VideoClipper {
    suspend fun clip(context: Context, source: File, startMs: Long, endMs: Long, target: File): Boolean = suspendCancellableCoroutine { cont ->
        val item = MediaItem.Builder()
            .setUri(Uri.fromFile(source))
            .setClippingConfiguration(MediaItem.ClippingConfiguration.Builder().setStartPositionMs(startMs).setEndPositionMs(endMs).build())
            .build()
        val transformer = Transformer.Builder(context.applicationContext)
            .addListener(object : Transformer.Listener {
                override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                    if (cont.isActive) cont.resume(target.isFile && target.length() > 0)
                }

                override fun onError(composition: Composition, exportResult: ExportResult, exportException: ExportException) {
                    if (cont.isActive) cont.resume(false)
                }
            })
            .build()
        target.parentFile?.mkdirs()
        target.delete()
        runCatching { transformer.start(EditedMediaItem.Builder(item).build(), target.absolutePath) }
            .onFailure { if (cont.isActive) cont.resume(false) }
        // Transformer is driven from the thread that started it (the main thread).
        cont.invokeOnCancellation { android.os.Handler(android.os.Looper.getMainLooper()).post { transformer.cancel() } }
    }
}
