package app.data

import app.data.model.DataJson
import app.data.model.PhotoBatchKey
import app.data.model.PhotoBatchPosition
import app.data.model.PhotoBatches
import app.data.model.Post
import app.data.model.batchKey
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** Several photos posted together (migration 0051, `layout.global.photoBatch`): grouping, the viewer's order and its dots. */
class PhotoBatchesTest {
    private data class Item(val id: String, val key: PhotoBatchKey?)

    private fun item(id: String, author: String? = null, batch: String? = null) =
        Item(id, if (author != null && batch != null) PhotoBatchKey(author, batch) else null)

    private fun ids(runs: List<List<Item>>) = runs.map { run -> run.map { it.id } }

    @Test fun postDecodesBatchIdAndKeepsNullWithoutIt() {
        val json = """
            {"id":"p1","media_id":"m1","group_id":"g1","author_id":"u1","caption":null,"voice_path":null,
             "voice_duration_ms":null,"invitation_id":null,"in_window":false,"reply_to_post_id":null,
             "created_at":"2026-10-15T13:35:09.329469+00:00","batch_id":"6A3B0C1D-2E3F-4A5B-8C7D-9E0F1A2B3C4D"}
        """
        val post = DataJson.decodeFromString(Post.serializer(), json)
        assertEquals("6A3B0C1D-2E3F-4A5B-8C7D-9E0F1A2B3C4D", post.batchId)
        assertEquals(PhotoBatchKey("u1", "6a3b0c1d-2e3f-4a5b-8c7d-9e0f1a2b3c4d"), post.batchKey)
        val alone = DataJson.decodeFromString(Post.serializer(), json.replace(",\"batch_id\":\"6A3B0C1D-2E3F-4A5B-8C7D-9E0F1A2B3C4D\"", ""))
        assertNull(alone.batchId)
        assertNull(alone.batchKey)
    }

    @Test fun sameAuthorAndBatchConsecutiveIsOneRun() {
        val runs = PhotoBatches.runs(listOf(item("1", "ana", "b"), item("2", "ana", "b"), item("3", "ana", "b"))) { it.key }
        assertEquals(listOf(listOf("1", "2", "3")), ids(runs))
    }

    @Test fun photosWithoutBatchStandAlone() {
        val runs = PhotoBatches.runs(listOf(item("1", "ana"), item("2", "ana"), item("3"))) { it.key }
        assertEquals(listOf(listOf("1"), listOf("2"), listOf("3")), ids(runs))
    }

    @Test fun otherAuthorOrOtherBatchStartsANewRun() {
        val runs = PhotoBatches.runs(
            listOf(item("1", "ana", "b"), item("2", "ana", "b"), item("3", "ben", "b"), item("4", "ana", "c"), item("5", "ana", "c")),
        ) { it.key }
        assertEquals(listOf(listOf("1", "2"), listOf("3"), listOf("4", "5")), ids(runs))
    }

    @Test fun anInterruptionSplitsTheBatchIntoTwoRuns() {
        val runs = PhotoBatches.runs(listOf(item("1", "ana", "b"), item("2", "ana", "b"), item("m"), item("3", "ana", "b"))) { it.key }
        assertEquals(listOf(listOf("1", "2"), listOf("m"), listOf("3")), ids(runs))
    }

    @Test fun aDeletedPhotoLeavesTheRestTogether() {
        val all = listOf(item("1", "ana", "b"), item("2", "ana", "b"), item("3", "ana", "b"))
        assertEquals(listOf(listOf("1", "3")), ids(PhotoBatches.runs(all.filter { it.id != "2" }) { it.key }))
        assertEquals(listOf(listOf("3")), ids(PhotoBatches.runs(all.filter { it.id == "3" }) { it.key }))
    }

    @Test fun batchIdsCompareWithoutCase() {
        assertEquals(PhotoBatchKey("ana", "ABC"), PhotoBatchKey("ana", "abc"))
    }

    @Test fun gatherPutsTheBatchSideBySideInPostedOrder() {
        // a wall (newest first) holds the batch reversed, with someone's photo between
        assertEquals(listOf("x", "1", "2", "3", "y", "z"), PhotoBatches.gather(listOf("x", "3", "y", "2", "1", "z"), listOf("1", "2", "3")))
        assertEquals(listOf("1", "2", "3", "x"), PhotoBatches.gather(listOf("1", "2", "3", "x"), listOf("1", "2", "3")))
        // members the context does not hold are not added
        assertEquals(listOf("x", "1", "3"), PhotoBatches.gather(listOf("x", "3", "1"), listOf("1", "2", "3")))
        // one member or none: unchanged
        assertEquals(listOf("x", "3"), PhotoBatches.gather(listOf("x", "3"), listOf("1", "2", "3")))
    }

    @Test fun positionIsWithinTheBatchOnly() {
        val context = listOf("x", "1", "2", "3", "y")
        assertEquals(PhotoBatchPosition(2, 3), PhotoBatches.position("2", context, listOf("1", "2", "3")))
        assertNull(PhotoBatches.position("x", context, listOf("1", "2", "3")))
        // a deleted member leaves the rest
        assertEquals(PhotoBatchPosition(2, 2), PhotoBatches.position("3", listOf("1", "3"), listOf("1", "2", "3")))
        // a batch with one photo left has no dots
        assertNull(PhotoBatches.position("3", listOf("3"), listOf("1", "2", "3")))
    }
}
