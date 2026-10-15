package app.feature.account

import androidx.navigation.NavGraphBuilder
import androidx.navigation.NavHostController
import app.main.emptyDestination
import app.model.AppRoute

/**
 * Destinations of the account feature group (surface specs in design/surfaces/). Replace each
 * [emptyDestination] with `composable<AppRoute.X> { … }` as its screen is built.
 */
fun NavGraphBuilder.accountDestinations(navController: NavHostController) {
    emptyDestination<AppRoute.AuthPhone>()
    emptyDestination<AppRoute.AuthCode>()
    emptyDestination<AppRoute.AuthAgeGate>()
    emptyDestination<AppRoute.AuthProfile>()
    emptyDestination<AppRoute.PermissionCamera>()
    emptyDestination<AppRoute.PermissionNotifications>()
    emptyDestination<AppRoute.PermissionPhotos>()
    emptyDestination<AppRoute.PermissionContacts>()
    emptyDestination<AppRoute.OnboardingWidget>()
    emptyDestination<AppRoute.InviteJoin>()
    emptyDestination<AppRoute.GroupsList>()
    emptyDestination<AppRoute.GroupCreate>()
    emptyDestination<AppRoute.GroupInvite>()
    emptyDestination<AppRoute.Group>()
    emptyDestination<AppRoute.GroupSettings>()
    emptyDestination<AppRoute.Settings>()
    emptyDestination<AppRoute.SettingsNotifications>()
    emptyDestination<AppRoute.SettingsAccount>()
    emptyDestination<AppRoute.SettingsBlocked>()
    emptyDestination<AppRoute.Paywall>()
    emptyDestination<AppRoute.SafetyReport>()
    emptyDestination<AppRoute.SafetyBlock>()
}
