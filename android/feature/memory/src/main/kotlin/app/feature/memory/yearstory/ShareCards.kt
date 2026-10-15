package app.feature.memory.yearstory

import android.content.Context
import android.graphics.Bitmap
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.requiredSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.wrapContentSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.graphics.rememberGraphicsLayer
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import app.designsystem.generated.Tokens
import app.feature.memory.share.MemoryFiles
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File

/**
 * Renders a story card into a share image (`layout.year.story.shareCard`: 1080 × 1920 px, the card's
 * canvas without progress bar, chrome or share row, at the default text size). The card is composed
 * off screen at the on-screen canvas size with a density that maps its width to 1080 px, recorded
 * into a GraphicsLayer (never drawn), and turned into a bitmap; PNG encoding runs off the main thread.
 */
@Stable
class ShareCardExporter {
    internal class Job(val card: StoryCard, val result: CompletableDeferred<ImageBitmap?>)

    internal var job by mutableStateOf<Job?>(null)
        private set

    /** Whether a render is running (the share controls ignore taps meanwhile). */
    val busy: Boolean get() = job != null

    /** The bitmap of [card], or null when it could not be rendered. */
    suspend fun render(card: StoryCard): ImageBitmap? {
        val next = Job(card, CompletableDeferred())
        job = next
        return try {
            next.result.await()
        } finally {
            if (job === next) job = null
        }
    }

    /** Renders [card] and writes it as a PNG under the share folder; returns its content:// URI. */
    suspend fun export(context: Context, card: StoryCard, name: String): Uri? {
        val bitmap = render(card) ?: return null
        return withContext(Dispatchers.IO) {
            val file = File(MemoryFiles.dir(context), "$name.png")
            val source = bitmap.asAndroidBitmap()
            val software = if (source.config == Bitmap.Config.HARDWARE) source.copy(Bitmap.Config.ARGB_8888, false) else source
            file.outputStream().use { software.compress(Bitmap.CompressFormat.PNG, PNG_QUALITY, it) }
            MemoryFiles.uriFor(context, file)
        }
    }

    private companion object {
        /** PNG is lossless; the platform ignores the quality argument for it. */
        const val PNG_QUALITY = 100
    }
}

@Composable
fun rememberShareCardExporter(): ShareCardExporter = remember { ShareCardExporter() }

/**
 * Hosts [exporter]'s off-screen render. Place it anywhere in the screen: it takes no space and draws
 * nothing. [canvasWidth] is the on-screen canvas width, so the share image matches the card's layout.
 */
@Composable
fun ShareCardHost(exporter: ShareCardExporter, canvasWidth: Dp) {
    val job = exporter.job ?: return
    val layer = rememberGraphicsLayer()
    val canvasHeight = canvasWidth * Tokens.Layouts.YearStoryCanvas.aspectHeight / Tokens.Layouts.YearStoryCanvas.aspectWidth
    val shareCard = Tokens.Layouts.YearStoryShareCard
    // Density so that canvasWidth dp = shareCard.width px; the share image always uses the default text size.
    val shareDensity = Density(density = shareCard.width / canvasWidth.value, fontScale = 1f)
    val settled = remember(job) { CompletableDeferred<Unit>() }
    Box(Modifier.size(0.dp).wrapContentSize(Alignment.TopStart, unbounded = true).clearAndSetSemantics { }) {
        CompositionLocalProvider(LocalDensity provides shareDensity) {
            Box(
                Modifier
                    .requiredSize(canvasWidth, canvasHeight)
                    .drawWithContent { layer.record { this@drawWithContent.drawContent() } }
                    .background(Tokens.Colors.globalBackgroundDeep),
            ) {
                StoryCardContent(job.card, canvasWidth, canvasHeight, revealed = true, softwareImages = true, onSettled = { settled.complete(Unit) })
            }
        }
    }
    LaunchedEffect(job) {
        settled.await()
        // Two frames: the image that just settled is drawn into the layer before it is read.
        withFrameNanos { }
        withFrameNanos { }
        job.result.complete(runCatching { layer.toImageBitmap() }.getOrNull())
    }
}
