package app.data

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.work.BackoffPolicy
import androidx.work.Data
import androidx.work.ListenableWorker
import androidx.work.NetworkType
import androidx.work.WorkInfo
import androidx.work.WorkManager
import androidx.work.WorkerFactory
import androidx.work.WorkerParameters
import androidx.work.testing.TestListenableWorkerBuilder
import androidx.work.workDataOf
import app.data.error.ApiError
import app.data.error.DataError
import app.data.error.DataErrorCodec
import app.data.error.DataException
import app.data.error.StorageFailure
import app.data.integration.initTestWorkManager
import app.data.media.upload.NewPost
import app.data.media.upload.PostRemote
import app.data.media.upload.PostUploader
import app.data.media.upload.UploadOutcome
import app.data.media.upload.UploadProgress
import app.data.media.upload.UploadQueue
import app.data.media.upload.UploadStep
import app.data.media.upload.UploadStore
import app.data.media.upload.UploadWorker
import app.data.model.DevelopingPost
import app.data.model.MediaKind
import app.data.model.NewMedia
import app.data.model.Post
import app.data.repo.PostOptions
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import java.io.File
import java.time.Instant
import java.util.UUID
import java.util.concurrent.TimeUnit

/** The upload pipeline: resumable uploader logic, the queue's WorkManager wiring, the worker's results. */
@RunWith(AndroidJUnit4::class)
class UploadTest {
    @get:Rule val tmp = TemporaryFolder()

    private val context: Context = ApplicationProvider.getApplicationContext()
    private lateinit var store: UploadStore
    private val userId = "9f0c2b7e-1111-4111-8111-111111111111"

    /** Records calls; each step can be made to fail once with a given error. */
    private class FakeRemote : PostRemote {
        val uploads = mutableListOf<String>()
        val inserted = mutableListOf<String>()
        val created = mutableListOf<Pair<String, PostOptions>>()
        val failUpload = mutableMapOf<String, DataError>()
        var failInsert: DataError? = null
        var failCreate: DataError? = null
        var existingPosts: List<Post> = emptyList()

        override suspend fun upload(path: String, file: File, contentType: String, onProgress: (Long, Long) -> Unit) {
            failUpload.remove(path.substringAfterLast('/'))?.let { throw DataException(it) }
            check(file.isFile) { "missing $file" }
            onProgress(file.length() / 2, file.length())
            onProgress(file.length(), file.length())
            uploads += path
        }

        val insertedRows = mutableListOf<NewMedia>()

        override suspend fun insertMedia(media: NewMedia) {
            failInsert?.let { failInsert = null; throw DataException(it) }
            inserted += media.id
            insertedRows += media
        }

        override suspend fun createPost(mediaId: String, groupIds: List<String>, options: PostOptions): List<Post> {
            failCreate?.let { failCreate = null; throw DataException(it) }
            created += mediaId to options
            return groupIds.map { post(mediaId, it) }
        }

        override suspend fun postsOfMedia(mediaId: String): List<Post> = existingPosts

        val developed = mutableListOf<Pair<String, List<String>>>()
        var failDevelop: DataError? = null

        override suspend fun createOvernightPost(mediaId: String, groupIds: List<String>): List<DevelopingPost> {
            failDevelop?.let { failDevelop = null; throw DataException(it) }
            developed += mediaId to groupIds
            return groupIds.map { DevelopingPost(it, Instant.EPOCH) }
        }

        fun post(mediaId: String, groupId: String) = Post("post-$groupId", mediaId, groupId, "u", null, null, null, null, false, null, Instant.EPOCH)
    }

    @Before fun setUp() {
        initTestWorkManager(context)
        store = UploadStore(tmp.newFolder("uploads"))
    }

    private fun file(name: String, size: Int) = File(tmp.root, name).apply { writeBytes(ByteArray(size) { 1 }) }

    private fun queue() = UploadQueue(context, store) { userId }

