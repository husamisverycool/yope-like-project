@file:UseSerializers(InstantSerializer::class, LocalDateSerializer::class)

package app.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.UseSerializers
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

/*
 * Plans and the weekly question (docs/API.md §14.2, §14.4): the tables in table order, as in Tables.kt, and the rows of
 * `next_plans` / `current_group_question`. `group_developing` (§14.3) returns [Developing] (RpcResults.kt).
 */

/** `plan_answers.answer` (text with a check, not a Postgres enum): Partiful's order Going · Maybe · Can't go (MERGE PL-1). */
@Serializable
enum class PlanAnswerKind(val wire: String) {
    @SerialName("going") Going("going"),
    @SerialName("maybe") Maybe("maybe"),
    @SerialName("cant_go") CantGo("cant_go"),
}

/**
 * §14.2 `plans`. [localDate] is the plan's day in the group's time zone; an all-day plan starts at 00:00 of it. A cancelled
 * plan keeps its row ([canceledAt]) and can be restored; there is no delete.
 */
@Serializable
data class Plan(
    val id: String,
    @SerialName("group_id") val groupId: String,
    @SerialName("created_by") val createdBy: String?,
    val title: String,
    @SerialName("starts_at") val startsAt: Instant,
    @SerialName("ends_at") val endsAt: Instant?,
    @SerialName("all_day") val allDay: Boolean,
    @SerialName("local_date") val localDate: LocalDate,
    val place: String?,
    val note: String?,
    @SerialName("cover_path") val coverPath: String?,
    @SerialName("canceled_at") val canceledAt: Instant?,
    @SerialName("canceled_by") val canceledBy: String?,
    @SerialName("created_at") val createdAt: Instant,
    @SerialName("updated_at") val updatedAt: Instant,
) {
    val canceled: Boolean get() = canceledAt != null

    /** "Over" as the server reads it (§14.2): after [endsAt], or after the end of [localDate] in [zone] (the group's). */
    fun isOver(now: Instant, zone: ZoneId): Boolean = !now.isBefore(endsAt ?: localDate.plusDays(1).atStartOfDay(zone).toInstant())
}

/** §14.2 `plan_answers`: no answer = no row. Can't go rows are visible only to their author and the plan's maker (RLS). */
@Serializable
data class PlanAnswer(
    @SerialName("plan_id") val planId: String,
    @SerialName("user_id") val userId: String,
    @SerialName("group_id") val groupId: String,
    val answer: PlanAnswerKind,
    @SerialName("answered_at") val answeredAt: Instant,
)

/** One row of `next_plans(p_group_id)`: an upcoming plan (not cancelled, not over), soonest first, with your own answer. */
@Serializable
data class NextPlan(
    val id: String,
    @SerialName("group_id") val groupId: String,
    @SerialName("created_by") val createdBy: String?,
    val title: String,
    @SerialName("starts_at") val startsAt: Instant,
    @SerialName("ends_at") val endsAt: Instant?,
    @SerialName("all_day") val allDay: Boolean,
    @SerialName("local_date") val localDate: LocalDate,
    val place: String?,
    @SerialName("cover_path") val coverPath: String?,
    @SerialName("my_answer") val myAnswer: PlanAnswerKind?,
)

/** Where a plan sits in the group's plans list (`group_plans`): upcoming, past (over) or cancelled. */
@Serializable
enum class GroupPlanState {
    @SerialName("upcoming") Upcoming,
    @SerialName("past") Past,
    @SerialName("canceled") Canceled,
}

/**
 * One row of `group_plans(p_group_id)` (§14.2): a plan of the group with your own answer and its list section. The server
 * orders the rows: upcoming soonest first, then past latest first, then cancelled latest first.
 */
@Serializable
data class GroupPlan(
    val id: String,
    @SerialName("group_id") val groupId: String,
    @SerialName("created_by") val createdBy: String?,
    val title: String,
    @SerialName("starts_at") val startsAt: Instant,
    @SerialName("ends_at") val endsAt: Instant?,
    @SerialName("all_day") val allDay: Boolean,
    @SerialName("local_date") val localDate: LocalDate,
    val place: String?,
    @SerialName("cover_path") val coverPath: String?,
    @SerialName("canceled_at") val canceledAt: Instant?,
    @SerialName("my_answer") val myAnswer: PlanAnswerKind?,
    val state: GroupPlanState,
)

/** §14.4 `group_questions`: one question per group week; [questionKey] is a copy key (`question.weekly.q01` …). */
@Serializable
data class GroupQuestion(
    val id: String,
    @SerialName("group_id") val groupId: String,
    @SerialName("week_start") val weekStart: LocalDate,
    @SerialName("question_key") val questionKey: String,
    @SerialName("created_at") val createdAt: Instant,
)

/** The row of `current_group_question(p_group_id)` (§14.4); none when the feature is off or no catalogue is configured. */
@Serializable
data class CurrentQuestion(
    val id: String,
    @SerialName("question_key") val questionKey: String,
    @SerialName("week_start") val weekStart: LocalDate,
    @SerialName("hidden_by_me") val hiddenByMe: Boolean,
)
