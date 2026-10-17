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
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.time.Instant

/** Pause All in settings.notifications (`set_notifications_paused`, migration 0037): until the next local midnight. */
@RunWith(AndroidJUnit4::class)
class PauseAllTest {
    @get:Rule val main = MainDispatcherRule()

    private fun world() = FakeAccountBackend().apply {
        signIn()
        profile(meId, "Ana Lima")
    }

    @Test fun onPausesUntilTheNextLocalMidnightOffResumesAndAFailureReverts() = runTest(main.dispatcher) {
        val backend = world()
        val vm = SettingsNotificationsViewModel(fakeEnvironment(backend))
        assertFalse(vm.state.value.paused)
        vm.setPaused(true)
        // the fake clock is 2026-10-15T17:00Z in UTC: the pause ends at the start of 16 October
        assertEquals(Instant.parse("2026-10-16T00:00:00Z"), vm.state.value.pausedUntil)
        assertEquals(Instant.parse("2026-10-16T00:00:00Z"), backend.notificationSettings!!.pausedUntil)
        vm.setPaused(false)
        assertNull(vm.state.value.pausedUntil)
        assertNull(backend.notificationSettings!!.pausedUntil)

        backend.failures["setNotificationsPaused"] = DataError.Network
        vm.setPaused(true)
        assertFalse(vm.state.value.paused) // the control returns
        assertTrue(vm.state.value.error)
    }

    @Test fun aStoredPauseShowsUntilItEndsAndAnEndedOneDoesNot() = runTest(main.dispatcher) {
        val ahead = world().apply { notificationSettings = NotificationSettings(meId, null, null, null, now, pausedUntil = now.plusSeconds(3600)) }
        assertTrue(SettingsNotificationsViewModel(fakeEnvironment(ahead)).state.value.paused)
        val ended = world().apply { notificationSettings = NotificationSettings(meId, null, null, null, now, pausedUntil = now.minusSeconds(60)) }
        assertFalse(SettingsNotificationsViewModel(fakeEnvironment(ended)).state.value.paused)
    }
}
