package app.feature.memory

import androidx.navigation.NavGraphBuilder
import androidx.navigation.NavHostController
import app.ui.nav.emptyDestination
import app.model.AppRoute

/**
 * Destinations of the memory feature group (surface specs in design/surfaces/). Replace each
 * [emptyDestination] with `composable<AppRoute.X> { … }` as its screen is built.
 */
fun NavGraphBuilder.memoryDestinations(navController: NavHostController) {
    emptyDestination<AppRoute.OnThisDay>()
    emptyDestination<AppRoute.BirthdayAdd>()
    emptyDestination<AppRoute.BirthdayContribute>()
    emptyDestination<AppRoute.Tribute>()
    emptyDestination<AppRoute.YearStory>()
}
