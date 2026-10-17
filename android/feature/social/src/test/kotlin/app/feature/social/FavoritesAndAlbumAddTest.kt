package app.feature.social

import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import app.data.model.MemberRole
import app.feature.social.FakeSocialData.Companion.ANA
import app.feature.social.FakeSocialData.Companion.BASE
import app.feature.social.FakeSocialData.Companion.BEN
import app.feature.social.FakeSocialData.Companion.GROUP
import app.feature.social.FakeSocialData.Companion.ME
import app.feature.social.albums.AlbumAddContent
import app.feature.social.albums.AlbumAddViewModel
import app.feature.social.albums.AlbumEffect
import app.feature.social.albums.AlbumPickerContent
import app.feature.social.albums.AlbumPickerViewModel
import app.feature.social.albums.AlbumViewModel
import app.feature.social.albums.AlbumsState
import app.feature.social.albums.AlbumsViewModel
import app.feature.social.viewer.PhotoViewerViewModel
import app.feature.social.viewer.ViewerEffect
import app.feature.social.walls.FavoritesContent
import app.feature.social.walls.FavoritesNav
import app.feature.social.walls.FavoritesState
import app.feature.social.walls.FavoritesViewModel
import app.model.PhotoContext
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.robolectric.annotation.Config

/**
 * Private favorites, a photo as the group cover and albums anyone can add to (owner decision 34; research #19, #14, #10):
 * the viewer's menu actions, the favorites grid, the album picker, the add sheet and removing from an album. Specs:
 * design/surfaces/photo.viewer.md, favorites.md, albums.view.md. Semantics only (no new snapshot baselines).
 */
@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(AndroidJUnit4::class)
@Config(qualifiers = "w393dp-h852dp-xhdpi")
class FavoritesAndAlbumAddTest {
    @get:Rule val compose = createComposeRule()
    private val effects = CoroutineScope(SupervisorJob() + UnconfinedTestDispatcher())

    @Before fun setUp() {
        fixLocale()
        Dispatchers.setMain(UnconfinedTestDispatcher())
    }

    @After fun tearDown() {
        effects.cancel()
        Dispatchers.resetMain()
    }

    private fun <T> collect(flow: kotlinx.coroutines.flow.Flow<T>): MutableList<T> {
        val out = ArrayList<T>()
        effects.launch { flow.collect { out += it } }
        return out
    }

    private fun FakeSocialData.makeMeAdmin() {
        members[GROUP] = members.getValue(GROUP).map { m ->
            if (m.member.userId == ME) m.copy(member = m.member.copy(role = MemberRole.Admin)) else m
        }.toMutableList()
    }

    // ---- photo.viewer: Favorite / Unfavorite ----

    @Test fun favoriteTogglesAtOnceAndIsReadFromMyOwnRows() {
        val data = viewerData().apply { favorites["md-v-2"] = BASE }
        val vm = PhotoViewerViewModel(data, GROUP, "v-1", PhotoContext.Album, "a-v", null)
        assertFalse(vm.state.value.favorite)
        vm.toggleFavorite()
        assertTrue("Unfavorite is offered now", vm.state.value.favorite)
        assertTrue("md-v-1" in data.favorites)
        vm.toggleFavorite()
        assertFalse(vm.state.value.favorite)
        assertFalse("md-v-1" in data.favorites)
        vm.select(1)
        assertTrue("my own favorites rows say v-2 is one", vm.state.value.favorite)
    }

    @Test fun failedFavoriteGoesBack() {
        val data = viewerData().apply { failNext += "setFavorite:md-v-1:true" }
        val vm = PhotoViewerViewModel(data, GROUP, "v-1", PhotoContext.Album, "a-v", null)
        val out = collect(vm.effects)
        vm.toggleFavorite()
        assertFalse("the heart goes back", vm.state.value.favorite)
        assertEquals(listOf<ViewerEffect>(ViewerEffect.FavoriteFailed), out)
    }

    // ---- photo.viewer: Use as Cover ----

