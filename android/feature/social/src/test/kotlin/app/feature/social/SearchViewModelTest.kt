package app.feature.social

import app.data.model.PhotoSearchHit
import app.feature.social.FakeSocialData.Companion.ANA
import app.feature.social.FakeSocialData.Companion.BASE
import app.feature.social.FakeSocialData.Companion.BEN
import app.feature.social.FakeSocialData.Companion.GROUP
import app.feature.social.FakeSocialData.Companion.ME
import app.feature.social.search.SearchResults
import app.feature.social.search.SearchState
import app.feature.social.search.SearchViewModel
import app.feature.social.viewer.PhotoViewerViewModel
import app.model.PhotoContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
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
import java.time.Instant
import java.time.LocalDate

/** `search.photos` over [FakeSocialData]: criteria, scope, paging, states; never a count (design/surfaces/search.photos.md). */
@OptIn(ExperimentalCoroutinesApi::class)
class SearchViewModelTest {
    @Before fun setUp() {
        Dispatchers.setMain(UnconfinedTestDispatcher())
    }

    @After fun tearDown() {
        Dispatchers.resetMain()
    }

    private fun hit(postId: String, at: Instant, groupId: String = GROUP, author: String = ANA) =
        PhotoSearchHit(postId, "md-$postId", groupId, author, at, listOf("caption"))

    /** A week of photos (w-1 … w-7) whose rows search answers newest first. */
    private fun seeded(): FakeSocialData = FakeSocialData().apply {
        seedWeek()
        searchHits += listOf("w-7", "w-5", "w-2").map { id -> hit(id, posts.getValue(id).createdAt, author = posts.getValue(id).authorId) }
    }

    @Test fun nothingToSearchStaysIdleAndAsksNothing() {
        val data = seeded()
        val vm = SearchViewModel(data, GROUP)
        vm.setText("   ")
        vm.search()
        assertEquals(SearchState.Phase.Idle, vm.state.value.phase)
        assertTrue("search_photos refuses an empty search: it is never asked", data.searches.isEmpty())
    }

    @Test fun theFieldsTextIsSearchedInTheGroupNewestFirst() {
        val data = seeded()
        val vm = SearchViewModel(data, GROUP)
        vm.setText("dinner")
        vm.search()
        val s = vm.state.value
        assertEquals(SearchState.Phase.Results, s.phase)
        assertEquals(listOf("w-7", "w-5", "w-2"), s.results.map { it.post.id })
        assertEquals("u/${s.results.first().post.authorId}/md-w-7/r/thumb.jpg", s.results.first().thumbPath)
        val (query, before) = data.searches.single()
        assertEquals("dinner", query.text)
        assertEquals(GROUP, query.groupId)
        assertNull(before)
        assertEquals(listOf("w-7", "w-5", "w-2"), SearchResults.postIds(vm.resultsKey))
        assertFalse(SearchResults.spansGroups(vm.resultsKey))
    }

    @Test fun aRowWhosePostCannotBeReadIsLeftOut() {
        val data = seeded().apply { searchHits += hit("gone", BASE.plusSeconds(999_999)) }
        val vm = SearchViewModel(data, GROUP)
        vm.setText("dinner")
        vm.search()
        assertEquals(listOf("w-7", "w-5", "w-2"), vm.state.value.results.map { it.post.id })
    }

    @Test fun oneMemberAtATimeAndTheChosenOneAgainClearsIt() {
        val data = seeded()
        val vm = SearchViewModel(data, GROUP)
        vm.toggleMember(ANA)
        assertEquals(ANA, vm.state.value.memberId)
        assertEquals(ANA, data.searches.last().first.memberId)
        vm.toggleMember(BEN)
        assertEquals(BEN, vm.state.value.memberId)
        vm.toggleMember(BEN)
        assertNull(vm.state.value.memberId)
        assertEquals("no criterion left: idle", SearchState.Phase.Idle, vm.state.value.phase)
    }

