package app.data.repo

import app.data.error.DataError
import app.data.error.DataException
import app.data.error.DbFailure
import app.data.error.dataCall
import app.data.model.Developing
import app.data.model.DevelopingPost
import app.data.model.Media
import app.data.model.NewMedia
import app.data.model.Post
import app.data.offline.CacheKey
import app.data.offline.DataState
import app.data.offline.OfflineCache
import app.data.offline.cachedFlow
import app.data.remote.Api
import app.data.remote.Rpc
import app.data.remote.Tables
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Order
import kotlinx.coroutines.flow.Flow
import kotlinx.serialization.builtins.ListSerializer
import java.time.Clock
import java.time.Instant

/** What `create_post` sends besides the media and groups (docs/API.md §6.2). */
data class PostOptions(
    val caption: String? = null,
    /** Your upload (convention `u/<uid>/<media_id>/voice.m4a`); needs [voiceDurationMs] > 0. */
    val voicePath: String? = null,
    val voiceDurationMs: Int? = null,
    /** The voice note's waveform: 100 levels of 0…31 (`p_voice_levels`); needs [voicePath]. */
    val voiceLevels: List<Int>? = null,
    /** The daily invitation being answered; never fails, never "late" (§6.2). */
    val invitationId: String? = null,
    /** Reply to a photo with a photo: exactly one group, the replied post's group. */
    val replyToPostId: String? = null,
    /**
     * The chosen groups' open invitations this post answers (camera.sendto while a window is open, `p_invitation_ids`,
     * migration 0035): each group's post is matched to its own; never fails, never "late".
     */
    val invitationIds: List<String>? = null,
)

/**
 * Posts and media: feed pages, single posts, replies, `create_post`, and deletion
 * (docs/API.md §5.7, §5.8, §6.2). Uploading files is [app.data.media.upload.UploadQueue]'s job.
 */
class PostRepository(private val api: Api, private val cache: OfflineCache, private val clock: Clock = Clock.systemUTC()) {

    /**
     * A feed page: newest first, [limit] posts, older than [before] (the previous page's last
     * `created_at`), exactly as §5.8 prescribes.
     */
    suspend fun feed(groupId: String, before: Instant? = null, limit: Int = FEED_PAGE): List<Post> =
        api.select(Tables.POSTS, Post.serializer()) {
            filter {
                eq("group_id", groupId)
                if (before != null) lt("created_at", app.data.model.InstantSerializer.format(before))
            }
            order("created_at", Order.DESCENDING)
            limit(limit.toLong())
        }

    /** The first feed page, cache-then-network (renders offline). */
    fun observeFeed(groupId: String): Flow<DataState<List<Post>>> =
        cachedFlow(cache, CacheKey.feed(groupId), ListSerializer(Post.serializer()), clock) { feed(groupId) }

    suspend fun post(postId: String): Post? = api.selectSingleOrNull(Tables.POSTS, Post.serializer()) { filter { eq("id", postId) } }

    /** Posts by id (recap items, album items, wall entries, history weeks); RLS drops hidden ones. */
    suspend fun posts(postIds: Collection<String>): List<Post> {
        if (postIds.isEmpty()) return emptyList()
        val byId = postIds.distinct().chunked(IN_CHUNK).flatMap { chunk ->
            api.select(Tables.POSTS, Post.serializer()) { filter { isIn("id", chunk) } }
        }.associateBy { it.id }
        return postIds.mapNotNull(byId::get)
    }

    /**
     * §14.3 a group's photos revealed together at [revealedAt] (one overnight reveal, `posts.revealed_at`), oldest first —
     * the time each was taken; RLS drops hidden ones.
     */
    suspend fun revealed(groupId: String, revealedAt: Instant): List<Post> = api.select(Tables.POSTS, Post.serializer()) {
        filter {
            eq("group_id", groupId)
            eq("revealed_at", app.data.model.InstantSerializer.format(revealedAt))
        }
        order("created_at", Order.ASCENDING)
        order("id", Order.ASCENDING)
    }

