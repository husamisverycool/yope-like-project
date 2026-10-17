package app.feature.account

import androidx.compose.ui.window.DialogProperties
import androidx.navigation.NavGraphBuilder
import androidx.navigation.NavHostController
import androidx.navigation.compose.composable
import androidx.navigation.compose.dialog
import androidx.navigation.toRoute
import app.feature.account.auth.AgeGateRoute
import app.feature.account.auth.CodeRoute
import app.feature.account.auth.PhoneRoute
import app.feature.account.auth.ProfileRoute
import app.feature.account.groups.GroupCreateRoute
import app.feature.account.groups.GroupFeedRoute
import app.feature.account.groups.GroupInviteRoute
import app.feature.account.groups.GroupSettingsRoute
import app.feature.account.groups.GroupsListRoute
import app.feature.account.invite.InviteJoinRoute
import app.feature.account.onboarding.NotificationsPermissionRoute
import app.feature.account.onboarding.WidgetRoute
import app.feature.account.paywall.PaywallRoute
import app.feature.account.paywall.Perk
import app.feature.account.safety.BlockRoute
import app.feature.account.safety.ReportRoute
import app.feature.account.safety.reportTarget
import app.feature.account.settings.SettingsAccountRoute
import app.feature.account.settings.SettingsBlockedRoute
import app.feature.account.settings.SettingsNotificationsRoute
import app.feature.account.settings.SettingsRootRoute
import app.model.AppRoute
import app.model.GroupEditRoute
import app.model.GroupCreateKindRoute
import app.model.GroupProfileRoute
import app.model.OnboardingWidgetFromSettingsRoute
import app.model.PaywallPerkRoute
import app.model.SafetyReportMessageRoute
import app.model.SafetyReportContentRoute
import app.model.SafetyReportSelfieRoute
import app.ui.nav.emptyDestination

/**
 * Destinations of the account feature group (surface specs in design/surfaces/). Screens read their
 * dependencies from [LocalAccountEnvironment], which the app shell provides.
 *
 * onboarding.permission.camera / .photos / .contacts have no screen of their own (their specs: the camera is asked in
 * camera.capture and its denied block is that screen's, photos need no permission and the denied save block is
 * photo.viewer's, contacts are offered inside groups.invite), so their routes stay empty destinations.
 */
fun NavGraphBuilder.accountDestinations(navController: NavHostController) {
    composable<AppRoute.AuthPhone> { PhoneRoute(navController) }
    composable<AppRoute.AuthCode> { CodeRoute(navController) }
    composable<AppRoute.AuthAgeGate> { AgeGateRoute(navController) }
    composable<AppRoute.AuthProfile> { ProfileRoute(navController) }
    emptyDestination<AppRoute.PermissionCamera>()
    composable<AppRoute.PermissionNotifications> { NotificationsPermissionRoute(navController) }
    emptyDestination<AppRoute.PermissionPhotos>()
    emptyDestination<AppRoute.PermissionContacts>()
    composable<AppRoute.OnboardingWidget> { WidgetRoute(navController) }
    composable<OnboardingWidgetFromSettingsRoute> { WidgetRoute(navController, fromSettings = true) }
    composable<AppRoute.InviteJoin> { entry ->
        val route = entry.toRoute<AppRoute.InviteJoin>()
        InviteJoinRoute(navController, route.token, route.join)
    }

    composable<AppRoute.GroupsList> { GroupsListRoute(navController) }
    composable<AppRoute.GroupCreate> { GroupCreateRoute(navController) }
    composable<GroupCreateKindRoute> { entry ->
        val wire = entry.toRoute<GroupCreateKindRoute>().kind
        GroupCreateRoute(navController, presetKind = app.data.model.GroupKind.entries.firstOrNull { it.wire == wire })
    }
    composable<GroupEditRoute> { entry -> GroupCreateRoute(navController, entry.toRoute<GroupEditRoute>().groupId) }
    composable<AppRoute.GroupInvite> { entry -> GroupInviteRoute(navController, entry.toRoute<AppRoute.GroupInvite>().groupId) }
    composable<AppRoute.Group> { entry -> GroupFeedRoute(navController, entry.toRoute<AppRoute.Group>().groupId) }
    // The chat header's "group" link (social): the same group screen (the redesign has one, MERGE RA-9).
    composable<GroupProfileRoute> { entry -> GroupFeedRoute(navController, entry.toRoute<GroupProfileRoute>().groupId) }
    composable<AppRoute.GroupSettings> { entry -> GroupSettingsRoute(navController, entry.toRoute<AppRoute.GroupSettings>().groupId) }

    composable<AppRoute.Settings> { SettingsRootRoute(navController) }
    composable<AppRoute.SettingsNotifications> { SettingsNotificationsRoute(navController) }
    composable<AppRoute.SettingsAccount> { SettingsAccountRoute(navController) }
    composable<AppRoute.SettingsBlocked> { SettingsBlockedRoute(navController) }
    composable<AppRoute.Paywall> { PaywallRoute(navController) }
    // A locked widget style's tap (widget.styles): the paywall at that perk's page.
    composable<PaywallPerkRoute> { entry -> PaywallRoute(navController, initialPerk = Perk.fromWire(entry.toRoute<PaywallPerkRoute>().perk)) }

    // Safety flows draw over the calling surface (sheet / dialog), so they are dialog destinations.
    val overlay = DialogProperties(usePlatformDefaultWidth = false, decorFitsSystemWindows = false)
    dialog<AppRoute.SafetyReport>(dialogProperties = overlay) { entry ->
        val target = reportTarget(entry.toRoute<AppRoute.SafetyReport>())
        if (target != null) ReportRoute(navController, target) else navController.popBackStack()
    }
    dialog<SafetyReportMessageRoute>(dialogProperties = overlay) { entry -> ReportRoute(navController, reportTarget(entry.toRoute<SafetyReportMessageRoute>())) }
    dialog<SafetyReportSelfieRoute>(dialogProperties = overlay) { entry -> ReportRoute(navController, reportTarget(entry.toRoute<SafetyReportSelfieRoute>())) }
    dialog<SafetyReportContentRoute>(dialogProperties = overlay) { entry ->
        val target = reportTarget(entry.toRoute<SafetyReportContentRoute>())
        if (target != null) ReportRoute(navController, target) else navController.popBackStack()
    }
    dialog<AppRoute.SafetyBlock>(dialogProperties = overlay) { entry -> BlockRoute(navController, entry.toRoute<AppRoute.SafetyBlock>().userId) }
}
