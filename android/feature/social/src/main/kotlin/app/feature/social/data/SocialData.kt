package app.feature.social.data

import android.content.Context
import app.data.DataGraph
import app.data.error.DataError
import app.data.error.DataException
import app.data.model.Album
import app.data.model.AlbumItem
import app.data.model.Collage
import app.data.model.Group
import app.data.model.HistoryWeek
import app.data.model.Media
import app.data.model.Message
import app.data.model.Post
import app.data.model.PostTag
import app.data.model.Profile
import app.data.model.WallItem
import app.data.model.WeeklyRecap
import app.data.offline.CacheKey
import app.data.offline.DataState
import app.data.realtime.GroupEvent
import app.data.remote.Tables
import io.github.jan.supabase.postgrest.query.Order
import app.data.repo.Member
import app.data.repo.ReactionEntry
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.emptyFlow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOf
import kotlinx.serialization.KSerializer
import java.io.File
import java.time.Instant
import java.time.LocalDate

/**
 * Everything the social screens read and write, as one interface over `core:data`
 * (docs/API.md §5–§8). The production implementation ([GraphSocialData]) forwards to the data
 * layer's repositories unchanged; tests use fakes. Nothing here counts anything: reactions are
 * `(user, emoji)` rows.
 */
interface SocialData {
    fun currentUserId(): String?

    /** Device reachability (core:data `Connectivity`). */
    val online: Flow<Boolean>

    /** Realtime inserts / updates / deletions of one group (core:data `GroupRealtime.events`). */
    fun events(groupId: String): Flow<GroupEvent>

    suspend fun group(groupId: String): Group?
    suspend fun myGroups(): List<Group>
    suspend fun members(groupId: String): List<Member>
    suspend fun profiles(ids: Collection<String>): List<Profile>

    fun observeMessages(groupId: String): Flow<DataState<List<Message>>>
    suspend fun messages(groupId: String, before: Instant?): List<Message>
    /** One message by id (a quoted message older than the loaded pages); null when it is gone. */
    suspend fun message(messageId: String): Message?
    /** A text message, optionally replying to a photo ([replyToPostId]) or a message ([replyToMessageId]) (`send_message`). */
    suspend fun sendText(groupId: String, body: String, replyToPostId: String? = null, replyToMessageId: String? = null): Message
    /** A voice message with its waveform ([levels]: 100 values of 0…31, `p_voice_levels`; null sends none). */
    suspend fun sendVoice(groupId: String, audio: File, durationMs: Int, levels: List<Int>? = null): Message
    suspend fun deleteMessage(messageId: String)

    /** Replies to a photo in its group's chat (`messages` with `reply_to_post_id`), oldest first (`photo.viewer.layout.comments`). */
    suspend fun replies(groupId: String, postId: String): List<Message>

    suspend fun feed(groupId: String, before: Instant?): List<Post>
    suspend fun posts(ids: Collection<String>): List<Post>
    suspend fun media(ids: Collection<String>): List<Media>
    suspend fun deleteMedia(mediaId: String)

    suspend fun reactions(postIds: Collection<String>): Map<String, List<ReactionEntry>>
    suspend fun react(postId: String, emoji: String)
    /** Takes back your reaction with [emoji] (`unreact`, `chat.reactions.layout.unreact`). */
    suspend fun unreact(postId: String, emoji: String)

    suspend fun isTaggedByMe(postId: String): Boolean
    /** `post_tags` of a photo in tag order (docs/API.md §5.11): who said "I'm in this". */
    suspend fun tags(postId: String): List<PostTag>
    suspend fun tagSelf(postId: String)
    suspend fun untagSelf(postId: String)

    fun observeWall(userId: String): Flow<DataState<List<WallItem>>>
    suspend fun wall(userId: String, before: Instant?, limit: Int): List<WallItem>
    suspend fun collages(ids: Collection<String>): List<Collage>

    fun observeHistory(groupId: String): Flow<DataState<List<HistoryWeek>>>
    suspend fun historyWeeks(groupId: String, beforeWeek: LocalDate?, limit: Int): List<HistoryWeek>

    suspend fun recaps(groupId: String): List<WeeklyRecap>
    suspend fun recap(recapId: String): WeeklyRecap?
    suspend fun updateRecap(recapId: String, items: List<String>, text: String): WeeklyRecap

    suspend fun albums(groupId: String): List<Album>
    suspend fun albumItems(albumId: String): List<AlbumItem>
    suspend fun saveAlbum(groupId: String, name: String, postIds: List<String>): Album
    suspend fun renameAlbum(albumId: String, name: String): Album
    suspend fun deleteAlbum(albumId: String)

    /** Signed read URLs (1 h, docs/API.md §7); unreadable paths are absent. */
    suspend fun signedUrls(paths: Collection<String>): Map<String, String>

    /** Bytes of an object you can read (save to gallery). */
    suspend fun download(path: String): ByteArray

