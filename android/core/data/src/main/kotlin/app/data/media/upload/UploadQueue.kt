package app.data.media.upload

import android.content.Context
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.Data
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequest
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkInfo
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import androidx.work.workDataOf
import app.data.DataGraph
import app.data.error.DataError
import app.data.error.DataErrorCodec
import app.data.error.DataException
import app.data.media.StoragePaths
import app.data.model.MediaKind
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import java.io.File
import java.util.UUID
import java.util.concurrent.TimeUnit

/** What the composer hands over to send a photo (recipe 9.4). Files are copied; the caller may delete its own. */
data class NewPost(
    val kind: MediaKind,
    /** JPEG for photos / Live-Photo-equivalents, MP4 for video. */
    val original: File,
    val width: Int? = null,
    val height: Int? = null,
    /** Front image of a dual capture (JPEG). */
    val front: File? = null,
    val frontWidth: Int? = null,
    val frontHeight: Int? = null,
    /** The motion clip of a motion photo (`live_photo`; required for that kind). MP4 or QuickTime. */
    val motion: File? = null,
    /** Video length, or the motion clip's length. Required for `video`. */
    val durationMs: Int? = null,
    /** Voice note (AAC in MP4, `.m4a`) and its length. */
    val voice: File? = null,
    val voiceDurationMs: Int? = null,
    val groupIds: List<String>,
    val caption: String? = null,
    val invitationId: String? = null,
    val replyToPostId: String? = null,
    /** The voice note's waveform: 100 levels of 0…31 (`p_voice_levels`, C-36). Last, so positional calls keep working. */
    val voiceLevels: List<Int>? = null,
    /**
     * Taken in 9 AM mode (`camera.overnight`): sent with `create_overnight_post` (§14.3), so a photo without caption,
     * voice note, invitation or reply. Last, so positional calls keep working.
     */
    val overnight: Boolean = false,
    /**
     * The weekly question this photo answers (`question.weekly` B, §14.4): after posting, the post in [questionGroupId]
     * (one of [groupIds]) is linked to it with `answer_question`; the posts to the other groups are not. Last, so
     * positional calls keep working.
     */
    val questionId: String? = null,
    val questionGroupId: String? = null,
) {
    init {
        require(groupIds.isNotEmpty()) { "no groups" }
        require(kind != MediaKind.LivePhoto || motion != null) { "live_photo needs a motion clip" }
        require(kind != MediaKind.Video || durationMs != null) { "video needs its duration" }
        require((voice == null) == (voiceDurationMs == null)) { "voice note and its duration go together" }
        require(voiceDurationMs == null || voiceDurationMs > 0) { "voice duration must be > 0" }
        require(!overnight || (kind == MediaKind.Photo && caption == null && voice == null && invitationId == null && replyToPostId == null)) {
            "an overnight post is a photo without caption, voice note, invitation or reply"
        }
    }
}

/** What a screen shows for one upload. */
sealed interface UploadProgress {
    data object Queued : UploadProgress
    data class Running(val step: UploadStep?) : UploadProgress
    /** Waiting for a retry (offline, server error). */
    data object Waiting : UploadProgress
    data class Done(val postIds: List<String>) : UploadProgress
    data class Failed(val error: DataError) : UploadProgress
}

/**
 * Sends posts in the background with WorkManager: needs a network, retries with exponential
 * backoff, survives process death, reports progress. One unique work per draft.
 */
