package app.feature.account

import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.data.error.DataError
import app.data.model.CurrentQuestion
import app.data.model.MemberRole
import app.data.model.PlanAnswerKind
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.account.groups.GroupSettingsViewModel
import app.feature.account.plans.PlanCreateError
import app.feature.account.plans.PlanCreateViewModel
import app.feature.account.plans.PlanPageViewModel
import app.feature.account.plans.loadNextPlan
import app.feature.account.question.loadQuestion
import app.feature.account.testing.FakeAccountBackend
import app.feature.account.testing.fakeEnvironment
import app.model.PlanCreateRoute
import app.model.PlanRoute
import app.ui.copy.WeeklyQuestions
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
import java.time.LocalTime

/** plans.create, plans.page, the weekly question card's data and switch, the plan row's data. */
@RunWith(AndroidJUnit4::class)
class PlansViewModelsTest {
    @get:Rule val main = MainDispatcherRule()

    private val env get() = fakeEnvironment(FakeAccountBackend())

    private fun world() = FakePlansBackend().apply {
        group("g1", zone = "America/New_York")
        member("g1", "u-me", "Ana Lima", MemberRole.Member)
        member("g1", "u-sam", "Sam Lee", MemberRole.Admin)
        member("g1", "u-zoe", "Zoe Park")
    }

    // plans.create -----------------------------------------------------------------------------------

    @Test fun createNeedsATitleAndADayAndWithoutATimeIsAllDay() = runTest(main.dispatcher) {
        val backend = world()
        val vm = PlanCreateViewModel(env, backend, "g1", null)
        val events = vm.recordEvents(backgroundScope)
        // The date picker starts at today in the group's time zone (17:00 UTC is 13:00 in New York, Oct 15).
        assertEquals(LocalDate.parse("2026-10-15"), vm.state.value.today)
        assertFalse(vm.state.value.canSubmit)
        vm.onTitle("Picnic at the lake")
        assertFalse(vm.state.value.canSubmit)
        vm.onDate(LocalDate.parse("2026-10-24"))
        assertTrue(vm.state.value.canSubmit)
        vm.onTitle("x".repeat(81))
        assertTrue(vm.state.value.tooLong)
        assertFalse(vm.state.value.canSubmit)
        vm.onTitle("  Picnic at the lake ")
        vm.onPlace("  Lake Park ")
        vm.submit()
        val created = backend.created!!
        assertEquals("Picnic at the lake", created.title)
        assertTrue("no time chosen = all-day", created.allDay)
        assertEquals(Instant.parse("2026-10-24T04:00:00Z"), created.startsAt) // 00:00 in New York (EDT)
        assertEquals("Lake Park", created.place)
        assertNull(created.note)
        assertEquals(PlanRoute("p-new", "g1"), events.navigations().single().route)
        assertTrue("no haptic on send", events.haptics().isEmpty())
    }

    @Test fun aTimedPlanStartsAtItsTimeInTheGroupsZone() = runTest(main.dispatcher) {
        val backend = world()
        val vm = PlanCreateViewModel(env, backend, "g1", null)
        vm.onTitle("Dinner")
        vm.onDate(LocalDate.parse("2026-10-24"))
        vm.onTime(LocalTime.of(19, 30))
        vm.submit()
        assertFalse(backend.created!!.allDay)
        assertEquals(Instant.parse("2026-10-24T23:30:00Z"), backend.created!!.startsAt)
        // All-day on hides the time and wins over it.
        val allDay = PlanCreateViewModel(env, backend, "g1", null)
        allDay.onTitle("Trip")
        allDay.onDate(LocalDate.parse("2026-10-25"))
        allDay.onTime(LocalTime.of(9, 0))
        allDay.onAllDay(true)
        assertTrue(allDay.state.value.sendsAllDay)
    }

    @Test fun failuresKeepTheSheetWithTheirLine() = runTest(main.dispatcher) {
        val backend = world().apply { failures["createPlan"] = DataError.Network }
        val vm = PlanCreateViewModel(env, backend, "g1", null)
        val events = vm.recordEvents(backgroundScope)
        vm.onTitle("Dinner")
        vm.onDate(LocalDate.parse("2026-10-24"))
        vm.submit()
        assertEquals(PlanCreateError.Offline, vm.state.value.error)
        assertFalse(vm.state.value.working)
        backend.failures["createPlan"] = DataError.Unexpected("x")
        vm.submit()
        assertEquals(PlanCreateError.Failed, vm.state.value.error)
        assertEquals(listOf(Tokens.Haptics.globalError, Tokens.Haptics.globalError), events.haptics())
        assertTrue(events.navigations().isEmpty())
    }

