package app.feature.capture

import androidx.navigation.NavGraphBuilder
import androidx.navigation.NavHostController
import app.ui.nav.emptyDestination
import app.model.AppRoute

/**
 * Destinations of the capture feature group (surface specs in design/surfaces/). Replace each
 * [emptyDestination] with `composable<AppRoute.X> { … }` as its screen is built.
 */
fun NavGraphBuilder.captureDestinations(navController: NavHostController) {
    emptyDestination<AppRoute.Camera>()
    emptyDestination<AppRoute.SendTo>()
    emptyDestination<AppRoute.DailyCapture>()
    emptyDestination<AppRoute.Collage>()
}
