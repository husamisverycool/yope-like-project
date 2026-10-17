package app.widget

import app.model.WidgetSnapshot
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.IOException
import kotlin.math.abs

/**
 * The friend and memories widgets' store and states (design/surfaces/widget.friend.md, widget.memories.md → States), All
 * Groups' empty states (`widget.home.small.layout.allGroups`) and the Frame style's print geometry
 * (`widget.styles.layout.frame`, sizes from design/surfaces/widget.styles.md → Frame).
 */
class PersonalWidgetsTest {
    @get:Rule val tmp = TemporaryFolder()
    private val slots by lazy { WidgetSlotStore(tmp.newFolder("widgets-friends")) }

    private fun snapshot(source: String, at: Long, group: String = "g1") = WidgetSnapshot(
        groupId = group, groupName = "Sunday dinners", photoFile = "pending", senderName = "Rui Costa", senderAvatarFile = "a.jpg",
        kind = WidgetSnapshot.Kind.Photo, postedAtEpochMillis = at, sourceId = source,
    )

    private fun bytes(s: String): (java.io.OutputStream) -> Unit = { it.write(s.toByteArray()) }

    @Test fun aSlotIsUnknownThenShownThenEmptyOrGone() {
        assertEquals(WidgetSlotStore.State.Unknown, slots.state("u2"))
        val stored = slots.write("u2", snapshot("p1", 1_000), bytes("photo"))
        assertEquals(WidgetSlotStore.State.Shown, slots.state("u2"))
        assertEquals("p1", slots.read("u2")?.sourceId)
        assertEquals("g1", slots.read("u2")?.groupId)
        assertNull("the widget draws no avatar", stored.senderAvatarFile)
        assertEquals("photo", slots.photo("u2", stored).readText())
        slots.markNone("u2")
        assertEquals(WidgetSlotStore.State.None, slots.state("u2"))
        assertNull(slots.read("u2"))
        slots.markGone("u2")
        assertEquals(WidgetSlotStore.State.Gone, slots.state("u2"))
        // The server's answer replaces the slot, older or not (a deleted newest photo).
        slots.write("u2", snapshot("p0", 500), bytes("older"))
        assertEquals("p0", slots.read("u2")?.sourceId)
    }

    @Test fun keepsOnePreviousPhotoAndAFailedWriteChangesNothing() {
        val a = slots.write("u2", snapshot("p1", 1_000), bytes("a"))
        val b = slots.write("u2", snapshot("p2", 2_000), bytes("b"))
        assertTrue(slots.photo("u2", a).isFile)
        slots.write("u2", snapshot("p3", 3_000), bytes("c"))
        assertFalse(slots.photo("u2", a).isFile)
        assertTrue(slots.photo("u2", b).isFile)
        try {
            slots.write("u2", snapshot("p4", 4_000)) { throw IOException("network") }
        } catch (_: IOException) {
        }
        assertEquals("p3", slots.read("u2")?.sourceId)
    }

    @Test fun deletionsAndLeftGroupsLeaveTheSlots() {
        slots.write("u2", snapshot("p1", 1_000, group = "g1"), bytes("a"))
        slots.write("u3", snapshot("p2", 1_000, group = "g2"), bytes("b"))
        assertEquals(setOf("u2"), slots.removeSource("p1"))
        assertEquals(WidgetSlotStore.State.Unknown, slots.state("u2"))
        assertEquals(setOf("u3"), slots.retainGroups(setOf("g1")))
        assertNull(slots.read("u3"))
        slots.write("u2", snapshot("p1", 1_000), bytes("a"))
        slots.retain(emptySet())
        assertEquals(emptySet<String>(), slots.slots())
    }

    @Test fun daysAreSlotsToo() {
        val memories = WidgetSlotStore(tmp.newFolder("widgets-memories"))
        memories.write("2026-10-17", snapshot("p9", 1_000), bytes("m"))
        memories.markNone("2026-10-18")
        assertEquals(WidgetSlotStore.State.Shown, memories.state("2026-10-17"))
        assertEquals(WidgetSlotStore.State.None, memories.state("2026-10-18"))
        assertEquals(WidgetSlotStore.State.Unknown, memories.state("2026-10-19"))
    }

