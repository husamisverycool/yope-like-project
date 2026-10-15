package app.data.media.upload

import app.data.error.ApiError
import app.data.error.AuthFailure
import app.data.error.DataError
import app.data.error.DataException
import app.data.error.ErrorMapping
import app.data.error.StorageFailure
import app.data.model.NewMedia
import app.data.model.Post
import app.data.repo.PostOptions
import kotlinx.coroutines.CancellationException
import java.io.File

/** The remote steps of recipe 9.4, behind an interface so the retry logic is unit-tested. */
interface PostRemote {
    suspend fun upload(path: String, file: File, contentType: String, onProgress: (Long, Long) -> Unit)
    suspend fun insertMedia(media: NewMedia)
    suspend fun createPost(mediaId: String, groupIds: List<String>, options: PostOptions): List<Post>
    suspend fun postsOfMedia(mediaId: String): List<Post>
}

/** Where an upload is. */
sealed interface UploadOutcome {
    data class Done(val postIds: List<String>) : UploadOutcome
    /** Transient (network, server): WorkManager retries with backoff. */
    data class Retry(val error: DataError) : UploadOutcome
    /** Permanent (not a member, premium required, file gone …): kept as a failed draft. */
    data class Failed(val error: DataError) : UploadOutcome
}

/** Progress of a running upload. */
data class UploadStep(val stage: Stage, val bytesSent: Long, val totalBytes: Long) {
    enum class Stage { Uploading, Posting }

    val fraction: Float get() = if (totalBytes <= 0) 0f else (bytesSent.toFloat() / totalBytes).coerceIn(0f, 1f)
}

/**
 * Runs one draft to completion, resuming where a previous attempt stopped:
 * 1. each file not yet uploaded (an object that already exists counts as uploaded: storage never
 *    overwrites, and an object only exists once fully written);
 * 2. the `media` row (a duplicate id counts as inserted);
 * 3. `create_post` (`already_posted` means an earlier attempt succeeded: its posts are read back).
 * Local copies are deleted once posted. Failed drafts stay on disk (API.md 9.4: "Retry, or leave them").
 */
class PostUploader(private val remote: PostRemote, private val store: UploadStore) {

    suspend fun run(draftId: String, attempt: Int = 0, onProgress: (UploadStep) -> Unit = {}): UploadOutcome {
        var draft = store.load(draftId) ?: return UploadOutcome.Failed(DataError.FileUnavailable)
        draft.postIds?.let { return UploadOutcome.Done(it) }
        try {
            val total = draft.totalBytes
            for (file in draft.files) {
                if (file.storagePath in draft.uploaded) continue
                val base = draft.uploadedBytes
                try {
                    remote.upload(file.storagePath, File(file.localPath), file.contentType) { sent, _ ->
                        onProgress(UploadStep(UploadStep.Stage.Uploading, base + sent.coerceAtMost(file.size), total))
                    }
                } catch (e: DataException) {
                    val error = e.error
                    if (!(error is DataError.Storage && error.kind == StorageFailure.AlreadyExists)) throw e
                }
                draft = draft.copy(uploaded = draft.uploaded + file.storagePath)
                store.save(draft)
                onProgress(UploadStep(UploadStep.Stage.Uploading, draft.uploadedBytes, total))
            }
            onProgress(UploadStep(UploadStep.Stage.Posting, total, total))
            if (!draft.mediaInserted) {
                remote.insertMedia(draft.newMedia())
                draft = draft.copy(mediaInserted = true)
                store.save(draft)
            }
            val posts = try {
                remote.createPost(draft.mediaId, draft.groupIds, draft.options())
            } catch (e: DataException) {
                val error = e.error
                if (error is DataError.Api && error.code == ApiError.AlreadyPosted) {
                    remote.postsOfMedia(draft.mediaId).filter { it.groupId in draft.groupIds }
                } else {
                    throw e
                }
            }
            val postIds = posts.map { it.id }
            store.save(draft.copy(postIds = postIds))
            // Keep the draft record (with post ids) only as long as the work result needs it.
            deleteLocalFiles(draft)
            return UploadOutcome.Done(postIds)
        } catch (e: CancellationException) {
            throw e
        } catch (e: Throwable) {
            val error = (e as? DataException)?.error ?: ErrorMapping.map(e)
            val retry = isTransient(error) && attempt + 1 < MAX_ATTEMPTS
            if (!retry) store.save(draft.copy(failure = app.data.error.DataErrorCodec.encode(error)))
            return if (retry) UploadOutcome.Retry(error) else UploadOutcome.Failed(error)
        }
    }

    private fun PostDraft.options() = PostOptions(
        caption = caption,
        voicePath = voice?.storagePath,
        voiceDurationMs = voiceDurationMs,
        invitationId = invitationId,
        replyToPostId = replyToPostId,
    )

    private fun deleteLocalFiles(draft: PostDraft) {
        val dir = store.dir(draft.id)
        draft.files.map { File(it.localPath) }.filter { it.parentFile == dir }.forEach { it.delete() }
    }

    companion object {
        const val MAX_ATTEMPTS = 8

        fun isTransient(error: DataError): Boolean = when (error) {
            DataError.Network -> true
            is DataError.Storage -> error.kind == StorageFailure.Other
            is DataError.Auth -> error.kind == AuthFailure.SessionExpired || error.kind == AuthFailure.RateLimited
            is DataError.Unexpected -> true
            is DataError.Api -> error.code == ApiError.Unknown && (error.httpStatus ?: 0) >= 500
            else -> false
        }
    }
}
