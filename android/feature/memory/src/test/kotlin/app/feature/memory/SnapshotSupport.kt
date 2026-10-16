package app.feature.memory

import android.net.Uri
import androidx.compose.foundation.layout.Box
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.painter.Painter
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onRoot
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.designsystem.LocalReduceMotionOverride
import app.feature.memory.birthday.LocalTributePlayer
import app.feature.memory.common.LocalMemoryBackend
import app.feature.memory.common.LocalMemoryImages
import app.feature.memory.common.LocalSeenStore
import app.feature.memory.common.MemoryBackend
import app.feature.memory.common.MemoryImage
import app.feature.memory.common.SeenStore
import app.testing.SamplePhotos
import app.ui.theme.AppTheme
import com.github.takahirom.roborazzi.captureRoboImage
import com.github.takahirom.roborazzi.captureScreenRoboImage
import org.junit.Rule
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * Test images: real sample photos (fixtures/photos/, :core:testing `SamplePhotos`), centre-cropped to the
 * aspect the URL names (`?w=3&h=4`) so photos keep their real proportions in snapshots. Renditions of one
 * photo (`p1`, `p1-d`, `a-display`, `a-thumb`) are the same picture; `<name>-avatar` is a portrait;
 * `collage…` is a grid of photos.
 */
object TestImages {
    private val cache = mutableMapOf<String, Painter>()

    /** The fixtures' photos by name (what the screens' sample data says they show). */
    private val photos = mapOf(
        // birthday.contribute: eligible photos of the honoree; the tribute poster (colourful to its edges: the
        // memory verification checklists find the player box by colour)
        "p1" to "friends-beach-hug-4x5", "p2" to "family-dinner-4x3", "p3" to "beach-sunset-wade-9x16",
        "p4" to "selfie-two-friends-1x1", "p5" to "friends-stairs-laughing-3x4", "poster" to "baby-bow-blanket-4x5",
        // onthisday: a day one and three years ago
        "a" to "concert-confetti-3x4", "b" to "campfire-friends-3x2", "c" to "snow-forest-walk-3x4",
        "d" to "autumn-bike-9x16", "e" to "snow-friends-beanies-1x1", "f" to "road-trip-window-3x2",
        // year.story: most reacted photos; tagging: the viewer's photo
        "r1" to "dinner-toast-candles-3x4", "r2" to "beach-friends-run-4x3", "viewer-photo" to "hike-mountain-friends-3x4",
    )

    private val people = mapOf("ana" to "avatar-01", "ben" to "avatar-06", "cleo" to "avatar-05", "sam" to "avatar-02")

    fun url(name: String, w: Int = 3, h: Int = 4) = "https://img.test/$name?w=$w&h=$h"

    fun painter(url: String): Painter = cache.getOrPut(url) {
        val uri = Uri.parse(url)
        val w = uri.getQueryParameter("w")?.toIntOrNull() ?: 3
        val h = uri.getQueryParameter("h")?.toIntOrNull() ?: 4
        val name = uri.lastPathSegment.orEmpty()
        val key = RENDITION.replace(name, "")
        // Every image keeps the intrinsic size of the generated one it replaces (w × 120 by h × 120 px).
        val width = w * INTRINSIC_UNIT
        val height = h * INTRINSIC_UNIT
        when {
            key.endsWith("-avatar") -> {
                val person = key.removeSuffix("-avatar").lowercase()
                SamplePhotos.painter(people[person] ?: SamplePhotos.avatarForKey(person), w, h, width, height)
            }
            key.startsWith("collage") -> {
                val tiles = (0 until COLLAGE_TILES).map { SamplePhotos.pick(it + (key.hashCode() and 0xFF)) }
                SamplePhotos.painter(SamplePhotos.collage(w * COLLAGE_UNIT, h * COLLAGE_UNIT, tiles, columns = 2, gap = COLLAGE_GAP), width, height)
            }
            else -> SamplePhotos.painter(photos[key] ?: SamplePhotos.forKey(key, w.toFloat() / h), w, h, width, height)
        }
    }

    /** Rendition suffixes: every rendition of a photo is the same picture. */
    private val RENDITION = Regex("-(d|display|thumb)$")
    private const val INTRINSIC_UNIT = 120f
    private const val COLLAGE_TILES = 4
    private const val COLLAGE_UNIT = 200
    private const val COLLAGE_GAP = 6
}

/** A "seen" store in memory (the On This Day intro counts as seen unless a test says otherwise). */
class TestSeenStore(private val seen: MutableSet<String> = mutableSetOf(), private val everything: Boolean = true) : SeenStore {
    override fun seen(userId: String, key: String) = everything || "$key.$userId" in seen
    override fun markSeen(userId: String, key: String) {
        seen += "$key.$userId"
    }
}

/** Theme and test locals: the sample photos, the poster in place of the decoder, motion on; [dark] = the appearance. */
@Composable
fun MemoryTestContent(
    backend: MemoryBackend? = null,
    dark: Boolean = false,
    seen: SeenStore = TestSeenStore(),
    content: @Composable () -> Unit,
) {
    AppTheme(dark = dark) {
        CompositionLocalProvider(
            LocalMemoryImages provides TestImages::painter,
            LocalReduceMotionOverride provides false,
            LocalSeenStore provides seen,
            LocalMemoryBackend provides backend,
            LocalTributePlayer provides { _, poster, modifier -> Box(modifier) { MemoryImage(poster, null, Modifier, ContentScale.Fit) } },
            content = content,
        )
    }
}

/**
 * Roborazzi baselines: `src/test/snapshots/<surface-id>/<state>-<light|dark>.png`, phone 393 × 852 dp (no system
 * bars in Robolectric). Every state is recorded in light; the primary state of each surface also in dark.
 */
@RunWith(AndroidJUnit4::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(qualifiers = "w393dp-h852dp-xhdpi")
abstract class SnapshotTest {
    @get:Rule val compose = createComposeRule()

    /** Lets reveals and effects finish with the clock paused, so spinners always draw the same frame. */
    protected open val settleMillis: Long = 2_000

    /**
     * Records [content] as `<surface>/<state>-<appearance>.png`. [screen]: the whole screen with its windows (sheets,
     * dialogs, menus); else the composition root.
     */
    fun snap(
        surface: String,
        state: String,
        backend: MemoryBackend? = null,
        dark: Boolean = false,
        screen: Boolean = false,
        seen: SeenStore = TestSeenStore(),
        settle: Long = settleMillis,
        content: @Composable () -> Unit,
    ) {
        compose.mainClock.autoAdvance = false
        compose.setContent { MemoryTestContent(backend, dark, seen, content) }
        compose.mainClock.advanceTimeBy(settle)
        if (screen) {
            // Sheets, dialogs and menus are separate windows: let them attach, lay out and settle.
            compose.waitForIdle()
            repeat(SHEET_FRAMES) { compose.mainClock.advanceTimeByFrame() }
            compose.mainClock.advanceTimeBy(settle)
        }
        val path = "src/test/snapshots/$surface/$state-${if (dark) "dark" else "light"}.png"
        if (screen) captureScreenRoboImage(path) else compose.onRoot().captureRoboImage(path)
    }

    private companion object {
        const val SHEET_FRAMES = 4
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
