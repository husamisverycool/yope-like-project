package app.data.repo

import app.data.media.ObjectUploader
import app.data.media.StoragePaths
import app.data.model.SelfieReaction
import app.data.remote.Api
import app.data.remote.Rpc
import app.data.remote.Tables
import io.github.jan.supabase.postgrest.query.Order
import java.io.File
import java.util.UUID

/**
 * Selfie reactions (docs/API.md §14.1, BeReal's RealMoji): one live front-camera selfie per person per post, rows
 * `(user, image)` read with the `reactions` rule (members who can see the post, blocks hide both ways). Never a count:
 * queries never ask PostgREST for a count header. Removals arrive as the `reactions_changed` broadcast. Reports go through
 * [SafetyRepository.report] with [app.data.model.ReportTargetKind.Selfie] and the row's id.
 */
class SelfieReactionRepository(private val api: Api, private val uploader: ObjectUploader) {

    /** The selfies on [postId], oldest first. */
    suspend fun selfies(postId: String): List<SelfieReaction> = api.select(Tables.SELFIE_REACTIONS, SelfieReaction.serializer()) {
        filter { eq("post_id", postId) }
        order("created_at", Order.ASCENDING)
    }

    /** Selfies of several posts at once, per post id, oldest first. */
    suspend fun selfiesFor(postIds: Collection<String>): Map<String, List<SelfieReaction>> {
        if (postIds.isEmpty()) return emptyMap()
        val rows = postIds.distinct().chunked(IN_CHUNK).flatMap { chunk ->
            api.select(Tables.SELFIE_REACTIONS, SelfieReaction.serializer()) {
                filter { isIn("post_id", chunk) }
                order("created_at", Order.ASCENDING)
            }
        }
        return rows.groupBy { it.postId }
    }

    /**
     * Uploads the still [file] (JPEG) to `u/<uid>/selfies/<uuid>.jpg`, then `react_with_selfie`: a new selfie replaces
     * yours (the server deletes the old file). Errors: `post_not_found`, `invalid_image`, `own_post`.
     */
    suspend fun react(postId: String, file: File): SelfieReaction {
        val path = StoragePaths.selfie(api.requireUserId(), UUID.randomUUID().toString())
        uploader.upload(path, file, JPEG) { _, _ -> }
        return api.rpc(Rpc.ReactWithSelfie, SelfieReaction.serializer()) {
            put("p_post_id", postId)
            put("p_image_path", path)
        }
    }

    /** Removes yours ([userId] null), or — the post's author — anyone's on your post (`not_allowed` otherwise). */
    suspend fun remove(postId: String, userId: String? = null) = api.rpcUnit(Rpc.RemoveSelfieReaction) {
        put("p_post_id", postId)
        opt("p_user_id", userId)
    }

    private companion object {
        const val JPEG = "image/jpeg"
        const val IN_CHUNK = 100
    }
}
