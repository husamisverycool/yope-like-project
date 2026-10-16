package app.model

import kotlinx.serialization.Serializable

/*
 * Routes added by the plans and weekly-question pass (same package and module, so they join the sealed [AppRoute]).
 * Surface ids from docs/SURFACES.md.
 */

/**
 * `plans.page` — one plan (design/surfaces/plans.page.md): pushed from the `groups.screen` plan row, a plan push
 * (`DeepLink.Plan`) or the countdown widget. [groupId] is known when the opener has it (the page reads the plan's own).
 */
@Serializable
data class PlanRoute(val planId: String, val groupId: String? = null) : AppRoute {
    override val surface get() = "plans.page"
}

/**
 * `plans.create` — make a plan in [groupId] (design/surfaces/plans.create.md); with [editPlanId] the same sheet in edit
 * mode ("Edit Plan" from the plan page's menu).
 */
@Serializable
data class PlanCreateRoute(val groupId: String, val editPlanId: String? = null) : AppRoute {
    override val surface get() = "plans.create"
}

/**
 * Hand-off keys set on the [AppRoute.Camera] entry's `SavedStateHandle` when `question.weekly`'s card opens the camera
 * (iOS `DeepLink.camera(groupID:, questionID:)`): the camera shows the question pill and the post to that group is linked
 * to the question after posting (`answer_question`). The camera route itself is unchanged.
 */
object QuestionHandoff {
    /** `group_questions.id` of this group week's question. */
    const val QUESTION_ID = "questionId"

    /** Its copy key (`question.weekly.q01` …), resolved to the localised text by the camera. */
    const val QUESTION_KEY = "questionKey"
}
