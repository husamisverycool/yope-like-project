package app.feature.memory.onthisday

import android.net.Uri
import app.data.error.DataError
import app.data.model.HiddenMemory
import app.designsystem.generated.Tokens
import app.feature.memory.FakeMemoryBackend
import app.feature.memory.FakeMemoryBackend.Companion.ME
import app.feature.memory.MainDispatcherRule
import app.feature.memory.Scenario
import app.feature.memory.common.MemoryCache
import app.feature.memory.common.MemoryEffect
import app.feature.memory.share.PhotoFiles
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.flow.toList
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import java.time.Clock
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZoneOffset
import kotlin.random.Random

/** Files that record what was saved and shared. */
class FakePhotoFiles(var ok: Boolean = true) : PhotoFiles {
    val saved = mutableListOf<String>()
    val shared = mutableListOf<String>()
    override suspend fun save(url: String, postId: String): Boolean = ok.also { if (it) saved += postId }
    override suspend fun shareUri(url: String, postId: String): Uri? = if (ok) Uri.parse("content://test/$postId").also { shared += postId } else null
}

@RunWith(RobolectricTestRunner::class)
class OnThisDayViewModelTest {
    @get:Rule val main = MainDispatcherRule()

    private fun vm(backend: FakeMemoryBackend = Scenario.backend(), files: PhotoFiles = FakePhotoFiles(), cache: MemoryCache = MemoryCache(), random: Random = Random(1)) =
        OnThisDayViewModel(FakeMemoryBackend.GROUP, backend, files, Scenario.clock, cache, random)

    private val OnThisDayViewModel.page get() = state.value as OnThisDayState.Page

    @Test fun oneMemoryPerPostNewestFirst() {
        val page = vm().page
        // API order (newest first) is the dial's order: slot 0 = the newest.
        assertEquals(listOf("p-2025", "p-2023a", "p-2023b", "p-2023c"), page.memories.map { it.postId })
        assertEquals(0, page.index)
        assertEquals(MemoryMode.Day, page.mode)
        assertEquals("Sunday Lunch", page.groupName)
        val first = page.memory
        assertEquals("Ana", first.authorName)
        assertEquals("https://signed.test/u/u-ana/m-p-2025/r/display.jpg", first.displayUrl)
        // The date title is the day it was posted, in the group's time zone (21:34 UTC = 22:34 in Paris).
        assertEquals(LocalDate.of(2025, 12, 5), first.date)
    }

    /** "Then & now" (owner decision 34, research #13): Reply answers the memory on screen, anyone's, and stops playing. */
    @Test fun replyNamesTheMemoryOnScreenAndStopsPlaying() {
        val vm = vm()
        vm.togglePlay()
        assertTrue(vm.page.playing)
        assertEquals("p-2025", vm.replyTarget())
        assertFalse(vm.page.playing)
        vm.step(+1)
        assertEquals("p-2023a", vm.replyTarget())
        val loading = OnThisDayViewModel(FakeMemoryBackend.GROUP, Scenario.backend().apply { online = false }, FakePhotoFiles(), Scenario.clock, MemoryCache())
        assertNull("no memory on screen: nothing to reply to", loading.replyTarget())
    }

    @Test fun asksForTheGroupLocalDateMinusTheDayBoundary() {
        val backend = Scenario.backend()
        // 03:30 in Paris on Dec 6 is still Dec 5 (boundary 5 h, layout.onthisday.dayBoundary).
        val clock = Clock.fixed(Instant.parse("2026-12-06T02:30:00Z"), ZoneOffset.UTC)
        OnThisDayViewModel(FakeMemoryBackend.GROUP, backend, FakePhotoFiles(), clock, MemoryCache())
        assertEquals(LocalDate.of(2026, 12, 5), backend.lastOnThisDayDate)
        assertEquals(LocalDate.of(2026, 12, 6), OnThisDayViewModel.localDate(Clock.fixed(Instant.parse("2026-12-06T04:30:00Z"), ZoneOffset.UTC), ZoneId.of("Europe/Paris")))
    }