    @Test fun useAsCoverIsForGroupAdminsOnly() {
        val member = PhotoViewerViewModel(viewerData(), GROUP, "v-1", PhotoContext.Album, "a-v", null)
        assertFalse("I am not an admin", member.state.value.canUseAsCover)

        val data = viewerData().apply { makeMeAdmin() }
        val vm = PhotoViewerViewModel(data, GROUP, "v-1", PhotoContext.Album, "a-v", null)
        val out = collect(vm.effects)
        assertTrue(vm.state.value.canUseAsCover)
        vm.useAsCover()
        assertEquals("v-1", data.coverPosts[GROUP])
        assertEquals(listOf<ViewerEffect>(ViewerEffect.CoverSet), out)

        data.renditionsPending += "v-2"
        vm.select(1)
        vm.useAsCover()
        assertEquals(ViewerEffect.CoverNotReady, out.last())
        assertEquals("v-1", data.coverPosts[GROUP])
    }

    // ---- favorites ----

    @Test fun favoritesNewestFirstAndTheirStates() {
        val data = viewerData().apply {
            favorites["md-v-1"] = BASE.plusSeconds(10)
            favorites["md-v-3"] = BASE.plusSeconds(20)
        }
        val vm = FavoritesViewModel(data)
        vm.load()
        val s = vm.state.value
        assertEquals(FavoritesState.Phase.Ready, s.phase)
        assertEquals(listOf("v-3", "v-1"), s.tiles.map { it.favorite.postId })
        assertEquals("Ben", s.tiles.first().authorName)

        val empty = FavoritesViewModel(viewerData()).apply { load() }
        assertEquals(FavoritesState.Phase.Empty, empty.state.value.phase)

        val offline = FavoritesViewModel(viewerData().apply { this.offline = true }).apply { load() }
        assertEquals(FavoritesState.Phase.OfflineEmpty, offline.state.value.phase)

        val failing = FavoritesViewModel(viewerData().apply { failNext += "myFavorites" }).apply { load() }
        assertEquals(FavoritesState.Phase.Error, failing.state.value.phase)
    }

    @Test fun favoritesGridOpensTheViewerAndShowsItsStates() {
        val data = viewerData().apply { favorites["md-v-3"] = BASE }
        val vm = FavoritesViewModel(data).apply { load() }
        var opened: Pair<String, String>? = null
        var state by mutableStateOf(vm.state.value)
        compose.setContent {
            TestScreen(data) {
                FavoritesContent(state, FavoritesNav(back = {}, photo = { g, p -> opened = g to p }), onRetry = {}, onMore = {})
            }
        }
        compose.onNodeWithText("Favorites").assertExists()
        compose.onNodeWithText("Nothing to see here yet").assertDoesNotExist()
        compose.onNodeWithContentDescription("Ben's photo", substring = true).performClick()
        assertEquals(GROUP to "v-3", opened)

        state = FavoritesState(phase = FavoritesState.Phase.Empty)
        compose.onNodeWithText("Nothing to see here yet").assertExists()
        compose.onNodeWithText("Photos you favorite will show up here. Only you can see them.").assertExists()
        state = FavoritesState(phase = FavoritesState.Phase.Error)
        compose.onNodeWithText("Error loading your favorites. Tap here to try again.").assertExists()
    }

    // ---- photo.viewer: the album picker ----

    @Test fun albumPickerAddsThePhotoOrMakesANewAlbum() {
        val data = FakeSocialData().apply { seedAlbums() }
        val picker = AlbumPickerViewModel(data, GROUP, "w-0")
        picker.add("a-1")
        assertTrue(picker.state.value.done)
        assertEquals(listOf("w-2", "w-1", "w-0"), data.albumItems.getValue("a-1").sortedBy { it.position }.map { it.postId })
        assertEquals(ME, data.albumItems.getValue("a-1").first { it.postId == "w-0" }.addedBy)

        val naming = AlbumPickerViewModel(data, GROUP, "w-0")
        naming.startNaming()
        naming.setName("   ")
        naming.create()
        assertTrue(naming.state.value.nameMissing)
        assertFalse(naming.state.value.done)
        naming.setName("cleo's best")
        naming.create()
        assertTrue(naming.state.value.done)
        assertTrue(data.calls.contains("saveAlbum:cleo's best:w-0"))
    }

