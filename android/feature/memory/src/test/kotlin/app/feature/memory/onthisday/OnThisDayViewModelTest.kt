package app.feature.memory.onthisday

import app.data.error.DataError
import app.feature.memory.FakeMemoryBackend
import app.feature.memory.MainDispatcherRule
import app.feature.memory.Scenario
import app.feature.memory.common.MemoryCache
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.flow.toList
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import java.time.Clock
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZoneOffset

class OnThisDayViewModelTest {
    @get:Rule val main = MainDispatcherRule()

    private fun vm(backend: FakeMemoryBackend = Scenario.backend(), cache: MemoryCache = MemoryCache()) =
        OnThisDayViewModel(FakeMemoryBackend.GROUP, backend, Scenario.clock, cache)

    private val OnThisDayViewModel.day get() = state.value as OnThisDayState.Day

    @Test fun groupsYearsNewestFirstAndKeepsApiOrderInsideAYear() {
        val day = vm().day
        assertEquals(listOf(1, 3), day.years.map { it.yearsAgo })
        assertEquals(listOf("p-2023a", "p-2023b", "p-2023c"), day.years[1].photos.map { it.postId })
        assertEquals(0, day.index)
        assertEquals(0.5f, day.progress)
        // Display + thumb renditions signed; poster's first name and avatar for the meta row.
        val single = day.years[0].photos.single()
        assertEquals("https://signed.test/u/u-ana/m-p-2025/r/display.jpg", single.displayUrl)
        assertEquals("Ana", single.authorName)
        assertEquals(0.75f, single.aspectRatio)
    }

    @Test fun asksForTheGroupLocalDateMinusTheDayBoundary() {
        val backend = Scenario.backend()
        // 03:30 in Paris on Dec 6 is still Dec 5 (boundary 5 h, layout.onthisday.dayBoundary).
        val clock = Clock.fixed(Instant.parse("2026-12-06T02:30:00Z"), ZoneOffset.UTC)
        OnThisDayViewModel(FakeMemoryBackend.GROUP, backend, clock, MemoryCache())
        assertEquals(LocalDate.of(2026, 12, 5), backend.lastOnThisDayDate)
        assertEquals(LocalDate.of(2026, 12, 6), OnThisDayViewModel.localDate(Clock.fixed(Instant.parse("2026-12-06T04:30:00Z"), ZoneOffset.UTC), ZoneId.of("Europe/Paris")))
    }

    @Test fun tapThroughNextPreviousAndCloseOnTheOldestYear() {
        val vm = vm()
        vm.previous()
        assertEquals("left half on the newest year does nothing", 0, vm.day.index)
        vm.next()
        assertEquals(1, vm.day.index)
        assertEquals(1f, vm.day.progress)
        vm.previous()
        assertEquals(0, vm.day.index)
        vm.next()
        vm.next()
        assertEquals("right half on the oldest year closes the day", OnThisDayState.Finished, vm.state.value)
    }

    @Test fun deletedPhotoDropsPhotoThenYearThenDay() {
        val vm = vm()
        vm.next()
        vm.onPostDeleted("p-2023b")
        assertEquals(listOf("p-2023a", "p-2023c"), vm.day.year.photos.map { it.postId })
        vm.onPostDeleted("p-2025")
        assertEquals(listOf(3), vm.day.years.map { it.yearsAgo })
        assertEquals(0, vm.day.index)
        vm.onPostDeleted("p-2023a")
        vm.onPostDeleted("p-2023c")
        assertEquals(OnThisDayState.Finished, vm.state.value)
    }

    @Test fun deletionsArriveFromTheRealtimeBroadcast() {
        val backend = Scenario.backend()
        val vm = vm(backend)
        backend.deletions.tryEmit("p-2025")
        assertEquals(listOf(3), vm.day.years.map { it.yearsAgo })
    }

    @Test fun noRowsFinishesWithoutAScreen() {
        val backend = Scenario.backend().apply { onThisDay.clear() }
        assertEquals(OnThisDayState.Finished, vm(backend).state.value)
    }

    @Test fun blockedAuthorsAreNotShown() {
        val backend = Scenario.backend().apply { blocked += FakeMemoryBackend.BEN }
        assertEquals(listOf("p-2023b", "p-2023c"), vm(backend).day.years[1].photos.map { it.postId })
    }

    @Test fun offlineAndErrorStates() {
        val offline = Scenario.backend().apply { online = false }
        assertEquals(OnThisDayState.Failed(offline = true), vm(offline).state.value)
        val failing = Scenario.backend().apply { failNext["onThisDay"] = DataError.Unexpected("boom") }
        val vm = vm(failing)
        assertEquals(OnThisDayState.Failed(offline = false), vm.state.value)
        vm.retry()
        assertTrue(vm.state.value is OnThisDayState.Day)
    }

    @Test fun cachedDayPaintsFirstWithoutALoadingFlash() = runTest {
        val cache = MemoryCache()
        vm(Scenario.backend(), cache) // first visit fills the cache
        val backend = Scenario.backend().apply { gates["group"] = CompletableDeferred() }
        val vm = vm(backend, cache)
        val seen = mutableListOf<OnThisDayState>()
        val job = launch(UnconfinedTestDispatcher(testScheduler)) { vm.state.toList(seen) }
        assertTrue("cached content before the network answers", vm.state.value is OnThisDayState.Day)
        backend.gates.getValue("group").complete(Unit)
        job.cancel()
        assertTrue(seen.isNotEmpty())
        assertFalse("no loading or error state flashes", seen.any { it !is OnThisDayState.Day })
    }

    @Test fun offlineKeepsCachedContent() {
        val cache = MemoryCache()
        vm(Scenario.backend(), cache)
        val offline = Scenario.backend().apply { online = false }
        assertTrue(vm(offline, cache).state.value is OnThisDayState.Day)
    }

    @Test fun entryShowsTheNewestYearOrNothing() = runTest {
        assertEquals(1, newestYearsAgo(Scenario.backend(), FakeMemoryBackend.GROUP, Scenario.clock))
        assertEquals(null, newestYearsAgo(Scenario.backend().apply { onThisDay.clear() }, FakeMemoryBackend.GROUP, Scenario.clock))
        assertEquals(null, newestYearsAgo(Scenario.backend().apply { online = false }, FakeMemoryBackend.GROUP, Scenario.clock))
    }
}
