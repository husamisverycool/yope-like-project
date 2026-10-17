package app.model

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.time.LocalDate

/** Plans in the shared vocabulary: the plan link, its back stack, the plan push and the countdown snapshot. */
class PlansModelTest {
    private val codec = DeepLinkCodec("example.org")

    @Test fun planLinksRoundTripWithAndWithoutTheirGroup() {
        val withGroup = DeepLink.Plan("p-1", "g-1")
        assertEquals("app://plan?plan=p-1&group=g-1", codec.format(withGroup))
        assertEquals(withGroup, codec.parse(codec.format(withGroup)))
        assertEquals(DeepLink.Plan("p-1"), codec.parse("app://plan?plan=p-1"))
        assertEquals("app://plan?plan=p-1", codec.format(DeepLink.Plan("p-1")))
        // A malformed group is dropped; the plan still opens.
        assertEquals(DeepLink.Plan("p-1"), codec.parse("app://plan?plan=p-1&group=..%2F"))
        assertNull(codec.parse("app://plan?group=g-1"))
        assertNull(codec.parse("app://plan/x?plan=p-1"))
    }

    @Test fun aPlanLinkLandsOnThePlanOverItsGroup() {
        assertEquals(
            listOf(DeepLinkRouting.home, AppRoute.Group("g-1"), PlanRoute("p-1", "g-1")),
            DeepLinkRouting.backStack(DeepLink.Plan("p-1", "g-1")),
        )
        assertEquals(listOf(DeepLinkRouting.home, PlanRoute("p-1")), DeepLinkRouting.backStack(DeepLink.Plan("p-1")))
        assertEquals("plans.page", DeepLinkRouting.destination(DeepLink.Plan("p-1")).surface)
        assertEquals("plans.create", PlanCreateRoute("g-1").surface)
    }

    @Test fun planPushesAreAlertsThatOpenThePlan() {
        val push = mapOf("type" to "plan", "title" to "Sunday Dinners", "body" to "Ana made a plan", "group_id" to "g-1", "plan_id" to "p-1", "collapse_key" to "plan:p-1")
        val alert = PushMessage.parse(push, codec) as PushMessage.Alert
        assertEquals(PushMessage.AlertKind.Plan, alert.kind)
        assertEquals(DeepLink.Plan("p-1", "g-1"), alert.link)
        assertEquals("plan:p-1", alert.collapseKey)
        // Without its group the plan still opens; without a plan id there is nothing to open.
        assertEquals(DeepLink.Plan("p-1"), (PushMessage.parse(push - "group_id", codec) as PushMessage.Alert).link)
        assertNull((PushMessage.parse(push - "plan_id", codec) as PushMessage.Alert).link)
        // An explicit link still wins.
        assertEquals(DeepLink.Post("g-1", "x"), (PushMessage.parse(push + ("link" to "app://post?group=g-1&post=x"), codec) as PushMessage.Alert).link)
    }

    @Test fun existingAlertKindsKeepTheirOrdinals() {
        // The ordinal is part of the notification id: new kinds go last.
        assertEquals(6, PushMessage.AlertKind.YearStory.ordinal)
        assertEquals(7, PushMessage.AlertKind.Plan.ordinal)
        assertEquals(8, PushMessage.AlertKind.PhotosDeveloped.ordinal)
        assertEquals(PushMessage.AlertKind.entries.size - 1, PushMessage.AlertKind.Memory.ordinal)
    }

    private fun plan(id: String, group: String, day: String) = CountdownPlan(id, group, "Group $group", "Plan $id", day)

    @Test fun theCountdownShowsTheSoonestPlanWhoseDayHasNotPassed() {
        val snapshot = CountdownSnapshot(listOf(plan("a", "g1", "2026-10-16"), plan("b", "g2", "2026-10-18"), plan("c", "g1", "2026-10-20")), 0)
        assertEquals("a", snapshot.next(null, LocalDate.parse("2026-10-16"))?.planId)
        // The day after falls through to the next plan.
        assertEquals("b", snapshot.next(null, LocalDate.parse("2026-10-17"))?.planId)
        assertEquals("c", snapshot.next("g1", LocalDate.parse("2026-10-17"))?.planId)
        assertNull(snapshot.next(null, LocalDate.parse("2026-10-21")))
        assertEquals(snapshot, CountdownSnapshot.fromJson(snapshot.toJson()))
        assertNull(CountdownSnapshot.fromJson("{"))
    }

    @Test fun daysAreCalendarDaysNotSpansOf24Hours() {
        val p = plan("a", "g1", "2026-10-18")
        assertEquals(2, p.daysFrom(LocalDate.parse("2026-10-16")))
        assertEquals(1, p.daysFrom(LocalDate.parse("2026-10-17")))
        assertEquals(0, p.daysFrom(LocalDate.parse("2026-10-18")))
    }
}