    @Test fun albumPickerListsTheGroupsAlbumsUnderNewAlbum() {
        val data = FakeSocialData().apply { seedAlbums() }
        val albums = AlbumsViewModel(data, GROUP)
        var added: String? = null
        var newAlbum = false
        compose.setContent {
            TestScreen(data) {
                AlbumPickerContent(albums.state.value, onClose = {}, onNew = { newAlbum = true }, onAlbum = { added = it }, onRetry = {})
            }
        }
        compose.onNodeWithText("Add to Album").assertExists()
        compose.onNodeWithText("New Album").performClick()
        assertTrue(newAlbum)
        compose.onNodeWithText("lake weekend").performClick()
        assertEquals("a-1", added)
        assertEquals(AlbumsState.Phase.Ready, albums.state.value.phase)
    }

    // ---- albums.view: add and remove ----

    @Test fun addSheetOffersPhotosTheAlbumLacksInPickOrder() {
        val data = FakeSocialData().apply { seedAlbums() }
        val vm = AlbumAddViewModel(data, GROUP, "a-1", setOf("w-1", "w-2"))
        val shown = vm.state.value.photos.map { it.post.id }
        assertFalse("w-1" in shown)
        assertFalse("w-2" in shown)
        assertEquals("newest week first, newest photo first", "w-7", shown.first())
        assertFalse(vm.state.value.canAdd)
        vm.toggle("w-5")
        vm.toggle("w-3")
        assertEquals(listOf("w-5", "w-3"), vm.state.value.picked)
        vm.add()
        assertTrue(vm.state.value.done)
        assertEquals(listOf("w-2", "w-1", "w-5", "w-3"), data.albumItems.getValue("a-1").sortedBy { it.position }.map { it.postId })
    }

    @Test fun addSheetButtonWaitsForAPick() {
        val data = FakeSocialData().apply { seedAlbums() }
        val vm = AlbumAddViewModel(data, GROUP, "a-1", setOf("w-1", "w-2"))
        compose.setContent {
            TestScreen(data) {
                val state by vm.state.collectAsState()
                AlbumAddContent(state, onToggle = vm::toggle, onAdd = vm::add, onRetry = {}, onClose = {})
            }
        }
        compose.onNodeWithTag("albums.view.add").assertExists()
        compose.onNodeWithText("Add").assertIsNotEnabled()
        vm.toggle("w-3")
        compose.onNodeWithText("Add").assertIsEnabled()
    }

    @Test fun removeOnlyWhatYouAddedUnlessCreatorOrAdmin() {
        val data = FakeSocialData().apply { seedAlbums() }
        kotlinx.coroutines.runBlocking { data.addToAlbum("a-1", listOf("w-3")) }
        val vm = AlbumViewModel(data, GROUP, "a-1")
        val out = collect(vm.effects)
        val s = vm.state.value
        assertFalse(s.canDelete)
        assertFalse("Ana's album, not added by me", s.canRemove("w-1"))
        assertTrue("I added it", s.canRemove("w-3"))
        vm.remove("w-1")
        assertEquals(listOf("w-2", "w-1", "w-3"), vm.state.value.photos.map { it.post.id })
        vm.remove("w-3")
        assertEquals(listOf("w-2", "w-1"), vm.state.value.photos.map { it.post.id })
        assertEquals(listOf<AlbumEffect>(AlbumEffect.Removed), out)
        assertTrue("the photo stays in the group", "w-3" in data.posts)

        val creator = AlbumViewModel(FakeSocialData(me = ANA).apply { seedAlbums() }, GROUP, "a-1")
        assertTrue(creator.state.value.canRemove("w-1"))
    }

    @Test fun removeRefusedPutsThePhotoBack() {
        val data = FakeSocialData().apply { seedAlbums() }
        kotlinx.coroutines.runBlocking { data.addToAlbum("a-1", listOf("w-3")) }
        val vm = AlbumViewModel(data, GROUP, "a-1")
        val out = collect(vm.effects)
        // Meanwhile the server's row says someone else added it.
        val items = data.albumItems.getValue("a-1")
        items.replaceAll { if (it.postId == "w-3") it.copy(addedBy = BEN) else it }
        vm.remove("w-3")
        assertEquals(listOf("w-2", "w-1", "w-3"), vm.state.value.photos.map { it.post.id })
        assertEquals(listOf<AlbumEffect>(AlbumEffect.RemoveNotAllowed), out)
        assertNull(data.coverPosts[GROUP])
    }
}
