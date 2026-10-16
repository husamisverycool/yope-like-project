package app.data.repo

import app.data.error.DataException
import app.data.error.ErrorMapping
import app.data.media.MediaStorage
import app.data.media.StoragePaths
import app.data.model.CurrentQuestion
import app.data.model.Developing
import app.data.model.Group
import app.data.model.NextPlan
import app.data.model.Plan
import app.data.model.PlanAnswer
import app.data.model.PlanAnswerKind
import app.data.model.Post
import app.data.offline.CacheKey
import app.data.offline.DataState
import app.data.offline.OfflineCache
import app.data.remote.Api
import app.data.remote.Rpc
import app.data.remote.Tables
import io.github.jan.supabase.postgrest.query.Order
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.flow
import kotlinx.serialization.Serializable
import java.io.File
import java.time.Clock
import java.time.Instant
import java.util.UUID

/** A plan with the answers you can see (RLS: Going / Maybe for all, Can't go for its author and the plan's maker). */
@Serializable
data class PlanDetail(val plan: Plan, val answers: List<PlanAnswer>)

/**
 * Plans (docs/API.md §14.2, Partiful / Apple Invites): the plan and its answers, the upcoming plans of your groups
 * (`next_plans`, the group screen's row and the countdown widget), the plan's photos (`plan_photos`), making, editing,
 * cancelling and restoring a plan, and answering. No counts anywhere: answers are rows. Every write is announced on
 * [changes] (the countdown widget's snapshot follows it).
 */
class PlanRepository(
    private val api: Api,
    private val storage: MediaStorage,
    private val cache: OfflineCache,
    private val clock: Clock = Clock.systemUTC(),
) {
    private val changed = MutableSharedFlow<String>(extraBufferCapacity = CHANGE_BUFFER)

    /** Ids of plans this device just wrote (made, edited, cancelled, restored, answered). */
    val changes: SharedFlow<String> = changed.asSharedFlow()

    suspend fun plan(planId: String): Plan? = api.selectSingleOrNull(Tables.PLANS, Plan.serializer()) { filter { eq("id", planId) } }

    /** Visible answers, oldest first (the order the names and avatars are listed in). */
    suspend fun answers(planId: String): List<PlanAnswer> = api.select(Tables.PLAN_ANSWERS, PlanAnswer.serializer()) {
        filter { eq("plan_id", planId) }
        order("answered_at", Order.ASCENDING)
    }

    /** The plan and its answers; null when it is gone or hidden (RLS: removed from the group, blocked maker). */
    suspend fun detail(planId: String): PlanDetail? {
        val plan = plan(planId) ?: return null
        return PlanDetail(plan, answers(planId))
    }

    /**
     * Cache-then-network plan page (`plans.page` → offline: cached content). A null value from the network means the plan
     * is gone or hidden (its cached copy is dropped).
     */
    fun observeDetail(planId: String): Flow<DataState<PlanDetail?>> = flow {
        val key = CacheKey("plans/$planId")
        val cached = cache.get(key, PlanDetail.serializer())
        val source = if (cached != null) DataState.Source.Cache else DataState.Source.None
        emit(DataState(cached?.value, source, cached?.savedAt, refreshing = true, error = null))
        val fresh = try {
            detail(planId)
        } catch (e: CancellationException) {
            throw e
        } catch (e: Throwable) {
            emit(DataState(cached?.value, source, cached?.savedAt, refreshing = false, error = (e as? DataException)?.error ?: ErrorMapping.map(e)))
            return@flow
        }
        if (fresh != null) cache.put(key, PlanDetail.serializer(), fresh) else cache.remove(key)
        emit(DataState(fresh, DataState.Source.Network, clock.instant(), refreshing = false, error = null))
    }

    /** Upcoming plans (not cancelled, not over) of one group, or of all your groups when [groupId] is null, soonest first. */
    suspend fun nextPlans(groupId: String? = null): List<NextPlan> = api.rpcList(Rpc.NextPlans, NextPlan.serializer()) {
        opt("p_group_id", groupId)
    }

    /** The group's posts of the plan's local days, oldest first (minus blocked authors); none for a cancelled plan. */
    suspend fun photos(planId: String): List<Post> = api.rpcList(Rpc.PlanPhotos, Post.serializer()) { put("p_plan_id", planId) }

    /** Uploads a cover JPEG to `u/<uid>/covers/<uuid>.jpg` before `create_plan` / `update_plan` (as group covers). */
    suspend fun uploadCover(jpeg: File): String {
        val path = StoragePaths.cover(api.requireUserId(), UUID.randomUUID().toString())
        storage.upload(path, jpeg, "image/jpeg") { _, _ -> }
        return path
    }

    /**
     * Any member. The maker's answer starts as Going; the members get one push. [startsAt] for an all-day plan is any
     * instant of its day (the server stores 00:00 of the group's day). No end time is sent (the design has no row).
     */
    suspend fun create(
        groupId: String,
        title: String,
        startsAt: Instant,
        allDay: Boolean,
        place: String? = null,
        note: String? = null,
        coverPath: String? = null,
    ): Plan = api.rpc(Rpc.CreatePlan, Plan.serializer()) {
        put("p_group_id", groupId)
        put("p_title", title)
        put("p_starts_at", startsAt)
        put("p_all_day", allDay)
        opt("p_place", place)
        opt("p_note", note)
        opt("p_cover_path", coverPath)
    }.also { changed.tryEmit(it.id) }

    /**
     * The maker or an admin, until the plan is over. Every field is replaced: pass the current [coverPath] to keep the
     * cover (null removes it), and null [place] / [note] clear them.
     */
    suspend fun update(
        planId: String,
        title: String,
        startsAt: Instant,
        allDay: Boolean,
        place: String?,
        note: String?,
        coverPath: String?,
    ): Plan = api.rpc(Rpc.UpdatePlan, Plan.serializer()) {
        put("p_plan_id", planId)
        put("p_title", title)
        put("p_starts_at", startsAt)
        put("p_all_day", allDay)
        put("p_place", place)
        put("p_note", note)
        put("p_cover_path", coverPath)
    }.also { changed.tryEmit(it.id) }

    /** The maker or an admin: Going and Maybe are told once; the plan stays (struck through) and can be restored. */
    suspend fun cancel(planId: String): Plan = api.rpc(Rpc.CancelPlan, Plan.serializer()) { put("p_plan_id", planId) }.also { changed.tryEmit(planId) }

    /** Undoes [cancel]; tells nobody. */
    suspend fun restore(planId: String): Plan = api.rpc(Rpc.RestorePlan, Plan.serializer()) { put("p_plan_id", planId) }.also { changed.tryEmit(planId) }

    /** One tap: replaces your previous answer. */
    suspend fun answer(planId: String, answer: PlanAnswerKind): PlanAnswer = api.rpc(Rpc.AnswerPlan, PlanAnswer.serializer()) {
        put("p_plan_id", planId)
        put("p_answer", answer.wire)
    }.also { changed.tryEmit(planId) }

    /** Back to no answer. */
    suspend fun clearAnswer(planId: String) {
        api.rpcUnit(Rpc.ClearAnswer) { put("p_plan_id", planId) }
        changed.tryEmit(planId)
    }

    private companion object {
        const val CHANGE_BUFFER = 8
    }
}

