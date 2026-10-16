package app.data.repo

import app.data.media.MediaStorage
import app.data.media.StoragePaths
import app.data.model.InstantSerializer
import app.data.model.Message
import app.data.model.MessageKind
import app.data.offline.CacheKey
import app.data.offline.DataState
import app.data.offline.OfflineCache
import app.data.offline.cachedFlow
import app.data.remote.Api
import app.data.remote.Rpc
import app.data.remote.Tables
import io.github.jan.supabase.postgrest.query.Order
import kotlinx.coroutines.flow.Flow
import kotlinx.serialization.builtins.ListSerializer
import java.io.File
import java.time.Clock
import java.time.Instant
import java.util.UUID

/**
 * Group chat (docs/API.md §5.9, §6.2): pages, text and voice messages, replies to a photo or a
 * message, and deleting your own messages. Photo messages are created by `create_post` and carry
 * `post_id`; render their caption and voice note from the post.
 */
class ChatRepository(
    private val api: Api,
    private val storage: MediaStorage,
    private val cache: OfflineCache,
    private val clock: Clock = Clock.systemUTC(),
) {
    /** Newest first, [limit] messages older than [before]. */
    suspend fun messages(groupId: String, before: Instant? = null, limit: Int = PAGE): List<Message> =
        api.select(Tables.MESSAGES, Message.serializer()) {
            filter {
                eq("group_id", groupId)
                if (before != null) lt("created_at", InstantSerializer.format(before))
            }
            order("created_at", Order.DESCENDING)
            limit(limit.toLong())
        }

    fun observeMessages(groupId: String): Flow<DataState<List<Message>>> =
        cachedFlow(cache, CacheKey.chat(groupId), ListSerializer(Message.serializer()), clock) { messages(groupId) }

    suspend fun message(messageId: String): Message? =
        api.selectSingleOrNull(Tables.MESSAGES, Message.serializer()) { filter { eq("id", messageId) } }

    /** A text message, optionally replying to a photo ([replyToPostId]) or a message. */
    suspend fun sendText(groupId: String, body: String, replyToPostId: String? = null, replyToMessageId: String? = null): Message =
        api.rpc(Rpc.SendMessage, Message.serializer()) {
            put("p_group_id", groupId)
            put("p_kind", MessageKind.Text.wire)
            put("p_body", body)
            opt("p_reply_to_post_id", replyToPostId)
            opt("p_reply_to_message_id", replyToMessageId)
        }

    /** Reply to a photo in the chat ("reply-to-photo"). A photo replying to a photo is `create_post`. */
    suspend fun replyToPhoto(groupId: String, postId: String, body: String): Message = sendText(groupId, body, replyToPostId = postId)

    /**
     * Uploads [audio] (AAC in MP4, `.m4a`) to `u/<uid>/voice/<uuid>.m4a`, then sends the voice message with its waveform
     * ([levels]: 100 values of 0…31, `p_voice_levels`; null sends none).
     */
    suspend fun sendVoice(
        groupId: String,
        audio: File,
        durationMs: Int,
        levels: List<Int>? = null,
        replyToPostId: String? = null,
        replyToMessageId: String? = null,
    ): Message {
        require(durationMs > 0) { "voice duration must be > 0" }
        val path = StoragePaths.chatVoice(api.requireUserId(), UUID.randomUUID().toString())
        storage.upload(path, audio, "audio/mp4") { _, _ -> }
        return api.rpc(Rpc.SendMessage, Message.serializer()) {
            put("p_group_id", groupId)
            put("p_kind", MessageKind.Voice.wire)
            put("p_voice_path", path)
            put("p_voice_duration_ms", durationMs)
            optInts("p_voice_levels", levels)
            opt("p_reply_to_post_id", replyToPostId)
            opt("p_reply_to_message_id", replyToMessageId)
        }
    }

    /** Your own text / voice message (a photo message goes with `delete_post`). */
    suspend fun deleteMessage(messageId: String) = api.rpcUnit(Rpc.DeleteMessage) { put("p_message_id", messageId) }

    companion object {
        const val PAGE = 50
    }
}
