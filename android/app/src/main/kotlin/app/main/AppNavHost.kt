package app.main

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.navigation.NavController
import androidx.navigation.NavGraphBuilder
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.toRoute
import app.model.AppRoute
import app.model.DeepLink
import app.model.DeepLinkRouting
import app.feature.account.accountDestinations
import app.feature.capture.captureDestinations
import app.feature.memory.memoryDestinations
import app.feature.social.socialDestinations
import kotlinx.coroutines.flow.Flow

/**
 * The navigation graph. Destinations are registered per feature module
 * (`android/feature/<group>`, `<Group>Navigation.kt`); a destination whose screen is not built yet
 * uses `app.ui.nav.emptyDestination`. New routes for a group go in `core/model/.../AppRoute<Group>.kt` (same package,
 * so they join the sealed [AppRoute]).
 */
@Composable
fun AppNavHost(deepLinks: Flow<DeepLink>, navController: NavHostController = rememberNavController()) {
    LaunchedEffect(navController, deepLinks) {
        deepLinks.collect { link -> navController.show(DeepLinkRouting.backStack(link)) }
    }
    NavHost(navController = navController, startDestination = DeepLinkRouting.home) {
        // One registration file per feature group, so each group's screens are built independently
        // (docs/SURFACES.md groups: account, capture, social, memory).
        accountDestinations(navController)
        captureDestinations(navController)
        socialDestinations(navController)
        memoryDestinations(navController)
    }
}

/** Replaces the back stack above home with [stack] (a deep link's full path). */
fun NavController.show(stack: List<AppRoute>) {
    popBackStack(graph.startDestinationId, inclusive = false)
    stack.dropWhile { it == DeepLinkRouting.home }.forEach { navigate(it) { launchSingleTop = true } }
}
