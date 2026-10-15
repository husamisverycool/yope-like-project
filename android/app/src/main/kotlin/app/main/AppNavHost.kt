package app.main

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.navigation.NavController
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.rememberNavController
import app.designsystem.generated.Tokens
import app.feature.account.AccountEnvironment
import app.feature.account.AccountEnvironments
import app.feature.account.LocalAccountEnvironment
import app.feature.account.accountDestinations
import app.feature.account.shell.RootGate
import app.feature.account.shell.ShellTabBar
import app.feature.capture.captureDestinations
import app.feature.memory.memoryDestinations
import app.feature.social.socialDestinations
import app.model.AppRoute
import app.ui.components.ToastHost
import app.model.DeepLink
import app.model.DeepLinkRouting
import kotlinx.coroutines.flow.Flow

/**
 * The app shell: the navigation graph (destinations registered per feature module,
 * `android/feature/<group>/<Group>Navigation.kt`), the root flow (signed out → sign-up → onboarding →
 * home, `RootGate`), the floating tab bar over the tab destinations, the toast host, and deep links (invite App Links,
 * widget and notification taps) turned into full back stacks (`DeepLinkRouting`).
 */
@Composable
fun AppNavHost(
    deepLinks: Flow<DeepLink>,
    navController: NavHostController = rememberNavController(),
    env: AccountEnvironment = AccountEnvironments.get(LocalContext.current),
) {
    CompositionLocalProvider(LocalAccountEnvironment provides env) {
        Box(Modifier.fillMaxSize().background(Tokens.Colors.globalBackgroundDeep)) {
            NavHost(navController = navController, startDestination = DeepLinkRouting.home) {
                // One registration file per feature group, so each group's screens are built independently
                // (docs/SURFACES.md groups: account, capture, social, memory).
                accountDestinations(navController)
                captureDestinations(navController)
                socialDestinations(navController)
                memoryDestinations(navController)
            }
            ShellTabBar(navController, env, Modifier.align(Alignment.BottomCenter))
            val ready = RootGate(navController, env)
            // Until the session is known nothing shows, so no screen flashes before sign-up / home.
            if (!ready) Box(Modifier.fillMaxSize().background(Tokens.Colors.globalBackgroundDeep))
            // Yope's lime toast over every screen (it outlives the navigation that follows it).
            ToastHost(env.toasts, Modifier.align(Alignment.TopCenter))
        }
        LaunchedEffect(navController, deepLinks) {
            deepLinks.collect { link -> navController.show(DeepLinkRouting.backStack(link)) }
        }
    }
}

/** Replaces the back stack above home with [stack] (a deep link's full path). */
fun NavController.show(stack: List<AppRoute>) {
    popBackStack(graph.startDestinationId, inclusive = false)
    stack.dropWhile { it == DeepLinkRouting.home }.forEach { navigate(it) { launchSingleTop = true } }
}