    @Test fun friendAndMemoriesStates() {
        assertEquals(WidgetEmptyState.SignedOut, WidgetEmptyState.ofFriend("u2", WidgetSlotStore.State.Shown, signedOut = true))
        assertEquals(WidgetEmptyState.NotSetUp, WidgetEmptyState.ofFriend(null, null, signedOut = false))
        assertEquals(WidgetEmptyState.NotSetUp, WidgetEmptyState.ofFriend("u2", WidgetSlotStore.State.Gone, signedOut = false))
        assertEquals(WidgetEmptyState.NoPhotos, WidgetEmptyState.ofFriend("u2", WidgetSlotStore.State.None, signedOut = false))
        assertEquals(WidgetEmptyState.Loading, WidgetEmptyState.ofFriend("u2", WidgetSlotStore.State.Unknown, signedOut = false))
        // A day not looked up is loading, never "none" (widget.memories: honest by construction).
        assertEquals(WidgetEmptyState.Loading, WidgetEmptyState.ofMemories(WidgetSlotStore.State.Unknown, signedOut = false))
        assertEquals(WidgetEmptyState.NoPhotos, WidgetEmptyState.ofMemories(WidgetSlotStore.State.None, signedOut = false))
        assertEquals(WidgetEmptyState.SignedOut, WidgetEmptyState.ofMemories(WidgetSlotStore.State.None, signedOut = true))
    }

    @Test fun allGroupsStatesAndThePremiumMarker() {
        val meta = WidgetGroupMeta(tmp.newFolder("widgets-meta"))
        assertEquals(WidgetEmptyState.NotSetUp, WidgetEmptyState.ofAllGroups(meta))
        meta.prepare("g1")
        meta.prepare("g2")
        assertEquals(setOf("g1", "g2"), meta.preparedGroups())
        assertEquals(WidgetEmptyState.Loading, WidgetEmptyState.ofAllGroups(meta))
        meta.setContent("g1", WidgetGroupMeta.Content.NoPhotos)
        meta.setContent("g2", WidgetGroupMeta.Content.NoPhotos)
        assertEquals(WidgetEmptyState.NoPhotos, WidgetEmptyState.ofAllGroups(meta))
        assertFalse(meta.isPremium())
        meta.setPremium(true)
        assertTrue(meta.isPremium())
        meta.retain(setOf("g1"))
        assertTrue("the marker is not a group", meta.isPremium())
        meta.setSignedOut(true)
        assertEquals(WidgetEmptyState.SignedOut, WidgetEmptyState.ofAllGroups(meta))
        meta.setPremium(false)
        assertFalse(meta.isPremium())
    }

    @Test fun allGroupsShowsTheNewestItemAcrossGroups() {
        val store = WidgetFileStore(tmp.newFolder("widgets"))
        fun incoming(group: String, at: Long) = WidgetFileStore.Incoming(group, group, WidgetSnapshot.Kind.Photo, java.time.Instant.ofEpochMilli(at), "p$at", "Ana", null)
        assertNull(newestAcross(store))
        store.write(incoming("g1", 2_000), bytes("a"))
        store.write(incoming("g2", 3_000), bytes("b"))
        store.write(incoming("g3", 1_000), bytes("c"))
        assertEquals("g2", newestAcross(store)?.groupId)
    }

    /** design/surfaces/widget.styles.md → Frame: small 158 × 158 → print 105 × 124; large 338 × 354 → 235 × 278. */
    @Test fun thePrintFitsTheWidgetAsMeasured() {
        fun near(expected: Float, actual: Float) = assertTrue("$expected ≈ $actual", abs(expected - actual) <= 1f)
        val small = FramePrint.geometry(158f, 158f)
        near(105f, small.print.width)
        near(124f, small.print.height)
        near((158f - small.print.width) / 2f, small.print.left)
        val large = FramePrint.geometry(338f, 354f)
        near(235f, large.print.width)
        near(278f, large.print.height)
        val medium = FramePrint.geometry(338f, 158f)
        near(105f, medium.print.width)
        // The window is square, 0.868 of the print, and leaves 0.214 of paper below it.
        val w = large.window
        assertEquals(w.width, w.height, 0.001f)
        near(0.868f * large.print.width, w.width)
        near(0.214f * large.print.width, large.print.bottom - w.bottom)
        near(0.066f * large.print.width, w.left - large.print.left)
        assertNotEquals(large.print, small.print)
    }
}
