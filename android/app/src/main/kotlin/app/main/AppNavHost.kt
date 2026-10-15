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
import kotlinx.coroutines.flow.Flow

/**
 * The navigation graph. Every destination is registered and empty; the screens pass replaces each
 * [EmptyDestination] with its screen (one file per surface, header naming the surface id).
 */
@Composable
fun AppNavHost(deepLinks: Flow<DeepLink>, navController: NavHostController = rememberNavController()) {
    LaunchedEffect(navController, deepLinks) {
        deepLinks.collect { link -> navController.show(DeepLinkRouting.backStack(link)) }
    }
    NavHost(navController = navController, startDestination = DeepLinkRouting.home) {
        // Getting in
        empty<AppRoute.AuthPhone>()
        empty<AppRoute.AuthCode>()
        empty<AppRoute.AuthAgeGate>()
        empty<AppRoute.AuthProfile>()
        empty<AppRoute.PermissionCamera>()
        empty<AppRoute.PermissionNotifications>()
        empty<AppRoute.PermissionPhotos>()
        empty<AppRoute.PermissionContacts>()
        empty<AppRoute.OnboardingWidget>()
        empty<AppRoute.InviteJoin>()
        // Groups
        empty<AppRoute.GroupsList>()
        empty<AppRoute.GroupCreate>()
        empty<AppRoute.GroupInvite>()
        empty<AppRoute.Group>()
        empty<AppRoute.GroupSettings>()
        // Posting
        empty<AppRoute.Camera>()
        empty<AppRoute.SendTo>()
        // Chat and photos
        empty<AppRoute.Chat>()
        empty<AppRoute.PhotoViewer>()
        // Walls
        empty<AppRoute.WallMine>()
        empty<AppRoute.WallMember>()
        empty<AppRoute.WallsBrowse>()
        // Daily invitation
        empty<AppRoute.DailyCapture>()
        empty<AppRoute.Collage>()
        // The week
        empty<AppRoute.WeekRecap>()
        empty<AppRoute.WeekEdit>()
        empty<AppRoute.WeekHistory>()
        empty<AppRoute.AlbumsList>()
        empty<AppRoute.AlbumView>()
        // Remembering
        empty<AppRoute.OnThisDay>()
        empty<AppRoute.BirthdayAdd>()
        empty<AppRoute.BirthdayContribute>()
        empty<AppRoute.Tribute>()
        empty<AppRoute.YearStory>()
        // Account, notifications, subscription, safety
        empty<AppRoute.Settings>()
        empty<AppRoute.SettingsNotifications>()
        empty<AppRoute.SettingsAccount>()
        empty<AppRoute.SettingsBlocked>()
        empty<AppRoute.Paywall>()
        empty<AppRoute.SafetyReport>()
        empty<AppRoute.SafetyBlock>()
    }
}

private inline fun <reified T : AppRoute> NavGraphBuilder.empty() {
    // The route class is captured here: a reified call inside the composable lambda is not
    // inlined by the Compose compiler and fails at runtime.
    val type = T::class
    composable<T> { entry -> EmptyDestination(entry.toRoute<AppRoute>(type)) }
}

/** Replaces the back stack above home with [stack] (a deep link's full path). */
fun NavController.show(stack: List<AppRoute>) {
    popBackStack(graph.startDestinationId, inclusive = false)
    stack.dropWhile { it == DeepLinkRouting.home }.forEach { navigate(it) { launchSingleTop = true } }
}

/**
 * A destination whose screen is not built yet. It draws nothing — no token exists for it — and is
 * tagged with its surface id for tests.
 */
@Composable
fun EmptyDestination(route: AppRoute) {
    Box(Modifier.fillMaxSize().testTag(route.surface))
}
