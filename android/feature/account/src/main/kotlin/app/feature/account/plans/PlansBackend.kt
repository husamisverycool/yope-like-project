package app.feature.account.plans

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.platform.LocalContext
import app.data.DataGraph
import app.data.error.DataError
import app.data.error.DataException
import app.data.model.CurrentQuestion
import app.data.model.Developing
import app.data.model.Group
import app.data.model.Media
import app.data.model.NextPlan
import app.data.model.Plan
import app.data.model.PlanAnswer
import app.data.model.PlanAnswerKind
import app.data.model.Post
import app.data.model.Profile
import app.data.offline.DataState
import app.data.repo.Member
import app.data.repo.PlanDetail
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.emptyFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOf
import java.io.File
import java.time.Instant

/**
 * Everything the plan screens, the weekly question card and the developing tile read and write, in one seam over
 * core:data (docs/API.md §14.2–§14.4) so view models are tested with fakes. [GraphPlansBackend] is the app's; every call
 * throws `DataException` with a typed `DataError` on failure.
 */
interface PlansBackend {
    val currentUserId: String?

    /** Device connectivity: current state first, then changes. */
    val online: Flow<Boolean>

    suspend fun group(groupId: String): Group?
    /** Members with their profiles (first names, avatars); cached first when offline. */
    suspend fun members(groupId: String): List<Member>
    suspend fun profiles(ids: Collection<String>): List<Profile>
    suspend fun media(ids: Collection<String>): List<Media>
    suspend fun signedUrls(paths: Collection<String>): Map<String, String>

    // Plans (§14.2)
    fun observePlan(planId: String): Flow<DataState<PlanDetail?>>
    suspend fun plan(planId: String): Plan?
    suspend fun nextPlans(groupId: String): List<NextPlan>
    suspend fun planPhotos(planId: String): List<Post>
    suspend fun uploadCover(jpeg: File): String
    suspend fun createPlan(groupId: String, title: String, startsAt: Instant, allDay: Boolean, place: String?, note: String?, coverPath: String?): Plan
    suspend fun updatePlan(planId: String, title: String, startsAt: Instant, allDay: Boolean, place: String?, note: String?, coverPath: String?): Plan
    suspend fun cancelPlan(planId: String): Plan
    suspend fun restorePlan(planId: String): Plan
    suspend fun answer(planId: String, answer: PlanAnswerKind): PlanAnswer
    suspend fun clearAnswer(planId: String)
    /** A refetch signal per `plans` / `plan_answers` change in the group (and per (re)subscription). */
    fun planChanges(groupId: String): Flow<Unit>

    // Weekly question (§14.4)
    suspend fun currentQuestion(groupId: String): CurrentQuestion?
    suspend fun questionAnswers(questionId: String): List<Post>
    suspend fun hideQuestion(questionId: String)
    suspend fun setWeeklyQuestion(groupId: String, on: Boolean): Group

    // Overnight photos (§14.3)
    suspend fun groupDeveloping(groupId: String): Developing

    /** The countdown widget's snapshot follows a plan change seen on screen. */
    fun planSeenChanged()
}

/** [PlansBackend] over the app's [DataGraph]. */
class GraphPlansBackend(private val graph: DataGraph) : PlansBackend {
    override val currentUserId: String? get() = graph.auth.currentUserId
    override val online: Flow<Boolean> get() = graph.connectivity.online

    override suspend fun group(groupId: String): Group? = graph.groups.group(groupId)

    override suspend fun members(groupId: String): List<Member> {
        val page = graph.groups.observeMembers(groupId).first { !it.refreshing || it.value != null }
        return page.value ?: page.error?.let { throw DataException(it) } ?: emptyList()
    }

    override suspend fun profiles(ids: Collection<String>): List<Profile> = graph.profiles.profiles(ids)
    override suspend fun media(ids: Collection<String>): List<Media> = graph.posts.media(ids)
    override suspend fun signedUrls(paths: Collection<String>): Map<String, String> = graph.signedUrls.urls(paths)

    override fun observePlan(planId: String): Flow<DataState<PlanDetail?>> = graph.plans.observeDetail(planId)
    override suspend fun plan(planId: String): Plan? = graph.plans.plan(planId)
    override suspend fun nextPlans(groupId: String): List<NextPlan> = graph.plans.nextPlans(groupId)
    override suspend fun planPhotos(planId: String): List<Post> = graph.plans.photos(planId)
    override suspend fun uploadCover(jpeg: File): String = graph.plans.uploadCover(jpeg)

