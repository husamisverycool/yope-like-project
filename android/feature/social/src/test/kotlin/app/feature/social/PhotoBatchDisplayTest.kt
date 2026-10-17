package app.feature.social

import app.data.model.MessageKind
import app.data.model.PhotoBatchKey
import app.data.model.PhotoBatchPosition
import app.data.model.PhotoBatches
import app.data.model.WallItem
import app.data.model.WallItemKind
import app.data.realtime.GroupEvent
import app.feature.social.FakeSocialData.Companion.ANA
import app.feature.social.FakeSocialData.Companion.BASE
import app.feature.social.FakeSocialData.Companion.BEN
import app.feature.social.FakeSocialData.Companion.GROUP
import app.feature.social.FakeSocialData.Companion.message
import app.feature.social.chat.ChatViewModel
import app.feature.social.chat.ThreadItem
import app.feature.social.chat.threadItems
import app.feature.social.viewer.PhotoViewerViewModel
import app.feature.social.walls.WallTile
import app.feature.social.walls.WallViewModel
import app.model.PhotoContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test
import java.time.ZoneOffset

/**
 * Several photos posted together (owner decision 34, research #1; `layout.global.photoBatch`): one thread item
 * (`chat.thread.layout.batch`), the viewer's order and dots (`photo.viewer.layout.batchDots`), the wall's batch ids.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class PhotoBatchDisplayTest {
    private val batchId = "6a3b0c1d-2e3f-4a5b-8c7d-9e0f1a2b3c4d"

    @Before fun setUp() = Dispatchers.setMain(UnconfinedTestDispatcher())

    @After fun tearDown() = Dispatchers.resetMain()

    /** Ana's three photos posted together, seconds apart, each with its photo message; [between] adds Ben's text after the second. */
    private fun batchData(between: Boolean = false): FakeSocialData = FakeSocialData().apply {
        seedGroup()
        (1..3).forEach { i ->
            val at = BASE.plusSeconds(60L + i)
            posts["b-$i"] = addPhoto("b-$i", ANA, at).copy(batchId = batchId)
            messages += message("mb-$i", GROUP, ANA, MessageKind.Photo, postId = "b-$i", at = at)
        }
        if (between) messages += message("mt-1", GROUP, BEN, MessageKind.Text, body = "wow", at = BASE.plusSeconds(62).plusMillis(500))
        addPhoto("x-1", BEN, BASE.plusSeconds(30))
    }

    private fun items(data: FakeSocialData): List<ThreadItem.Item> =
        threadItems(ChatViewModel(data, GROUP).state.value.rows, ZoneOffset.UTC).filterIsInstance<ThreadItem.Item>()

    // ---- chat.thread ----

    @Test fun aBatchIsOneThreadItemLedByItsFirstPhoto() {
        val photos = items(batchData()).filter { it.row.kind == MessageKind.Photo }
        assertEquals(listOf("mb-1"), photos.map { it.row.id })
        assertEquals(listOf("b-2", "b-3"), photos.single().row.batch)
        assertEquals(true, photos.single().row.isBatch)
    }

    @Test fun aMessageBetweenSplitsTheBatch() {
        val all = items(batchData(between = true))
        assertEquals(listOf("mb-1", "mt-1", "mb-3"), all.map { it.row.id })
        assertEquals(listOf(listOf("b-2"), emptyList(), emptyList()), all.map { it.row.batch })
    }

    @Test fun photosWithoutABatchKeepOneItemEach() {
        val data = batchData()
        (1..3).forEach { i -> data.posts["b-$i"] = data.posts.getValue("b-$i").copy(batchId = null) }
        val all = items(data)
        assertEquals(listOf("mb-1", "mb-2", "mb-3"), all.map { it.row.id })
        assertEquals(listOf(false, false, false), all.map { it.row.isBatch })
        assertEquals(listOf(true, false, false), all.map { it.startsRun })
    }

    @Test fun aDeletedPhotoOfTheBatchLeavesTheRest() = runBlocking {
        val data = batchData()
        val vm = ChatViewModel(data, GROUP)
        data.emit(GroupEvent.PostDeleted(GROUP, "b-2", null))
        val photos = threadItems(vm.state.value.rows, ZoneOffset.UTC).filterIsInstance<ThreadItem.Item>()
        assertEquals(listOf("mb-1"), photos.map { it.row.id })
        assertEquals(listOf("b-3"), photos.single().row.batch)
    }

    // ---- photo.viewer ----

    @Test fun aLinkToABatchPhotoOpensTheWholeBatchWithDots() {
        val vm = PhotoViewerViewModel(batchData(), GROUP, "b-2", PhotoContext.Reveal, "b-2", null)
        val s = vm.state.value
        assertEquals(listOf("b-1", "b-2", "b-3"), s.photos.map { it.postId })
        assertEquals(1, s.index)
        assertEquals(PhotoBatchPosition(2, 3), s.batchPosition("b-2"))
    }

    @Test fun aWallOrderGetsTheBatchSideBySideInPostedOrder() {
        val data = batchData()
        // newest first, someone's photo between
        data.walls[ANA] = mutableListOf("b-3", "x-1", "b-2", "b-1").map { id ->
            val p = data.posts.getValue(id)
            WallItem(WallItemKind.Post, p.id, p.mediaId, null, listOf(GROUP), BASE.plusSeconds(200L - listOf("b-3", "x-1", "b-2", "b-1").indexOf(id)))
        }.toMutableList()
        val vm = PhotoViewerViewModel(data, GROUP, "b-2", PhotoContext.Wall, ANA, null)
        val s = vm.state.value
        assertEquals(listOf("b-1", "b-2", "b-3", "x-1"), s.photos.map { it.postId })
        assertEquals("b-2", s.current?.postId)
        assertEquals(PhotoBatchPosition(2, 3), s.batchPosition("b-2"))
        assertNull("dots only within the batch", s.batchPosition("x-1"))
    }

    @Test fun aPhotoPostedAloneHasNoDotsAndABatchFailureKeepsThePhoto() {
        val alone = PhotoViewerViewModel(batchData(), GROUP, "x-1", PhotoContext.Reveal, "x-1", null)
        assertEquals(listOf("x-1"), alone.state.value.photos.map { it.postId })
        assertNull(alone.state.value.batchPosition("x-1"))

        val data = batchData().apply { failNext += "batchOf" }
        val failed = PhotoViewerViewModel(data, GROUP, "b-2", PhotoContext.Reveal, "b-2", null)
        assertEquals(listOf("b-2"), failed.state.value.photos.map { it.postId })
        assertNull(failed.state.value.batchPosition("b-2"))
    }

    // ---- walls ----

    @Test fun wallTilesCarryTheirBatchAndGroupIntoOneRun() {
        val data = batchData()
        (1..3).forEach { i ->
            val p = data.posts.getValue("b-$i")
            data.media[p.mediaId] = data.media.getValue(p.mediaId).copy(batchId = batchId)
        }
        data.walls[ANA] = (1..3).map { i ->
            val p = data.posts.getValue("b-$i")
            WallItem(WallItemKind.Post, p.id, p.mediaId, null, listOf(GROUP), p.createdAt)
        }.toMutableList()
        val tiles = WallViewModel(data, ANA).state.value.tiles.filterIsInstance<WallTile.Photo>()
        val runs = PhotoBatches.runs(tiles.sortedBy { it.createdAt }) { t -> t.batchId?.let { PhotoBatchKey(ANA, it) } }
        assertEquals(listOf(listOf("b-1", "b-2", "b-3")), runs.map { run -> run.map { it.postId } })
    }
}
