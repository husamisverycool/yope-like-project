package app.data.repo

import app.data.model.PostTag
import app.data.model.Reaction
import app.data.remote.Api
import app.data.remote.Rpc
import app.data.remote.Tables
import io.github.jan.supabase.postgrest.query.Order
import java.time.Instant

/**
 * One reaction as shown: who reacted with what. There is deliberately no count anywhere. [createdAt] orders it among
 * selfie reactions in the Reactions sheet (null = optimistic, the newest).
 */
data class ReactionEntry(val userId: String, val emoji: String, val createdAt: Instant? = null)

/**
 * Reactions (docs/API.md §5.10, §6.2): rows `(user, emoji)`, never numbers (tenet: no counts).
 * Queries never ask PostgREST for a count header.
 */
class ReactionRepository(private val api: Api) {

    /** Who reacted to [postId] with what, oldest first. */
    suspend fun reactions(postId: String): List<ReactionEntry> = api.select(Tables.REACTIONS, Reaction.serializer()) {
        filter { eq("post_id", postId) }
        order("created_at", Order.ASCENDING)
    }.map { ReactionEntry(it.userId, it.emoji, it.createdAt) }

    /** Reactions of several posts at once (a feed page), per post id. */
    suspend fun reactionsFor(postIds: Collection<String>): Map<String, List<ReactionEntry>> {
        if (postIds.isEmpty()) return emptyMap()
        val rows = postIds.distinct().chunked(IN_CHUNK).flatMap { chunk ->
            api.select(Tables.REACTIONS, Reaction.serializer()) {
                filter { isIn("post_id", chunk) }
                order("created_at", Order.ASCENDING)
            }
        }
        return rows.groupBy({ it.postId }, { ReactionEntry(it.userId, it.emoji, it.createdAt) })
    }

    /** Idempotent: reacting twice with the same emoji returns the existing row. */
    suspend fun react(postId: String, emoji: String): Reaction = api.rpc(Rpc.React, Reaction.serializer()) {
        put("p_post_id", postId)
        put("p_emoji", emoji)
    }

    /** Removes only your row. */
    suspend fun unreact(postId: String, emoji: String) = api.rpcUnit(Rpc.Unreact) {
        put("p_post_id", postId)
        put("p_emoji", emoji)
    }

    private companion object {
        const val IN_CHUNK = 100
    }
}

/** "I'm in this" self-tags (docs/API.md §5.11, §6.2): only ever tags the caller. */
class TagRepository(private val api: Api) {

    suspend fun tags(postId: String): List<PostTag> = api.select(Tables.POST_TAGS, PostTag.serializer()) {
        filter { eq("post_id", postId) }
        order("created_at", Order.ASCENDING)
    }

    /** Posts of [groupId] you tagged yourself in (e.g. eligible tribute photos). */
    suspend fun myTags(groupId: String): List<PostTag> = api.select(Tables.POST_TAGS, PostTag.serializer()) {
        filter {
            eq("group_id", groupId)
            eq("user_id", api.requireUserId())
        }
    }

    suspend fun tagSelf(postId: String): PostTag = api.rpc(Rpc.TagSelf, PostTag.serializer()) { put("p_post_id", postId) }

    suspend fun untagSelf(postId: String) = api.rpcUnit(Rpc.UntagSelf) { put("p_post_id", postId) }
}
