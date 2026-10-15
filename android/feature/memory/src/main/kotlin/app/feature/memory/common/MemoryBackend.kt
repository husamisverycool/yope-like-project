package app.feature.memory.common

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.platform.LocalContext
import app.data.DataGraph
import app.data.error.DataError
import app.data.error.DataException
import app.data.model.Collage
import app.data.model.Group
import app.data.model.Media
import app.data.model.OnThisDayItem
import app.data.model.Post
import app.data.model.Profile
import app.data.model.ProfilePrivate
import app.data.model.RenderStatus
import app.data.model.Tribute
import app.data.model.TributeContribution
import app.data.model.TributeRequest
import app.data.model.YearStory
import app.data.realtime.GroupEvent
import app.data.remote.Tables
import io.github.jan.supabase.postgrest.query.Order
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.emptyFlow
import kotlinx.coroutines.flow.filterIsInstance
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.flow.map
import java.time.LocalDate

/**
 * Everything the memory screens read and write, in one seam so view models are tested with fakes.
 * The app's implementation is [GraphMemoryBackend] over core:data ([DataGraph]); every call throws
 * [DataException] with a typed [DataError] on failure (docs/API.md §3).
 */
interface MemoryBackend {
    /** The signed-in user, or null. */
    val currentUserId: String?

    /** Whether the device is online now (core:data `Connectivity`). */
    fun isOnline(): Boolean

    suspend fun group(groupId: String): Group?
    suspend fun onThisDay(groupId: String, localDate: LocalDate): List<OnThisDayItem>

    /** Posts by id in the given order (RLS drops hidden ones). */
    suspend fun posts(ids: List<String>): List<Post>
    suspend fun media(ids: List<String>): List<Media>
    suspend fun profiles(ids: List<String>): List<Profile>

    /** Signed read URLs (1 h); unreadable paths are absent. */
    suspend fun signedUrls(paths: Collection<String>): Map<String, String>

    /** Post ids from the group's private `post_deleted` broadcast (docs/API.md §8.2). */
    fun postDeletions(groupId: String): Flow<String>

    // Birthdays (docs/API.md §5.2, §5.16-§5.18, set_birthday, contribute_tribute).
    suspend fun privateProfile(): ProfilePrivate?
    suspend fun setBirthday(birthday: LocalDate?, optIn: Boolean): ProfilePrivate
    suspend fun openRequests(): List<TributeRequest>
    suspend fun request(requestId: String): TributeRequest?
    suspend fun myContribution(requestId: String): TributeContribution?
    suspend fun contribute(requestId: String, postId: String, line: String): TributeContribution
    suspend fun withdraw(requestId: String)

    /** Posts of [groupId] you posted ∪ posts you are self-tagged in; newest first, no duplicates. */
    suspend fun eligiblePosts(groupId: String): List<Post>
    suspend fun tribute(tributeId: String): Tribute?

    // Year story (docs/API.md §5.19, §5.13).
    suspend fun yearStory(groupId: String, year: Int): YearStory?
    suspend fun yearStories(groupId: String): List<YearStory>
    suspend fun collages(ids: List<String>): List<Collage>

    // "I'm in this" (docs/API.md §5.11, tag_self / untag_self).
    suspend fun isTagged(postId: String): Boolean
    suspend fun tagSelf(postId: String)
    suspend fun untagSelf(postId: String)
}

/** core:data behind [MemoryBackend]. Only the data layer's public API is used. */
class GraphMemoryBackend(private val graph: DataGraph) : MemoryBackend {
    override val currentUserId: String? get() = graph.auth.currentUserId

    override fun isOnline(): Boolean = graph.connectivity.isOnline()

    override suspend fun group(groupId: String): Group? = graph.groups.group(groupId)

    override suspend fun onThisDay(groupId: String, localDate: LocalDate): List<OnThisDayItem> = graph.browse.onThisDay(groupId, localDate)

    override suspend fun posts(ids: List<String>): List<Post> = graph.posts.posts(ids)

    override suspend fun media(ids: List<String>): List<Media> = graph.posts.media(ids)

    override suspend fun profiles(ids: List<String>): List<Profile> = graph.profiles.profiles(ids)

    override suspend fun signedUrls(paths: Collection<String>): Map<String, String> = graph.signedUrls.urls(paths)

    override fun postDeletions(groupId: String): Flow<String> =
        graph.realtime.deletions(groupId).filterIsInstance<GroupEvent.PostDeleted>().map { it.postId }

    override suspend fun privateProfile(): ProfilePrivate? = graph.profiles.privateProfile()

    override suspend fun setBirthday(birthday: LocalDate?, optIn: Boolean): ProfilePrivate = graph.birthdays.setBirthday(birthday, optIn)

    override suspend fun openRequests(): List<TributeRequest> = graph.birthdays.openRequests()

    override suspend fun request(requestId: String): TributeRequest? = graph.birthdays.request(requestId)

