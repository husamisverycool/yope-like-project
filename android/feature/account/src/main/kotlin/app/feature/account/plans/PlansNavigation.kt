package app.feature.account.plans

import androidx.navigation.NavGraphBuilder
import androidx.navigation.NavHostController
import androidx.navigation.compose.composable
import androidx.navigation.toRoute
import app.model.PlanCreateRoute
import app.model.PlanRoute
import app.model.PlansListRoute

/**
 * Destinations of the plan surfaces (design/surfaces/plans.page.md, plans.create.md, plans.list.md), registered by the app
 * shell next to the account group's: the plan page (pushed from the group screen's plan row, the plans list, a plan push
 * or the countdown widget), the group's plans list, and the create / edit sheet (a full-screen page sheet, as
 * `groups.create`).
 */
fun NavGraphBuilder.planDestinations(navController: NavHostController) {
    composable<PlanRoute> { entry -> PlanPageRoute(navController, entry.toRoute<PlanRoute>().planId) }
    composable<PlansListRoute> { entry -> PlansListRoute(navController, entry.toRoute<PlansListRoute>().groupId) }
    composable<PlanCreateRoute> { entry ->
        val route = entry.toRoute<PlanCreateRoute>()
        PlanCreateSheetRoute(navController, route.groupId, route.editPlanId)
    }
}