    /** The offline page cache for what the screens compose themselves (posts and profiles of a page). */
    suspend fun <T> cacheGet(key: String, serializer: KSerializer<T>): T?
    suspend fun <T> cachePut(key: String, serializer: KSerializer<T>, value: T)
}

/** [SocialData] over the app's [DataGraph]. */
class GraphSocialData(private val graph: DataGraph) : SocialData {
    override fun currentUserId(): String? = graph.auth.currentUserId
    override val online: Flow<Boolean> get() = graph.connectivity.online
    override fun events(groupId: String): Flow<GroupEvent> = graph.realtime.events(groupId)

    override suspend fun group(groupId: String) = graph.groups.group(groupId)
    override suspend fun myGroups() = graph.groups.myGroups()
    override suspend fun members(groupId: String) = graph.groups.members(groupId)
    override suspend fun profiles(ids: Collection<String>) = graph.profiles.profiles(ids)

    override fun observeMessages(groupId: String) = graph.chat.observeMessages(groupId)
    override suspend fun messages(groupId: String, before: Instant?) = graph.chat.messages(groupId, before)
    override suspend fun message(messageId: String) = graph.chat.message(messageId)
    override suspend fun sendText(groupId: String, body: String, replyToPostId: String?, replyToMessageId: String?) = graph.chat.sendText(groupId, body, replyToPostId, replyToMessageId)
    override suspend fun sendVoice(groupId: String, audio: File, durationMs: Int, levels: List<Int>?) = graph.chat.sendVoice(groupId, audio, durationMs, levels)
    override suspend fun deleteMessage(messageId: String) = graph.chat.deleteMessage(messageId)
    override suspend fun replies(groupId: String, postId: String): List<Message> =
        graph.api.select(Tables.MESSAGES, Message.serializer()) {
            filter {
                eq("group_id", groupId)
                eq("reply_to_post_id", postId)
            }
            order("created_at", Order.ASCENDING)
        }

    override suspend fun feed(groupId: String, before: Instant?) = graph.posts.feed(groupId, before)
    override suspend fun posts(ids: Collection<String>) = graph.posts.posts(ids)
    override suspend fun media(ids: Collection<String>) = graph.posts.media(ids)
    override suspend fun deleteMedia(mediaId: String) = graph.posts.deleteMedia(mediaId)

    override suspend fun reactions(postIds: Collection<String>) = graph.reactions.reactionsFor(postIds)
    override suspend fun react(postId: String, emoji: String) {
        graph.reactions.react(postId, emoji)
    }
    override suspend fun unreact(postId: String, emoji: String) = graph.reactions.unreact(postId, emoji)

    override suspend fun isTaggedByMe(postId: String): Boolean {
        val me = currentUserId() ?: return false
        return graph.tags.tags(postId).any { it.userId == me }
    }
    override suspend fun tags(postId: String): List<PostTag> = graph.tags.tags(postId)
    override suspend fun tagSelf(postId: String) {
        graph.tags.tagSelf(postId)
    }
    override suspend fun untagSelf(postId: String) = graph.tags.untagSelf(postId)

    override fun observeWall(userId: String) = graph.browse.observeWall(userId)
    override suspend fun wall(userId: String, before: Instant?, limit: Int) = graph.browse.wall(userId, before, limit)
    override suspend fun collages(ids: Collection<String>) = ids.distinct().mapNotNull { graph.invitations.collage(it) }

    override fun observeHistory(groupId: String) = graph.browse.observeHistory(groupId)
    override suspend fun historyWeeks(groupId: String, beforeWeek: LocalDate?, limit: Int) = graph.browse.historyWeeks(groupId, beforeWeek, limit)

    override suspend fun recaps(groupId: String) = graph.recaps.recaps(groupId)
    override suspend fun recap(recapId: String) = graph.recaps.recap(recapId)
    override suspend fun updateRecap(recapId: String, items: List<String>, text: String) = graph.recaps.updateRecap(recapId, items, text)

    override suspend fun albums(groupId: String) = graph.albums.albums(groupId)
    override suspend fun albumItems(albumId: String) = graph.albums.items(albumId)
    override suspend fun saveAlbum(groupId: String, name: String, postIds: List<String>) = graph.albums.saveAlbum(groupId, name, postIds)
    override suspend fun renameAlbum(albumId: String, name: String) = graph.albums.renameAlbum(albumId, name)
    override suspend fun deleteAlbum(albumId: String) = graph.albums.deleteAlbum(albumId)

    override suspend fun signedUrls(paths: Collection<String>) = graph.signedUrls.urls(paths)
    override suspend fun download(path: String) = graph.storage.download(path)

    override suspend fun <T> cacheGet(key: String, serializer: KSerializer<T>): T? = graph.cache.get(CacheKey("social/$key"), serializer)?.value
    override suspend fun <T> cachePut(key: String, serializer: KSerializer<T>, value: T) = graph.cache.put(CacheKey("social/$key"), serializer, value)
}

