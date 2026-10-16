package app.feature.memory

import app.data.error.ApiError
import app.data.error.DataError
import app.data.error.DataException
import app.data.model.Collage
import app.data.model.Group
import app.data.model.HistoryWeek
import app.data.model.GroupKind
import app.data.model.Media
import app.data.model.MediaKind
import app.data.model.OnThisDayItem
import app.data.model.Post
import app.data.model.PostTag
import app.data.model.Profile
import app.data.model.ProfilePrivate
import app.data.model.RenderStatus
import app.data.model.Tribute
import app.data.model.TributeContribution
import app.data.model.TributeRequest
import app.data.model.YearStory
import app.feature.memory.common.MemoryBackend
import app.feature.memory.common.mergeEligible
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonObject
import java.time.Instant
import java.time.LocalDate

/**
 * An in-memory [MemoryBackend] that applies the same visibility rules as the database (RLS:
 * requests never visible to their honoree; tributes visible to the honoree only after delivery;
 * blocked authors' posts hidden), records writes, and fails on demand.
 */
class FakeMemoryBackend(override var currentUserId: String? = ME) : MemoryBackend {
    var online = true
    val groups = mutableMapOf<String, Group>()
    val posts = mutableMapOf<String, Post>()
    val media = mutableMapOf<String, Media>()
    val profiles = mutableMapOf<String, Profile>()
    val onThisDay = mutableMapOf<String, List<OnThisDayItem>>()
    val requests = mutableMapOf<String, TributeRequest>()
    val contributions = mutableMapOf<String, TributeContribution>()
    val tributes = mutableMapOf<String, Tribute>()
    val yearStories = mutableMapOf<Pair<String, Int>, YearStory>()
    val collages = mutableMapOf<String, Collage>()
    /** (post, user) self-tags in tag order. */
    val tags = linkedSetOf<Pair<String, String>>()
    /** The group's history weeks (`group_history_weeks`), newest first. */
    val history = mutableListOf<HistoryWeek>()
    var privateRow: ProfilePrivate? = null
    /** Authors hidden from the caller by a block. */
    val blocked = mutableSetOf<String>()
    var now: Instant = NOW

    /** Fails the next call of that name with [error] (then succeeds again). */
    val failNext = mutableMapOf<String, DataError>()
    /** Calls of that name wait until completed (to observe optimistic / pending states). */
    val gates = mutableMapOf<String, CompletableDeferred<Unit>>()
    val calls = mutableListOf<String>()
    val deletions = MutableSharedFlow<String>(extraBufferCapacity = 8)

    private suspend fun call(name: String) {
        calls += name
        gates[name]?.await()
        failNext.remove(name)?.let { throw DataException(it) }
        if (!online) throw DataException(DataError.Network)
    }

    private fun me(): String = currentUserId ?: throw DataException(DataError.NotSignedIn)

    override fun isOnline(): Boolean = online

    override suspend fun group(groupId: String): Group? = call("group").let { groups[groupId] }

    override suspend fun onThisDay(groupId: String, localDate: LocalDate): List<OnThisDayItem> {
        call("onThisDay")
        lastOnThisDayDate = localDate
        return onThisDay[groupId].orEmpty().filter { it.authorId !in blocked }
    }

    var lastOnThisDayDate: LocalDate? = null

    override suspend fun posts(ids: List<String>): List<Post> = call("posts").let { ids.mapNotNull { posts[it] }.filter { it.authorId !in blocked } }

    override suspend fun media(ids: List<String>): List<Media> = call("media").let { ids.mapNotNull { media[it] } }

    override suspend fun profiles(ids: List<String>): List<Profile> = call("profiles").let { ids.mapNotNull { profiles[it] } }

    override suspend fun signedUrls(paths: Collection<String>): Map<String, String> = call("signedUrls").let { paths.associateWith { "https://signed.test/$it" } }

    override fun postDeletions(groupId: String): Flow<String> = deletions

    override suspend fun historyWeeks(groupId: String, beforeWeek: LocalDate?, limit: Int): List<HistoryWeek> {
        call("historyWeeks")
        return history.filter { beforeWeek == null || it.weekStart.isBefore(beforeWeek) }.take(limit)
    }

