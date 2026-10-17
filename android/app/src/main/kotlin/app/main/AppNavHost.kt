package app.main

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.navigation.NavController
import androidx.navigation.NavDestination.Companion.hasRoute
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.toRoute
import app.data.repo.AuthState
import app.feature.account.AccountEnvironment
import app.feature.account.AccountEnvironments
import app.feature.account.LocalAccountEnvironment
import app.feature.account.accountDestinations
import app.feature.account.plans.planDestinations
import app.feature.account.shell.RootGate
import app.feature.account.shell.ShellTabBar
import app.feature.capture.captureDestinations
import app.feature.capture.share.ShareIn
import app.feature.capture.share.ShareInbox
import app.feature.capture.share.ShareTargets
import app.feature.memory.memoryDestinations
import app.feature.social.socialDestinations
import app.model.AppRoute
import app.ui.components.ToastHost
import app.ui.foundation.PageRoles
import app.model.DeepLink
import app.model.DeepLinkRouting
import app.model.SessionPromptGate
import app.data.DataGraph
import kotlinx.coroutines.flow.Flow

/**
 * The app shell: the navigation graph (destinations registered per feature module,
 * `android/feature/<group>/<Group>Navigation.kt`), the root flow (signed out → sign-up → onboarding →
 * home, `RootGate`), the tab bar under the tab destinations (C-04), the confirmation toasts (C-26, platform
 * toasts), and deep links (invite App Links,
 * widget and notification taps) turned into full back stacks (`DeepLinkRouting`).
 */
@Composable
fun AppNavHost(
    deepLinks: Flow<DeepLink>,
    navController: NavHostController = rememberNavController(),
    env: AccountEnvironment = AccountEnvironments.get(LocalContext.current),
) {
    CompositionLocalProvider(LocalAccountEnvironment provides env) {
        Box(Modifier.fillMaxSize().background(PageRoles.page)) {
            NavHost(navController = navController, startDestination = DeepLinkRouting.home) {
                // One registration file per feature group, so each group's screens are built independently
                // (docs/SURFACES.md groups: account, capture, social, memory).
                accountDestinations(navController)
                captureDestinations(navController)
                socialDestinations(navController)
                memoryDestinations(navController)
                // plans.page / plans.create (the account group's plan surfaces).
                planDestinations(navController)
            }
            ShellTabBar(navController, env, Modifier.align(Alignment.BottomCenter))
            val ready = RootGate(navController, env)
            // share.in: photos shared from another app open the camera (which takes them as a library selection) once the
            // person is home — signed in and onboarded; signed out, sign-in and onboarding come first.
            val shared by ShareInbox.pending.collectAsState()
            val entry by navController.currentBackStackEntryAsState()
            val signedIn = env.backend.authState.collectAsState().value is AuthState.SignedIn
            LaunchedEffect(ready, signedIn, shared != null, entry?.destination) {
                if (ready && signedIn && shared != null && ShareIn.opensCameraFrom(entry?.destination)) {
                    navController.navigate(AppRoute.Camera()) { launchSingleTop = true }
                }
            }
            // share.in: a group opened (groups.screen) becomes one of the share sheet's per-group targets.
            val openedGroupId = entry?.takeIf { it.destination.hasRoute<AppRoute.Group>() }?.toRoute<AppRoute.Group>()?.groupId
            val appContext = LocalContext.current
            LaunchedEffect(openedGroupId) {
                if (signedIn && openedGroupId != null) ShareTargets.recordOpen(appContext, openedGroupId)
            }
            // Until the session is known nothing shows, so no screen flashes before sign-up / home.
            if (!ready) Box(Modifier.fillMaxSize().background(PageRoles.page))
            // Confirmations raised by the account flows, shown as platform toasts (C-26); they outlive the
            // navigation that follows them.
            ToastHost(env.toasts)
        }
        val context = LocalContext.current
        LaunchedEffect(navController, deepLinks) {
            deepLinks.collect { link ->
                if (link is DeepLink.Premium) {
                    // widget.styles → Locked: the paywall at the perk when the session's one prompt is still available
                    // (`paywall.layout.promptRule`), over the widget's own place; otherwise that place alone.
                    val prompt = !isPremium(context) && SessionPromptGate.process.tryClaim()
                    when {
                        prompt -> navController.show(DeepLinkRouting.withPaywall(link))
                        link.then != null -> navController.show(DeepLinkRouting.backStack(link))
                    }
                } else {
                    navController.show(DeepLinkRouting.backStack(link))
                }
            }
        }
    }
}

/** Whether the signed-in person has premium now; false when signed out or unreadable (the paywall then offers it). */
private suspend fun isPremium(context: android.content.Context): Boolean {
    val graph = DataGraph.get(context) ?: return false
    if (graph.auth.currentUserId == null) return false
    return try {
        graph.entitlements.isPremium()
    } catch (e: kotlinx.coroutines.CancellationException) {
        throw e
    } catch (_: Exception) {
        false
    }
}

/** Replaces the back stack above home with [stack] (a deep link's full path). */
fun NavController.show(stack: List<AppRoute>) {
    popBackStack(graph.startDestinationId, inclusive = false)
    stack.dropWhile { it == DeepLinkRouting.home }.forEach { navigate(it) { launchSingleTop = true } }
}
