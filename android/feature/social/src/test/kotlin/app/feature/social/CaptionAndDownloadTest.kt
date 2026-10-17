package app.feature.social

import app.data.model.DownloadItem
import app.data.model.DownloadScope
import app.data.model.MediaKind
import app.data.realtime.GroupEvent
import app.feature.social.FakeSocialData.Companion.BASE
import app.feature.social.FakeSocialData.Companion.GROUP
import app.feature.social.FakeSocialData.Companion.ME
import app.feature.social.albums.AlbumEffect
import app.feature.social.albums.AlbumViewModel
import app.feature.social.downloads.DownloadCursor
import app.feature.social.downloads.DownloadCursors
import app.feature.social.downloads.DownloadEffect
import app.feature.social.downloads.DownloadSaver
import app.feature.social.downloads.DownloadUiState
import app.feature.social.downloads.DownloadViewModel
import app.feature.social.viewer.PhotoViewerViewModel
import app.feature.social.viewer.ViewerEffect
import app.model.PhotoContext
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/**
 * Editing a caption (owner decision 34, research #8) and downloads (decisions 29 and 34, research #2: all my photos free,
 * an album premium). Specs: design/surfaces/photo.viewer.md, settings.downloads.md, albums.view.md. No new image captures.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class CaptionAndDownloadTest {
    private val effects = CoroutineScope(SupervisorJob() + UnconfinedTestDispatcher())

    @Before fun setUp() {
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

    // ---- caption (photo.viewer.layout.editCaption) ----

    @Test fun onlyYourOwnPhotoOffersTheCaptionItem() {
        val data = viewerData()
        val theirs = PhotoViewerViewModel(data, GROUP, "v-1", PhotoContext.Album, "a-v", null)
        assertFalse(theirs.state.value.canEditCaption)
        assertTrue("Ana's photo has a caption", theirs.state.value.hasCaption)
        val mine = PhotoViewerViewModel(data, GROUP, "v-2", PhotoContext.Album, "a-v", null)
        assertTrue(mine.state.value.canEditCaption)
        assertFalse("no caption yet: Add a Caption", mine.state.value.hasCaption)
        theirs.saveCaption("not mine")
        assertFalse(data.calls.any { it.startsWith("editCaption") })
    }

    @Test fun savingACaptionShowsItWithEditedAndBlankRemovesIt() {
        val data = viewerData()
        val vm = PhotoViewerViewModel(data, GROUP, "v-2", PhotoContext.Single, "v-2", null)
        assertNull(vm.state.value.current!!.post!!.captionEditedAt)
        vm.saveCaption("  first light  ")
        assertTrue(data.calls.contains("editCaption:v-2"))
        assertEquals("first light", vm.state.value.current!!.post!!.caption)
        assertNotNull("the date line reads '… · Edited'", vm.state.value.current!!.post!!.captionEditedAt)
        assertEquals("first light", data.posts.getValue("v-2").caption)

        // The same text again sends nothing.
        val before = data.calls.size
        vm.saveCaption("first light")
        assertEquals(before, data.calls.size)

        vm.saveCaption("   ")
        assertNull(vm.state.value.current!!.post!!.caption)
        assertFalse(vm.state.value.hasCaption)
    }

    @Test fun aFailedCaptionEditKeepsTheCaption() {
        val data = viewerData().apply { posts["v-2"] = posts.getValue("v-2").copy(caption = "dawn") }
        val vm = PhotoViewerViewModel(data, GROUP, "v-2", PhotoContext.Single, "v-2", null)
        val out = collect(vm.effects)
        data.failNext += "editCaption:v-2"
        vm.saveCaption("dusk")
        assertEquals("dawn", vm.state.value.current!!.post!!.caption)
        assertNull(vm.state.value.current!!.post!!.captionEditedAt)
        assertEquals(listOf<ViewerEffect>(ViewerEffect.CaptionFailed), out)
    }

    @Test fun theCaptionStopsAtTheAPILimit() {
        val data = viewerData()
        val vm = PhotoViewerViewModel(data, GROUP, "v-2", PhotoContext.Single, "v-2", null)
        vm.saveCaption("a".repeat(PhotoViewerViewModel.CAPTION_MAX + 5))
        assertEquals(PhotoViewerViewModel.CAPTION_MAX, vm.state.value.current!!.post!!.caption!!.length)
    }

    @Test fun anotherDevicesEditArrivesLive() = runBlocking {
        val data = viewerData()
        val vm = PhotoViewerViewModel(data, GROUP, "v-1", PhotoContext.Single, "v-1", null)
        val edited = data.posts.getValue("v-1").copy(caption = "sunday sunsets!", captionEditedAt = BASE)
        data.emit(GroupEvent.PostUpdated(GROUP, edited))
        assertEquals("sunday sunsets!", vm.state.value.current!!.post!!.caption)
        assertEquals(BASE, vm.state.value.current!!.post!!.captionEditedAt)
        assertNotNull("the media stays", vm.state.value.current!!.media)
    }

    // ---- downloads (settings.downloads) ----

    private class MemoryCursors : DownloadCursors {
        val map = HashMap<String, DownloadCursor>()
        override fun get(key: String): DownloadCursor? = map[key]
        override fun put(key: String, cursor: DownloadCursor?) {
            if (cursor == null) map.remove(key) else map[key] = cursor
        }
    }

    /** Saves and records; fails ([ok] false) once [failAfter] photos were saved. */
    private class RecordingSaver(var failAfter: Int = Int.MAX_VALUE) : DownloadSaver {
        val saved = ArrayList<String>()
        var gate: CompletableDeferred<Unit>? = null
        override suspend fun save(item: DownloadItem): Boolean {
            gate?.await()
            if (saved.size >= failAfter) return false
            saved += item.postId
            return true
        }
    }

    private fun items(count: Int): List<DownloadItem> = (0 until count).map { i ->
        DownloadItem(
            postId = "d-$i", mediaId = "md-d-$i", kind = if (i == 1) MediaKind.LivePhoto else MediaKind.Photo,
            originalPath = "u/$ME/md-d-$i/original.jpg", motionPath = if (i == 1) "u/$ME/md-d-$i/motion.mov" else null,
            postedAt = BASE.minusSeconds(60L * i),
        )
    }

    @Test fun everyOneOfMyPhotosIsSavedNewestFirst() {
        val data = FakeSocialData().apply { downloads += items(4) }
        val saver = RecordingSaver()
        val vm = DownloadViewModel(data, DownloadScope.Mine, saver, MemoryCursors())
        val out = collect(vm.effects)
        assertEquals(DownloadUiState.Phase.Idle, vm.state.value.phase)
        assertFalse(vm.state.value.canResume)
        vm.start()
        assertEquals(listOf("d-0", "d-1", "d-2", "d-3"), saver.saved)
        assertEquals(DownloadUiState.Phase.Done, vm.state.value.phase)
        assertNull("your photos: an indeterminate bar, never a figure", vm.state.value.fraction)
        assertEquals(listOf<DownloadEffect>(DownloadEffect.Done), out)
    }

    @Test fun fullPagesAreFollowedUntilAShortPage() {
        val all = items(app.data.repo.PostRepository.DOWNLOAD_PAGE + 2)
        val data = FakeSocialData().apply { downloads += all }
        val saver = RecordingSaver()
        DownloadViewModel(data, DownloadScope.Mine, saver, MemoryCursors()).start()
        assertEquals(all.size, saver.saved.size)
        assertEquals(listOf(null, all[app.data.repo.PostRepository.DOWNLOAD_PAGE - 1].postedAt), data.downloadCursors)
    }

    @Test fun aFailureKeepsThePlaceAndContinueGoesOnFromIt() {
        val all = items(4)
        val data = FakeSocialData().apply { downloads += all }
        val cursors = MemoryCursors()
        val failing = RecordingSaver(failAfter = 2)
        val first = DownloadViewModel(data, DownloadScope.Mine, failing, cursors)
        val out = collect(first.effects)
        first.start()
        assertEquals(DownloadUiState.Phase.Failed, first.state.value.phase)
        assertTrue("Continue", first.state.value.canResume)
        assertEquals(listOf<DownloadEffect>(DownloadEffect.Failed), out)

        // The page opened again: Continue goes on before the last saved photo.
        val saver = RecordingSaver()
        val again = DownloadViewModel(data, DownloadScope.Mine, saver, cursors)
        assertTrue(again.state.value.canResume)
        again.start()
        assertEquals(listOf("d-2", "d-3"), saver.saved)
        assertEquals(all[1].postedAt, data.downloadCursors.last())
        assertEquals(DownloadUiState.Phase.Done, again.state.value.phase)
        assertFalse("done: the place is forgotten", again.state.value.canResume)
    }

    @Test fun cancelStopsAfterThePhotoBeingSaved() {
        val data = FakeSocialData().apply { downloads += items(3) }
        val cursors = MemoryCursors()
        val saver = RecordingSaver().apply { gate = CompletableDeferred() }
        val vm = DownloadViewModel(data, DownloadScope.Mine, saver, cursors)
        vm.start()
        assertTrue(vm.state.value.running)
        vm.cancel()
        assertEquals(DownloadUiState.Phase.Idle, vm.state.value.phase)
        assertTrue(saver.saved.isEmpty())
        assertFalse("nothing saved yet: Download", vm.state.value.canResume)
    }

    @Test fun offlineAndNothingToDownload() {
        val empty = DownloadViewModel(FakeSocialData(), DownloadScope.Mine, RecordingSaver(), MemoryCursors())
        empty.start()
        assertEquals(DownloadUiState.Phase.Empty, empty.state.value.phase)

        val data = FakeSocialData().apply { downloads += items(1); offline = true }
        val offline = DownloadViewModel(data, DownloadScope.Mine, RecordingSaver(), MemoryCursors())
        offline.start()
        assertEquals(DownloadUiState.Phase.Offline, offline.state.value.phase)
    }

    @Test fun deniedAccessShowsTheAlert() {
        val vm = DownloadViewModel(FakeSocialData(), DownloadScope.Mine, RecordingSaver(), MemoryCursors())
        val out = collect(vm.effects)
        vm.accessDenied()
        assertTrue(vm.state.value.denied)
        assertEquals(listOf<DownloadEffect>(DownloadEffect.Failed), out)
        vm.dismissDenied()
        assertFalse(vm.state.value.denied)
    }

    @Test fun anAlbumSavesInAlbumOrderWithABarAndResumes() {
        val rows = items(3)
        val data = FakeSocialData().apply { albumDownloads["a-1"] = rows }
        val cursors = MemoryCursors()
        val first = DownloadViewModel(data, DownloadScope.InAlbum("a-1"), RecordingSaver(failAfter = 1), cursors)
        first.start()
        assertEquals(DownloadUiState.Phase.Failed, first.state.value.phase)
        assertEquals(1f / 3f, first.state.value.fraction!!, 0.0001f)

        val saver = RecordingSaver()
        val again = DownloadViewModel(data, DownloadScope.InAlbum("a-1"), saver, cursors)
        assertTrue(again.state.value.canResume)
        again.start()
        assertEquals(listOf("d-1", "d-2"), saver.saved)
        assertEquals(1f, again.state.value.fraction!!, 0.0001f)
    }

    @Test fun anAlbumWithoutPremiumAsksForThePaywall() {
        val data = FakeSocialData().apply {
            albumDownloads["a-1"] = items(1)
            downloadsNeedPremium = true
        }
        val vm = DownloadViewModel(data, DownloadScope.InAlbum("a-1"), RecordingSaver(), MemoryCursors())
        val out = collect(vm.effects)
        vm.start()
        assertEquals(listOf<DownloadEffect>(DownloadEffect.Paywall), out)
        assertEquals(DownloadUiState.Phase.Idle, vm.state.value.phase)
    }

    @Test fun downloadAlbumOpensTheDownloadWithPremiumAndThePaywallWithout() {
        val free = FakeSocialData().apply { seedAlbums() }
        val freeVm = AlbumViewModel(free, GROUP, "a-1")
        val freeOut = collect(freeVm.effects)
        assertFalse(freeVm.state.value.premium)
        freeVm.download()
        assertEquals(listOf<AlbumEffect>(AlbumEffect.OpenPaywall), freeOut)

        val paid = FakeSocialData().apply { seedAlbums(); premium = true }
        val paidVm = AlbumViewModel(paid, GROUP, "a-1")
        val paidOut = collect(paidVm.effects)
        assertTrue(paidVm.state.value.premium)
        paidVm.download()
        assertEquals(listOf<AlbumEffect>(AlbumEffect.OpenDownload), paidOut)
    }

    @Test fun cursorsAreKeptPerAccountAndScope() {
        assertEquals("u.mine", DownloadViewModel.cursorKey("u", DownloadScope.Mine))
        assertEquals("u.album.a-1", DownloadViewModel.cursorKey("u", DownloadScope.InAlbum("a-1")))
    }
}