    override suspend fun deletePost(postId: String) {
        call("deletePost")
        val post = posts[postId] ?: throw DataException(api(ApiError.PostNotFound))
        if (post.authorId != me()) throw DataException(api(ApiError.PostNotFound))
        posts -= postId
        deletedPosts += postId
    }

    val deletedPosts = mutableListOf<String>()

    override suspend fun privateProfile(): ProfilePrivate? = call("privateProfile").let { privateRow }

    override suspend fun setBirthday(birthday: LocalDate?, optIn: Boolean): ProfilePrivate {
        call("setBirthday")
        val row = ProfilePrivate(me(), if (optIn) birthday else privateRow?.birthday, optIn, null, now)
        privateRow = row
        return row
    }

    /** RLS: members other than the honoree, minus anyone blocked with the honoree. */
    private fun visible(r: TributeRequest) = r.honoreeId != currentUserId && r.honoreeId !in blocked

    override suspend fun openRequests(): List<TributeRequest> = call("openRequests").let { requests.values.filter { visible(it) && it.isOpen(now) }.sortedBy { it.dueAt } }

    override suspend fun request(requestId: String): TributeRequest? = call("request").let { requests[requestId]?.takeIf(::visible) }

    override suspend fun myContribution(requestId: String): TributeContribution? =
        call("myContribution").let { contributions.values.firstOrNull { it.requestId == requestId && it.contributorId == currentUserId } }

    override suspend fun contribute(requestId: String, postId: String, line: String): TributeContribution {
        call("contribute")
        val request = requests[requestId]?.takeIf(::visible) ?: throw DataException(api(ApiError.RequestNotFound))
        if (!request.isOpen(now)) throw DataException(api(ApiError.TributeClosed))
        val post = posts[postId] ?: throw DataException(api(ApiError.PostNotFound))
        if (post.groupId != request.groupId || (post.authorId != me() && (postId to me()) !in tags)) throw DataException(api(ApiError.PostNotEligible))
        val c = TributeContribution("c-$requestId-${me()}", requestId, me(), postId, line.trim(), now, now)
        contributions[c.id] = c
        lastContributedLine = line
        return c
    }

    var lastContributedLine: String? = null

    override suspend fun withdraw(requestId: String) {
        call("withdraw")
        contributions.values.removeAll { it.requestId == requestId && it.contributorId == currentUserId }
    }

    override suspend fun eligiblePosts(groupId: String): List<Post> {
        call("eligiblePosts")
        val me = me()
        val mine = posts.values.filter { it.groupId == groupId && it.authorId == me }
        val tagged = posts.values.filter { it.groupId == groupId && (it.id to me) in tags && it.authorId !in blocked }
        return mergeEligible(mine, tagged)
    }

    /** RLS: the honoree only once delivered_at is set and past; other members (not blocked) any time. */
    override suspend fun tribute(tributeId: String): Tribute? {
        call("tribute")
        val t = tributes[tributeId] ?: return null
        if (t.honoreeId in blocked) return null
        if (t.honoreeId == currentUserId && (t.deliveredAt == null || t.deliveredAt!!.isAfter(now))) return null
        return t
    }

    override suspend fun yearStory(groupId: String, year: Int): YearStory? = call("yearStory").let { yearStories[groupId to year] }

    override suspend fun yearStories(groupId: String): List<YearStory> = call("yearStories").let { yearStories.values.filter { it.groupId == groupId } }

    override suspend fun collages(ids: List<String>): List<Collage> = call("collages").let { ids.mapNotNull { collages[it] }.filter { it.status == RenderStatus.Ready } }

    override suspend fun postTags(postId: String): List<PostTag> =
        call("postTags").let { tags.filter { it.first == postId }.map { (p, u) -> PostTag(p, u, posts[p]?.groupId ?: GROUP, NOW) } }

    override suspend fun tagSelf(postId: String) {
        call("tagSelf")
        if (postId !in posts) throw DataException(api(ApiError.PostNotFound))
        tags += postId to me()
    }

