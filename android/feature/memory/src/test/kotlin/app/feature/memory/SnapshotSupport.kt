package app.feature.memory

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Shader
import android.net.Uri
import androidx.compose.foundation.layout.Box
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.painter.BitmapPainter
import androidx.compose.ui.graphics.painter.Painter
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onRoot
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.designsystem.LocalReduceMotionOverride
import app.feature.memory.birthday.LocalTributePlayer
import app.feature.memory.common.LocalMemoryBackend
import app.feature.memory.common.LocalMemoryImages
import app.feature.memory.common.LocalReviewBlockedToasts
import app.feature.memory.common.MemoryBackend
import app.feature.memory.common.MemoryImage
import app.feature.memory.tagging.CoachStore
import app.feature.memory.tagging.LocalCoachStore
import app.ui.theme.AppTheme
import com.github.takahirom.roborazzi.captureRoboImage
import com.github.takahirom.roborazzi.captureScreenRoboImage
import org.junit.Rule
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import kotlin.math.absoluteValue

/**
 * Generated test images (no reference material): a two-colour diagonal gradient per URL, at the
 * aspect the URL names (`?w=3&h=4`), so photos keep their real proportions in snapshots.
 */
object TestImages {
    private val cache = mutableMapOf<String, Painter>()
    private val palette = intArrayOf(
        0xFF3D5A80.toInt(), 0xFF98C1D9.toInt(), 0xFFEE6C4D.toInt(), 0xFF293241.toInt(), 0xFF6A994E.toInt(),
        0xFFBC4749.toInt(), 0xFFF2CC8F.toInt(), 0xFF81B29A.toInt(), 0xFF5E548E.toInt(), 0xFFE07A5F.toInt(),
    )

    fun url(name: String, w: Int = 3, h: Int = 4) = "https://img.test/$name?w=$w&h=$h"

    fun painter(url: String): Painter = cache.getOrPut(url) {
        val uri = Uri.parse(url)
        val w = uri.getQueryParameter("w")?.toIntOrNull() ?: 3
        val h = uri.getQueryParameter("h")?.toIntOrNull() ?: 4
        val scale = 120
        val bitmap = Bitmap.createBitmap(w * scale, h * scale, Bitmap.Config.ARGB_8888)
        val seed = url.hashCode().absoluteValue
        val paint = Paint().apply {
            shader = LinearGradient(0f, 0f, bitmap.width.toFloat(), bitmap.height.toFloat(), palette[seed % palette.size], palette[(seed / 7 + 3) % palette.size], Shader.TileMode.CLAMP)
        }
        Canvas(bitmap).drawRect(0f, 0f, bitmap.width.toFloat(), bitmap.height.toFloat(), paint)
        BitmapPainter(bitmap.asImageBitmap())
    }
}

/** A coach store in memory. */
class TestCoachStore(private val dismissed: MutableSet<String> = mutableSetOf()) : CoachStore {
    override fun dismissed(userId: String) = userId in dismissed
    override fun dismiss(userId: String) {
        dismissed += userId
    }
}

/** Theme and test locals: generated images, the poster in place of the decoder, motion on. */
@Composable
fun MemoryTestContent(
    backend: MemoryBackend? = null,
    reviewToasts: Boolean = false,
    coach: CoachStore = TestCoachStore(),
    content: @Composable () -> Unit,
) {
    AppTheme {
        CompositionLocalProvider(
            LocalMemoryImages provides TestImages::painter,
            LocalReduceMotionOverride provides false,
            LocalReviewBlockedToasts provides reviewToasts,
            LocalCoachStore provides coach,
            LocalMemoryBackend provides backend,
            LocalTributePlayer provides { _, poster, modifier -> Box(modifier) { MemoryImage(poster, null, Modifier, ContentScale.Fit) } },
            content = content,
        )
    }
}

/** Roborazzi baselines: `src/test/snapshots/<surface-id>/<state>.png`, phone 393 × 852 dp. */
@RunWith(AndroidJUnit4::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(qualifiers = "w393dp-h852dp-xhdpi")
abstract class SnapshotTest {
    @get:Rule val compose = createComposeRule()

    /** Lets reveals and effects finish with the clock paused, so spinners always draw the same frame. */
    protected open val settleMillis: Long = 2_000

    fun snap(
        surface: String,
        state: String,
        backend: MemoryBackend? = null,
        reviewToasts: Boolean = false,
        screen: Boolean = false,
        coach: CoachStore = TestCoachStore(),
        content: @Composable () -> Unit,
    ) {
        compose.mainClock.autoAdvance = false
        compose.setContent { MemoryTestContent(backend, reviewToasts, coach, content) }
        compose.mainClock.advanceTimeBy(settleMillis)
        val path = "src/test/snapshots/$surface/$state.png"
        if (screen) captureScreenRoboImage(path) else compose.onRoot().captureRoboImage(path)
    }
}

/**
 * androidx FileProvider caches each authority's paths in a static map; Robolectric gives every test a
 * new data directory in the same class loader, so a cached entry would point at an earlier test's.
 */
fun resetFileProviderCache() {
    val field = androidx.core.content.FileProvider::class.java.getDeclaredField("sCache")
    field.isAccessible = true
    (field.get(null) as MutableMap<*, *>).clear()
}
