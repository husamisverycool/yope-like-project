package app.feature.capture

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.datastore.preferences.core.mutablePreferencesOf
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.compose
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.model.WidgetSnapshot
import app.model.WidgetStyle
import app.widget.FriendPhotoWidget
import app.widget.GroupPhotoWidget
import app.widget.MemoriesWidget
import app.widget.PersonalWidgets
import app.widget.PhotoWidgetSlots
import app.widget.TokenPhotoWidgetSlots
import app.widget.WidgetBinding
import app.widget.WidgetFileStore
import app.widget.WidgetGroupMeta
import app.widget.WidgetSlotStore
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.time.Instant
import java.time.LocalDate

/**
 * Friend Updates, Your Memories and All Groups composed to RemoteViews and drawn (design/surfaces/widget.friend.md,
 * widget.memories.md, widget.home.small.md → All Groups) in every style (widget.styles.md): what each state says to
 * TalkBack, and that a premium style without premium draws exactly Photo. No image baselines: the assertions compare
 * renders with each other.
 */
@RunWith(AndroidJUnit4::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(qualifiers = "w393dp-h852dp-xxhdpi")
class FriendMemoriesWidgetTest {
    private val context: Context get() = ApplicationProvider.getApplicationContext()
    private val groups get() = WidgetFileStore.default(context)
    private val meta get() = WidgetGroupMeta.of(groups)
    private val friends get() = WidgetSlotStore.friends(context)
    private val memories get() = WidgetSlotStore.memories(context)
    private val small = DpSize(158.dp, 158.dp)
    private val today = LocalDate.parse("2026-10-17")

    @Before fun setUp() {
        groups.root.deleteRecursively()
        meta.root.deleteRecursively()
        friends.clear()
        memories.clear()
        PhotoWidgetSlots.current = TokenPhotoWidgetSlots
        PersonalWidgets.today = { today }
    }

    @After fun tearDown() {
        PersonalWidgets.today = { LocalDate.now() }
    }

    private fun snapshot(source: String, at: String = "2024-10-17T12:00:00Z") = WidgetSnapshot(
        groupId = "g1", groupName = "Sunday dinners", photoFile = "pending", senderName = "Rui Costa",
        kind = WidgetSnapshot.Kind.Photo, postedAtEpochMillis = Instant.parse(at).toEpochMilli(), sourceId = source,
    )

    private fun photo(seed: Int = 0): (java.io.OutputStream) -> Unit {
        val file = Images.photoFile(context.cacheDir, "slot-$seed.jpg", 1092, 1146, seed)
        return { out -> file.inputStream().use { it.copyTo(out) } }
    }

    private class Render(val bitmap: Bitmap, val labels: List<String>)

    private fun render(widget: GlanceAppWidget, style: WidgetStyle = WidgetStyle.Photo, person: String? = null, allGroups: Boolean = false): Render = runBlocking {
        val state = mutablePreferencesOf().apply {
            person?.let { this[WidgetBinding.PERSON_ID] = it }
            if (allGroups) this[WidgetBinding.ALL_GROUPS] = true
            this[WidgetBinding.STYLE] = style.wire
            this[WidgetBinding.REVISION] = 1L
        }
        val views = widget.compose(context, size = small, state = state)
        val view: View = views.apply(context, FrameLayout(context))
        val density = context.resources.displayMetrics.density
        val w = (small.width.value * density).toInt()
        val h = (small.height.value * density).toInt()
        view.measure(View.MeasureSpec.makeMeasureSpec(w, View.MeasureSpec.EXACTLY), View.MeasureSpec.makeMeasureSpec(h, View.MeasureSpec.EXACTLY))
        view.layout(0, 0, w, h)
        val bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        view.draw(Canvas(bitmap))
        Render(bitmap, labels(view))
    }

    private fun labels(view: View): List<String> {
        val own = listOfNotNull(view.contentDescription?.toString())
        if (view !is ViewGroup) return own
        return own + (0 until view.childCount).flatMap { labels(view.getChildAt(it)) }
    }

    @Test fun friendStatesSayWhatTheyAre() {
        assertTrue("not set up", "Tap to choose a friend" in render(FriendPhotoWidget()).labels)
        friends.markNone("u2")
        assertTrue("No photos yet" in render(FriendPhotoWidget(), person = "u2").labels)
        friends.markGone("u2")
        assertTrue("a block or no shared group: not set up", "Tap to choose a friend" in render(FriendPhotoWidget(), person = "u2").labels)
        friends.write("u2", snapshot("p1"), photo())
        assertTrue("Rui's photo in Sunday dinners" in render(FriendPhotoWidget(), person = "u2").labels)
        meta.setSignedOut(true)
        assertTrue("Log in to see your content" in render(FriendPhotoWidget(), person = "u2").labels)
    }

    @Test fun memoriesStatesAndTheirLabel() {
        // A day not looked up yet: loading (no label, never "none").
        assertTrue(render(MemoriesWidget()).labels.none { it == "No photos found for this day" })
        memories.markNone(today.toString())
        assertTrue("No photos found for this day" in render(MemoriesWidget()).labels)
        memories.write(today.toString(), snapshot("p9"), photo(1))
        assertTrue("Your memory from Oct 17, 2024 in Sunday dinners" in render(MemoriesWidget()).labels)
        // Tomorrow's slot is another day.
        PersonalWidgets.today = { today.plusDays(1) }
        assertTrue(render(MemoriesWidget()).labels.none { it.startsWith("Your memory") })
    }

    @Test fun premiumStylesDrawPhotoWithoutPremium() {
        friends.write("u2", snapshot("p1"), photo())
        val plain = render(FriendPhotoWidget(), WidgetStyle.Photo, person = "u2").bitmap
        assertTrue("locked Date draws Photo", plain.sameAs(render(FriendPhotoWidget(), WidgetStyle.Date, person = "u2").bitmap))
        assertTrue("locked Frame draws Photo", plain.sameAs(render(FriendPhotoWidget(), WidgetStyle.Frame, person = "u2").bitmap))
        meta.setPremium(true)
        assertTrue("Photo is Photo with premium too", plain.sameAs(render(FriendPhotoWidget(), WidgetStyle.Photo, person = "u2").bitmap))
        val date = render(FriendPhotoWidget(), WidgetStyle.Date, person = "u2").bitmap
        val frame = render(FriendPhotoWidget(), WidgetStyle.Frame, person = "u2").bitmap
        assertFalse("the date title is drawn", plain.sameAs(date))
        assertFalse("the print is drawn", plain.sameAs(frame))
        // The print's paper (widget.styles.color.frame) shows between the window and the print's bottom edge.
        val density = context.resources.displayMetrics.density
        val paper = frame.getPixel(frame.width / 2, (frame.height / 2 + 50 * density).toInt())
        assertEquals(0xFFD5D6CD.toInt(), paper)
    }

    @Test fun allGroupsShowsTheNewestAcrossGroupsAndItsStates() {
        assertTrue("no group yet: not set up", "Tap to choose a group" in render(GroupPhotoWidget(), allGroups = true).labels)
        meta.prepare("g1")
        meta.prepare("g2")
        assertTrue("still looking up: no label", render(GroupPhotoWidget(), allGroups = true).labels.none { it.isNotBlank() })
        fun incoming(group: String, name: String, at: String, sender: String) =
            WidgetFileStore.Incoming(group, name, WidgetSnapshot.Kind.Photo, Instant.parse(at), "p-$group", sender, null)
        groups.write(incoming("g1", "Sunday dinners", "2026-10-16T10:00:00Z", "Ana Lima"), writePhoto = photo(0))
        groups.write(incoming("g2", "Book club", "2026-10-17T10:00:00Z", "Maya"), writePhoto = photo(2))
        assertTrue("Maya's photo in Book club" in render(GroupPhotoWidget(), allGroups = true).labels)
        groups.remove("g2")
        groups.remove("g1")
        meta.setContent("g1", WidgetGroupMeta.Content.NoPhotos)
        meta.setContent("g2", WidgetGroupMeta.Content.NoPhotos)
        assertTrue("No photos yet. Tap to add one" in render(GroupPhotoWidget(), allGroups = true).labels)
    }
}
