package app.feature.memory.birthday

import android.net.Uri
import app.data.error.ApiError
import app.data.error.DataError
import app.data.model.ProfilePrivate
import app.data.model.RenderStatus
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
import java.time.LocalDate

class TributeViewModelTest {
    @get:Rule val main = MainDispatcherRule()

    private class Files(var ok: Boolean = true) : TributeFiles {
        val saved = mutableListOf<String>()
        override suspend fun save(url: String, tributeId: String): Boolean = ok.also { if (it) saved += url }
        override suspend fun shareUri(url: String, tributeId: String): Uri? = null
    }

    private fun vm(backend: FakeMemoryBackend, files: TributeFiles = Files(), cache: MemoryCache = MemoryCache()) =
        TributeViewModel("t-1", backend, files, Scenario.clock, cache)

    @Test fun honoreeSeesTheTributeOnlyAfterDelivery() {
        val before = Scenario.backend().apply { tributes["t-1"] = Rows.tribute(honoree = ME, delivered = null) }
        assertEquals(TributeContent.NotFound, vm(before).state.value.content)
        val scheduled = Scenario.backend().apply { tributes["t-1"] = Rows.tribute(honoree = ME, delivered = Scenario.at("2026-12-06T00:00:00Z")) }
        assertEquals("delivered_at in the future", TributeContent.NotFound, vm(scheduled).state.value.content)
        val after = Scenario.backend().apply { tributes["t-1"] = Rows.tribute(honoree = ME, delivered = Scenario.at("2026-12-05T08:00:00Z")) }
        val ready = vm(after).state.value
        assertEquals(TributeContent.Ready("https://signed.test/g/g-1/tributes/t-1/video.mp4", "https://signed.test/g/g-1/tributes/t-1/poster.jpg"), ready.content)
        assertEquals("Sunday Lunch", ready.groupName)
        assertTrue("the honoree's title is \"Your birthday video\"", ready.forMe)
    }

    @Test fun membersSeeTheHonoreesName() {
        val member = Scenario.backend().apply { tributes["t-1"] = Rows.tribute(honoree = ANA, delivered = null) }
        val state = vm(member).state.value
        assertFalse(state.forMe)
        assertEquals("Ana", state.honoreeName)
    }

    @Test fun otherMembersSeeItAnyTimeUnlessBlockedWithTheHonoree() {
        val member = Scenario.backend().apply { tributes["t-1"] = Rows.tribute(honoree = ANA, delivered = null) }
        assertTrue(vm(member).state.value.content is TributeContent.Ready)
        val blocked = Scenario.backend().apply {
            tributes["t-1"] = Rows.tribute(honoree = ANA, delivered = null)
            this.blocked += ANA
        }
        assertEquals(TributeContent.NotFound, vm(blocked).state.value.content)
    }

    @Test fun renderingOfflineAndErrorStates() {
        val pending = Scenario.backend().apply { tributes["t-1"] = Rows.tribute(honoree = ANA, delivered = null, status = RenderStatus.Pending) }
        val vm = vm(pending)
        assertEquals(TributeContent.Rendering, vm.state.value.content)
        pending.tributes["t-1"] = Rows.tribute(honoree = ANA, delivered = null)
        vm.refreshIfRendering()
        assertTrue(vm.state.value.content is TributeContent.Ready)
        assertEquals(TributeContent.Offline, vm(Scenario.backend().apply { online = false }).state.value.content)
        val failing = Scenario.backend().apply {
            tributes["t-1"] = Rows.tribute(honoree = ANA, delivered = null)
            failNext["tribute"] = DataError.Unexpected("x")
        }
        assertEquals(TributeContent.Failed, vm(failing).state.value.content)
    }

    @Test fun downloadSucceedsOrFailsWithToastAndHaptic() = runTest {
        val backend = Scenario.backend().apply { tributes["t-1"] = Rows.tribute(honoree = ANA, delivered = null) }
        val files = Files()
        val vm = vm(backend, files)
        val effects = mutableListOf<MemoryEffect>()
        val job = launch(UnconfinedTestDispatcher(testScheduler)) { vm.effects.toList(effects) }
        vm.save()
        assertEquals(TributeState.Toast.Saved, vm.state.value.toast)
        assertEquals(1, files.saved.size)
        files.ok = false
        vm.save()
        assertEquals(TributeState.Toast.SaveFailed, vm.state.value.toast)
        vm.save(accessGranted = false)
        assertTrue("photo access refused: the alert with a Settings button", vm.state.value.saveDenied)
        vm.dismissSaveDenied()
        assertFalse(vm.state.value.saveDenied)
        job.cancel()
        assertEquals(
            listOf(Tokens.Haptics.globalSuccess, Tokens.Haptics.globalError, Tokens.Haptics.globalError),
            effects.map { (it as MemoryEffect.Haptic).constant },
        )
    }

