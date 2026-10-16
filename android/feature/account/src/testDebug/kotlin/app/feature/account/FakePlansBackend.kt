package app.feature.account

import app.data.error.DataError
import app.data.error.DataException
import app.data.model.CurrentQuestion
import app.data.model.Developing
import app.data.model.Group
import app.data.model.GroupKind
import app.data.model.GroupMember
import app.data.model.Media
import app.data.model.MediaKind
import app.data.model.MemberRole
import app.data.model.NextPlan
import app.data.model.Plan
import app.data.model.PlanAnswer
import app.data.model.PlanAnswerKind
import app.data.model.Post
import app.data.model.Profile
import app.data.offline.DataState
import app.data.repo.Member
import app.data.repo.PlanDetail
import app.feature.account.plans.PlansBackend
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.flow
import java.io.File
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

/** An in-memory [PlansBackend] for view-model tests: plans, answers, members, a question; scripted failures by method name. */
class FakePlansBackend(val now: Instant = Instant.parse("2026-10-15T17:00:00Z")) : PlansBackend {
    var me: String? = "u-me"
    override val currentUserId: String? get() = me
    val onlineState = MutableStateFlow(true)
    override val online: Flow<Boolean> = onlineState

    val failures = HashMap<String, DataError>()
    val calls = mutableListOf<String>()
    val groups = LinkedHashMap<String, Group>()
    val members = LinkedHashMap<String, MutableList<Member>>()
    val plans = LinkedHashMap<String, Plan>()
    val answers = LinkedHashMap<String, MutableList<PlanAnswer>>()
    val photos = LinkedHashMap<String, List<Post>>()
    val media = LinkedHashMap<String, Media>()
    var question: CurrentQuestion? = null
    val questionAnswers = mutableListOf<Post>()
    var developing = Developing(false, null)
    val changes = MutableSharedFlow<Unit>(extraBufferCapacity = 4)
    var seenChanged = 0

    private fun call(name: String) {
        calls += name
        failures[name]?.let { throw DataException(it) }
    }

    fun group(id: String, zone: String = "UTC", weeklyQuestion: Boolean = false) {
        groups[id] = Group(id, "Sunday dinners", GroupKind.Friends, null, zone, null, null, false, "u-me", now, now, weeklyQuestion)
    }

    fun member(groupId: String, userId: String, name: String, role: MemberRole = MemberRole.Member) {
        members.getOrPut(groupId) { mutableListOf() } += Member(GroupMember(groupId, userId, role, false, now), Profile(userId, name, null, now, now))
    }

    fun plan(id: String, groupId: String, day: String, createdBy: String? = "u-me", canceled: Boolean = false, allDay: Boolean = false): Plan {
        val date = LocalDate.parse(day)
        val plan = Plan(
            id, groupId, createdBy, "Picnic at the lake", date.atTime(18, 30).atZone(ZoneId.of("UTC")).toInstant(), null, allDay, date,
            "Lake Park", "Bring a blanket", null, if (canceled) now else null, if (canceled) createdBy else null, now, now,
        )
        plans[id] = plan
        return plan
    }

    fun answer(planId: String, userId: String, kind: PlanAnswerKind) {
        val plan = plans.getValue(planId)
        answers.getOrPut(planId) { mutableListOf() } += PlanAnswer(planId, userId, plan.groupId, kind, now)
    }

    override suspend fun group(groupId: String): Group? = groups[groupId].also { call("group") }
    override suspend fun members(groupId: String): List<Member> = members[groupId].orEmpty().also { call("members") }
    override suspend fun profiles(ids: Collection<String>): List<Profile> = emptyList<Profile>().also { call("profiles") }
    override suspend fun media(ids: Collection<String>): List<Media> = ids.mapNotNull { media[it] }.also { call("media") }
    override suspend fun signedUrls(paths: Collection<String>): Map<String, String> = paths.associateWith { "https://signed.example/$it" }

