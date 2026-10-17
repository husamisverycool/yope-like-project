package app.feature.social

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onAllNodesWithContentDescription
import androidx.compose.ui.test.onFirst
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.data.model.HistoryMonth
import app.data.model.HistoryWeek
import app.data.model.PhotoSearchHit
import app.feature.social.FakeSocialData.Companion.ANA
import app.feature.social.FakeSocialData.Companion.GROUP
import app.feature.social.search.SearchNav
import app.feature.social.search.SearchPhotosScreen
import app.feature.social.search.SearchState
import app.feature.social.search.SearchViewModel
import app.feature.social.week.HistoryNav
import app.feature.social.week.HistoryViewModel
import app.feature.social.week.RecapEdits
import app.feature.social.week.WeekHistoryScreen
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import java.time.LocalDate
import java.time.ZoneOffset

/**
 * `search.photos` and week.history's calendar on Robolectric, by semantics (no new image captures): the glyph, the chips,
 * the results' labels, the calendar's days and the jump.
 */
@RunWith(AndroidJUnit4::class)
@Config(qualifiers = "w393dp-h852dp-xhdpi")
@OptIn(ExperimentalCoroutinesApi::class)
class SearchCalendarUiTest {
    @get:Rule val compose = createComposeRule()

    private val monday = LocalDate.parse("2026-10-12")
    private val historyNav = HistoryNav(back = {}, photo = { _, _ -> }, recap = {}, saveAsAlbum = {}, camera = {})

    @Before fun setUp() {
        fixLocale()
        Dispatchers.setMain(UnconfinedTestDispatcher())
        RecapEdits.pending.value = emptyMap()
    }

    @After fun tearDown() = Dispatchers.resetMain()

    @Test fun theCalendarGlyphShowsOnlyOnceThereAreMonths() {
        val data = FakeSocialData().apply { seedWeek() }
        val vm = HistoryViewModel(data, GROUP) { monday }
        compose.setContent { TestScreen(data) { WeekHistoryScreen(vm, historyNav) } }
        compose.waitForIdle()
        assertTrue(compose.onAllNodesWithContentDescription("View all memories").fetchSemanticsNodes().isEmpty())
    }

    @Test fun aDayOfTheCalendarJumpsToItsWeek() {
        val data = FakeSocialData().apply {
            seedGroup()
            weeks[GROUP] = (0 until 12).map { i ->
                val start = monday.minusWeeks(i.toLong())
                val p = addPhoto("h-$i", ANA, start.plusDays(1).atStartOfDay(ZoneOffset.UTC).toInstant())
                HistoryWeek(start, listOf(p.id))
            }.toMutableList()
            months[GROUP] = listOf(
                HistoryMonth(LocalDate.parse("2026-10-01"), listOf(LocalDate.parse("2026-10-13")), monday),
                HistoryMonth(LocalDate.parse("2026-07-01"), listOf(LocalDate.parse("2026-07-28")), LocalDate.parse("2026-07-27")),
            )
        }
        val vm = HistoryViewModel(data, GROUP) { monday }
        compose.setContent { TestScreen(data) { WeekHistoryScreen(vm, historyNav) } }
        compose.waitForIdle()
        compose.onNodeWithContentDescription("View all memories").performClick()
        compose.waitForIdle()
        compose.onNodeWithText("Memories").assertIsDisplayed()
        // a day without anything is read as such and does nothing; a day with something is a button to its week
        compose.onAllNodesWithContentDescription("Wednesday, October 14, 2026, no photos").onFirst().assertExists()
        compose.onNodeWithText("July 2026").assertExists()
        compose.onNodeWithContentDescription("Tuesday, July 28, 2026").performClick()
        compose.waitForIdle()
        assertEquals(LocalDate.parse("2026-07-27"), vm.state.value.startsAt)
        assertEquals("h-11", vm.state.value.weeks.first().photos.single().post.id)
    }

    @Test fun searchShowsIdleThenAMembersPhotosWithoutACount() {
        val data = FakeSocialData().apply {
            seedWeek()
            listOf("w-7", "w-4", "w-1").forEach { id ->
                val p = posts.getValue(id)
                searchHits += PhotoSearchHit(id, p.mediaId, GROUP, p.authorId, p.createdAt, listOf("author"))
            }
        }
        val opened = ArrayList<String>()
        val vm = SearchViewModel(data, GROUP)
        compose.setContent { TestScreen(data) { SearchPhotosScreen(vm, SearchNav(back = {}, photo = { _, postId -> opened += postId })) } }
        compose.waitForIdle()
        compose.onNodeWithText("Find a photo").assertIsDisplayed()
        compose.onNodeWithText("You").assertExists()
        compose.onNodeWithText("Date").assertExists()
        compose.onNodeWithText("Ana").performClick()
        compose.waitForIdle()
        assertEquals(SearchState.Phase.Results, vm.state.value.phase)
        assertEquals(ANA, data.searches.last().first.memberId)
        val cells = compose.onAllNodesWithContentDescription("'s photo, ", substring = true).fetchSemanticsNodes()
        assertEquals(3, cells.size)
        compose.onAllNodesWithContentDescription("'s photo, ", substring = true)[0].performClick()
        assertEquals(listOf("w-7"), opened)
        assertTrue("no result count is written", compose.onAllNodesWithText("3", substring = true).fetchSemanticsNodes().isEmpty())
    }
}