class UploadQueue(
    private val context: Context,
    private val store: UploadStore,
    private val userId: () -> String?,
) {
    private val workManager: WorkManager get() = WorkManager.getInstance(context)

    /** Copies the files into the draft folder, persists the draft and queues it. Returns the draft id. */
    fun enqueue(post: NewPost): String {
        val uid = userId() ?: throw DataException(DataError.NotSignedIn)
        val mediaId = UUID.randomUUID().toString()
        val dir = store.dir(mediaId).apply { mkdirs() }
        try {
            fun copy(source: File, name: String): File {
                if (!source.isFile) throw DataException(DataError.FileUnavailable)
                return source.copyTo(File(dir, name), overwrite = true)
            }
            val originalExt = post.original.extension.lowercase().ifEmpty { if (post.kind == MediaKind.Video) "mp4" else "jpg" }
            val original = copy(post.original, "original.$originalExt")
            val front = post.front?.let { copy(it, "front.jpg") }
            val motionExt = post.motion?.extension?.lowercase()?.takeIf { it == "mov" || it == "mp4" } ?: "mp4"
            val motion = post.motion?.let { copy(it, "motion.$motionExt") }
            val voice = post.voice?.let { copy(it, "voice.m4a") }
            fun draftFile(file: File, path: String, type: String) = DraftFile(file.absolutePath, path, type, file.length())
            val draft = PostDraft(
                mediaId = mediaId,
                ownerId = uid,
                kind = post.kind,
                original = draftFile(original, StoragePaths.original(uid, mediaId, originalExt), StoragePaths.contentTypeFor(originalExt)),
                front = front?.let { draftFile(it, StoragePaths.front(uid, mediaId), "image/jpeg") },
                motion = motion?.let { draftFile(it, StoragePaths.motion(uid, mediaId, motionExt), StoragePaths.contentTypeFor(motionExt)) },
                voice = voice?.let { draftFile(it, StoragePaths.postVoice(uid, mediaId), "audio/mp4") },
                width = post.width,
                height = post.height,
                frontWidth = post.frontWidth,
                frontHeight = post.frontHeight,
                durationMs = post.durationMs,
                groupIds = post.groupIds.distinct(),
                caption = post.caption,
                voiceDurationMs = post.voiceDurationMs,
                voiceLevels = post.voiceLevels.takeIf { post.voice != null },
                invitationId = post.invitationId,
                replyToPostId = post.replyToPostId,
                overnight = post.overnight,
                questionId = post.questionId?.takeIf { post.questionGroupId in post.groupIds },
                questionGroupId = post.questionGroupId?.takeIf { post.questionId != null && it in post.groupIds },
            )
            if (draft.files.any { it.size > StoragePaths.MAX_OBJECT_BYTES }) {
                throw DataException(DataError.Storage(app.data.error.StorageFailure.TooLarge, null, null))
            }
            store.save(draft)
        } catch (e: Exception) {
            store.delete(mediaId)
            throw e
        }
        submit(mediaId)
        return mediaId
    }

    /** Queues a stored draft again (after a permanent failure, e.g. once premium is bought). */
    fun retry(draftId: String) {
        val draft = store.load(draftId) ?: throw DataException(DataError.FileUnavailable)
        store.save(draft.copy(failure = null))
        submit(draftId, ExistingWorkPolicy.REPLACE)
    }

    /** Cancels the work and deletes the draft and its copies. Already-uploaded objects stay private (9.4). */
    fun discard(draftId: String) {
        workManager.cancelUniqueWork(workName(draftId))
        store.delete(draftId)
    }

    /**
     * A session ended (sign-out, account deletion, expiry): every queued upload is cancelled and every draft with its photo
     * copies deleted, so nothing of the person who left stays on the device or is sent with the next person's session
     * (as iOS empties its outbox, `PostPublisher.removeAll`).
     */
    fun discardAll() {
        workManager.cancelAllWorkByTag(TAG)
        store.all().forEach { store.delete(it.id) }
    }

    /** Drafts not yet posted (queued, running, or failed). */
    fun pending(): List<PostDraft> = store.all().filter { it.postIds == null }

    fun progress(draftId: String): Flow<UploadProgress> =
        workManager.getWorkInfosForUniqueWorkFlow(workName(draftId)).map { infos -> toProgress(infos.lastOrNull(), store.load(draftId)) }

    private fun submit(draftId: String, policy: ExistingWorkPolicy = ExistingWorkPolicy.KEEP) {
        workManager.enqueueUniqueWork(workName(draftId), policy, request(draftId))
    }

    companion object {
        const val TAG = "post-upload"
        private const val BACKOFF_SECONDS = 30L

        fun workName(draftId: String) = "post-upload:$draftId"

        fun request(draftId: String): OneTimeWorkRequest = OneTimeWorkRequestBuilder<UploadWorker>()
            .setInputData(workDataOf(UploadWorker.KEY_DRAFT to draftId))
            .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
            .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, BACKOFF_SECONDS, TimeUnit.SECONDS)
            .addTag(TAG)
            .build()

        internal fun toProgress(info: WorkInfo?, draft: PostDraft?): UploadProgress {
            draft?.postIds?.let { return UploadProgress.Done(it) }
            if (info == null) {
                val failure = DataErrorCodec.decode(draft?.failure)
                return if (failure != null) UploadProgress.Failed(failure) else UploadProgress.Queued
            }
            return when (info.state) {
                WorkInfo.State.ENQUEUED, WorkInfo.State.BLOCKED -> if (info.runAttemptCount > 0) UploadProgress.Waiting else UploadProgress.Queued
                WorkInfo.State.RUNNING -> UploadProgress.Running(UploadWorker.stepOf(info.progress))
                WorkInfo.State.SUCCEEDED -> UploadProgress.Done(info.outputData.getNullableStringArray(UploadWorker.KEY_POST_IDS)?.filterNotNull().orEmpty())
                WorkInfo.State.FAILED -> UploadProgress.Failed(DataErrorCodec.decode(info.outputData.getString(UploadWorker.KEY_ERROR)) ?: DataError.Unexpected(null))
                WorkInfo.State.CANCELLED -> UploadProgress.Failed(DataError.Unexpected("cancelled"))
            }
        }
    }
}