    /**
     * Migration 0051: a group's photos of one batch (the same author and `batch_id`, several photos posted together),
     * oldest first — the order the viewer pages through them (`photo.viewer.layout.batchDots`); RLS drops hidden ones.
     */
    suspend fun batch(groupId: String, authorId: String, batchId: String): List<Post> = api.select(Tables.POSTS, Post.serializer()) {
        filter {
            eq("group_id", groupId)
            eq("author_id", authorId)
            eq("batch_id", batchId)
        }
        order("created_at", Order.ASCENDING)
        order("id", Order.ASCENDING)
    }

    /** The posts of one media (one per group it was sent to that you can see). */
    suspend fun postsOfMedia(mediaId: String): List<Post> = api.select(Tables.POSTS, Post.serializer()) {
        filter { eq("media_id", mediaId) }
        order("created_at", Order.ASCENDING)
    }

    /** Photos replying to [postId]. */
    suspend fun replies(postId: String): List<Post> = api.select(Tables.POSTS, Post.serializer()) {
        filter { eq("reply_to_post_id", postId) }
        order("created_at", Order.ASCENDING)
    }

    suspend fun media(mediaIds: Collection<String>): List<Media> {
        if (mediaIds.isEmpty()) return emptyList()
        val byId = mediaIds.distinct().chunked(IN_CHUNK).flatMap { chunk ->
            api.select(Tables.MEDIA, Media.serializer()) { filter { isIn("id", chunk) } }
        }.associateBy { it.id }
        return mediaIds.mapNotNull(byId::get)
    }

    suspend fun mediaOf(post: Post): Media? = media(listOf(post.mediaId)).firstOrNull()

    /**
     * Step 2 of recipe 9.4: the `media` row (direct insert, §5.0). Inserting the same id again is
     * treated as done, so a retried upload is idempotent.
     */
    suspend fun insertMedia(media: NewMedia) {
        try {
            dataCall { api.client.from(Tables.MEDIA).insert(media) }
        } catch (e: DataException) {
            val error = e.error
            if (error is DataError.Database && error.kind == DbFailure.UniqueViolation) return
            throw e
        }
    }

    /** One post per group (and one chat photo message per group), all or nothing. */
    suspend fun createPost(mediaId: String, groupIds: List<String>, options: PostOptions = PostOptions()): List<Post> =
        api.rpcList(Rpc.CreatePost, Post.serializer()) {
            put("p_media_id", mediaId)
            put("p_group_ids", groupIds.distinct())
            opt("p_caption", options.caption)
            opt("p_voice_path", options.voicePath)
            opt("p_voice_duration_ms", options.voiceDurationMs)
            optInts("p_voice_levels", options.voiceLevels?.takeIf { options.voicePath != null })
            opt("p_invitation_id", options.invitationId)
            opt("p_reply_to_post_id", options.replyToPostId)
            opt("p_invitation_ids", options.invitationIds?.takeIf { it.isNotEmpty() })
        }

    /**
     * §14.3 a photo taken in 9 AM mode: held for each group until its first 09:00 (group time zone) after now, readable
     * by nobody until then, the sender included. Photos only (`develop_photo_only`), once per group (`already_posted`).
     */
    suspend fun createOvernightPost(mediaId: String, groupIds: List<String>): List<DevelopingPost> =
        api.rpcList(Rpc.CreateOvernightPost, DevelopingPost.serializer()) {
            put("p_media_id", mediaId)
            put("p_group_ids", groupIds.distinct())
        }

    /** §14.3 whether you have photos developing (any group) and the next reveal (`my_developing`); never a number. */
    suspend fun myDeveloping(): Developing =
        api.rpcList(Rpc.MyDeveloping, Developing.serializer()).firstOrNull() ?: Developing(developing = false, revealAt = null)

    /** Author only: removes the photo from one group (the media goes with its last post). */
    suspend fun deletePost(postId: String) = api.rpcUnit(Rpc.DeletePost) { put("p_post_id", postId) }

    /** Owner only: deletes the photo everywhere (every group, chat, reactions, tags, albums, recaps…). */
    suspend fun deleteMedia(mediaId: String) = api.rpcUnit(Rpc.DeleteMedia) { put("p_media_id", mediaId) }

    companion object {
        const val FEED_PAGE = 30
        /** Ids per `in.(…)` filter, keeping URLs short. */
        private const val IN_CHUNK = 100
    }
}