    private fun enqueueTypical(): String = queue().enqueue(
        NewPost(
            kind = MediaKind.Photo, original = file("orig.jpg", 1000), width = 4, height = 3,
            front = file("front.jpg", 500), frontWidth = 2, frontHeight = 2,
            voice = file("v.m4a", 300), voiceDurationMs = 1500,
            groupIds = listOf("g1", "g2", "g1"), caption = "hi",
        ),
    )

    @Test fun enqueueCopiesFilesBuildsPathsAndQueuesUniqueNetworkWork() {
        val id = enqueueTypical()
        val draft = store.load(id)!!
        assertEquals(id, draft.mediaId)
        assertEquals("u/$userId/$id/original.jpg", draft.original.storagePath)
        assertEquals("u/$userId/$id/front.jpg", draft.front!!.storagePath)
        assertEquals("u/$userId/$id/voice.m4a", draft.voice!!.storagePath)
        assertEquals("audio/mp4", draft.voice.contentType)
        assertEquals(listOf("g1", "g2"), draft.groupIds)
        assertEquals(1800L, draft.totalBytes)
        assertTrue(File(draft.original.localPath).parentFile == store.dir(id))

        val infos = WorkManager.getInstance(context).getWorkInfosForUniqueWork(UploadQueue.workName(id)).get()
        assertEquals(1, infos.size)
        assertEquals(WorkInfo.State.ENQUEUED, infos.single().state)
        assertTrue(infos.single().tags.contains(UploadQueue.TAG))
        val request = UploadQueue.request(id)
        assertEquals(NetworkType.CONNECTED, request.workSpec.constraints.requiredNetworkType)
        assertEquals(BackoffPolicy.EXPONENTIAL, request.workSpec.backoffPolicy)
        assertEquals(TimeUnit.SECONDS.toMillis(30), request.workSpec.backoffDelayDuration)
    }

    @Test fun livePhotoNeedsMotionVideoNeedsDurationAndSignedOutCannotEnqueue() {
        assertThrows(IllegalArgumentException::class.java) { NewPost(kind = MediaKind.LivePhoto, original = file("a.jpg", 1), groupIds = listOf("g")) }
        assertThrows(IllegalArgumentException::class.java) { NewPost(kind = MediaKind.Video, original = file("a.mp4", 1), groupIds = listOf("g")) }
        assertThrows(IllegalArgumentException::class.java) { NewPost(kind = MediaKind.Photo, original = file("a.jpg", 1), groupIds = emptyList()) }
        val live = queue().enqueue(NewPost(kind = MediaKind.LivePhoto, original = file("b.jpg", 1), motion = file("clip.mp4", 2), durationMs = 1400, groupIds = listOf("g")))
        assertEquals("u/$userId/$live/motion.mp4", store.load(live)?.motion?.storagePath)
        assertEquals("video/mp4", store.load(live)?.motion?.contentType)
        val signedOut = UploadQueue(context, store) { null }
        val error = assertThrows(DataException::class.java) { signedOut.enqueue(NewPost(kind = MediaKind.Photo, original = file("c.jpg", 1), groupIds = listOf("g"))) }
        assertEquals(DataError.NotSignedIn, error.error)
        val missing = assertThrows(DataException::class.java) { queue().enqueue(NewPost(kind = MediaKind.Photo, original = File(tmp.root, "nope.jpg"), groupIds = listOf("g"))) }
        assertEquals(DataError.FileUnavailable, missing.error)
    }

