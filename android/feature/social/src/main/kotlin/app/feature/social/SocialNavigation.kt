package app.feature.social

import androidx.navigation.NavGraphBuilder
import androidx.navigation.NavHostController
import app.ui.nav.emptyDestination
import app.model.AppRoute

/**
 * Destinations of the social feature group (surface specs in design/surfaces/). Replace each
 * [emptyDestination] with `composable<AppRoute.X> { … }` as its screen is built.
 */
fun NavGraphBuilder.socialDestinations(navController: NavHostController) {
    emptyDestination<AppRoute.Chat>()
    emptyDestination<AppRoute.PhotoViewer>()
    emptyDestination<AppRoute.WallMine>()
    emptyDestination<AppRoute.WallMember>()
    emptyDestination<AppRoute.WallsBrowse>()
    emptyDestination<AppRoute.WeekRecap>()
    emptyDestination<AppRoute.WeekEdit>()
    emptyDestination<AppRoute.WeekHistory>()
    emptyDestination<AppRoute.AlbumsList>()
    emptyDestination<AppRoute.AlbumView>()
}
