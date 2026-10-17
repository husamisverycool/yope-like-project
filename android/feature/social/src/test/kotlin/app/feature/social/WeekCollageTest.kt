package app.feature.social

import app.data.model.GroupCollage
import app.data.model.HistoryWeek
import app.feature.social.FakeSocialData.Companion.GROUP
import app.feature.social.week.HistoryViewModel
import app.feature.social.week.RecapEdits
import app.feature.social.week.RecapViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.time.LocalDate

/**
 * The same-moment collage in the group's history (migration 0033): week.history shows each day's collage in its week,
 * week.recap shows the week's collages (`weekly_recaps.collage_ids`) after the cover.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class WeekCollageTest {
    @Before fun setUp() {
        Dispatchers.setMain(UnconfinedTestDispatcher())
        RecapEdits.pending.value = emptyMap()
    }

    @After fun tearDown() {
        Dispatchers.resetMain()
    }

    private fun collage(id: String, day: String) = GroupCollage(
        collageId = id,
        invitationId = "inv-$id",
        localDate = LocalDate.parse(day),
        imagePath = "g/$GROUP/collages/$id/1/display-1.jpg",
        widgetPath = "g/$GROUP/collages/$id/1/widget.jpg",
    )

    private fun seeded(): FakeSocialData = FakeSocialData().apply {
        seedWeek()
        val monday = LocalDate.parse("2026-10-12")
        val weeks = weeks.getValue(GROUP)
        weeks[0] = weeks[0].copy(collages = listOf(collage("c-1", "2026-10-13"), collage("c-2", "2026-10-15")))
        // a week with a collage and no photo still shows (the collage is the group's photo of that day)
        weeks += HistoryWeek(monday.minusDays(14), emptyList(), listOf(collage("c-0", "2026-09-30")))
        recaps["r-w"] = recaps.getValue("r-w").copy(collageIds = listOf("c-2", "c-1"))
    }

    @Test fun historyShowsEachDaysCollageInItsWeek() {
        val vm = HistoryViewModel(seeded(), GROUP) { LocalDate.parse("2026-10-14") }
        val weeks = vm.state.value.weeks
        val current = weeks.first { it.weekStart == LocalDate.parse("2026-10-12") }
        assertEquals(listOf("c-1", "c-2"), current.collages.map { it.collageId })
        assertEquals("g/$GROUP/collages/c-1/1/widget.jpg", current.collages.first().tilePath)
        val onlyCollage = weeks.first { it.weekStart == LocalDate.parse("2026-09-28") }
        assertTrue(onlyCollage.photos.isEmpty())
        assertEquals(listOf("c-0"), onlyCollage.collages.map { it.collageId })
        assertFalse(vm.state.value.isEmpty)
    }

    @Test fun aHistoryOfOnlyCollagesIsNotEmpty() {
        val data = FakeSocialData().apply {
            seedGroup()
            weeks[GROUP] = mutableListOf(HistoryWeek(LocalDate.parse("2026-10-05"), emptyList(), listOf(collage("c-9", "2026-10-06"))))
        }
        val state = HistoryViewModel(data, GROUP) { LocalDate.parse("2026-10-14") }.state.value
        assertFalse(state.isEmpty)
        assertEquals(listOf("c-9"), state.weeks.flatMap { it.collages }.map { it.collageId })
    }

    @Test fun recapShowsItsCollagesInRecapOrder() {
        val state = RecapViewModel(seeded(), GROUP, "r-w").state.value
        assertEquals(listOf("c-2", "c-1"), state.collages.map { it.collageId })
        // a recap made before collages were kept has none
        val data = seeded().apply { recaps["r-w"] = recaps.getValue("r-w").copy(collageIds = emptyList()) }
        assertTrue(RecapViewModel(data, GROUP, "r-w").state.value.collages.isEmpty())
    }
}
