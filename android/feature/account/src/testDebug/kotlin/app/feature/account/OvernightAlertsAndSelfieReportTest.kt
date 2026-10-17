package app.feature.account

import androidx.test.ext.junit.runners.AndroidJUnit4
import app.data.error.DataError
import app.data.model.MemberRole
import app.data.model.NotificationSettings
import app.data.model.ReportTargetKind
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.account.common.AccountEvent
import app.feature.account.safety.ReportPhase
import app.feature.account.safety.ReportReasons
import app.feature.account.safety.ReportViewModel
import app.feature.account.safety.reportTarget
import app.feature.account.safety.reportTitle
import app.feature.account.settings.SettingsNotificationsViewModel
import app.feature.account.testing.FakeAccountBackend
import app.feature.account.testing.fakeEnvironment
import app.model.SafetyReportSelfieRoute
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/** The overnight photos' switch in settings.notifications (camera.overnight) and a selfie reaction's report (viewer.selfiereaction). */
@RunWith(AndroidJUnit4::class)
class OvernightAlertsAndSelfieReportTest {
    @get:Rule val main = MainDispatcherRule()

    private fun world() = FakeAccountBackend().apply {
        signIn()
        profile(meId, "Ana Lima")
        profile("u-sam", "Sam Lee")
        group("g1", "Sunday dinners")
        member("g1", meId, MemberRole.Admin)
        member("g1", "u-sam")
    }

    @Test fun developedPhotosIsOnByDefaultAndFollowsTheStoredSetting() = runTest(main.dispatcher) {
        assertTrue(SettingsNotificationsViewModel(fakeEnvironment(world())).state.value.overnightOn)
        val off = world().apply { notificationSettings = NotificationSettings(meId, null, null, null, now, overnight = false) }
        assertFalse(SettingsNotificationsViewModel(fakeEnvironment(off)).state.value.overnightOn)
    }

    @Test fun theSwitchSavesKeepsQuietHoursAndRevertsOnFailure() = runTest(main.dispatcher) {
        val backend = world()
        val vm = SettingsNotificationsViewModel(fakeEnvironment(backend))
        vm.setOvernight(false)
        assertFalse(vm.state.value.overnightOn)
        assertFalse(backend.notificationSettings!!.overnight)
        // Quiet hours do not turn the overnight alerts back on.
        vm.setQuietOn(true)
        vm.setStart(java.time.LocalTime.of(22, 0))
        vm.setEnd(java.time.LocalTime.of(7, 0))
        assertFalse(backend.notificationSettings!!.overnight)

        backend.failures["setOvernightAlerts"] = DataError.Network
        vm.setOvernight(true)
        assertFalse(vm.state.value.overnightOn) // the control returns
        assertTrue(vm.state.value.error)

        // Offline: nothing is sent, the alert shows.
        vm.dismissError()
        backend.onlineState.value = false
        val calls = backend.calls.count { it == "setOvernightAlerts" }
        vm.setOvernight(true)
        assertEquals(calls, backend.calls.count { it == "setOvernightAlerts" })
        assertTrue(vm.state.value.error)
    }

    @Test fun aSelfieIsReportedByItsIdWithTheContentReasonsAndItsAuthorCanBeBlocked() = runTest(main.dispatcher) {
        val backend = world()
        val target = reportTarget(SafetyReportSelfieRoute("g1", "s-1", "u-sam"))
        assertEquals(ReportTargetKind.Selfie, target.kind)
        val vm = ReportViewModel(fakeEnvironment(backend), target)
        val events = vm.recordEvents(backgroundScope)
        assertEquals("Sam", vm.state.value.firstName) // "Block Sam" in Next Steps
        val reasons = ReportReasons.of(ReportTargetKind.Selfie)
        // The sheet asks about the selfie (`safety.report.title.selfie`) with the selfie list, the post reasons (MERGE SR-10).
        assertEquals(R.string.safety_report_title_selfie, reportTitle(ReportTargetKind.Selfie))
        assertEquals(Tokens.Layouts.SafetyReportLayoutReasons.selfie.split(" · "), reasons.map { it.wire })
        assertEquals(ReportReasons.of(ReportTargetKind.Post).map { it.copy }, reasons.map { it.copy })
        vm.choose(reasons[1])
        assertEquals(Triple(ReportTargetKind.Selfie, "s-1", "Nudity or sexual activity"), backend.reports.single())
        assertEquals(listOf(AccountEvent.Toast(R.string.safety_report_sent_title)), events.toasts())

        val next = ReportViewModel(fakeEnvironment(backend), target)
        next.choose(reasons.first())
        assertEquals(ReportPhase.NextSteps, next.state.value.phase)
    }
}
