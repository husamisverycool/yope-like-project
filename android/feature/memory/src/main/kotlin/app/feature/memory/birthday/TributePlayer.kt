package app.feature.memory.birthday

import android.view.LayoutInflater
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
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

/**
 * The tribute video (`layout.birthday.tribute.player`): Media3 PlayerView with its default controls,
 * 16:9, poster = the title card until the first frame. The video has no audio; it starts once when
 * the screen opens unless [autoplay] is false (Reduce Motion, see the screen).
 */
@Composable
fun TributePlayer(videoUrl: String, posterUrl: String?, autoplay: Boolean, modifier: Modifier = Modifier) {
    LocalTributePlayer.current?.let { stand_in ->
        stand_in(videoUrl, posterUrl, modifier.aspectRatio(tributeAspect))
        return
    }
    val context = LocalContext.current
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    // Autoplay happens once per screen visit, not again after a configuration change.
    val autoplayed = rememberSaveable(videoUrl) { booleanArrayOf(false) }
    val player = remember(videoUrl) {
        ExoPlayer.Builder(context).build().apply {
            setMediaItem(MediaItem.fromUri(videoUrl))
            playWhenReady = autoplay && !autoplayed[0]
            autoplayed[0] = true
            prepare()
        }
    }
    DisposableEffect(player, lifecycle) {
        val observer = LifecycleEventObserver { _, event -> if (event == Lifecycle.Event.ON_PAUSE) player.pause() }
        lifecycle.addObserver(observer)
        onDispose {
            lifecycle.removeObserver(observer)
            player.release()
        }
    }
    Box(modifier.aspectRatio(tributeAspect)) {
        MemoryImage(posterUrl, contentDescription = null, modifier = Modifier.fillMaxSize(), contentScale = ContentScale.Fit)
        AndroidView(
            factory = { ctx -> (LayoutInflater.from(ctx).inflate(R.layout.memory_tribute_player, null, false) as PlayerView) },
            update = { view -> view.player = player },
            onRelease = { view -> view.player = null },
            modifier = Modifier.fillMaxSize(),
        )
    }
}