    @Test fun membersPutYouFirstThenJoiningOrderEachPersonOnce() {
        val data = FakeSocialData().apply {
            seedGroup()
            seedGroup("g-2", "climbing")
        }
        val one = SearchViewModel(data, GROUP).state.value.members
        assertEquals(listOf(ME, ANA, BEN), one.map { it.userId })
        assertTrue(one.first().isMe)
        assertEquals("Ana", one[1].name)
        val all = SearchViewModel(data, null).state.value.members
        assertEquals("each person once over all groups", listOf(ME, ANA, BEN), all.map { it.userId })
    }

    @Test fun theDateFilterIsOrderedAndCleared() {
        val data = seeded()
        val vm = SearchViewModel(data, GROUP)
        vm.setDates(LocalDate.parse("2026-10-18"), LocalDate.parse("2026-10-12"))
        assertEquals(LocalDate.parse("2026-10-12"), vm.state.value.from)
        assertEquals(LocalDate.parse("2026-10-18"), vm.state.value.to)
        assertEquals(LocalDate.parse("2026-10-12"), data.searches.last().first.from)
        assertEquals(SearchState.Phase.Results, vm.state.value.phase)
        vm.clearDates()
        assertFalse(vm.state.value.hasDates)
        assertEquals(SearchState.Phase.Idle, vm.state.value.phase)
    }

    @Test fun clearingTheFieldGoesBackToIdle() {
        val vm = SearchViewModel(seeded(), GROUP)
        vm.setText("dinner")
        vm.search()
        vm.setText("")
        assertEquals(SearchState.Phase.Idle, vm.state.value.phase)
        assertTrue(vm.state.value.results.isEmpty())
    }

    @Test fun nothingMatchingIsTheEmptyState() {
        val data = FakeSocialData().apply { seedWeek() }
        val vm = SearchViewModel(data, GROUP)
        vm.setText("zzz")
        vm.search()
        assertEquals(SearchState.Phase.Empty, vm.state.value.phase)
    }

    @Test fun resultsPageWithTheLastCreatedAtAndRepeatTheAskedSearch() {
        val data = FakeSocialData().apply { seedGroup() }
        (0 until 61).forEach { i ->
            val p = data.addPhoto("s-$i", ANA, BASE.minusSeconds(3_600L * (i + 1)), caption = "beach")
            data.searchHits += hit(p.id, p.createdAt)
        }
        val vm = SearchViewModel(data, GROUP)
        vm.setText("beach")
        vm.search()
        assertEquals(SearchViewModel.PAGE, vm.state.value.results.size)
        assertTrue(vm.state.value.hasMore)
        val last = vm.state.value.results.last().hit.createdAt
        vm.setText("beach and more typed meanwhile")
        vm.loadMore()
        assertEquals(61, vm.state.value.results.size)
        assertFalse(vm.state.value.hasMore)
        assertEquals(last, data.searches.last().second)
        assertEquals("beach", data.searches.last().first.text)
    }

    @Test fun errorsAndOfflineThenRetry() {
        val data = seeded()
        val vm = SearchViewModel(data, GROUP)
        vm.setText("dinner")
        data.failNext += "search"
        vm.search()
        assertEquals(SearchState.Phase.Error, vm.state.value.phase)
        data.offline = true
        vm.search()
        assertEquals(SearchState.Phase.Offline, vm.state.value.phase)
        data.offline = false
        vm.search()
        assertEquals(SearchState.Phase.Results, vm.state.value.phase)
    }

    @Test fun theViewerSwipesThroughTheResultsInTheirOrder() {
        val data = seeded()
        val vm = SearchViewModel(data, null)
        vm.setText("dinner")
        vm.search()
        assertTrue("from all groups the viewer names each photo's group", SearchResults.spansGroups(vm.resultsKey))
        val viewer = PhotoViewerViewModel(data, GROUP, "w-5", PhotoContext.Search, vm.resultsKey, null)
        assertEquals(listOf("w-7", "w-5", "w-2"), viewer.state.value.photos.map { it.postId })
        assertEquals(1, viewer.state.value.index)
        assertTrue(viewer.state.value.fromWall)
        // a key nothing was kept under (a new process): the opened photo alone
        val alone = PhotoViewerViewModel(data, GROUP, "w-5", PhotoContext.Search, "search:none", null)
        assertEquals(listOf("w-5"), alone.state.value.photos.map { it.postId })
    }
}