    override suspend fun myContribution(requestId: String): TributeContribution? = graph.birthdays.myContribution(requestId)

    override suspend fun contribute(requestId: String, postId: String, line: String): TributeContribution =
        graph.birthdays.contribute(requestId, postId, line)

    override suspend fun withdraw(requestId: String) = graph.birthdays.withdraw(requestId)

    override suspend fun eligiblePosts(groupId: String): List<Post> {
        val uid = graph.api.requireUserId()
        // design/surfaces/birthday.contribute.md, Data: posts where author = you ∪ posts with your tag.
        val mine = graph.api.select(Tables.POSTS, Post.serializer()) {
            filter {
                eq("group_id", groupId)
                eq("author_id", uid)
            }
            order("created_at", Order.DESCENDING)
        }
        val tagged = graph.posts.posts(graph.tags.myTags(groupId).map { it.postId })
        return mergeEligible(mine, tagged)
    }

    override suspend fun tribute(tributeId: String): Tribute? = graph.birthdays.tribute(tributeId)

    override suspend fun yearStory(groupId: String, year: Int): YearStory? = graph.yearStories.yearStory(groupId, year)

    override suspend fun yearStories(groupId: String): List<YearStory> = graph.yearStories.yearStories(groupId)

    override suspend fun collages(ids: List<String>): List<Collage> =
        ids.distinct().mapNotNull { graph.invitations.collage(it) }.filter { it.status == RenderStatus.Ready }

    override suspend fun isTagged(postId: String): Boolean {
        val uid = graph.api.requireUserId()
        return graph.tags.tags(postId).any { it.userId == uid }
    }

    override suspend fun tagSelf(postId: String) {
        graph.tags.tagSelf(postId)
    }

    override suspend fun untagSelf(postId: String) = graph.tags.untagSelf(postId)
}

/** Eligible tribute photos: both sets, newest first, each post once. */
fun mergeEligible(mine: List<Post>, tagged: List<Post>): List<Post> =
    (mine + tagged).distinctBy { it.id }.sortedByDescending { it.createdAt }

/**
 * No data layer (config/app.json has no Supabase URL / key yet, `DataGraph.get` is null): every
 * call fails with [DataError.NotConfigured], which the screens show as their error state.
 */
object UnconfiguredMemoryBackend : MemoryBackend {
    private fun fail(): Nothing = throw DataException(DataError.NotConfigured)
    override val currentUserId: String? get() = null
    override fun isOnline(): Boolean = true
    override suspend fun group(groupId: String): Group? = fail()
    override suspend fun onThisDay(groupId: String, localDate: LocalDate): List<OnThisDayItem> = fail()
    override suspend fun posts(ids: List<String>): List<Post> = fail()
    override suspend fun media(ids: List<String>): List<Media> = fail()
    override suspend fun profiles(ids: List<String>): List<Profile> = fail()
    override suspend fun signedUrls(paths: Collection<String>): Map<String, String> = fail()
    override fun postDeletions(groupId: String): Flow<String> = emptyFlow()
    override suspend fun privateProfile(): ProfilePrivate? = fail()
    override suspend fun setBirthday(birthday: LocalDate?, optIn: Boolean): ProfilePrivate = fail()
    override suspend fun openRequests(): List<TributeRequest> = fail()
    override suspend fun request(requestId: String): TributeRequest? = fail()
    override suspend fun myContribution(requestId: String): TributeContribution? = fail()
    override suspend fun contribute(requestId: String, postId: String, line: String): TributeContribution = fail()
    override suspend fun withdraw(requestId: String) = fail()
    override suspend fun eligiblePosts(groupId: String): List<Post> = fail()
    override suspend fun tribute(tributeId: String): Tribute? = fail()
    override suspend fun yearStory(groupId: String, year: Int): YearStory? = fail()
    override suspend fun yearStories(groupId: String): List<YearStory> = fail()
    override suspend fun collages(ids: List<String>): List<Collage> = fail()
    override suspend fun isTagged(postId: String): Boolean = fail()
    override suspend fun tagSelf(postId: String) = fail()
    override suspend fun untagSelf(postId: String) = fail()
}

/** Overrides the backend below this point (tests, previews). Null = the app's [DataGraph]. */
val LocalMemoryBackend = staticCompositionLocalOf<MemoryBackend?> { null }

/** The backend for the memory screens: the override, else the process-wide [DataGraph]. */
@Composable
fun rememberMemoryBackend(): MemoryBackend {
    LocalMemoryBackend.current?.let { return it }
    val context = LocalContext.current.applicationContext
    return remember(context) { memoryBackend(context) }
}

fun memoryBackend(context: Context): MemoryBackend = DataGraph.get(context)?.let(::GraphMemoryBackend) ?: UnconfiguredMemoryBackend

/** Emits nothing; for fakes. */
fun noDeletions(): Flow<String> = flowOf()
