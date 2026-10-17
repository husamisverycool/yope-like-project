package app.data.media.upload

import app.data.error.ApiError
import app.data.error.AuthFailure
import app.data.error.DataError
import app.data.error.DataException
import app.data.error.ErrorMapping
import app.data.error.StorageFailure
import app.data.model.DevelopingPost
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
    /** §14.3 `create_overnight_post`: the photo develops in each group at its next 09:00. */
    suspend fun createOvernightPost(mediaId: String, groupIds: List<String>): List<DevelopingPost>
    /** §14.4 `answer_question`: links [postId] (yours) to the group week's question. */
    suspend fun answerQuestion(postId: String, questionId: String) {}
}

/** Where an upload is. */
sealed interface UploadOutcome {
    /** Posted; an overnight photo has no post ids yet (it is not a post until its reveal, §14.3). */
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
 * 3. `create_post` (`already_posted` means an earlier attempt succeeded: its posts are read back), or
 *    `create_overnight_post` for a photo taken in 9 AM mode.
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
            val postIds = if (draft.overnight) developOvernight(draft) else post(draft)
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

    /** 3. `create_post`; `already_posted` means an earlier attempt succeeded: its posts are read back. */
    private suspend fun post(draft: PostDraft): List<String> {
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
        answerQuestion(draft, posts)
        return posts.map { it.id }
    }

    /**
     * Links the post in the question's group to the weekly question (`question.weekly` B). Best effort: the photo is
     * posted either way, and a question that closed meanwhile (`question_closed`, `question_off`) is not an upload failure.
     */
    private suspend fun answerQuestion(draft: PostDraft, posts: List<Post>) {
        val question = draft.questionId ?: return
        val post = posts.firstOrNull { it.groupId == draft.questionGroupId } ?: return
        try {
            remote.answerQuestion(post.id, question)
        } catch (e: CancellationException) {
            throw e
        } catch (_: Exception) {
            // The post stays an ordinary post of the group.
        }
    }

    /**
     * 3. (9 AM mode) `create_overnight_post`: nobody can read the photo until it develops, so there are no post ids;
     * `already_posted` means an earlier attempt succeeded.
     */
    private suspend fun developOvernight(draft: PostDraft): List<String> {
        try {
            remote.createOvernightPost(draft.mediaId, draft.groupIds)
        } catch (e: DataException) {
            val error = e.error
            if (!(error is DataError.Api && error.code == ApiError.AlreadyPosted)) throw e
        }
        return emptyList()
    }

    private fun PostDraft.options() = PostOptions(
        caption = caption,
        voicePath = voice?.storagePath,
        voiceDurationMs = voiceDurationMs,
        voiceLevels = voiceLevels,
        invitationId = invitationId,
        replyToPostId = replyToPostId,
        invitationIds = invitationIds,
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