    override suspend fun createPlan(groupId: String, title: String, startsAt: Instant, allDay: Boolean, place: String?, note: String?, coverPath: String?): Plan =
        graph.plans.create(groupId, title, startsAt, allDay, place, note, coverPath)

    override suspend fun updatePlan(planId: String, title: String, startsAt: Instant, allDay: Boolean, place: String?, note: String?, coverPath: String?): Plan =
        graph.plans.update(planId, title, startsAt, allDay, place, note, coverPath)

    override suspend fun cancelPlan(planId: String): Plan = graph.plans.cancel(planId)
    override suspend fun restorePlan(planId: String): Plan = graph.plans.restore(planId)
    override suspend fun answer(planId: String, answer: PlanAnswerKind): PlanAnswer = graph.plans.answer(planId, answer)
    override suspend fun clearAnswer(planId: String) = graph.plans.clearAnswer(planId)
    override fun planChanges(groupId: String): Flow<Unit> = graph.planRealtime.changes(groupId)

    override suspend fun currentQuestion(groupId: String): CurrentQuestion? = graph.questions.current(groupId)
    override suspend fun questionAnswers(questionId: String): List<Post> = graph.questions.answers(questionId)
    override suspend fun hideQuestion(questionId: String) = graph.questions.hide(questionId)
    override suspend fun setWeeklyQuestion(groupId: String, on: Boolean): Group = graph.questions.setWeekly(groupId, on)

    override suspend fun groupDeveloping(groupId: String): Developing = graph.developing.group(groupId)

    override fun planSeenChanged() = graph.countdown.request()
}

/** While `config/app.json` has no Supabase URL / key: nothing loads (every read fails with `NotConfigured`). */
object UnconfiguredPlansBackend : PlansBackend {
    private fun fail(): Nothing = throw DataException(DataError.NotConfigured)
    override val currentUserId: String? get() = null
    override val online: Flow<Boolean> = flowOf(true)
    override suspend fun group(groupId: String): Group? = fail()
    override suspend fun members(groupId: String): List<Member> = fail()
    override suspend fun profiles(ids: Collection<String>): List<Profile> = fail()
    override suspend fun media(ids: Collection<String>): List<Media> = fail()
    override suspend fun signedUrls(paths: Collection<String>): Map<String, String> = emptyMap()
    override fun observePlan(planId: String): Flow<DataState<PlanDetail?>> =
        flow { emit(DataState(null, DataState.Source.None, null, refreshing = false, error = DataError.NotConfigured)) }
    override suspend fun plan(planId: String): Plan? = fail()
    override suspend fun nextPlans(groupId: String): List<NextPlan> = fail()
    override suspend fun planPhotos(planId: String): List<Post> = fail()
    override suspend fun uploadCover(jpeg: File): String = fail()
    override suspend fun createPlan(groupId: String, title: String, startsAt: Instant, allDay: Boolean, place: String?, note: String?, coverPath: String?): Plan = fail()
    override suspend fun updatePlan(planId: String, title: String, startsAt: Instant, allDay: Boolean, place: String?, note: String?, coverPath: String?): Plan = fail()
    override suspend fun cancelPlan(planId: String): Plan = fail()
    override suspend fun restorePlan(planId: String): Plan = fail()
    override suspend fun answer(planId: String, answer: PlanAnswerKind): PlanAnswer = fail()
    override suspend fun clearAnswer(planId: String) = fail()
    override fun planChanges(groupId: String): Flow<Unit> = emptyFlow()
    override suspend fun currentQuestion(groupId: String): CurrentQuestion? = fail()
    override suspend fun questionAnswers(questionId: String): List<Post> = fail()
    override suspend fun hideQuestion(questionId: String) = fail()
    override suspend fun setWeeklyQuestion(groupId: String, on: Boolean): Group = fail()
    override suspend fun groupDeveloping(groupId: String): Developing = fail()
    override fun planSeenChanged() = Unit
}

/** Tests and previews replace the backend here; null = the process-wide [DataGraph]. */
val LocalPlansBackend = staticCompositionLocalOf<PlansBackend?> { null }

/** The backend for the plan screens: the override, else the process-wide [DataGraph]. */
@Composable
fun rememberPlansBackend(): PlansBackend {
    LocalPlansBackend.current?.let { return it }
    val context = LocalContext.current.applicationContext
    return remember(context) { plansBackend(context) }
}

fun plansBackend(context: Context): PlansBackend = DataGraph.get(context)?.let(::GraphPlansBackend) ?: UnconfiguredPlansBackend
