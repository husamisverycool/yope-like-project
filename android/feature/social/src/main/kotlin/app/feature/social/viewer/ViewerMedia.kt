// Surface: photo.viewer — a video post and a Live Photo in the viewer (design/surfaces/photo.viewer.md → "Video" and
// "Live Photo"; tokens `photo.viewer.layout.video`, `photo.viewer.layout.livePhoto`).
// References: Retro's web viewer (references/auto/retro/web/retro.app-viewer-and-hero-js-excerpts.txt §1: Mux player
// with loop, autoPlay "muted", shown once it can play; taps still go forward / back), Apple HIG Playing audio and Live
// Photos (system badge, press to play). Media3 ExoPlayer plays both on Android.
package app.feature.social.viewer

import android.content.Context
import android.view.TextureView
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.VideoSize
import androidx.media3.exoplayer.ExoPlayer
import app.data.model.Media
import app.data.model.MediaKind
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.social.common.LocalSocialData
import app.feature.social.common.stringRes
import app.ui.components.CircleButtonStyle
import app.ui.components.CircleIconButton
import app.ui.foundation.tapClickable
import app.ui.text.TextRoles

/**
 * The viewer's one player (a video page or a Live Photo's motion; one plays at a time): what it holds, whether the
 * first frame is drawn, whether it plays, and the sound rule of `photo.viewer.layout.video` → audio — muted: volume 0,
 * no audio focus (other apps keep playing); with sound: the media audio focus (USAGE_MEDIA, CONTENT_TYPE_MOVIE) and a
 * pause when headphones are disconnected ("Don't be noisy").
 */
@Stable
class ViewerPlayback(context: Context) {
    private val player: ExoPlayer = ExoPlayer.Builder(context.applicationContext).build()

    /** The storage path loaded (a video's `original_path` or a Live Photo's `motion_path`). */
    var key by mutableStateOf<String?>(null)
        private set
    var videoSize by mutableStateOf(VideoSize.UNKNOWN)
        private set
    var firstFrame by mutableStateOf(false)
        private set
    var playing by mutableStateOf(false)
        private set
    var ended by mutableStateOf(false)
        private set
    var failed by mutableStateOf(false)
        private set

    /** Stopped by the system (headphones out, audio focus lost): the play circle shows. */
    var interrupted by mutableStateOf(false)
        private set

    init {
        player.addListener(object : Player.Listener {
            override fun onVideoSizeChanged(size: VideoSize) { videoSize = size }
            override fun onRenderedFirstFrame() { firstFrame = true }
            override fun onIsPlayingChanged(isPlaying: Boolean) { playing = isPlaying }
            override fun onPlaybackStateChanged(state: Int) { ended = state == Player.STATE_ENDED }
            override fun onPlayerError(error: PlaybackException) { failed = true }
            override fun onPlayWhenReadyChanged(playWhenReady: Boolean, reason: Int) {
                interrupted = !playWhenReady && (reason == Player.PLAY_WHEN_READY_CHANGE_REASON_AUDIO_BECOMING_NOISY ||
                    reason == Player.PLAY_WHEN_READY_CHANGE_REASON_AUDIO_FOCUS_LOSS)
            }
        })
    }

    /** Prepares [path] at [url] (once per path), then applies the loop, sound and autoplay of this page. */
    fun load(path: String, url: String, loop: Boolean, sound: Boolean, autoplay: Boolean) {
        if (key != path) {
            key = path
            firstFrame = false
            failed = false
            ended = false
            interrupted = false
            videoSize = VideoSize.UNKNOWN
            player.setMediaItem(MediaItem.fromUri(url))
            player.prepare()
        }
        player.repeatMode = if (loop) Player.REPEAT_MODE_ONE else Player.REPEAT_MODE_OFF
        setSound(sound)
        player.playWhenReady = autoplay
    }

    fun setSound(on: Boolean) {
        player.volume = if (on) 1f else 0f
        player.setAudioAttributes(AudioAttributes.Builder().setUsage(C.USAGE_MEDIA).setContentType(C.AUDIO_CONTENT_TYPE_MOVIE).build(), on)
        player.setHandleAudioBecomingNoisy(on)
    }

