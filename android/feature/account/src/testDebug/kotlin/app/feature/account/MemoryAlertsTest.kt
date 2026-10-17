package app.feature.account

import androidx.test.ext.junit.runners.AndroidJUnit4
import app.data.error.DataError
import app.data.model.NotificationSettings
import app.feature.account.settings.SettingsNotificationsViewModel
import app.feature.account.testing.FakeAccountBackend
import app.feature.account.testing.fakeEnvironment
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/** "Memories" in settings.notifications: the opt-in memory notification (`set_memory_alerts`, migration 0049). */
@RunWith(AndroidJUnit4::class)
class MemoryAlertsTest {
    @get:Rule val main = MainDispatcherRule()

    private fun world() = FakeAccountBackend().apply {
        signIn()
        profile(meId, "Ana Lima")
    }

    @Test fun offByDefaultOnSendsTheDeviceZoneAndAFailureReverts() = runTest(main.dispatcher) {
        val backend = world()
        val env = fakeEnvironment(backend)
        val vm = SettingsNotificationsViewModel(env)
        assertFalse(vm.state.value.memoriesOn)

        vm.setMemories(true)
        assertTrue(vm.state.value.memoriesOn)
        assertTrue(backend.notificationSettings!!.memories)
        assertEquals(env.zone().id, backend.notificationSettings!!.memoryTimeZone)
        // Quiet hours do not turn the memory notification off.
        vm.setQuietOn(true)
        vm.setStart(java.time.LocalTime.of(22, 0))
        vm.setEnd(java.time.LocalTime.of(7, 0))
        assertTrue(backend.notificationSettings!!.memories)

        vm.setMemories(false)
        assertFalse(vm.state.value.memoriesOn)
        assertFalse(backend.notificationSettings!!.memories)

        backend.failures["setMemoryAlerts"] = DataError.Network
        vm.setMemories(true)
        assertFalse(vm.state.value.memoriesOn) // the control returns
        assertTrue(vm.state.value.error)
    }

    @Test fun aStoredChoiceIsRead() = runTest(main.dispatcher) {
        val on = world().apply { notificationSettings = NotificationSettings(meId, null, null, null, now, memories = true, memoryTimeZone = "Europe/Lisbon") }
        assertTrue(SettingsNotificationsViewModel(fakeEnvironment(on)).state.value.memoriesOn)
        val none = world()
        assertFalse(SettingsNotificationsViewModel(fakeEnvironment(none)).state.value.memoriesOn)
    }
}