    /** Migrations 0050 / 0051: the draft keeps the day a library photo was taken and its selection's id; the media insert sends both. */
    @Test fun theMediaInsertCarriesTheDayTakenAndTheBatch() = runBlocking {
        val day = java.time.LocalDate.of(2026, 9, 14)
        val picked = queue().enqueue(NewPost(kind = MediaKind.Photo, original = file("p.jpg", 10), groupIds = listOf("g1"), takenOn = day, batchId = "batch-1"))
        val camera = queue().enqueue(NewPost(kind = MediaKind.Photo, original = file("c.jpg", 10), groupIds = listOf("g1")))
        assertEquals(day, store.load(picked)!!.takenOn)
        assertEquals("batch-1", store.load(picked)!!.batchId)
        val remote = FakeRemote()
        PostUploader(remote, store).run(picked)
        PostUploader(remote, store).run(camera)
        assertEquals(listOf(day, null), remote.insertedRows.map { it.takenOn })
        assertEquals(listOf("batch-1", null), remote.insertedRows.map { it.batchId })
        // A draft saved before migration 0050 (no such keys) still decodes.
        val older = app.data.model.DataJson.decodeFromString(
            app.data.media.upload.PostDraft.serializer(),
            app.data.model.DataJson.encodeToString(app.data.media.upload.PostDraft.serializer(), store.load(camera)!!)
                .replace(",\"takenOn\":null", "").replace(",\"batchId\":null", ""),
        )
        assertNull(older.takenOn)
        assertNull(older.batchId)
    }

    @Test fun uploaderRunsAllStepsReportsProgressAndCleansUp() = runBlocking {
        val id = enqueueTypical()
        val remote = FakeRemote()
        val steps = mutableListOf<UploadStep>()
        val outcome = PostUploader(remote, store).run(id) { steps += it }
        assertEquals(UploadOutcome.Done(listOf("post-g1", "post-g2")), outcome)
        assertEquals(3, remote.uploads.size)
        assertEquals(listOf(id), remote.inserted)
        assertEquals(PostOptions(caption = "hi", voicePath = "u/$userId/$id/voice.m4a", voiceDurationMs = 1500), remote.created.single().second)
        assertEquals(UploadStep.Stage.Posting, steps.last().stage)
        val sent = steps.filter { it.stage == UploadStep.Stage.Uploading }.map { it.bytesSent }
        assertEquals(sent.sorted(), sent) // monotonic
        assertEquals(1800L, sent.last())
        assertEquals(1f, steps.last().fraction)
        val draft = store.load(id)!!
        assertEquals(listOf("post-g1", "post-g2"), draft.postIds)
        assertFalse(File(draft.original.localPath).exists()) // local copies removed once posted
        // Running again is a no-op that reports the same posts.
        assertEquals(outcome, PostUploader(remote, store).run(id))
        assertEquals(3, remote.uploads.size)
    }

    @Test fun aRetryResumesWhereTheLastAttemptStopped() = runBlocking {
        val id = enqueueTypical()
        val remote = FakeRemote().apply { failUpload["front.jpg"] = DataError.Network }
        val first = PostUploader(remote, store).run(id, attempt = 0)
        assertEquals(UploadOutcome.Retry(DataError.Network), first)
        assertEquals(listOf("u/$userId/$id/original.jpg"), remote.uploads)
        assertNull(store.load(id)!!.failure)

        // The original is not sent again; an object that already exists counts as uploaded.
        remote.failUpload["voice.m4a"] = DataError.Storage(StorageFailure.AlreadyExists, 400, "Duplicate")
        remote.failInsert = DataError.Network
        assertTrue(PostUploader(remote, store).run(id, attempt = 1) is UploadOutcome.Retry)
        assertEquals(listOf("u/$userId/$id/original.jpg", "u/$userId/$id/front.jpg"), remote.uploads)
        assertEquals(setOf("original.jpg", "front.jpg", "voice.m4a"), store.load(id)!!.uploaded.map { it.substringAfterLast('/') }.toSet())

        // create_post answered already_posted: an earlier attempt went through; its posts are read back.
        remote.failCreate = DataError.Api(ApiError.AlreadyPosted, "already_posted", 409, null)
        remote.existingPosts = listOf(remote.post(id, "g1"), remote.post(id, "g2"), remote.post(id, "elsewhere"))
        assertEquals(UploadOutcome.Done(listOf("post-g1", "post-g2")), PostUploader(remote, store).run(id, attempt = 2))
    }

