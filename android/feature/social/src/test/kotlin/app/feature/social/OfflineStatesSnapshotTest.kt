package app.feature.social

import app.feature.social.FakeSocialData.Companion.ANA
import app.feature.social.FakeSocialData.Companion.BEN
import app.feature.social.FakeSocialData.Companion.GROUP
import app.feature.social.walls.BrowseState
import app.feature.social.walls.BrowseViewModel
import app.feature.social.walls.WallNav
import app.feature.social.walls.WallsBrowseContent
import app.feature.social.week.HistoryNav
import app.feature.social.week.HistoryState
import app.feature.social.week.HistoryViewModel
import app.feature.social.week.WeekHistoryContent
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

/**
 * Offline states of walls.browse and week.history, as the specs and iOS have them: walls.browse keeps the last grid
 * (nothing cached → the error line); week.history with nothing cached shows `week.history.offline`, not the error copy.
 */
class OfflineStatesSnapshotTest : SnapshotBase() {
    private val wallNav = WallNav({}, {}, { _, _, _ -> }, { _, _ -> }, {}, {}, {}, {}, {})
    private val historyNav = HistoryNav({}, { _, _ -> }, {}, {}, {})

    @Test fun browseOfflineKeepsTheCachedGrid() {
        val data = FakeSocialData().apply { seedWall(BEN, 1) }
        assertEquals(listOf(ANA, BEN), BrowseViewModel(data).state.value.people.map { it.id })
        data.offline = true
        val offline = BrowseViewModel(data).state.value
        assertEquals(BrowseState.Phase.Ready, offline.phase)
        assertEquals("the last grid, from the page cache", listOf(ANA, BEN), offline.people.map { it.id })
        snap(data) { WallsBrowseContent(offline, wallNav, {}, {}) }
    }

    @Test fun browseOfflineWithNothingCachedShowsTheErrorLine() {
        val data = FakeSocialData().apply {
            seedWall(BEN, 1)
            offline = true
        }
        assertEquals(BrowseState.Phase.OfflineEmpty, BrowseViewModel(data).state.value.phase)
    }

    @Test fun historyOfflineWithNothingCached() {
        val data = FakeSocialData().apply {
            seedGroup()
            offline = true
        }
        val state = HistoryViewModel(data, GROUP) { LocalDate.parse("2026-10-14") }.state.value
        assertEquals(HistoryState.Phase.Error, state.phase)
        assertTrue("the screen shows week.history.offline", state.offline)
        snap(data) { WeekHistoryContent(state, historyNav, {}, {}) }
    }
}
