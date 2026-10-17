package app.feature.account

import androidx.test.ext.junit.runners.AndroidJUnit4
import app.data.error.DataError
import app.data.model.HiddenMemory
import app.designsystem.generated.Tokens
import app.feature.account.settings.HiddenRow
import app.feature.account.settings.SettingsHiddenViewModel
import app.feature.account.testing.FakeAccountBackend
import app.feature.account.testing.fakeEnvironment
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

/** settings.hidden (owner decision 34, research #12; `my_hidden_memories` / `unhide_memory`, migration 0038). */
@RunWith(AndroidJUnit4::class)
class HiddenMemoriesTest {
    @get:Rule val main = MainDispatcherRule()

    private val paris: ZoneId = ZoneId.of("Europe/Paris")

    private fun world() = FakeAccountBackend().apply {
        signIn()
        profile(meId, "Ana Lima")
        // Newest hide first: a whole day, then one photo (posted at 23:30 UTC = 00:30 the next day in Paris).
        hiddenRows += HiddenMemory("h-2", day = LocalDate.of(2023, 12, 5), createdAt = now)
        hiddenRows += HiddenMemory(
            "h-1", mediaId = "m-1", createdAt = now.minusSeconds(60), postId = "p-1", groupId = "g1",
            thumbPath = "u/u-sam/m-1/r/thumb.jpg", takenAt = Instant.parse("2022-07-21T23:30:00Z"),
        )
    }

    @Test fun listsHiddenDaysAndPhotosNewestFirst() = runTest(main.dispatcher) {
        val vm = SettingsHiddenViewModel(fakeEnvironment(world()), paris)
        val rows = vm.state.value.rows!!
        assertEquals(listOf("h-2", "h-1"), rows.map { it.id })
        assertEquals(HiddenRow("h-2", LocalDate.of(2023, 12, 5), isDay = true), rows[0])
        assertFalse(rows[1].isDay)
        assertEquals("the day it was posted, in this device's zone", LocalDate.of(2022, 7, 22), rows[1].date)
        assertNull("an unsigned thumbnail keeps the placeholder", rows[1].thumbnailUrl)
    }

    @Test fun unhideRemovesTheRowAndAFailureBringsItBack() = runTest(main.dispatcher) {
        val backend = world()
        val vm = SettingsHiddenViewModel(fakeEnvironment(backend), paris)
        val events = vm.recordEvents(backgroundScope)
        val photo = vm.state.value.rows!![1]

        backend.failures["unhideMemory"] = DataError.Network
        vm.unhide(photo)
        assertEquals(listOf("h-2", "h-1"), vm.state.value.rows!!.map { it.id })
        assertTrue("the message-only alert", vm.state.value.unhideFailed)
        vm.dismissError()
        assertFalse(vm.state.value.unhideFailed)

        backend.failures.clear()
        vm.unhide(photo)
        assertEquals(listOf("h-2"), vm.state.value.rows!!.map { it.id })
        assertEquals(listOf("h-2"), backend.hiddenRows.map { it.id })
        assertEquals(listOf(Tokens.Haptics.globalError, Tokens.Haptics.globalSuccess), events.haptics())
        assertTrue("no toast: the row fading out is the confirmation", events.toasts().isEmpty())
    }

    @Test fun emptyErrorAndRetry() = runTest(main.dispatcher) {
        val empty = FakeAccountBackend().apply { signIn() }
        assertEquals(emptyList<HiddenRow>(), SettingsHiddenViewModel(fakeEnvironment(empty), paris).state.value.rows)

        val failing = world().apply { failures["hiddenMemories"] = DataError.Network }
        val vm = SettingsHiddenViewModel(fakeEnvironment(failing), paris)
        assertNull(vm.state.value.rows)
        assertTrue("error and offline: Retro's one tappable line", vm.state.value.error)
        failing.failures.clear()
        vm.load()
        assertFalse(vm.state.value.error)
        assertEquals(2, vm.state.value.rows!!.size)
    }
}