    @Test fun permanentErrorsFailAndAreKeptForTheScreens() = runBlocking {
        for (error in listOf(
            DataError.Api(ApiError.NotGroupMember, "not_group_member", 403, "g2"),
            DataError.Api(ApiError.PremiumRequired, "premium_required", 402, null),
            DataError.Storage(StorageFailure.Forbidden, 400, null),
            DataError.NotSignedIn,
        )) {
            val id = enqueueTypical()
            val remote = FakeRemote().apply { failCreate = error }
            assertEquals(UploadOutcome.Failed(error), PostUploader(remote, store).run(id))
            val draft = store.load(id)!!
            assertEquals(DataErrorCodec.encode(error), draft.failure)
            assertTrue(File(draft.original.localPath).exists()) // kept: retry or discard is the person's call
        }
        // Transient errors give up after the attempt limit.
        val id = enqueueTypical()
        val remote = FakeRemote().apply { failInsert = DataError.Network }
        assertEquals(UploadOutcome.Failed(DataError.Network), PostUploader(remote, store).run(id, attempt = PostUploader.MAX_ATTEMPTS - 1))
        assertTrue(PostUploader.isTransient(DataError.Storage(StorageFailure.Other, 500, null)))
        assertFalse(PostUploader.isTransient(DataError.Api(ApiError.InvalidVoice, "invalid_voice", 400, null)))
        assertEquals(UploadOutcome.Failed(DataError.FileUnavailable), PostUploader(FakeRemote(), store).run(UUID.randomUUID().toString()))
    }

    /** 9 AM mode (camera.overnight): the draft is kept as overnight and goes to `create_overnight_post`, never `create_post`. */
    @Test fun overnightDraftsDevelopInsteadOfPosting() = runBlocking {
        val id = queue().enqueue(NewPost(kind = MediaKind.Photo, original = file("night.jpg", 400), width = 3, height = 4, groupIds = listOf("g1", "g2"), overnight = true))
        assertTrue(store.load(id)!!.overnight)
        val remote = FakeRemote().apply { failDevelop = DataError.Network }
        assertEquals(UploadOutcome.Retry(DataError.Network), PostUploader(remote, store).run(id))
        // already_posted: an earlier attempt went through.
        remote.failDevelop = DataError.Api(ApiError.AlreadyPosted, "already_posted", 409, "g1")
        assertEquals(UploadOutcome.Done(emptyList()), PostUploader(remote, store).run(id, attempt = 1))
        assertTrue(remote.created.isEmpty())
        assertEquals(emptyList<String>(), store.load(id)!!.postIds)
        assertFalse(File(store.load(id)!!.original.localPath).exists()) // the local copy goes once uploaded (uploadQueue.localFile)

        val next = queue().enqueue(NewPost(kind = MediaKind.Photo, original = file("night2.jpg", 10), groupIds = listOf("g1"), overnight = true))
        assertEquals(UploadOutcome.Done(emptyList()), PostUploader(remote, store).run(next))
        assertEquals(next to listOf("g1"), remote.developed.last())
        // Photos only, without caption, voice note, invitation or reply.
        assertThrows(IllegalArgumentException::class.java) { NewPost(kind = MediaKind.Photo, original = file("x.jpg", 1), groupIds = listOf("g"), caption = "hi", overnight = true) }
        assertThrows(IllegalArgumentException::class.java) { NewPost(kind = MediaKind.Video, original = file("x.mp4", 1), durationMs = 1, groupIds = listOf("g"), overnight = true) }
        Unit
    }

    private fun worker(id: String, uploader: PostUploader, attempt: Int = 0) = TestListenableWorkerBuilder<UploadWorker>(context)
        .setInputData(workDataOf(UploadWorker.KEY_DRAFT to id))
        .setRunAttemptCount(attempt)
        .setWorkerFactory(object : WorkerFactory() {
            override fun createWorker(appContext: Context, workerClassName: String, workerParameters: WorkerParameters): ListenableWorker =
                UploadWorker(appContext, workerParameters, uploader)
        })
        .build()