    @Test fun editPrefillsAndSavesEveryFieldKeepingTheCover() = runTest(main.dispatcher) {
        val backend = world()
        backend.plan("p1", "g1", "2026-10-24").let { backend.plans["p1"] = it.copy(coverPath = "u/u-me/covers/c.jpg") }
        val vm = PlanCreateViewModel(env, backend, "g1", "p1")
        val events = vm.recordEvents(backgroundScope)
        val s = vm.state.value
        assertEquals("Picnic at the lake", s.title)
        assertEquals(LocalDate.parse("2026-10-24"), s.date)
        assertEquals(LocalTime.of(14, 30), s.time) // 18:30 UTC in New York
        assertFalse(s.hasUnsavedInput)
        vm.onNote("")
        assertTrue(vm.state.value.hasUnsavedInput)
        vm.submit()
        assertEquals("u/u-me/covers/c.jpg", backend.updated!!.coverPath)
        assertNull("a cleared note is cleared", backend.updated!!.note)
        assertTrue(events.any { it == app.feature.account.common.AccountEvent.Back })
    }

    // plans.page -------------------------------------------------------------------------------------

    @Test fun thePageListsGoingAndMaybeInAnswerOrderAndOnlyVisibleCantGo() = runTest(main.dispatcher) {
        val backend = world()
        backend.plan("p1", "g1", "2026-10-24", createdBy = "u-sam")
        backend.answer("p1", "u-sam", PlanAnswerKind.Going)
        backend.answer("p1", "u-zoe", PlanAnswerKind.Maybe)
        backend.answer("p1", "u-me", PlanAnswerKind.Going)
        val vm = PlanPageViewModel(env, backend, "p1")
        val s = vm.state.value
        assertEquals(listOf("Sam", "Ana"), s.going.map { it.firstName })
        assertEquals(listOf("Zoe"), s.maybe.map { it.firstName })
        assertEquals(PlanAnswerKind.Going, s.myAnswer)
        assertEquals("Sam", s.maker?.firstName)
        assertFalse("neither the maker nor an admin", s.canManage)
        assertFalse(s.past(backend.now))
    }

    @Test fun answeringIsOptimisticAndAFailureRevertsWithTheToast() = runTest(main.dispatcher) {
        val backend = world()
        backend.plan("p1", "g1", "2026-10-24")
        val vm = PlanPageViewModel(env, backend, "p1")
        val events = vm.recordEvents(backgroundScope)
        assertTrue("the maker manages the plan", vm.state.value.canManage)
        vm.answer(PlanAnswerKind.Maybe)
        assertEquals(PlanAnswerKind.Maybe, vm.state.value.myAnswer)
        assertEquals(listOf("Ana"), vm.state.value.maybe.map { it.firstName })
        // Tapping the chosen capsule again clears the answer.
        vm.answer(null)
        assertNull(vm.state.value.myAnswer)
        assertTrue(vm.state.value.maybe.isEmpty())
        backend.failures["answer"] = DataError.Network
        vm.answer(PlanAnswerKind.Going)
        assertNull("reverted", vm.state.value.myAnswer)
        assertEquals(R.string.plans_page_error_answer, events.toasts().single().copy)
        assertEquals(listOf("answer", "clearAnswer", "answer"), backend.calls.filter { it == "answer" || it == "clearAnswer" })
    }

    @Test fun pastAndCancelledPlansTakeNoAnswersAndCancelRestoreFollowTheConfirm() = runTest(main.dispatcher) {
        val backend = world()
        backend.plan("past", "g1", "2026-10-10")
        val past = PlanPageViewModel(env, backend, "past")
        assertTrue(past.state.value.past(backend.now))
        past.answer(PlanAnswerKind.Going)
        assertTrue("no answer after the day", backend.calls.none { it == "answer" })

        backend.plan("p1", "g1", "2026-10-24")
        val vm = PlanPageViewModel(env, backend, "p1")
        vm.askCancel()
        assertTrue(vm.state.value.confirmCancel)
        vm.confirmCancel()
        assertTrue(vm.state.value.plan!!.canceled)
        vm.answer(PlanAnswerKind.Going)
        assertTrue(backend.calls.none { it == "answer" })
        vm.restore()
        assertFalse(vm.state.value.plan!!.canceled)
    }