    @Test fun cachedTributeShowsWithoutALoadingFlash() = runTest {
        val cache = MemoryCache()
        vm(Scenario.backend().apply { tributes["t-1"] = Rows.tribute(honoree = ANA, delivered = null) }, cache = cache)
        val backend = Scenario.backend().apply {
            tributes["t-1"] = Rows.tribute(honoree = ANA, delivered = null)
            gates["tribute"] = CompletableDeferred()
        }
        val vm = vm(backend, cache = cache)
        val seen = mutableListOf<TributeContent>()
        val job = launch(UnconfinedTestDispatcher(testScheduler)) { vm.state.collect { seen += it.content } }
        backend.gates.getValue("tribute").complete(Unit)
        job.cancel()
        assertTrue(seen.all { it is TributeContent.Ready })
    }
}

class BirthdayAddViewModelTest {
    @get:Rule val main = MainDispatcherRule()

    private val pattern = DateEntryPattern(listOf('M', 'd', 'y'), '/')

    private fun vm(backend: FakeMemoryBackend = Scenario.backend(), cache: MemoryCache = MemoryCache()) = BirthdayAddViewModel(backend, pattern, cache)

    @Test fun notOptedInShowsTheAddForm() {
        val vm = vm()
        assertFalse(vm.state.value.loading)
        assertFalse(vm.state.value.optedIn)
    }

    @Test fun optedInShowsManageWithDayAndMonth() {
        val backend = Scenario.backend().apply { privateRow = ProfilePrivate(ME, LocalDate.of(1999, 5, 26), true, null, FakeMemoryBackend.NOW) }
        assertEquals(LocalDate.of(1999, 5, 26), vm(backend).state.value.saved)
    }

    @Test fun addEnablesOnlyWithACompleteRealDateThenSavesAndFinishes() = runTest {
        val backend = Scenario.backend()
        val vm = vm(backend)
        val effects = mutableListOf<MemoryEffect>()
        val job = launch(UnconfinedTestDispatcher(testScheduler)) { vm.effects.toList(effects) }
        vm.setDigits("0526")
        assertNull(vm.enteredDate)
        vm.add()
        assertFalse("no call without a complete date", "setBirthday" in backend.calls)
        vm.setDigits("13451999")
        assertEquals(BirthdayAddState.Inline.Invalid, vm.state.value.inline)
        vm.setDigits("05261999")
        assertEquals(LocalDate.of(1999, 5, 26), vm.enteredDate)
        vm.add()
        assertEquals(LocalDate.of(1999, 5, 26), backend.privateRow?.birthday)
        assertTrue(vm.state.value.finished)
        assertEquals(BirthdayAddState.Toast.Added, vm.state.value.toast)
        job.cancel()
        assertEquals(listOf(MemoryEffect.Haptic(Tokens.Haptics.globalSuccess)), effects)
    }

    @Test fun serverInvalidOfflineAndErrorStates() {
        val backend = Scenario.backend()
        val vm = vm(backend)
        vm.setDigits("05261999")
        backend.failNext["setBirthday"] = FakeMemoryBackend.api(ApiError.InvalidBirthday)
        vm.add()
        assertEquals(BirthdayAddState.Inline.Invalid, vm.state.value.inline)
        backend.online = false
        vm.add()
        assertEquals(BirthdayAddState.Inline.Offline, vm.state.value.inline)
        backend.online = true
        backend.failNext["setBirthday"] = DataError.Unexpected("x")
        vm.add()
        assertTrue("error block; the primary becomes try again", vm.state.value.error)
        vm.add()
        assertTrue(vm.state.value.finished)
    }

    @Test fun removeIsOptimisticAndRollsBack() {
        val backend = Scenario.backend().apply { privateRow = ProfilePrivate(ME, LocalDate.of(1999, 5, 26), true, null, FakeMemoryBackend.NOW) }
        val vm = vm(backend)
        assertTrue(vm.state.value.optedIn)
        backend.gates["setBirthday"] = CompletableDeferred()
        vm.remove()
        assertFalse("add form at once", vm.state.value.optedIn)
        backend.failNext["setBirthday"] = DataError.Unexpected("x")
        backend.gates.getValue("setBirthday").complete(Unit)
        assertEquals(LocalDate.of(1999, 5, 26), vm.state.value.saved)
        assertTrue(vm.state.value.error)
        vm.remove()
        assertFalse(vm.state.value.optedIn)
        assertEquals(false, backend.privateRow?.birthdayOptIn)
        assertEquals(BirthdayAddState.Toast.Removed, vm.state.value.toast)
    }

    @Test fun maybeLaterMakesNoCall() = runTest {
        val backend = Scenario.backend()
        val vm = vm(backend)
        val effects = mutableListOf<MemoryEffect>()
        val job = launch(UnconfinedTestDispatcher(testScheduler)) { vm.effects.toList(effects) }
        vm.later()
        job.cancel()
        assertEquals(listOf(MemoryEffect.Close), effects)
        assertFalse("setBirthday" in backend.calls)
    }

    @Test fun cachedOptInSkipsTheLoadingState() {
        val cache = MemoryCache()
        vm(cache = cache)
        val backend = Scenario.backend().apply { gates["privateProfile"] = CompletableDeferred() }
        assertFalse(vm(backend, cache).state.value.loading)
    }
}
