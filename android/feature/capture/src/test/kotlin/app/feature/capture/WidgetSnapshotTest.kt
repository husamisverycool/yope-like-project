package app.feature.capture

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.RectF
import android.view.View
import android.widget.FrameLayout
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import app.designsystem.generated.Tokens
import app.widget.WidgetTap
import org.robolectric.RuntimeEnvironment
import androidx.datastore.preferences.core.mutablePreferencesOf
import androidx.glance.appwidget.compose
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.model.WidgetSnapshot
import app.widget.GroupPhotoWidget
import app.widget.PhotoWidgetSlots
import app.widget.TokenPhotoWidgetSlots
import app.widget.WidgetBinding
import app.widget.WidgetEmptyState
import app.widget.WidgetFileStore
import app.widget.WidgetGroupMeta
import app.widget.WidgetSizeClass
import com.github.takahirom.roborazzi.captureRoboImage
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.time.Instant

/**
 * The real Glance widget (`GroupPhotoWidget` with [TokenPhotoWidgetSlots]) composed to RemoteViews, inflated as
 * the launcher would, and drawn: one snapshot per size and state (surfaces widget.android, widget.home.small /
 * .medium / .large, widget.arrival), the photo state also in dark (the widget is a media surface: identical by
 * design). "small" is 158 × 158 dp, the size of Retro's widget preview art (references/auto/retro/apk/
 * widget_preview_journals.webp), so the side-by-side compares at 1:1.
 */