    @Test fun aPlanThatIsGoneReadsAsNotFound() = runTest(main.dispatcher) {
        val vm = PlanPageViewModel(env, world(), "nope")
        assertTrue(vm.state.value.notFound)
        val failing = world().apply { failures["observePlan"] = DataError.Unexpected("x") }
        assertTrue(PlanPageViewModel(env, failing, "nope").state.value.error)
    }

    @Test fun editOpensTheSheetInEditMode() = runTest(main.dispatcher) {
        val backend = world()
        backend.plan("p1", "g1", "2026-10-24")
        val vm = PlanPageViewModel(env, backend, "p1")
        val events = vm.recordEvents(backgroundScope)
        vm.edit()
        assertEquals(PlanCreateRoute("g1", "p1"), events.navigations().single().route)
    }

    // groups.screen entries ----------------------------------------------------------------------------

    @Test fun theNextPlanRowReadsTheSoonestPlanInTheGroupsZone() = runTest(main.dispatcher) {
        val backend = world()
        assertNull("none upcoming", loadNextPlan(backend, "g1")!!.row)
        backend.plan("p1", "g1", "2026-10-24")
        val row = loadNextPlan(backend, "g1")!!.row!!
        assertEquals("p1", row.planId)
        // 18:30 UTC is 2:30 PM in New York, the group's zone.
        assertTrue(row.whenLine, row.whenLine.contains("Oct 24, 2026") && row.whenLine.contains("2:30"))
        backend.failures["nextPlans"] = DataError.Network
        assertNull("a failed read", loadNextPlan(backend, "g1"))
    }

    @Test fun theQuestionCardNeedsAQuestionWithCopyThatYouHaveNotRemoved() = runTest(main.dispatcher) {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val text: (String) -> String? = { WeeklyQuestions.text(context, it) }
        val backend = world()
        assertNull("off for the group", loadQuestion(backend, "g1", text))
        backend.question = CurrentQuestion("q1", "question.weekly.q01", LocalDate.parse("2026-10-12"), hiddenByMe = false)
        val empty = loadQuestion(backend, "g1", text)!!
        assertEquals("What made you laugh this week?", empty.text)
        assertTrue(empty.answers.isEmpty())
        assertNull(empty.newestPhotoUrl)
        backend.questionAnswers += backend.post("a1", "g1", backend.now.minusSeconds(3600), "q1")
        backend.questionAnswers += backend.post("a2", "g1", backend.now, "q1")
        val answered = loadQuestion(backend, "g1", text)!!
        assertEquals("a1", answered.answers.first().id)
        assertEquals("https://signed.example/u/u-sam/ma2/original.jpg", answered.newestPhotoUrl)
        backend.question = backend.question!!.copy(hiddenByMe = true)
        assertNull("removed by you", loadQuestion(backend, "g1", text))
        backend.question = backend.question!!.copy(hiddenByMe = false, questionKey = "question.weekly.q99")
        assertNull("no copy for the key", loadQuestion(backend, "g1", text))
        assertNull(WeeklyQuestions.text(context, "question.weekly.../x"))
    }

    @Test fun theWeeklyQuestionSwitchIsOptimisticAndReverts() = runTest(main.dispatcher) {
        val account = FakeAccountBackend().apply {
            signIn()
            group("g1", "Sunday dinners")
            member("g1", meId, MemberRole.Admin)
        }
        val plans = world().apply { group("g1") }
        val vm = GroupSettingsViewModel(fakeEnvironment(account), "g1", plans)
        assertFalse(vm.state.value.group!!.weeklyQuestion)
        vm.setWeeklyQuestion(true)
        assertTrue(vm.state.value.group!!.weeklyQuestion)
        plans.failures["setWeeklyQuestion"] = DataError.Network
        vm.setWeeklyQuestion(false)
        assertTrue("reverted", vm.state.value.group!!.weeklyQuestion)
        assertTrue(vm.state.value.failed)
    }
}