    @Test fun dialStepsStopAtBothEnds() {
        val vm = vm()
        vm.step(-1)
        assertEquals("no wrap before the first", 0, vm.page.index)
        vm.step(+1)
        vm.step(+1)
        assertEquals(2, vm.page.index)
        repeat(10) { vm.step(+1) }
        assertEquals("no wrap after the last", 3, vm.page.index)
        vm.step(-1)
        assertEquals(2, vm.page.index)
    }

    @Test fun playingAdvancesAndStopsAfterTheLastMemory() {
        val vm = vm()
        vm.togglePlay()
        assertTrue(vm.page.playing)
        vm.advance()
        vm.advance()
        vm.advance()
        assertEquals(3, vm.page.index)
        vm.advance()
        assertFalse("stops after the last memory", vm.page.playing)
        assertEquals(3, vm.page.index)
        vm.togglePlay()
        assertEquals("playing again from the last starts at the first", 0, vm.page.index)
        vm.togglePlay()
        assertFalse(vm.page.playing)
        vm.advance()
        assertEquals("paused: no automatic step", 0, vm.page.index)
    }

    @Test fun diceShowsRandomMemoriesFromTheHistoryAndStepsThroughFurtherPicks() {
        val backend = Scenario.backend()
        val vm = vm(backend)
        vm.shuffle()
        val first = vm.page
        assertEquals(MemoryMode.Shuffle, first.mode)
        assertEquals(1, first.memories.size)
        assertTrue(first.memory.postId in listOf("p-mine1", "p-tagged", "p-other"))
        vm.step(+1)
        assertEquals("a step past the last pick picks again", 2, vm.page.memories.size)
        assertEquals(1, vm.page.index)
        assertTrue("a new pick while others exist", vm.page.memories.map { it.postId }.distinct().size == 2)
        vm.step(-1)
        assertEquals("previous = back through the picks", first.memory.postId, vm.page.memory.postId)
        assertEquals(1, backend.calls.count { it == "historyWeeks" })
    }

    @Test fun modeMenuGoesBackFromShuffleToTheDay() {
        val vm = vm(Scenario.backend())
        vm.step(+1)
        vm.showDay()
        assertEquals("already the day: nothing changes", 1, vm.page.index)
        vm.shuffle()
        assertEquals(MemoryMode.Shuffle, vm.page.mode)
        vm.step(+1)
        vm.togglePlay()
        vm.showDay()
        assertEquals(MemoryMode.Day, vm.page.mode)
        assertEquals("back at the newest memory of the day", 0, vm.page.index)
        assertEquals(listOf("p-2025", "p-2023a", "p-2023b", "p-2023c"), vm.page.memories.map { it.postId })
        assertFalse(vm.page.playing)
    }

    @Test fun menuSaveShareAndDeleteYourOwnMemory() = runTest {
        val backend = Scenario.backend()
        val files = FakePhotoFiles()
        val vm = vm(backend, files)
        val events = mutableListOf<OnThisDayEvent>()
        val effects = mutableListOf<MemoryEffect>()
        val a = launch(UnconfinedTestDispatcher(testScheduler)) { vm.requests.toList(events) }
        val b = launch(UnconfinedTestDispatcher(testScheduler)) { vm.effects.toList(effects) }
        // Owner decision 28: any memory saves to your own library. Decision 12: only your own is shared out of the app.
        assertFalse("Ana's memory: Save and Report Post", vm.isMine(vm.page.memory))
        val anas = vm.page.memory.postId
        vm.save()
        vm.share()
        assertEquals(listOf(anas), files.saved)
        assertTrue(files.shared.isEmpty())
        repeat(3) { vm.step(+1) }
        assertTrue("your own memory: Save, Delete Post and the share circle", vm.isMine(vm.page.memory))
        vm.save()
        assertEquals(listOf(anas, "p-2023c"), files.saved)
        vm.share()
        assertEquals(listOf("p-2023c"), files.shared)
        files.ok = false
        vm.save()
        vm.save(accessGranted = false)
        vm.delete()
        assertEquals(listOf("p-2023c"), backend.deletedPosts)
        assertEquals("the memory leaves the dial", listOf("p-2025", "p-2023a", "p-2023b"), vm.page.memories.map { it.postId })
        assertEquals(2, vm.page.index)
        a.cancel()
        b.cancel()
        assertEquals(
            listOf(
                OnThisDayEvent.Toast(OnThisDayEvent.Toast.Kind.Saved),
                OnThisDayEvent.Toast(OnThisDayEvent.Toast.Kind.Saved),
                OnThisDayEvent.Share(Uri.parse("content://test/p-2023c")),
                OnThisDayEvent.Toast(OnThisDayEvent.Toast.Kind.SaveFailed),
                OnThisDayEvent.SaveDenied,
                OnThisDayEvent.Toast(OnThisDayEvent.Toast.Kind.Deleted),
            ),
            events,
        )
        assertEquals(
            listOf(Tokens.Haptics.globalSuccess, Tokens.Haptics.globalSuccess, Tokens.Haptics.globalError, Tokens.Haptics.globalError, Tokens.Haptics.globalWarning),
            effects.map { (it as MemoryEffect.Haptic).constant },
        )
    }