    override fun observePlan(planId: String): Flow<DataState<PlanDetail?>> = flow {
        emit(DataState(null, DataState.Source.None, null, refreshing = true, error = null))
        try {
            call("observePlan")
            val detail = plans[planId]?.let { PlanDetail(it, answers[planId].orEmpty().toList()) }
            emit(DataState(detail, DataState.Source.Network, now, refreshing = false, error = null))
        } catch (e: DataException) {
            emit(DataState(null, DataState.Source.None, null, refreshing = false, error = e.error))
        }
    }

    override suspend fun plan(planId: String): Plan? = plans[planId].also { call("plan") }
    override suspend fun nextPlans(groupId: String): List<NextPlan> {
        call("nextPlans")
        return plans.values.filter { it.groupId == groupId && !it.canceled }.map {
            NextPlan(it.id, it.groupId, it.createdBy, it.title, it.startsAt, it.endsAt, it.allDay, it.localDate, it.place, it.coverPath, null)
        }
    }
    override suspend fun planPhotos(planId: String): List<Post> = photos[planId].orEmpty().also { call("planPhotos") }
    override suspend fun uploadCover(jpeg: File): String = "u/u-me/covers/new.jpg".also { call("uploadCover") }

    var created: Plan? = null
    var updated: Plan? = null

    override suspend fun createPlan(groupId: String, title: String, startsAt: Instant, allDay: Boolean, place: String?, note: String?, coverPath: String?): Plan {
        call("createPlan")
        val date = startsAt.atZone(ZoneId.of(groups[groupId]?.timeZone ?: "UTC")).toLocalDate()
        return Plan("p-new", groupId, me, title, startsAt, null, allDay, date, place, note, coverPath, null, null, now, now).also { created = it; plans[it.id] = it }
    }

    override suspend fun updatePlan(planId: String, title: String, startsAt: Instant, allDay: Boolean, place: String?, note: String?, coverPath: String?): Plan {
        call("updatePlan")
        val old = plans.getValue(planId)
        return old.copy(title = title, startsAt = startsAt, allDay = allDay, place = place, note = note, coverPath = coverPath).also { updated = it; plans[planId] = it }
    }

    override suspend fun cancelPlan(planId: String): Plan {
        call("cancelPlan")
        return plans.getValue(planId).copy(canceledAt = now, canceledBy = me).also { plans[planId] = it }
    }

    override suspend fun restorePlan(planId: String): Plan {
        call("restorePlan")
        return plans.getValue(planId).copy(canceledAt = null, canceledBy = null).also { plans[planId] = it }
    }

    override suspend fun answer(planId: String, answer: PlanAnswerKind): PlanAnswer {
        call("answer")
        val list = answers.getOrPut(planId) { mutableListOf() }
        list.removeAll { it.userId == me }
        return PlanAnswer(planId, me!!, plans.getValue(planId).groupId, answer, now).also { list += it }
    }

    override suspend fun clearAnswer(planId: String) {
        call("clearAnswer")
        answers[planId]?.removeAll { it.userId == me }
    }

    override fun planChanges(groupId: String): Flow<Unit> = changes

    override suspend fun currentQuestion(groupId: String): CurrentQuestion? = question.also { call("currentQuestion") }
    override suspend fun questionAnswers(questionId: String): List<Post> = questionAnswers.toList().also { call("questionAnswers") }
    override suspend fun hideQuestion(questionId: String) = call("hideQuestion")
    override suspend fun setWeeklyQuestion(groupId: String, on: Boolean): Group {
        call("setWeeklyQuestion")
        return groups.getValue(groupId).copy(weeklyQuestion = on).also { groups[groupId] = it }
    }
    override suspend fun groupDeveloping(groupId: String): Developing = developing.also { call("groupDeveloping") }
    override fun planSeenChanged() {
        seenChanged++
    }

    fun post(id: String, groupId: String, at: Instant, questionId: String? = null): Post {
        media["m$id"] = Media("m$id", "u-sam", MediaKind.Photo, "u/u-sam/m$id/original.jpg", null, null, null, null, null, null, null, null, null, null, null, null, null, at)
        return Post(id, "m$id", groupId, "u-sam", null, null, null, null, false, null, at, questionId = questionId)
    }
}
