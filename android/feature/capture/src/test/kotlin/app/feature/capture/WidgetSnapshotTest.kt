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
 * The real Glance widget (`GroupPhotoWidget` with [TokenPhotoWidgetSlots]) composed to
 * RemoteViews, inflated as the launcher would, and drawn: one snapshot per size class and state
 * (surfaces widget.android, widget.home.small / .medium / .large, widget.arrival).
 */
@RunWith(AndroidJUnit4::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(qualifiers = "w393dp-h852dp-xxhdpi")
class WidgetSnapshotTest {
    private val context: Context = ApplicationProvider.getApplicationContext()
    private val store = WidgetFileStore.default(context)
    private val meta = WidgetGroupMeta.of(store)

    @Before fun setUp() {
        store.root.deleteRecursively()
        meta.root.deleteRecursively()
        PhotoWidgetSlots.current = TokenPhotoWidgetSlots
    }

    private val sizes = mapOf(
        "small" to WidgetSizeClass.Small.minSize,
        "medium" to WidgetSizeClass.Medium.minSize,
        "large" to WidgetSizeClass.Large.minSize,
    )

    private fun writePhoto(groupId: String, caption: String?, avatar: Boolean, kind: WidgetSnapshot.Kind = WidgetSnapshot.Kind.Photo, seed: Int = 0) {
        val dir = context.cacheDir
        val photo = Images.photoFile(dir, "rendition-$seed.jpg", 1092, 1146, seed)
        val face = Images.photoFile(dir, "avatar.jpg", 120, 120, seed + 2)
        store.write(
            WidgetFileStore.Incoming(groupId, "Sunday dinners", kind, Instant.parse("2026-05-26T19:00:00Z"), "p1", if (kind == WidgetSnapshot.Kind.Photo) "Ana Lima" else null, caption),
            writePhoto = { out -> photo.inputStream().use { it.copyTo(out) } },
            writeAvatar = if (avatar) { out -> face.inputStream().use { it.copyTo(out) } } else null,
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
        launcherMask(bitmap)
    }

    /** The launcher clips widgets to `system_app_widget_background_radius` (a software draw does not). */
    private fun launcherMask(src: Bitmap): Bitmap {
        val r = context.resources.getDimension(android.R.dimen.system_app_widget_background_radius)
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

    @Test fun photoWithCaptionEverySize() {
        writePhoto("g1", caption = "sunday dinner at the limas", avatar = true)
        meta.prepare("g1")
        sizes.forEach { (n, s) -> snap("widget.android_$n" + "_photo-caption", render(s, "g1")) }
    }

    @Test fun photoWithoutCaptionOrAvatarEverySize() {
        writePhoto("g1", caption = null, avatar = false, seed = 1)
        meta.prepare("g1")
        sizes.forEach { (n, s) -> snap("widget.android_$n" + "_photo-noavatar", render(s, "g1")) }
    }

    @Test fun collageEverySize() {
        writePhoto("g1", caption = null, avatar = false, kind = WidgetSnapshot.Kind.Collage, seed = 3)
        meta.prepare("g1")
        sizes.forEach { (n, s) -> snap("widget.android_$n" + "_collage", render(s, "g1")) }
    }

    @Test fun loadingPlaceholderWithMemberAvatars() {
        meta.prepare("g1")
        val faces = (0..2).map { Images.photoFile(context.cacheDir, "m$it.jpg", 90, 90, it) }
        meta.setMembers("g1", listOf({ out: java.io.OutputStream -> faces[0].inputStream().use { it.copyTo(out) } }, null, { out -> faces[2].inputStream().use { it.copyTo(out) } }))
        sizes.forEach { (n, s) -> snap("widget.android_$n" + "_loading", render(s, "g1")) }
    }

    @Test fun emptyAndNotSetUp() {
        meta.prepare("g1")
        meta.setContent("g1", WidgetGroupMeta.Content.NoPhotos)
        sizes.forEach { (n, s) -> snap("widget.android_$n" + "_empty", render(s, "g1")) }
        sizes.forEach { (n, s) -> snap("widget.android_$n" + "_notsetup", render(s, null)) }
    }

    @Test fun emptyStateRulesAndTheWidgetLabel() {
        assertEquals(WidgetEmptyState.NotSetUp, WidgetEmptyState.of(null, meta))
        assertEquals(WidgetEmptyState.NotSetUp, WidgetEmptyState.of("g1", meta)) // bound but gone
        meta.prepare("g1")
        assertTrue(WidgetEmptyState.of("g1", meta) is WidgetEmptyState.Loading)
        meta.setContent("g1", WidgetGroupMeta.Content.NoPhotos)
        assertEquals(WidgetEmptyState.NoPhotos, WidgetEmptyState.of("g1", meta))
        // Leaving the group (retainGroups) drops the entry: "not set up", tap → configuration.
        store.retainGroups(emptySet())
        assertEquals(WidgetEmptyState.NotSetUp, WidgetEmptyState.of("g1", meta))
        assertFalse(TokenPhotoWidgetSlots.opensCamera(context, null, "g1"))
        assertEquals("Tap to set up", TokenPhotoWidgetSlots.contentDescription(context, null, "g1"))
        writePhoto("g2", caption = "hi", avatar = false)
        val snapshot = store.read("g2")!!
        assertTrue(TokenPhotoWidgetSlots.opensCamera(context, snapshot, "g2"))
        assertEquals("Ana’s photo in Sunday dinners, hi", TokenPhotoWidgetSlots.contentDescription(context, snapshot, "g2"))
    }

    @Test fun arrivalReplacesTheImageInOneUpdate() {
        writePhoto("g1", caption = null, avatar = false, seed = 0)
        meta.prepare("g1")
        val before = render(sizes.getValue("small"), "g1")
        store.write(
            WidgetFileStore.Incoming("g1", "Sunday dinners", WidgetSnapshot.Kind.Photo, Instant.parse("2026-05-26T19:05:00Z"), "p2", "Ana", null),
            writePhoto = { out -> Images.photoFile(context.cacheDir, "new.jpg", 1092, 1146, 2).inputStream().use { it.copyTo(out) } },
        )
        val after = render(sizes.getValue("small"), "g1")
        snap("widget.arrival_before", before)
        snap("widget.arrival_after", after)
        assertFalse(before.sameAs(after))
    }

}
