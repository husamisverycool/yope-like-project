package app.feature.capture

import android.app.Application
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.data.model.DayMemory
import app.data.model.PersonPhoto
import app.data.model.WidgetPerson
import app.data.repo.WidgetRepository
import app.feature.capture.widget.PersonalWidgetSync
import app.widget.WidgetFileStore
import app.widget.WidgetGroupMeta
import app.widget.WidgetSlotStore
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

/**
 * The app's own look-up for Friend Updates and Your Memories (iOS `WidgetContentSync.syncFriends` / `syncMemories`;
 * docs/WIDGET_REFRESH.md "Friend and memories widgets"): self-tags arrive this way, blocks and lost groups make the
 * widget "not set up", a day without a memory is recorded as none, and failures keep what the widget shows.
 */
@RunWith(AndroidJUnit4::class)
class PersonalWidgetSyncTest {
    private val app = ApplicationProvider.getApplicationContext<Application>()
    private val friends get() = WidgetSlotStore.friends(app)
    private val memories get() = WidgetSlotStore.memories(app)
    private val data = FakeCaptureData()
    private val today = LocalDate.parse("2026-10-17")
    private val zone = ZoneId.of("Europe/Lisbon")

    @Before fun setUp() {
        friends.clear()
        memories.clear()
        WidgetGroupMeta.of(WidgetFileStore.default(app)).setPremium(false)
    }

    private fun photo(post: String, via: String = PersonPhoto.VIA_TAG, widget: String? = "u/u3/$post/widget.jpg") = PersonPhoto(
        postId = post, mediaId = "m-$post", groupId = "g1", groupName = "Sunday dinners", authorId = "u3", authorName = "Rui",
        widgetPath = widget, visibleAt = Instant.parse("2026-10-17T09:00:00Z"), via = via,
    )

    private fun memory(day: LocalDate, post: String, widget: String? = "u/me/$post/widget.jpg") = DayMemory(
        day = day, postId = post, mediaId = "m-$post", groupId = "g1", groupName = "Sunday dinners", authorId = "me", authorName = "Me",
        widgetPath = widget, takenAt = Instant.parse("2024-10-17T12:00:00Z"), yearsAgo = 2,
    )

    @Test fun aFriendsSelfTaggedPhotoIsStoredWithItsPosterAndGroup() = runBlocking {
        data.people = listOf(WidgetPerson("u2", "Ana Lima"))
        data.photosOf["u2"] = listOf(photo("p1", widget = null), photo("p2"))
        PersonalWidgetSync.refreshFriends(app, data, setOf("u2"))
        val shown = friends.read("u2")!!
        assertEquals("the first row with a rendition", "p2", shown.sourceId)
        assertEquals("g1", shown.groupId)
        assertEquals("the poster's name (a self-tag: who took it)", "Rui", shown.senderName)
        assertEquals(listOf("https://storage.example/u/u3/p2/widget.jpg"), data.downloads)
        // The same photo is not downloaded again.
        PersonalWidgetSync.refreshFriends(app, data, setOf("u2"))
        assertEquals(1, data.downloads.size)
    }

    @Test fun nothingToShowIsEmptyAndABlockIsNotSetUp() = runBlocking {
        data.people = listOf(WidgetPerson("u2", "Ana Lima"))
        data.photosOf["u2"] = emptyList()
        PersonalWidgetSync.refreshFriends(app, data, setOf("u2"))
        assertEquals(WidgetSlotStore.State.None, friends.state("u2"))
        // No longer listed by widget_people (a block, no shared group).
        data.people = emptyList()
        PersonalWidgetSync.refreshFriends(app, data, setOf("u2"))
        assertEquals(WidgetSlotStore.State.Gone, friends.state("u2"))
    }

    @Test fun failuresKeepWhatTheWidgetShows() = runBlocking {
        data.people = listOf(WidgetPerson("u2", "Ana Lima"))
        data.photosOf["u2"] = listOf(photo("p1"))
        PersonalWidgetSync.refreshFriends(app, data, setOf("u2"))
        // Offline: the people and the photos cannot be read.
        data.people = null
        data.photosOf["u2"] = null
        PersonalWidgetSync.refreshFriends(app, data, setOf("u2"))
        assertEquals("p1", friends.read("u2")?.sourceId)
        // A rendition still being made: the shown photo stays.
        data.people = listOf(WidgetPerson("u2", "Ana Lima"))
        data.photosOf["u2"] = listOf(photo("p3", widget = null))
        PersonalWidgetSync.refreshFriends(app, data, setOf("u2"))
        assertEquals("p1", friends.read("u2")?.sourceId)
    }

    @Test fun memoriesAreStoredPerDayForAWeek() = runBlocking {
        data.memories = listOf(memory(today, "p9"), memory(today.plusDays(2), "p8", widget = null))
        PersonalWidgetSync.refreshMemories(app, data, force = true, today = today, zone = zone)
        assertEquals(Triple(today, WidgetRepository.MEMORY_DAYS, zone), data.memoriesAsked)
        assertEquals("p9", memories.read(today.toString())?.sourceId)
        assertEquals(Instant.parse("2024-10-17T12:00:00Z").toEpochMilli(), memories.read(today.toString())?.postedAtEpochMillis)
        assertEquals(WidgetSlotStore.State.None, memories.state(today.plusDays(1).toString()))
        assertEquals("no rendition: none, never another photo", WidgetSlotStore.State.None, memories.state(today.plusDays(2).toString()))
        assertEquals(WidgetSlotStore.State.None, memories.state(today.plusDays(6).toString()))
        assertEquals("beyond the week: not looked up", WidgetSlotStore.State.Unknown, memories.state(today.plusDays(7).toString()))
        // The next day drops the past one.
        PersonalWidgetSync.refreshMemories(app, data, force = true, today = today.plusDays(1), zone = zone)
        assertNull(memories.read(today.toString()))
        assertFalse(today.toString() in memories.slots())
    }

    @Test fun memoriesFailingToLoadKeepTheStoredDays() = runBlocking {
        data.memories = listOf(memory(today, "p9"))
        PersonalWidgetSync.refreshMemories(app, data, force = true, today = today, zone = zone)
        data.memories = null
        PersonalWidgetSync.refreshMemories(app, data, force = true, today = today, zone = zone)
        assertEquals("p9", memories.read(today.toString())?.sourceId)
        // Without a placed memories widget nothing is asked.
        data.memoriesAsked = null
        PersonalWidgetSync.refreshMemories(app, data, today = today, zone = zone)
        assertNull(data.memoriesAsked)
    }

    @Test fun thePremiumMarkerFollowsTheEntitlementWhenKnown() = runBlocking {
        val meta = WidgetGroupMeta.of(WidgetFileStore.default(app))
        data.premiumKnown = null
        PersonalWidgetSync.refreshPremium(app, data)
        assertFalse(meta.isPremium())
        data.premiumKnown = true
        PersonalWidgetSync.refreshPremium(app, data)
        assertTrue(meta.isPremium())
        data.premiumKnown = null
        PersonalWidgetSync.refreshPremium(app, data)
        assertTrue("unknown keeps the last answer", meta.isPremium())
        data.premiumKnown = false
        PersonalWidgetSync.refreshPremium(app, data)
        assertFalse(meta.isPremium())
    }
}
