package app.feature.social

import app.data.model.HistoryMonth
import app.data.model.HistoryWeek
import app.data.realtime.GroupEvent
import app.feature.social.FakeSocialData.Companion.ANA
import app.feature.social.FakeSocialData.Companion.GROUP
import app.feature.social.week.HistoryViewModel
import app.feature.social.week.RecapEdits
import app.feature.memory.common.calendarCells
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.time.LocalDate
import java.time.ZoneOffset

/** week.history's calendar (`week.history.layout.calendar`): the months, the grid, and the jump to a week. */
@OptIn(ExperimentalCoroutinesApi::class)
class HistoryCalendarTest {
    private val monday = LocalDate.parse("2026-10-12")

    @Before fun setUp() {
        Dispatchers.setMain(UnconfinedTestDispatcher())
        RecapEdits.pending.value = emptyMap()
    }

    @After fun tearDown() {
        Dispatchers.resetMain()
    }

    /** Twelve weeks with one photo each (this week back to 11 weeks ago): more than a page of eight. */
    private fun twelveWeeks(): FakeSocialData = FakeSocialData().apply {
        seedGroup()
        weeks[GROUP] = (0 until 12).map { i ->
            val start = monday.minusWeeks(i.toLong())
            val p = addPhoto("h-$i", ANA, start.plusDays(1).atStartOfDay(ZoneOffset.UTC).toInstant())
            HistoryWeek(start, listOf(p.id))
        }.toMutableList()
        months[GROUP] = listOf(
            HistoryMonth(LocalDate.parse("2026-10-01"), listOf(LocalDate.parse("2026-10-06"), LocalDate.parse("2026-10-13")), monday),
            HistoryMonth(LocalDate.parse("2026-07-01"), listOf(LocalDate.parse("2026-07-28")), LocalDate.parse("2026-07-27")),
        )
    }

    @Test fun theMonthsArriveWithTheHistoryAndNoneMeansNoGlyph() {
        val vm = HistoryViewModel(twelveWeeks(), GROUP) { monday }
        assertEquals(listOf(LocalDate.parse("2026-10-01"), LocalDate.parse("2026-07-01")), vm.state.value.months.map { it.month })

        val none = HistoryViewModel(FakeSocialData().apply { seedWeek() }, GROUP) { monday }
        assertTrue(none.state.value.months.isEmpty())

        val offline = FakeSocialData().apply {
            seedWeek()
            this.offline = true
        }
        assertTrue("a failure leaves the glyph out", HistoryViewModel(offline, GROUP) { monday }.state.value.months.isEmpty())
    }

    @Test fun aLoadedWeekIsScrolledToWithoutReloading() {
        val vm = HistoryViewModel(twelveWeeks(), GROUP) { monday }
        val before = vm.state.value.weeks
        vm.jumpTo(monday.minusWeeks(3))
        assertEquals(monday.minusWeeks(3), vm.state.value.scrollTo)
        assertEquals(before, vm.state.value.weeks)
        assertNull(vm.state.value.startsAt)
        vm.scrolled()
        assertNull(vm.state.value.scrollTo)
    }

    @Test fun anOlderWeekStartsTheListThereAndRefreshReturnsToTheNewest() = runBlocking {
        val data = twelveWeeks()
        val vm = HistoryViewModel(data, GROUP) { monday }
        val target = monday.minusWeeks(11)
        assertTrue("eleven weeks back is beyond the first page", vm.state.value.weeks.none { it.weekStart == target })

        vm.jumpTo(target)
        val s = vm.state.value
        assertEquals(target, s.startsAt)
        assertEquals(target, s.scrollTo)
        assertEquals(target, s.weeks.first().weekStart)
        assertTrue("no current week above it", s.weeks.none { it.isCurrent })
        assertEquals(listOf("h-11"), s.weeks.first().photos.map { it.post.id })
        assertTrue(s.endReached)

        // a new photo this week does not put the current week above the jumped-to one
        val fresh = data.addPhoto("new", ANA, monday.plusDays(2).atStartOfDay(ZoneOffset.UTC).toInstant())
        data.emit(GroupEvent.PostInserted(GROUP, fresh))
        assertEquals(target, vm.state.value.weeks.first().weekStart)

        vm.refresh()
        assertNull(vm.state.value.startsAt)
        assertEquals(monday, vm.state.value.weeks.first().weekStart)
        assertTrue(vm.state.value.weeks.first().isCurrent)
    }

    @Test fun aFailedJumpKeepsTheList() {
        val data = twelveWeeks()
        val vm = HistoryViewModel(data, GROUP) { monday }
        val before = vm.state.value.weeks
        data.offline = true
        vm.jumpTo(monday.minusWeeks(11))
        assertEquals(before, vm.state.value.weeks)
        assertNull(vm.state.value.startsAt)
        assertTrue(vm.state.value.offline)
    }

    @Test fun theGridStartsOnMondayAndFillsItsLastRow() {
        val october = calendarCells(LocalDate.parse("2026-10-01"))
        assertEquals(35, october.size)
        assertEquals("1 October 2026 is a Thursday", listOf(null, null, null), october.take(3))
        assertEquals(LocalDate.parse("2026-10-01"), october[3])
        assertEquals(LocalDate.parse("2026-10-31"), october[33])
        assertNull(october.last())
        val february = calendarCells(LocalDate.parse("2027-02-01"))
        assertEquals("1 February 2027 is a Monday: no blank, four full weeks", 28, february.size)
        assertFalse(february.contains(null))
    }
}
