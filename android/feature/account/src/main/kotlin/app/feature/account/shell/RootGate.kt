package app.feature.account.shell

import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.navigation.NavDestination
import androidx.navigation.NavDestination.Companion.hasRoute
import androidx.navigation.NavHostController
import androidx.navigation.compose.currentBackStackEntryAsState
import app.data.error.DataError
import app.data.repo.AuthState
import app.feature.account.AccountEnvironment
import app.feature.account.common.AccountEvent
import app.feature.account.common.dataError
import app.feature.account.common.navigateAccount
import app.model.AppRoute
import app.model.SessionPromptGate

/**
 * The root flow: signed out → sign-up (auth.phone; or the remembered under-age refusal) →
 * onboarding → home. Watches the session ([AccountEnvironment.backend] `authState`):
 * - signed out (launch without a session, sign-out, account deletion) → auth.phone, stack cleared;
 * - signed in at launch → the first unfinished step (AccountFlow), or home (pending invite → join);
 *   home with at least one group opens the camera over groups.list (camera.capture → In: "app
 *   launch (the app opens to the camera)"; groups.list stays the root, Back and the tab bar lead there).
 *   A deep link that already moved the app off groups.list wins.
 * Sign-up screens drive their own steps; the gate only acts outside them. Returns whether the first
 * decision is made (the shell covers the screen until then, so no wrong screen flashes).
 */
@Composable
fun RootGate(nav: NavHostController, env: AccountEnvironment): Boolean {
    var ready by remember { mutableStateOf(false) }
    val entry by nav.currentBackStackEntryAsState()
    val onboarding = isSignUpDestination(entry?.destination)
    // The premium prompt is never shown during sign-up or onboarding (SessionPromptGate).
    DisposableEffect(onboarding, env.promptGate) {
        if (onboarding) env.promptGate.enter(SessionPromptGate.Blocker.Onboarding)
        onDispose { if (onboarding) env.promptGate.exit(SessionPromptGate.Blocker.Onboarding) }
    }
    LaunchedEffect(env) {
        var resolvedFor: String? = null
        env.backend.authState.collect { state ->
            val destination = nav.currentBackStackEntry?.destination
            when (state) {
                AuthState.Initializing -> Unit
                AuthState.SignedOut -> {
                    resolvedFor = null
                    val refused = env.stores.ageRefusal() != null
                    val target = if (refused) AppRoute.AuthAgeGate else AppRoute.AuthPhone
                    val keep = if (refused) destination?.hasRoute<AppRoute.AuthAgeGate>() == true else isSignUpDestination(destination) || destination?.hasRoute<AppRoute.InviteJoin>() == true
                    if (!keep) nav.navigateAccount(AccountEvent.Navigate(target, clearStack = true))
                    ready = true
                }
                is AuthState.SignedIn -> {
                    if (resolvedFor != state.userId) {
                        resolvedFor = state.userId
                        if (!isSignUpDestination(destination) && destination?.hasRoute<AppRoute.InviteJoin>() != true) {
                            val next = try {
                                AccountFlow.nextAfterSignIn(env, state.userId, justVerified = false)
                            } catch (t: Throwable) {
                                // Offline at launch: home with cached content when this device finished
                                // onboarding, else the first sign-up step that can tell (age gate).
                                if (t.dataError() == DataError.Network && env.stores.isOnboardingDone(state.userId)) AccountFlow.home(env) else AppRoute.AuthAgeGate
                            }
                            if (next != AppRoute.GroupsList) {
                                nav.navigateAccount(AccountEvent.Navigate(next, clearStack = true))
                            } else if (env.launchToCamera && runCatching { AccountFlow.hasGroups(env) }.getOrDefault(false) &&
                                nav.currentBackStackEntry?.destination?.hasRoute<AppRoute.GroupsList>() == true
                            ) {
                                nav.navigate(AppRoute.Camera()) { launchSingleTop = true }
                            }
                        }
                    }
                    ready = true
                }
            }
        }
    }
    return ready
}

private fun isSignUpDestination(destination: NavDestination?): Boolean {
    if (destination == null) return false
    return destination.hasRoute<AppRoute.AuthPhone>() || destination.hasRoute<AppRoute.AuthCode>() ||
        destination.hasRoute<AppRoute.AuthAgeGate>() || destination.hasRoute<AppRoute.AuthProfile>() ||
        destination.hasRoute<AppRoute.PermissionNotifications>() || destination.hasRoute<AppRoute.OnboardingWidget>()
}
