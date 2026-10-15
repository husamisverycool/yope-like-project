package app.feature.memory.birthday

import app.data.error.ApiError
import app.data.error.DataError
import app.designsystem.generated.Tokens
import app.feature.memory.FakeMemoryBackend
import app.feature.memory.FakeMemoryBackend.Companion.ANA
import app.feature.memory.FakeMemoryBackend.Companion.ME
import app.feature.memory.MainDispatcherRule
import app.feature.memory.Rows
import app.feature.memory.Scenario
import app.feature.memory.common.MemoryCache
import app.feature.memory.common.MemoryEffect
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
import java.time.Clock
import java.time.Instant
import java.time.ZoneOffset

class BirthdayRequestViewModelTest {
    @get:Rule val main = MainDispatcherRule()

    private fun vm(requestId: String = "r-1", backend: FakeMemoryBackend = Scenario.backend(), clock: Clock = Scenario.clock, cache: MemoryCache = MemoryCache()) =
        BirthdayRequestViewModel(FakeMemoryBackend.GROUP, requestId, backend, clock, cache)

    private val BirthdayRequestViewModel.ready get() = state.value.request as RequestState.Ready
    private val BirthdayRequestViewModel.contribute get() = state.value.contribute

    @Test fun showsTheRequestForAnotherMember() {
        val ready = vm().ready
        assertEquals("Ana", ready.info.honoreeName)
        assertEquals("Sunday Lunch", ready.info.groupName)
        assertNull("nobody has contributed yet; there is no 'you haven't contributed' state", ready.contribution)
        assertFalse(ready.closed)
    }

    @Test fun honoreeNeverSeesTheirRequest() {
        // RLS hides it (request_not_found).
        assertEquals(RequestState.NotFound, vm("r-mine").state.value.request)
        // Even if a row leaked through, the screen refuses to show it to the honoree.
        val leaky = object : app.feature.memory.common.MemoryBackend by Scenario.backend() {
            override suspend fun request(requestId: String) = Rows.request("r-mine", ME)
        }
        val vm = BirthdayRequestViewModel(FakeMemoryBackend.GROUP, "r-mine", leaky, Scenario.clock, MemoryCache())
        assertEquals(RequestState.NotFound, vm.state.value.request)
    }

    @Test fun honoreeGetsNoEntryRow() = runTest {
        val entries = openRequestEntries(Scenario.backend(), FakeMemoryBackend.GROUP, Scenario.clock)!!
        assertEquals(listOf("r-1"), entries.map { it.requestId })
        assertEquals("Ana", entries.single().honoreeName)
    }

    @Test fun eligiblePhotosAreMineOrSelfTaggedNewestFirst() {
        val vm = vm()
        vm.startContribution()
        assertEquals(RequestPage.Photo, vm.state.value.page)
        val photos = (vm.contribute.photos as PhotosState.Loaded).photos.map { it.postId }
        assertTrue(photos.containsAll(listOf("p-mine1", "p-mine2", "p-tagged")))
        assertFalse("someone else's photo I'm not in", "p-other" in photos)
        assertEquals("newest first", "p-mine1", photos.first())
    }

    @Test fun contributeFlowIsOptimisticAndTrimsTheLine() = runTest {
        val backend = Scenario.backend().apply { gates["contribute"] = CompletableDeferred() }
        val vm = vm(backend = backend)
        val effects = mutableListOf<MemoryEffect>()
        val job = launch(UnconfinedTestDispatcher(testScheduler)) { vm.effects.toList(effects) }
        vm.startContribution()
        vm.usePhoto()
        assertEquals("nothing selected yet", RequestPage.Photo, vm.state.value.page)
        vm.select("p-tagged")
        vm.usePhoto()
        assertEquals(RequestPage.Message, vm.state.value.page)
        assertFalse("no line yet", vm.contribute.canSubmit)
        vm.setLine("  you make every Sunday better  ")
        vm.submit()
        // Optimistic: step 3 and the own block before the server answers.
        assertEquals(RequestPage.Done, vm.state.value.page)
        assertEquals("p-tagged", vm.ready.contribution?.postId)
        assertEquals("you make every Sunday better", vm.ready.contribution?.line)
        backend.gates.getValue("contribute").complete(Unit)
        assertEquals("you make every Sunday better", backend.lastContributedLine)
        vm.done()
        assertEquals(RequestPage.Request, vm.state.value.page)
        assertEquals("p-tagged", vm.ready.contribution?.postId)
        job.cancel()
        assertEquals(
            listOf(MemoryEffect.Haptic(Tokens.Haptics.globalSelect), MemoryEffect.Haptic(Tokens.Haptics.globalSend)),
            effects,
        )
    }

    @Test fun notEligibleRollsBackToStepOne() {
        val backend = Scenario.backend().apply { failNext["contribute"] = FakeMemoryBackend.api(ApiError.PostNotEligible) }
        val vm = vm(backend = backend)
        vm.startContribution()
        vm.select("p-mine1")
        vm.usePhoto()
        vm.setLine("hi")
        vm.submit()
        assertEquals(RequestPage.Photo, vm.state.value.page)
        assertEquals(ContributeState.Inline.NotEligible, vm.contribute.inline)
        assertNull("optimistic contribution rolled back", vm.ready.contribution)
    }