/**
 * The weekly question (docs/API.md §14.4, Retro's prompt cards / Apple Journal): this group week's question, hiding it
 * for yourself, linking a post of yours to it, the admin switch, and the week's answers (posts carrying the question).
 * Nothing counts or lists who answered.
 */
class QuestionRepository(private val api: Api) {

    /** This group week's question; null when the feature is off for the group or no catalogue is configured. */
    suspend fun current(groupId: String): CurrentQuestion? =
        api.rpcList(Rpc.CurrentGroupQuestion, CurrentQuestion.serializer()) { put("p_group_id", groupId) }.firstOrNull()

    /** "Remove": the card goes for you, that week. */
    suspend fun hide(questionId: String) = api.rpcUnit(Rpc.HideQuestion) { put("p_question_id", questionId) }

    /** Links your post (in the question's group, during its week) to the question; null unlinks. */
    suspend fun answer(postId: String, questionId: String?): Post = api.rpc(Rpc.AnswerQuestion, Post.serializer()) {
        put("p_post_id", postId)
        put("p_question_id", questionId)
    }

    /** The answers: posts carrying [questionId], oldest first (the strip's order). */
    suspend fun answers(questionId: String): List<Post> = api.select(Tables.POSTS, Post.serializer()) {
        filter { eq("question_id", questionId) }
        order("created_at", Order.ASCENDING)
    }

    /** Admins: turns the question on or off for the group. */
    suspend fun setWeekly(groupId: String, on: Boolean): Group = api.rpc(Rpc.SetGroupWeeklyQuestion, Group.serializer()) {
        put("p_group_id", groupId)
        put("p_on", on)
    }
}

/** Overnight photos as a group sees them (docs/API.md §14.3): whether any develop and the next reveal — never a number. */
class DevelopingRepository(private val api: Api) {
    suspend fun group(groupId: String): Developing =
        api.rpcList(Rpc.GroupDeveloping, Developing.serializer()) { put("p_group_id", groupId) }.firstOrNull()
            ?: Developing(developing = false, revealAt = null)
}
