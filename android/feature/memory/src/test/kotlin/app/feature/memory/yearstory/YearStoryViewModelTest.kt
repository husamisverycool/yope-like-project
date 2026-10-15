package app.feature.memory.yearstory

import app.data.model.RenderStatus
import app.feature.memory.FakeMemoryBackend
import app.feature.memory.FakeMemoryBackend.Companion.GROUP
import app.feature.memory.MainDispatcherRule
import app.feature.memory.Rows
import app.feature.memory.Scenario
import app.feature.memory.common.MemoryCache
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import java.time.LocalDate

class YearStoryViewModelTest {
    @get:Rule val main = MainDispatcherRule()

    private fun vm(backend: FakeMemoryBackend = Scenario.backend(), cache: MemoryCache = MemoryCache()) =
        YearStoryViewModel(GROUP, 2026, backend, Scenario.clock, cache)

    private val YearStoryViewModel.story get() = state.value as YearStoryState.Story

    @Test fun cardsInOrderOneFactEach() {
        val cards = vm().story.cards
        val kinds = cards.map { it::class.simpleName }
        assertEquals(
            listOf(
                "Intro", "MomentsSetup", "Moments", "BusiestMonth", "MostReactedSetup",
                "MostReactedPhoto", "MostReactedPhoto", "MostReactedPhoto", "MostReactedPhoto", "MostReactedPhoto",
                "TogetherSetup", "TogetherDay", "TogetherDay", "Teaser", "Outro", "Summary",
            ),
            kinds,
        )
        assertEquals(StoryCard.Moments("Sunday Lunch", 1284), cards[2])
        assertEquals(StoryCard.BusiestMonth(7), cards[3])
    }

    @Test fun mostReactedKeepsTheWorkerOrderOfTheFirstFiveWithoutNumbers() {
        val photos = vm().story.cards.filterIsInstance<StoryCard.MostReactedPhoto>()
        assertEquals(listOf("p-r1", "p-r2", "p-r3", "p-r4", "p-r5"), photos.map { it.postId })
        assertEquals(StoryCard.MostReactedPhoto("p-r1", "https://signed.test/u/u-ana/m-p-r1/r/display.jpg", "Ana", LocalDate.of(2026, 2, 25)), photos.first())
        // The card carries no number or rank: its fields are the photo, the first name and the date.
        assertEquals(listOf("postId", "url", "name", "date"), StoryCard.MostReactedPhoto::class.java.declaredFields.map { it.name }.filterNot { it.startsWith("$") })
    }

    @Test fun photosHiddenByABlockAreSkippedNotReplaced() {
        val backend = Scenario.backend().apply { blocked += FakeMemoryBackend.BEN }
        val photos = vm(backend).story.cards.filterIsInstance<StoryCard.MostReactedPhoto>()
        assertEquals(listOf("p-r1", "p-r3", "p-r4", "p-r5"), photos.map { it.postId })
    }

    @Test fun cardsWithoutDataAreSkipped() {
        val backend = Scenario.backend().apply { yearStories[GROUP to 2026] = Rows.yearStory(Rows.storyData(busiest = null)) }
        val kinds = vm(backend).story.cards.map { it::class.simpleName }
        assertEquals(listOf("Intro", "MomentsSetup", "Moments", "Teaser", "Outro", "Summary"), kinds)
    }

    @Test fun shareCardsAreTheFactCards() {
        val share = vm().story.shareCards
        assertEquals(9, share.size)
        assertTrue(share.none { it == StoryCard.Intro || it == StoryCard.Teaser || it == StoryCard.Outro || it == StoryCard.MomentsSetup })
    }

    @Test fun tapThroughStopsAtBothEndsAndReplays() {
        val vm = vm()
        vm.previous()
        assertEquals(0, vm.story.index)
        repeat(30) { vm.next() }
        assertEquals(StoryCard.Summary, vm.story.card)
        vm.replay()
        assertEquals(0, vm.story.index)
    }

    @Test fun deletedPhotoDropsItsCardsAndAnEmptySetup() {
        val backend = Scenario.backend()
        val vm = vm(backend)
        backend.deletions.tryEmit("p-r4")
        val cards = vm.story.cards
        assertFalse(cards.any { it is StoryCard.MostReactedPhoto && it.postId == "p-r4" })
        assertEquals("col-2 contained it", listOf("col-1"), cards.filterIsInstance<StoryCard.TogetherDay>().map { it.collageId })
        backend.deletions.tryEmit("p-r1")
        assertFalse("no everyone-day left → no setup card", StoryCard.TogetherSetup in vm.story.cards)
    }

    @Test fun notReadyOfflineAndErrorStates() {
        val pending = Scenario.backend().apply { yearStories[GROUP to 2026] = Rows.yearStory(null, RenderStatus.Pending) }
        assertEquals(YearStoryState.Failed(offline = false), vm(pending).state.value)
        assertEquals(YearStoryState.Failed(offline = true), vm(Scenario.backend().apply { online = false }).state.value)
    }

    @Test fun parseRejectsOtherVersions() {
        assertNull(YearStoryData.parse(kotlinx.serialization.json.JsonObject(mapOf("version" to kotlinx.serialization.json.JsonPrimitive(2)))))
        assertEquals(1284, YearStoryData.parse(Rows.storyData())?.momentsShared)
    }

    @Test fun entryShowsOnlyAReadyStoryOfTheCurrentYear() = runTest {
        assertEquals(2026, readyStoryYear(Scenario.backend(), GROUP, Scenario.clock))
        val pending = Scenario.backend().apply { yearStories[GROUP to 2026] = Rows.yearStory(null, RenderStatus.Pending) }
        assertNull(readyStoryYear(pending, GROUP, Scenario.clock))
    }

    @Test fun cachedStoryPaintsFirstAndKeepsTheCard() = runTest {
        val cache = MemoryCache()
        vm(cache = cache)
        val backend = Scenario.backend().apply { gates["yearStory"] = CompletableDeferred() }
        val vm = vm(backend, cache)
        val seen = mutableListOf<YearStoryState>()
        val job = launch(UnconfinedTestDispatcher(testScheduler)) { vm.state.collect { seen += it } }
        vm.next()
        vm.next()
        backend.gates.getValue("yearStory").complete(Unit)
        job.cancel()
        assertTrue(seen.all { it is YearStoryState.Story })
        assertEquals("the refresh keeps the viewer on the same card", 2, vm.story.index)
    }
}
