package app.feature.memory.yearstory

import app.data.model.RenderStatus
import app.feature.memory.FakeMemoryBackend.Companion.ANA
import app.feature.memory.FakeMemoryBackend.Companion.GROUP
import app.feature.memory.Rows
import app.feature.memory.Scenario
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** The group screen's year-story cards carry the story's cover, as iOS `YearStoryEntryModel` (groups.screen item 8). */
class YearStoryEntryTest {
    @Test fun theCardShowsTheFirstVisibleMostReactedPhoto() = runTest {
        val cards = readyStoryCards(Scenario.backend(), GROUP)!!
        assertEquals(listOf(2026), cards.map { it.year })
        assertEquals("https://signed.test/u/$ANA/m-p-r1/r/display.jpg", cards.single().coverUrl)
    }

    @Test fun aHiddenPhotoIsSkippedAndThePostsAreTheFallback() = runTest {
        val blocked = Scenario.backend().apply { posts.remove("p-r1") }
        assertEquals("https://signed.test/u/u-ben/m-p-r2/r/display.jpg", readyStoryCards(blocked, GROUP)!!.single().coverUrl)
        val noReactions = Scenario.backend().apply {
            yearStories[GROUP to 2026] = Rows.yearStory(Rows.storyData(mostReacted = emptyList()), postIds = listOf("p-r3"))
        }
        assertEquals("https://signed.test/u/u-cleo/m-p-r3/r/display.jpg", readyStoryCards(noReactions, GROUP)!!.single().coverUrl)
        val nothingVisible = Scenario.backend().apply {
            yearStories[GROUP to 2026] = Rows.yearStory(Rows.storyData(mostReacted = emptyList()), postIds = listOf("p-gone"))
        }
        assertNull("no photo: the media black card", readyStoryCards(nothingVisible, GROUP)!!.single().coverUrl)
    }

    @Test fun everyReadyStoryNewestFirstAndAFailedReadKeepsTheCards() = runTest {
        val past = Scenario.backend().apply {
            yearStories[GROUP to 2025] = Rows.yearStory(Rows.storyData(year = 2025), year = 2025)
            yearStories[GROUP to 2024] = Rows.yearStory(null, RenderStatus.Pending, year = 2024)
        }
        assertEquals(listOf(2026, 2025), readyStoryCards(past, GROUP)!!.map { it.year })
        assertNull(readyStoryCards(Scenario.backend().apply { online = false }, GROUP))
    }
}