    /** Owner decision 34 (research #12): "Hide Photo" on any memory, for you only; it leaves the dial at once, as a deletion does. */
    @Test fun hidePhotoTakesItOffTheDialAtOnce() = runTest {
        val backend = Scenario.backend()
        val vm = vm(backend)
        val events = mutableListOf<OnThisDayEvent>()
        val effects = mutableListOf<MemoryEffect>()
        val a = launch(UnconfinedTestDispatcher(testScheduler)) { vm.requests.toList(events) }
        val b = launch(UnconfinedTestDispatcher(testScheduler)) { vm.effects.toList(effects) }
        vm.step(+1)
        assertFalse("Ben's photo: someone else's memory hides too", vm.isMine(vm.page.memory))
        vm.hidePhoto()
        assertEquals("hide_memory(p_media_id)", listOf("m-p-2023a"), backend.hides.map { it.mediaId })
        assertEquals(listOf("p-2025", "p-2023b", "p-2023c"), vm.page.memories.map { it.postId })
        assertEquals("the next memory shows", "p-2023b", vm.page.memory.postId)
        assertTrue("the photo stays in the group", backend.deletedPosts.isEmpty())
        // The next read of the day leaves it out too (on_this_day skips your hidden photos).
        assertEquals(listOf("p-2025", "p-2023b", "p-2023c"), vm(backend).page.memories.map { it.postId })
        a.cancel()
        b.cancel()
        assertEquals(listOf(OnThisDayEvent.Toast(OnThisDayEvent.Toast.Kind.Hidden)), events)
        assertEquals(listOf(Tokens.Haptics.globalSuccess), effects.map { (it as MemoryEffect.Haptic).constant })
    }

    /** "Hide This Day" (Timehop "Hide your bad memories"): every memory of that calendar day (group time zone) leaves. */
    @Test fun hideThisDayTakesEveryMemoryOfThatDay() {
        val backend = Scenario.backend()
        val vm = vm(backend)
        vm.step(+1)
        vm.hideDay()
        assertEquals("hide_memory(p_day), the day in Paris", listOf(LocalDate.of(2023, 12, 5)), backend.hides.map { it.day })
        assertEquals(listOf("p-2025"), vm.page.memories.map { it.postId })
        assertEquals("p-2025", vm.page.memory.postId)
        vm.hideDay()
        assertEquals("nothing left: the empty block", OnThisDayState.Empty, vm.state.value)
    }

    @Test fun aFailedHideKeepsTheMemoryAndSaysSo() = runTest {
        val backend = Scenario.backend().apply { failNext["hideMemory"] = DataError.Network }
        val vm = vm(backend)
        val events = mutableListOf<OnThisDayEvent>()
        val effects = mutableListOf<MemoryEffect>()
        val a = launch(UnconfinedTestDispatcher(testScheduler)) { vm.requests.toList(events) }
        val b = launch(UnconfinedTestDispatcher(testScheduler)) { vm.effects.toList(effects) }
        vm.hidePhoto()
        assertEquals(4, vm.page.memories.size)
        assertEquals("p-2025", vm.page.memory.postId)
        a.cancel()
        b.cancel()
        assertEquals(listOf(OnThisDayEvent.Toast(OnThisDayEvent.Toast.Kind.HideOffline)), events)
        assertEquals(listOf(Tokens.Haptics.globalError), effects.map { (it as MemoryEffect.Haptic).constant })
    }

