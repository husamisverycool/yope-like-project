package app.feature.account.plans

import androidx.navigation.NavGraphBuilder
import androidx.navigation.NavHostController
import androidx.navigation.compose.composable
import androidx.navigation.toRoute
import app.model.PlanCreateRoute
import app.model.PlanRoute

/**
 * Destinations of the plan surfaces (design/surfaces/plans.page.md, plans.create.md), registered by the app shell next
 * to the account group's: the plan page (pushed from the group screen's plan row, a plan push or the countdown widget)
 * and the create / edit sheet (a full-screen page sheet, as `groups.create`).
 */
fun NavGraphBuilder.planDestinations(navController: NavHostController) {
    composable<PlanRoute> { entry -> PlanPageRoute(navController, entry.toRoute<PlanRoute>().planId) }
    composable<PlanCreateRoute> { entry ->
        val route = entry.toRoute<PlanCreateRoute>()
        PlanCreateSheetRoute(navController, route.groupId, route.editPlanId)
    }
}