    @Test fun errorAndOfflineStayOnTheMessageStep() {
        val backend = Scenario.backend().apply { failNext["contribute"] = DataError.Unexpected("500") }
        val vm = vm(backend = backend)
        vm.startContribution()
        vm.select("p-mine1")
        vm.usePhoto()
        vm.setLine("hi")
        vm.submit()
        assertEquals(RequestPage.Message, vm.state.value.page)
        assertEquals(ContributeState.Inline.Error, vm.contribute.inline)
        backend.online = false
        vm.submit()
        assertEquals(ContributeState.Inline.Offline, vm.contribute.inline)
        backend.online = true
        vm.submit()
        assertEquals(RequestPage.Done, vm.state.value.page)
    }

    @Test fun closedWhileContributing() {
        val backend = Scenario.backend().apply { failNext["contribute"] = FakeMemoryBackend.api(ApiError.TributeClosed) }
        val vm = vm(backend = backend)
        vm.startContribution()
        vm.select("p-mine1")
        vm.usePhoto()
        vm.setLine("hi")
        vm.submit()
        assertTrue(vm.contribute.closed)
        assertTrue(vm.ready.closed)
    }

    @Test fun requestPastItsDueTimeIsClosed() {
        val late = Clock.fixed(Instant.parse("2026-12-12T09:00:00Z"), ZoneOffset.UTC)
        assertTrue(vm(clock = late).ready.closed)
    }

    @Test fun withdrawIsOptimisticAndRollsBack() {
        val backend = Scenario.backend()
        backend.contributions["c-1"] = app.data.model.TributeContribution("c-1", "r-1", ME, "p-mine1", "hi", Scenario.at("2026-12-01T00:00:00Z"), Scenario.at("2026-12-01T00:00:00Z"))
        val vm = vm(backend = backend)
        assertEquals("p-mine1", vm.ready.contribution?.postId)
        backend.gates["withdraw"] = CompletableDeferred()
        vm.withdraw()
        assertNull("removed at once", vm.ready.contribution)
        backend.failNext["withdraw"] = DataError.Unexpected("500")
        backend.gates.getValue("withdraw").complete(Unit)
        assertEquals("rolled back", "p-mine1", vm.ready.contribution?.postId)
        vm.withdraw()
        assertNull(vm.ready.contribution)
        assertTrue(backend.contributions.isEmpty())
    }

    @Test fun lineIsCappedAtTheApiBound() {
        val vm = vm()
        vm.setLine("x".repeat(400))
        assertEquals(BirthdayRequestViewModel.LINE_API_BOUND, vm.contribute.line.length)
    }

    @Test fun deletedChosenPhotoSendsYouBackToStepOne() {
        val backend = Scenario.backend()
        val vm = vm(backend = backend)
        vm.startContribution()
        vm.select("p-mine2")
        vm.usePhoto()
        backend.deletions.tryEmit("p-mine2")
        assertEquals(RequestPage.Photo, vm.state.value.page)
        assertNull(vm.contribute.selected)
        assertFalse((vm.contribute.photos as PhotosState.Loaded).photos.any { it.postId == "p-mine2" })
    }

    @Test fun backWalksThePagesThenCloses() = runTest {
        val vm = vm()
        val effects = mutableListOf<MemoryEffect>()
        val job = launch(UnconfinedTestDispatcher(testScheduler)) { vm.effects.toList(effects) }
        vm.startContribution()
        vm.select("p-mine1")
        vm.usePhoto()
        vm.back()
        assertEquals(RequestPage.Photo, vm.state.value.page)
        vm.back()
        assertEquals(RequestPage.Request, vm.state.value.page)
        vm.back()
        job.cancel()
        assertTrue(MemoryEffect.Close in effects)
    }

    @Test fun offlineNotFoundAndErrorStates() {
        assertEquals(RequestState.Offline, vm(backend = Scenario.backend().apply { online = false }).state.value.request)
        assertEquals(RequestState.NotFound, vm("r-gone").state.value.request)
        assertEquals(RequestState.Failed, vm(backend = Scenario.backend().apply { failNext["request"] = DataError.Unexpected("x") }).state.value.request)
        assertEquals(RequestState.NotFound, vm(backend = Scenario.backend().apply { blocked += ANA }).state.value.request)
    }

    @Test fun cachedRequestPaintsFirstWithoutALoadingFlash() = runTest {
        val cache = MemoryCache()
        vm(cache = cache)
        val backend = Scenario.backend().apply { gates["request"] = CompletableDeferred() }
        val vm = vm(backend = backend, cache = cache)
        val seen = mutableListOf<RequestState>()
        val collect = launch(UnconfinedTestDispatcher(testScheduler)) { vm.state.collect { seen += it.request } }
        assertTrue(vm.state.value.request is RequestState.Ready)
        backend.gates.getValue("request").complete(Unit)
        collect.cancel()
        assertFalse(seen.any { it !is RequestState.Ready })
    }
}