    /** From the start once it ended; else where it is. */
    fun play() {
        if (ended) player.seekTo(0)
        interrupted = false
        player.play()
    }

    fun pause() = player.pause()

    /** Leaves the current media (another page, a released hold). */
    fun stop() {
        player.stop()
        player.clearMediaItems()
        key = null
        firstFrame = false
        playing = false
    }

    fun attach(view: TextureView) = player.setVideoTextureView(view)
    fun detach(view: TextureView) = player.clearVideoTextureView(view)
    fun release() = player.release()
}

/** The viewer's player; null in snapshot tests (the poster and the controls are drawn, no decoder runs). */
val LocalViewerPlayback = staticCompositionLocalOf<ViewerPlayback?> { null }

/** One player for the open viewer, paused when the app goes to the background and released when the viewer closes. */
@Composable
fun rememberViewerPlayback(): ViewerPlayback {
    val context = LocalContext.current
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    val playback = remember { ViewerPlayback(context) }
    DisposableEffect(playback, lifecycle) {
        val observer = LifecycleEventObserver { _, event -> if (event == Lifecycle.Event.ON_PAUSE) playback.pause() }
        lifecycle.addObserver(observer)
        onDispose {
            lifecycle.removeObserver(observer)
            playback.release()
        }
    }
    return playback
}

/** A video's own aspect once its size is known. */
private val VideoSize.aspect: Float? get() = if (width > 0 && height > 0) width * pixelWidthHeightRatio / height else null

/** The player's picture, aspect fit in the frame (the poster stays under it until the first frame). */
@Composable
private fun BoxScope.VideoSurface(playback: ViewerPlayback) {
    // A TextureView is transparent until its first frame: the poster under it shows until then.
    val aspect = playback.videoSize.aspect
    AndroidView(
        factory = { ctx -> TextureView(ctx).also { playback.attach(it) } },
        update = { playback.attach(it) },
        onRelease = { playback.detach(it) },
        modifier = Modifier
            .align(Alignment.Center)
            .then(if (aspect != null) Modifier.aspectRatio(aspect, matchHeightConstraintsFirst = aspect < 1f) else Modifier.fillMaxSize())
            .clearAndSetSemantics { },
    )
}

/**
 * A video page (`photo.viewer.layout.video`): over the poster, the video starts muted and loops ([autoplay]); the C-11
 * glass sound circle sits at the visible video's bottom-trailing corner, `size.global.screenMargin` in ([letterbox]: the
 * frame's side bar beside a narrower video); without autoplay (Reduce Motion) or after a system pause, the glass play
 * circle is centred and plays it once with sound; a video that cannot play shows `photo.viewer.error.load` (tap retries).
 * [active] false (another layer covers the photo) pauses it.
 */