/** The WorkManager side of [PostUploader]. */
class UploadWorker(
    context: Context,
    params: WorkerParameters,
    private val uploaderOverride: PostUploader?,
) : CoroutineWorker(context, params) {

    @Suppress("unused") // instantiated by WorkManager's default factory
    constructor(context: Context, params: WorkerParameters) : this(context, params, null)

    override suspend fun doWork(): Result {
        val draftId = inputData.getString(KEY_DRAFT) ?: return Result.failure(errorData(DataError.Unexpected("no draft")))
        val uploader = uploaderOverride ?: run {
            val graph = DataGraph.get(applicationContext) ?: return Result.failure(errorData(DataError.NotConfigured))
            graph.awaitSessionLoaded()
            if (graph.auth.currentUserId == null) return Result.failure(errorData(DataError.NotSignedIn))
            graph.uploader
        }
        var lastReport = 0L
        val outcome = uploader.run(draftId, runAttemptCount) { step ->
            val now = System.currentTimeMillis()
            if (now - lastReport >= PROGRESS_INTERVAL_MS || step.stage == UploadStep.Stage.Posting) {
                lastReport = now
                setProgressAsync(step.toData())
            }
        }
        return when (outcome) {
            is UploadOutcome.Done -> Result.success(workDataOf(KEY_POST_IDS to outcome.postIds.toTypedArray()))
            is UploadOutcome.Retry -> Result.retry()
            is UploadOutcome.Failed -> Result.failure(errorData(outcome.error))
        }
    }

    companion object {
        const val KEY_DRAFT = "draft"
        const val KEY_POST_IDS = "postIds"
        const val KEY_ERROR = "error"
        private const val KEY_STAGE = "stage"
        private const val KEY_SENT = "sent"
        private const val KEY_TOTAL = "total"
        private const val PROGRESS_INTERVAL_MS = 250L

        fun errorData(error: DataError): Data = workDataOf(KEY_ERROR to DataErrorCodec.encode(error))

        fun UploadStep.toData(): Data = workDataOf(KEY_STAGE to stage.name, KEY_SENT to bytesSent, KEY_TOTAL to totalBytes)

        fun stepOf(data: Data): UploadStep? {
            val stage = data.getString(KEY_STAGE)?.let { name -> UploadStep.Stage.entries.firstOrNull { it.name == name } } ?: return null
            return UploadStep(stage, data.getLong(KEY_SENT, 0), data.getLong(KEY_TOTAL, 0))
        }
    }
}