    /** The dice never lands on a photo or a day you hid: picks are filtered with `my_hidden_memories`. */
    @Test fun diceLeavesOutHiddenPhotosAndDays() {
        val backend = Scenario.backend().apply {
            hides += HiddenMemory("h-1", mediaId = "m-p-mine1", createdAt = FakeMemoryBackend.NOW)
            // p-tagged was posted on Nov 12 (Paris).
            hides += HiddenMemory("h-2", day = LocalDate.of(2026, 11, 12), createdAt = FakeMemoryBackend.NOW)
        }
        val vm = vm(backend)
        vm.shuffle()
        assertEquals(MemoryMode.Shuffle, vm.page.mode)
        assertEquals("p-other", vm.page.memory.postId)
        vm.step(+1)
        assertTrue("only the photo you did not hide", vm.page.memories.all { it.postId == "p-other" })
        assertEquals(1, backend.calls.count { it == "hiddenMemories" })
    }

    @Test fun deletedMemoriesLeaveTheDialThenTheEmptyBlock() {
        val backend = Scenario.backend()
        val vm = vm(backend)
        vm.step(+1)
        backend.deletions.tryEmit("p-2023a")
        assertEquals("the shown memory went: the next one shows", "p-2023b", vm.page.memory.postId)
        backend.deletions.tryEmit("p-2025")
        assertEquals("p-2023b", vm.page.memory.postId)
        assertEquals(0, vm.page.index)
        backend.deletions.tryEmit("p-2023b")
        backend.deletions.tryEmit("p-2023c")
        assertEquals(OnThisDayState.Empty, vm.state.value)
    }

    @Test fun noRowsFinishesWithoutAPage() {
        val backend = Scenario.backend().apply { onThisDay.clear() }
        assertEquals(OnThisDayState.Finished, vm(backend).state.value)
    }

    @Test fun blockedAuthorsAreNotShown() {
        val backend = Scenario.backend().apply { blocked += FakeMemoryBackend.ANA }
        assertEquals(listOf("p-2023a", "p-2023c"), vm(backend).page.memories.map { it.postId })
    }

    @Test fun offlineAndErrorStates() {
        assertEquals(OnThisDayState.Failed(offline = true), vm(Scenario.backend().apply { online = false }).state.value)
        val failing = Scenario.backend().apply { failNext["group"] = DataError.Unexpected("x") }
        val vm = vm(failing)
        assertEquals(OnThisDayState.Failed(offline = false), vm.state.value)
        vm.retry()
        assertTrue(vm.state.value is OnThisDayState.Page)
    }

    @Test fun cachedDayPaintsFirstWithoutALoadingFlash() = runTest {
        val cache = MemoryCache()
        vm(cache = cache)
        val backend = Scenario.backend().apply { gates["onThisDay"] = CompletableDeferred() }
        val vm = vm(backend, cache = cache)
        val seen = mutableListOf<OnThisDayState>()
        val job = launch(UnconfinedTestDispatcher(testScheduler)) { vm.state.collect { seen += it } }
        backend.gates.getValue("onThisDay").complete(Unit)
        job.cancel()
        assertTrue(seen.all { it is OnThisDayState.Page })
    }

    @Test fun entryShowsTodaysDateOrNothing() = runTest {
        assertEquals(LocalDate.of(2026, 12, 5), entryDate(Scenario.backend(), FakeMemoryBackend.GROUP, Scenario.clock))
        assertNull(entryDate(Scenario.backend().apply { onThisDay.clear() }, FakeMemoryBackend.GROUP, Scenario.clock))
        assertNull(entryDate(Scenario.backend().apply { online = false }, FakeMemoryBackend.GROUP, Scenario.clock))
    }

    @Test fun reportIsForSomeoneElsesMemory() {
        val vm = vm()
        assertFalse(vm.isMine(vm.page.memory))
        assertEquals(ME, Scenario.backend().posts.getValue("p-2023c").authorId)
    }
}