@Composable
fun BoxScope.ViewerVideo(
    media: Media,
    active: Boolean,
    autoplay: Boolean,
    sound: Boolean,
    onSound: (Boolean) -> Unit,
    playRequest: Int,
    onPlay: () -> Unit,
    letterbox: Dp,
) {
    val playback = LocalViewerPlayback.current
    val data = LocalSocialData.current
    val path = media.originalPath
    var attempt by remember(path) { mutableStateOf(0) }
    var url by remember(path) { mutableStateOf<String?>(null) }
    var urlFailed by remember(path) { mutableStateOf(false) }
    LaunchedEffect(path, attempt, playback) {
        if (playback == null) return@LaunchedEffect
        val signed = runCatching { data.signedUrls(listOf(path))[path] }.getOrNull()
        urlFailed = signed == null
        url = signed
    }
    LaunchedEffect(playback, url, active, autoplay, attempt) {
        val p = playback ?: return@LaunchedEffect
        val u = url ?: return@LaunchedEffect
        if (active) p.load(path, u, loop = autoplay, sound = sound || !autoplay, autoplay = autoplay) else p.pause()
    }
    DisposableEffect(playback, path) { onDispose { if (playback?.key == path) playback.stop() } }
    // The sound and play requests come from the circles and from the photo's TalkBack actions alike.
    LaunchedEffect(playback, sound) { if (playback?.key == path) playback.setSound(sound) }
    // Requests made on earlier pages do not start this one.
    val requestsBefore = remember(path) { playRequest }
    LaunchedEffect(playback, playRequest) {
        if (playRequest > requestsBefore && playback?.key == path) {
            playback.setSound(true)
            playback.play()
        }
    }
    if (playback != null && playback.key == path) VideoSurface(playback)

    if (urlFailed || (playback?.key == path && playback.failed)) {
        Text(
            stringRes(R.string.photo_viewer_error_load),
            style = TextRoles.body,
            color = Tokens.ColorsDark.globalTextSecondary,
            textAlign = TextAlign.Center,
            modifier = Modifier
                .align(Alignment.Center)
                .tapClickable {
                    urlFailed = false
                    playback?.stop()
                    attempt++
                }
                .padding(horizontal = Tokens.Sizes.globalScreenMargin),
        )
        return
    }
    if (videoWaitsForPlay(autoplay)) {
        CircleIconButton(
            Tokens.Icons.globalPlay,
            stringRes(R.string.photo_viewer_a11y_play),
            onClick = {
                onSound(true)
                onPlay()
            },
            modifier = Modifier.align(Alignment.Center).testTag("viewer.video.play"),
            style = CircleButtonStyle.Glass,
        )
    } else {
        // Muted by default; the choice holds for the open viewer (photo.viewer.layout.video → sound).
        CircleIconButton(
            if (sound) Tokens.Icons.photoViewerSoundOn else Tokens.Icons.photoViewerSoundOff,
            stringRes(if (sound) R.string.photo_viewer_a11y_mute else R.string.photo_viewer_a11y_unmute),
            onClick = { onSound(!sound) },
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .padding(end = letterbox + Tokens.Sizes.globalScreenMargin, bottom = Tokens.Sizes.globalScreenMargin)
                .testTag("viewer.video.sound"),
            style = CircleButtonStyle.Glass,
        )
    }
}

/**
 * A Live Photo (`photo.viewer.layout.livePhoto`): while [holding], its motion plays with its sound over the still (and
 * stops on release); the badge (`icon.photo.viewer.livePhoto`, `color.global.textOnMedia`, `size.global.icon`) sits at
 * the visible photo's top-leading corner, `size.global.videoPillInset` in ([letterbox]: the frame's side bar). Decorative.
 */
@Composable
fun BoxScope.ViewerLiveMotion(media: Media, holding: Boolean, letterbox: Dp) {
    val motion = media.motionPath ?: return
    val playback = LocalViewerPlayback.current
    val data = LocalSocialData.current
    var url by remember(motion) { mutableStateOf<String?>(null) }
    LaunchedEffect(motion, playback) {
        if (playback != null) url = runCatching { data.signedUrls(listOf(motion))[motion] }.getOrNull()
    }
    LaunchedEffect(playback, url, holding) {
        val p = playback ?: return@LaunchedEffect
        val u = url ?: return@LaunchedEffect
        if (holding) {
            p.load(motion, u, loop = false, sound = true, autoplay = true)
            p.play()
        } else if (p.key == motion) {
            p.stop()
        }
    }
    DisposableEffect(playback, motion) { onDispose { if (playback?.key == motion) playback.stop() } }
    if (holding && playback != null && playback.key == motion) VideoSurface(playback)
    Icon(
        Tokens.Icons.photoViewerLivePhoto,
        contentDescription = null,
        tint = Tokens.Colors.globalTextOnMedia,
        modifier = Modifier
            .align(Alignment.TopStart)
            .padding(start = letterbox + Tokens.Sizes.globalVideoPillInset, top = Tokens.Sizes.globalVideoPillInset)
            .size(Tokens.Sizes.globalIcon)
            .testTag("viewer.livePhoto.badge"),
    )
}

/** Whether the play circle shows: no autoplay and not playing, or stopped by the system. */
@Composable
fun videoWaitsForPlay(autoplay: Boolean): Boolean {
    val playback = LocalViewerPlayback.current
    return (!autoplay && playback?.playing != true) || playback?.interrupted == true
}

/** Whether [media] is a video post / a Live Photo with its motion. */
internal val Media.isVideo: Boolean get() = kind == MediaKind.Video
internal val Media.isLivePhoto: Boolean get() = kind == MediaKind.LivePhoto && motionPath != null