    override suspend fun untagSelf(postId: String) {
        call("untagSelf")
        tags -= postId to me()
    }

    companion object {
        const val ME = "u-me"
        const val ANA = "u-ana"
        const val BEN = "u-ben"
        const val CLEO = "u-cleo"
        const val GROUP = "g-1"
        val NOW: Instant = Instant.parse("2026-12-05T18:00:00Z")

        fun api(code: ApiError) = DataError.Api(code, code.wire, code.httpStatus, null)
    }
}

/** Builders for rows (only the columns the screens read are meaningful). */
object Rows {
    private val T0: Instant = Instant.parse("2020-01-01T00:00:00Z")

    fun group(id: String = FakeMemoryBackend.GROUP, name: String = "Sunday Lunch", tz: String = "Europe/Paris") =
        Group(id, name, GroupKind.Friends, null, tz, null, null, false, null, T0, T0)

    fun profile(id: String, name: String, avatar: Boolean = true) = Profile(id, name, if (avatar) "avatars/$id/a.jpg" else null, T0, T0)

    fun media(id: String, owner: String, w: Int = 3, h: Int = 4) = Media(
        id, owner, MediaKind.Photo, "u/$owner/$id/original.jpg", null, null, "u/$owner/$id/r/display.jpg", "u/$owner/$id/r/thumb.jpg", null,
        null, null, w, h, null, null, null, T0, T0,
    )

    fun post(id: String, author: String, at: Instant, group: String = FakeMemoryBackend.GROUP, mediaId: String = "m-$id") =
        Post(id, mediaId, group, author, null, null, null, null, false, null, at)

    fun request(id: String = "r-1", honoree: String = FakeMemoryBackend.ANA, birthday: LocalDate = LocalDate.of(2026, 12, 12), group: String = FakeMemoryBackend.GROUP) =
        TributeRequest(id, group, honoree, birthday, birthday.atStartOfDay(java.time.ZoneId.of("Europe/Paris")).toInstant(), null, T0)

    fun tribute(id: String = "t-1", honoree: String = FakeMemoryBackend.ME, delivered: Instant?, status: RenderStatus = RenderStatus.Ready) =
        Tribute(id, "r-1", FakeMemoryBackend.GROUP, honoree, if (status == RenderStatus.Ready) "g/g-1/tributes/$id/video.mp4" else null, "g/g-1/tributes/$id/poster.jpg", status, T0, delivered, T0)

    fun collage(id: String, postIds: List<String>) = Collage(id, FakeMemoryBackend.GROUP, "inv-$id", "B", postIds, "g/g-1/collages/$id/display-1.jpg", null, null, RenderStatus.Ready, T0, T0)

    fun storyData(
        year: Int = 2026,
        moments: Int = 1284,
        busiest: Int? = 7,
        mostReacted: List<String> = emptyList(),
        days: List<Triple<String, String, List<String>>> = emptyList(),
    ): JsonElement = buildJsonObject {
        put("version", 1)
        put("year", year)
        put("time_zone", "Europe/Paris")
        put("moments_shared", moments)
        if (busiest != null) putJsonObject("busiest_month") { put("month", busiest) }
        put("most_reacted", buildJsonArray { mostReacted.forEach { add(kotlinx.serialization.json.JsonPrimitive(it)) } })
        put(
            "everyone_days",
            buildJsonArray {
                days.forEach { (date, collage, ids) ->
                    add(
                        buildJsonObject {
                            put("local_date", date)
                            put("invitation_id", "inv-$collage")
                            put("collage_id", collage)
                            put("post_ids", buildJsonArray { ids.forEach { add(kotlinx.serialization.json.JsonPrimitive(it)) } })
                        },
                    )
                }
            },
        )
    }

    fun yearStory(data: JsonElement?, status: RenderStatus = RenderStatus.Ready, year: Int = 2026, postIds: List<String> = emptyList()) =
        YearStory("ys-$year", FakeMemoryBackend.GROUP, year, status, data, postIds, emptyList(), T0, T0)
}
