package app.feature.memory.birthday

import android.content.Context
import android.view.LayoutInflater
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView
import app.designsystem.generated.Tokens
import app.feature.memory.R
import app.feature.memory.common.MemoryImage

/** Aspect of the tribute video (`layout.birthday.tribute.video`, 16:9). */
val tributeAspect: Float get() = Tokens.Layouts.BirthdayTributeVideo.width / Tokens.Layouts.BirthdayTributeVideo.height

/**
 * Replaces the Media3 player below this point (snapshot tests draw the poster only, so no decoder
 * runs). Null = the real player.
 */
val LocalTributePlayer = compositionLocalOf<(@Composable (videoUrl: String, posterUrl: String?, Modifier) -> Unit)?> { null }

/** Creates the screen's player once (on open, before the tribute row arrives) and releases it on leave. */
class TributePlayerHolder(context: Context) {
    val player: ExoPlayer = ExoPlayer.Builder(context.applicationContext).build()
    private var loaded: String? = null
    private var autoplayed = false

    /** Loads and prepares [url] as soon as it is known (buffering starts before the view is laid out). */
    fun load(url: String, autoplay: Boolean, alreadyAutoplayed: Boolean) {
        if (loaded == url) return
        loaded = url
        player.setMediaItem(MediaItem.fromUri(url))
        player.repeatMode = Player.REPEAT_MODE_OFF
        // The video starts once when the screen opens (not again after a configuration change).
        player.playWhenReady = autoplay && !alreadyAutoplayed && !autoplayed
        autoplayed = true
        player.prepare()
    }

    fun release() = player.release()
}

/** The screen's [TributePlayerHolder], paused when the app goes to the background. */
@Composable
fun rememberTributePlayerHolder(): TributePlayerHolder? {
    if (LocalTributePlayer.current != null) return null
    val context = LocalContext.current
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    val holder = remember { TributePlayerHolder(context) }
    DisposableEffect(holder, lifecycle) {
        val observer = LifecycleEventObserver { _, event -> if (event == Lifecycle.Event.ON_PAUSE) holder.player.pause() }
        lifecycle.addObserver(observer)
        onDispose {
            lifecycle.removeObserver(observer)
            holder.release()
        }
    }
    return holder
}

/**
 * The tribute video (`layout.birthday.tribute.player`): Media3 PlayerView with its default controls,
 * 16:9 from the first frame of the screen (no layout jump), poster = the title card until the video
 * draws. The video has no audio.
 */
@Composable
fun TributePlayer(holder: TributePlayerHolder?, videoUrl: String, posterUrl: String?, autoplay: Boolean, modifier: Modifier = Modifier) {
    LocalTributePlayer.current?.let { standIn ->
        standIn(videoUrl, posterUrl, modifier.aspectRatio(tributeAspect))
        return
    }
    val player = holder ?: return
    val autoplayedBefore = rememberSaveable(videoUrl) { booleanArrayOf(false) }
    LaunchedEffect(videoUrl) {
        player.load(videoUrl, autoplay, autoplayedBefore[0])
        autoplayedBefore[0] = true
    }
    Box(modifier.aspectRatio(tributeAspect)) {
        MemoryImage(posterUrl, contentDescription = null, modifier = Modifier.fillMaxSize(), contentScale = ContentScale.Fit)
        AndroidView(
            factory = { ctx -> (LayoutInflater.from(ctx).inflate(R.layout.memory_tribute_player, null, false) as PlayerView) },
            update = { view -> view.player = player.player },
            onRelease = { view -> view.player = null },
            modifier = Modifier.fillMaxSize(),
        )
    }
}