/** While `config/app.json` has no Supabase URL / key: every call fails with [DataError.NotConfigured]. */
object UnconfiguredSocialData : SocialData {
    private fun fail(): Nothing = throw DataException(DataError.NotConfigured)
    private fun <T> failing(): Flow<DataState<T>> = flowOf(DataState(null, DataState.Source.None, null, refreshing = false, error = DataError.NotConfigured))

    override fun currentUserId(): String? = null
    override val online: Flow<Boolean> = flowOf(true)
    override fun events(groupId: String): Flow<GroupEvent> = emptyFlow()
    override suspend fun group(groupId: String): Group? = fail()
    override suspend fun myGroups(): List<Group> = fail()
    override suspend fun members(groupId: String): List<Member> = fail()
    override suspend fun profiles(ids: Collection<String>): List<Profile> = fail()
    override fun observeMessages(groupId: String): Flow<DataState<List<Message>>> = failing()
    override suspend fun messages(groupId: String, before: Instant?): List<Message> = fail()
    override suspend fun message(messageId: String): Message? = fail()
    override suspend fun sendText(groupId: String, body: String, replyToPostId: String?, replyToMessageId: String?): Message = fail()
    override suspend fun sendVoice(groupId: String, audio: File, durationMs: Int, levels: List<Int>?): Message = fail()
    override suspend fun deleteMessage(messageId: String) = fail()
    override suspend fun replies(groupId: String, postId: String): List<Message> = fail()
    override suspend fun feed(groupId: String, before: Instant?): List<Post> = fail()
    override suspend fun posts(ids: Collection<String>): List<Post> = fail()
    override suspend fun media(ids: Collection<String>): List<Media> = fail()
    override suspend fun deleteMedia(mediaId: String) = fail()
    override suspend fun reactions(postIds: Collection<String>): Map<String, List<ReactionEntry>> = fail()
    override suspend fun react(postId: String, emoji: String) = fail()
    override suspend fun unreact(postId: String, emoji: String) = fail()
    override suspend fun isTaggedByMe(postId: String): Boolean = fail()
    override suspend fun tags(postId: String): List<PostTag> = fail()
    override suspend fun tagSelf(postId: String) = fail()
    override suspend fun untagSelf(postId: String) = fail()
    override fun observeWall(userId: String): Flow<DataState<List<WallItem>>> = failing()
    override suspend fun wall(userId: String, before: Instant?, limit: Int): List<WallItem> = fail()
    override suspend fun collages(ids: Collection<String>): List<Collage> = fail()
    override fun observeHistory(groupId: String): Flow<DataState<List<HistoryWeek>>> = failing()
    override suspend fun historyWeeks(groupId: String, beforeWeek: LocalDate?, limit: Int): List<HistoryWeek> = fail()
    override suspend fun recaps(groupId: String): List<WeeklyRecap> = fail()
    override suspend fun recap(recapId: String): WeeklyRecap? = fail()
    override suspend fun updateRecap(recapId: String, items: List<String>, text: String): WeeklyRecap = fail()
    override suspend fun albums(groupId: String): List<Album> = fail()
    override suspend fun albumItems(albumId: String): List<AlbumItem> = fail()
    override suspend fun saveAlbum(groupId: String, name: String, postIds: List<String>): Album = fail()
    override suspend fun renameAlbum(albumId: String, name: String): Album = fail()
    override suspend fun deleteAlbum(albumId: String) = fail()
    override suspend fun signedUrls(paths: Collection<String>): Map<String, String> = emptyMap()
    override suspend fun download(path: String): ByteArray = fail()
    override suspend fun <T> cacheGet(key: String, serializer: KSerializer<T>): T? = null
    override suspend fun <T> cachePut(key: String, serializer: KSerializer<T>, value: T) = Unit
}

/** The app's [SocialData]: the data graph once configured. */
fun socialDataFor(context: Context): SocialData = DataGraph.get(context)?.let(::GraphSocialData) ?: UnconfiguredSocialData

/** The typed reason of a failure, for choosing the error / offline state. */
fun Throwable.dataError(): DataError = (this as? DataException)?.error ?: app.data.error.ErrorMapping.map(this)

/** A cache-then-network flow over any loader, through [SocialData.cacheGet]/[SocialData.cachePut] (same shape as core:data `cachedFlow`). */
fun <T> SocialData.cached(key: String, serializer: KSerializer<T>, fetch: suspend () -> T): Flow<DataState<T>> = flow {
    val cached = runCatching { cacheGet(key, serializer) }.getOrNull()
    emit(DataState(cached, if (cached != null) DataState.Source.Cache else DataState.Source.None, null, refreshing = true, error = null))
    val fresh = try {
        fetch()
    } catch (e: kotlinx.coroutines.CancellationException) {
        throw e
    } catch (e: Throwable) {
        emit(DataState(cached, if (cached != null) DataState.Source.Cache else DataState.Source.None, null, refreshing = false, error = e.dataError()))
        return@flow
    }
    runCatching { cachePut(key, serializer, fresh) }
    emit(DataState(fresh, DataState.Source.Network, null, refreshing = false, error = null))
}
