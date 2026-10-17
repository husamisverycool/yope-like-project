package app.feature.account

import androidx.test.ext.junit.runners.AndroidJUnit4
import app.data.model.MemberRole
import app.data.model.ReportTargetKind
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.account.common.AccountEvent
import app.feature.account.safety.ReportPhase
import app.feature.account.safety.ReportReasons
import app.feature.account.safety.ReportViewModel
import app.feature.account.safety.reportTarget
import app.feature.account.safety.reportTitle
import app.feature.account.testing.FakeAccountBackend
import app.feature.account.testing.fakeEnvironment
import app.model.SafetyReportContentRoute
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/** Reports of a plan, a birthday video, a year story, a collage and a recap (safety.report, MERGE FV-4). */
@RunWith(AndroidJUnit4::class)
class ContentReportTest {
    @get:Rule val main = MainDispatcherRule()

    private fun world() = FakeAccountBackend().apply {
        signIn()
        profile(meId, "Ana Lima")
        profile("u-sam", "Sam Lee")
        group("g1", "Sunday dinners")
        member("g1", meId, MemberRole.Admin)
        member("g1", "u-sam")
    }

    @Test fun eachKindIsReportedByItsIdWithThePostReasonsAndItsOwnQuestion() = runTest(main.dispatcher) {
        val kinds = listOf(
            Triple("plan", ReportTargetKind.Plan, R.string.safety_report_title_plan),
            Triple("tribute", ReportTargetKind.Tribute, R.string.safety_report_title_video),
            Triple("year_story", ReportTargetKind.YearStory, R.string.safety_report_title_recap),
            Triple("collage", ReportTargetKind.Collage, R.string.safety_report_title_collage),
            Triple("recap", ReportTargetKind.Recap, R.string.safety_report_title_recap),
        )
        val backend = world()
        for ((wire, kind, title) in kinds) {
            val target = reportTarget(SafetyReportContentRoute(wire, "id-$wire", "g1"))!!
            assertEquals(kind, target.kind)
            assertEquals(title, reportTitle(kind))
            val reasons = ReportReasons.of(kind)
            assertEquals(ReportReasons.of(ReportTargetKind.Post).map { it.copy }, reasons.map { it.copy })
            assertEquals(Tokens.Layouts.SafetyReportLayoutReasons.post.split(" · "), reasons.map { it.wire })
            val vm = ReportViewModel(fakeEnvironment(backend), target)
            val events = vm.recordEvents(backgroundScope)
            vm.choose(reasons.last())
            assertEquals(Triple(kind, "id-$wire", "Other"), backend.reports.last())
            assertEquals(listOf(AccountEvent.Toast(R.string.safety_report_sent_title)), events.toasts())
        }
        assertNull("a kind this build does not know", reportTarget(SafetyReportContentRoute("poll", "x", "g1")))
    }

    @Test fun aPlansMakerCanBeBlockedFromNextSteps() = runTest(main.dispatcher) {
        val backend = world()
        val vm = ReportViewModel(fakeEnvironment(backend), reportTarget(SafetyReportContentRoute("plan", "p1", "g1", "u-sam"))!!)
        assertEquals("Sam", vm.state.value.firstName) // "Block Sam"
        vm.choose(ReportReasons.of(ReportTargetKind.Plan).first())
        assertEquals(ReportPhase.NextSteps, vm.state.value.phase)
        // a group-made recap names nobody: Next Steps offer "Leave the group" only
        val recap = ReportViewModel(fakeEnvironment(backend), reportTarget(SafetyReportContentRoute("recap", "r1", "g1"))!!)
        assertNull(recap.state.value.firstName)
    }
}