@RunWith(AndroidJUnit4::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(qualifiers = "w393dp-h852dp-xxhdpi")
class WidgetSnapshotTest {
    private val context: Context get() = ApplicationProvider.getApplicationContext()
    private val store get() = WidgetFileStore.default(context)
    private val meta get() = WidgetGroupMeta.of(store)

    @Before fun setUp() {
        store.root.deleteRecursively()
        meta.root.deleteRecursively()
        PhotoWidgetSlots.current = TokenPhotoWidgetSlots
    }

    private val sizes = mapOf(
        "small" to DpSize(REFERENCE_DP.dp, REFERENCE_DP.dp),
        "medium" to WidgetSizeClass.Medium.minSize,
        "large" to WidgetSizeClass.Large.minSize,
    )

    private fun writePhoto(groupId: String, sender: String? = "Ana Lima", group: String = "Sunday dinners", kind: WidgetSnapshot.Kind = WidgetSnapshot.Kind.Photo, seed: Int = 0) {
        val dir = context.cacheDir
        val collage = kind == WidgetSnapshot.Kind.Collage
        val photo = if (collage) Images.collageFile(dir, "rendition-$seed.jpg", 1092, 1146, seed) else Images.photoFile(dir, "rendition-$seed.jpg", 1092, 1146, seed)
        store.write(
            WidgetFileStore.Incoming(groupId, group, kind, Instant.parse("2026-05-26T19:00:00Z"), "p1", if (kind == WidgetSnapshot.Kind.Photo) sender else null, null),
            writePhoto = { out -> photo.inputStream().use { it.copyTo(out) } },
            writeAvatar = null,
        )
    }

    private fun render(size: DpSize, groupId: String?): Bitmap = runBlocking {
        val state = mutablePreferencesOf().apply {
            groupId?.let { this[WidgetBinding.GROUP_ID] = it }
            this[WidgetBinding.REVISION] = 1L
        }
        val views = GroupPhotoWidget().compose(context, size = size, state = state)
        val parent = FrameLayout(context)
        val view: View = views.apply(context, parent)
        val density = context.resources.displayMetrics.density
        val w = (size.width.value * density).toInt()
        val h = (size.height.value * density).toInt()
        view.measure(View.MeasureSpec.makeMeasureSpec(w, View.MeasureSpec.EXACTLY), View.MeasureSpec.makeMeasureSpec(h, View.MeasureSpec.EXACTLY))
        view.layout(0, 0, w, h)
        val bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        view.draw(Canvas(bitmap))
        cornerMask(bitmap)
    }

    /**
     * Android 12+ clips the widget root to its `cornerRadius` (`widget.android.radius.widget`) with an outline,
     * which a software draw does not apply: the test applies the same clip.
     */
    private fun cornerMask(src: Bitmap): Bitmap {
        val r = Tokens.Radii.widgetAndroidRadiusWidget.value * context.resources.displayMetrics.density
        val out = Bitmap.createBitmap(src.width, src.height, Bitmap.Config.ARGB_8888)
        val c = Canvas(out)
        c.drawColor(0xFF808080.toInt()) // test backdrop (a neutral home screen), not app UI
        val layer = Bitmap.createBitmap(src.width, src.height, Bitmap.Config.ARGB_8888)
        val lc = Canvas(layer)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        lc.drawRoundRect(RectF(0f, 0f, src.width.toFloat(), src.height.toFloat()), r, r, paint)
        paint.xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_IN)
        lc.drawBitmap(src, 0f, 0f, paint)
        c.drawBitmap(layer, 0f, 0f, null)
        return out
    }

    private fun snap(name: String, bitmap: Bitmap) = bitmap.captureRoboImage("src/test/snapshots/$name.png")

    @Test fun photoEverySize() {
        writePhoto("g1")
        meta.prepare("g1")
        sizes.forEach { (n, s) -> snap("widget.android_${n}_photo", render(s, "g1")) }
    }

    @Test fun photoDark() {
        RuntimeEnvironment.setQualifiers("+night")
        writePhoto("g1")
        meta.prepare("g1")
        snap("widget.android_small_photo-dark", render(sizes.getValue("small"), "g1"))
    }

    @Test fun collageEverySize() {
        writePhoto("g1", kind = WidgetSnapshot.Kind.Collage, seed = 3)
        meta.prepare("g1")
        sizes.forEach { (n, s) -> snap("widget.android_${n}_collage", render(s, "g1")) }
    }

    @Test fun loadingIsBlackWithNoContent() {
        meta.prepare("g1")
        sizes.forEach { (n, s) -> snap("widget.android_${n}_loading", render(s, "g1")) }
    }

    @Test fun emptyNotSetUpAndSignedOut() {
        meta.prepare("g1")
        meta.setContent("g1", WidgetGroupMeta.Content.NoPhotos)
        sizes.forEach { (n, s) -> snap("widget.android_${n}_empty", render(s, "g1")) }
        sizes.forEach { (n, s) -> snap("widget.android_${n}_notsetup", render(s, null)) }
        meta.setSignedOut(true)
        sizes.forEach { (n, s) -> snap("widget.android_${n}_signedout", render(s, "g1")) }
    }

    /**
     * The lock-screen widget hub slot (owner decision 18; token `widget.android.layout.lockScreen`): "approximately 4
     * cells wide by 3 cells tall" → `PlatformWidgetGrid.minSize(4, 3)`, which the responsive layouts draw with the
     * Medium class — photo with the text stack, collage, and the state column (empty, signed out).
     */
    @Test fun keyguardHubSlot() {
        val hub = app.widget.PlatformWidgetGrid.minSize(4, 3)
        assertEquals(WidgetSizeClass.Medium, WidgetSizeClass.of(hub))
        writePhoto("g1")
        writePhoto("g2", kind = WidgetSnapshot.Kind.Collage, seed = 3)
        meta.prepare("g1")
        meta.prepare("g2")
        meta.prepare("g3")
        meta.setContent("g3", WidgetGroupMeta.Content.NoPhotos)
        snap("widget.android_keyguard_photo", render(hub, "g1"))
        snap("widget.android_keyguard_collage", render(hub, "g2"))
        snap("widget.android_keyguard_empty", render(hub, "g3"))
        meta.setSignedOut(true)
        snap("widget.android_keyguard_signedout", render(hub, "g1"))
    }

    @Test fun stateRulesTapTargetsAndTheWidgetLabel() {
        assertEquals(WidgetEmptyState.NotSetUp, WidgetEmptyState.of(null, meta))
        assertEquals(WidgetEmptyState.NotSetUp, WidgetEmptyState.of("g1", meta)) // bound but gone
        meta.prepare("g1")
        assertEquals(WidgetEmptyState.Loading, WidgetEmptyState.of("g1", meta))
        assertEquals(WidgetTap.Camera("g1"), TokenPhotoWidgetSlots.tap(context, null, "g1"))
        meta.setContent("g1", WidgetGroupMeta.Content.NoPhotos)
        assertEquals(WidgetEmptyState.NoPhotos, WidgetEmptyState.of("g1", meta))
        assertEquals("No photos yet. Tap to add one", TokenPhotoWidgetSlots.contentDescription(context, null, "g1"))
        // Leaving the group (retainGroups) drops the entry: "not set up", tap → configuration.
        store.retainGroups(emptySet())
        assertEquals(WidgetEmptyState.NotSetUp, WidgetEmptyState.of("g1", meta))
        assertEquals(WidgetTap.Configure, TokenPhotoWidgetSlots.tap(context, null, "g1"))
        assertEquals("Tap to choose a group", TokenPhotoWidgetSlots.contentDescription(context, null, "g1"))
        // A photo: tap → the camera with the group; label "{name}'s photo in {group}" (first name only).
        writePhoto("g2")
        val snapshot = store.read("g2")!!
        assertEquals(WidgetTap.Camera("g2"), TokenPhotoWidgetSlots.tap(context, snapshot, "g2"))
        assertEquals("Ana's photo in Sunday dinners", TokenPhotoWidgetSlots.contentDescription(context, snapshot, "g2"))
        // Signed out: every widget says so; tap → the app (sign-in).
        meta.setSignedOut(true)
        assertEquals(WidgetEmptyState.SignedOut, WidgetEmptyState.of("g2", meta))
        assertEquals(WidgetTap.App, TokenPhotoWidgetSlots.tap(context, snapshot, "g2"))
        assertEquals("Log in to see your content", TokenPhotoWidgetSlots.contentDescription(context, null, "g2"))
        meta.setSignedOut(false)
        assertEquals(WidgetTap.Camera("g2"), TokenPhotoWidgetSlots.tap(context, snapshot, "g2"))
    }

    /**
     * Pixel geometry of the drawn widget for design/verification/widget.android.md (dp): the text stack's trailing
     * inset, last baseline and line pitch (lines without descenders: "Ana" over "Book club"), the scrim, the state
     * glyph's box and tint.
     */
    @Test fun measureGeometry() {
        val density = context.resources.displayMetrics.density
        val small = sizes.getValue("small")
        writePhoto("g1", sender = "Ana", group = "Book club")
        meta.prepare("g1")
        val withText = render(small, "g1")
        // The same photo and scrim without the text stack.
        PhotoWidgetSlots.current = object : PhotoWidgetSlots {
            override fun photo(context: Context, photo: Bitmap, widgetWidthPx: Int): Bitmap = TokenPhotoWidgetSlots.photo(context, photo, widgetWidthPx)
        }
        val noText = render(small, "g1")
        PhotoWidgetSlots.current = object : PhotoWidgetSlots {}
        val bare = render(small, "g1")
        PhotoWidgetSlots.current = TokenPhotoWidgetSlots
        val ink = diffBox(withText, noText)
        val inkRows = (ink.top..ink.bottom).filter { y -> (ink.left..ink.right).any { x -> withText.getPixel(x, y) != noText.getPixel(x, y) } }
        val lineBottoms = inkRows.zipWithNext().filter { (a, b) -> b - a > 1 }.map { it.first } + inkRows.last()
        fun dp(px: Number) = Math.round(px.toDouble() / density * 10) / 10.0
        val h = withText.height
        // Scrim: darkening at the bottom-left corner sample (no text there) vs the bare photo, and at 50 % height (none).
        fun luminance(c: Int) = (android.graphics.Color.red(c) * 299 + android.graphics.Color.green(c) * 587 + android.graphics.Color.blue(c) * 114) / 1000.0
        val x = Math.round(SCRIM_SAMPLE_DP * density)
        val scrimBottom = 1 - luminance(noText.getPixel(x, h - 3)) / luminance(bare.getPixel(x, h - 3)).coerceAtLeast(1.0)
        val scrimMiddle = 1 - luminance(noText.getPixel(x, h / 2)) / luminance(bare.getPixel(x, h / 2)).coerceAtLeast(1.0)
        // State column.
        meta.setContent("g1", WidgetGroupMeta.Content.NoPhotos)
        store.remove("g1")
        val empty = render(small, "g1")
        val bright = colorBox(empty) { c -> android.graphics.Color.red(c) > 150 && android.graphics.Color.red(c) == android.graphics.Color.blue(c) }
        val json = org.json.JSONObject()
            .put("widthDp", dp(withText.width)).put("heightDp", dp(h))
            .put("textTrailingInset", dp(withText.width - 1 - ink.right))
            .put("lastBaselineFromBottom", dp(h - 1 - lineBottoms.last()))
            .put("linePitch", if (lineBottoms.size > 1) dp(lineBottoms.last() - lineBottoms[lineBottoms.size - 2]) else null)
            .put("textLeft", dp(ink.left))
            .put("scrimDarkeningBottom", Math.round(scrimBottom * 100) / 100.0)
            .put("scrimDarkeningMiddle", Math.round(scrimMiddle * 100) / 100.0)
            .put("stateInkTop", dp(bright.top)).put("stateInkBottom", dp(bright.bottom)).put("stateInkLeft", dp(bright.left)).put("stateInkRight", dp(bright.right))
            .put("stateBackground", Integer.toHexString(empty.getPixel(Math.round(EDGE_SAMPLE_DP * density), Math.round(EDGE_SAMPLE_DP * density))))
            .put("stateTintSample", Integer.toHexString(empty.getPixel(bright.centerX(), bright.top + 1)))
        java.io.File("build/verification").mkdirs()
        java.io.File("build/verification/widget.android.json").writeText(json.toString(2))
        assertTrue(scrimBottom > scrimMiddle)
    }

    private fun diffBox(a: Bitmap, b: Bitmap): android.graphics.Rect {
        val r = android.graphics.Rect(a.width, a.height, -1, -1)
        for (y in 0 until a.height) for (x in 0 until a.width) if (a.getPixel(x, y) != b.getPixel(x, y)) r.union(x, y)
        return r
    }

    private fun colorBox(a: Bitmap, match: (Int) -> Boolean): android.graphics.Rect {
        val r = android.graphics.Rect(a.width, a.height, -1, -1)
        for (y in 0 until a.height) for (x in 0 until a.width) if (match(a.getPixel(x, y))) r.union(x, y)
        return r
    }

    @Test fun arrivalReplacesTheImageInOneUpdate() {
        writePhoto("g1", seed = 0)
        meta.prepare("g1")
        val before = render(sizes.getValue("small"), "g1")
        store.write(
            WidgetFileStore.Incoming("g1", "Sunday dinners", WidgetSnapshot.Kind.Photo, Instant.parse("2026-05-26T19:05:00Z"), "p2", "Maya", null),
            writePhoto = { out -> Images.photoFile(context.cacheDir, "new.jpg", 1092, 1146, 2).inputStream().use { it.copyTo(out) } },
        )
        val after = render(sizes.getValue("small"), "g1")
        snap("widget.arrival_before", before)
        snap("widget.arrival_after", after)
        assertFalse(before.sameAs(after))
    }
}

/** Retro's widget preview art is 158 × 158 dp (mdpi, 1 px = 1 dp). */
private const val REFERENCE_DP = 158

/** Sample point inside the corner radius, clear of the state column (test geometry). */
private const val EDGE_SAMPLE_DP = 12f

/** Scrim sample column: outside the 22-dp corner clip, clear of the trailing text stack (test geometry). */
private const val SCRIM_SAMPLE_DP = 30f