    @Test fun workerTurnsOutcomesIntoWorkResults() = runBlocking {
        val ok = enqueueTypical()
        val done = worker(ok, PostUploader(FakeRemote(), store)).doWork()
        assertEquals(ListenableWorker.Result.success(workDataOf(UploadWorker.KEY_POST_IDS to arrayOf("post-g1", "post-g2"))), done)

        val flaky = enqueueTypical()
        assertEquals(ListenableWorker.Result.retry(), worker(flaky, PostUploader(FakeRemote().apply { failInsert = DataError.Network }, store)).doWork())

        val refused = enqueueTypical()
        val failed = worker(refused, PostUploader(FakeRemote().apply { failCreate = DataError.Api(ApiError.PremiumRequired, "premium_required", 402, null) }, store)).doWork()
        assertEquals(ListenableWorker.Result.failure(workDataOf(UploadWorker.KEY_ERROR to "api:premium_required")), failed)
    }

    @Test fun progressMapsWorkStatesForScreens() {
        val id = enqueueTypical()
        val draft = store.load(id)!!
        fun info(state: WorkInfo.State, attempts: Int = 0, output: Data = Data.EMPTY, progress: Data = Data.EMPTY) =
            WorkInfo(UUID.randomUUID(), state, setOf(UploadQueue.TAG), output, progress, attempts)
        assertEquals(UploadProgress.Queued, UploadQueue.toProgress(info(WorkInfo.State.ENQUEUED), draft))
        assertEquals(UploadProgress.Waiting, UploadQueue.toProgress(info(WorkInfo.State.ENQUEUED, attempts = 2), draft))
        val running = UploadQueue.toProgress(info(WorkInfo.State.RUNNING, progress = with(UploadWorker) { UploadStep(UploadStep.Stage.Uploading, 900, 1800).toData() }), draft)
        assertEquals(UploadProgress.Running(UploadStep(UploadStep.Stage.Uploading, 900, 1800)), running)
        assertEquals(0.5f, (running as UploadProgress.Running).step!!.fraction)
        assertEquals(UploadProgress.Failed(DataError.Api(ApiError.NotGroupMember, "not_group_member", 403, null)),
            UploadQueue.toProgress(info(WorkInfo.State.FAILED, output = workDataOf(UploadWorker.KEY_ERROR to "api:not_group_member")), draft))
        assertEquals(UploadProgress.Done(listOf("p")), UploadQueue.toProgress(info(WorkInfo.State.SUCCEEDED, output = workDataOf(UploadWorker.KEY_POST_IDS to arrayOf("p"))), draft))
        assertEquals(UploadProgress.Done(listOf("x")), UploadQueue.toProgress(null, draft.copy(postIds = listOf("x"))))
        assertEquals(UploadProgress.Failed(DataError.Network), UploadQueue.toProgress(null, draft.copy(failure = "network")))
    }

    @Test fun discardCancelsAndDeletesRetryRequeues() {
        val q = queue()
        val id = enqueueTypical()
        store.save(store.load(id)!!.copy(failure = "network"))
        q.retry(id)
        assertNull(store.load(id)!!.failure)
        assertEquals(1, q.pending().size)
        q.discard(id)
        assertNull(store.load(id))
        val infos = WorkManager.getInstance(context).getWorkInfosForUniqueWork(UploadQueue.workName(id)).get()
        assertTrue(infos.all { it.state == WorkInfo.State.CANCELLED })
        assertNotNull(q)
    }

    /** A session ended (SessionGlue): nothing of the person who left stays queued or on disk. */
    @Test fun discardAllEmptiesTheOutbox() {
        val q = queue()
        val first = enqueueTypical()
        val second = enqueueTypical()
        store.save(store.load(second)!!.copy(failure = "network"))
        q.discardAll()
        assertTrue(q.pending().isEmpty())
        assertNull(store.load(first))
        assertTrue(!store.dir(first).exists() && !store.dir(second).exists())
        val work = WorkManager.getInstance(context)
        assertTrue(listOf(first, second).all { id -> work.getWorkInfosForUniqueWork(UploadQueue.workName(id)).get().all { it.state == WorkInfo.State.CANCELLED } })
    }
}
