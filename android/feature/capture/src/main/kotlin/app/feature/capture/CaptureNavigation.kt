package app.feature.capture

import android.content.Context
import androidx.compose.animation.EnterTransition
import androidx.compose.animation.ExitTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.navigation.NavDestination.Companion.hasRoute
import androidx.navigation.NavGraphBuilder
import androidx.navigation.NavHostController
import androidx.navigation.compose.composable
import androidx.navigation.toRoute
import app.feature.capture.camera.CameraRoute
import app.feature.capture.collage.CollageRoute
import app.feature.capture.daily.DailyCaptureRoute
import app.designsystem.ReduceMotion
import app.designsystem.generated.Tokens
import app.feature.capture.sendto.SendToRoute
import app.model.AppRoute
import app.model.DeepLinkRouting
import app.model.SocialHandoff

/**
 * Destinations of the capture feature group (surface specs in design/surfaces/):
 * `camera.capture` (+ `camera.fromwidget`, the widget's `app://camera?group=` link), `camera.sendto`,
 * `daily.capture` (+ `daily.dualimage`), `collage.view` (+ `collage.share`).
 */
fun NavGraphBuilder.captureDestinations(navController: NavHostController) {
    composable<AppRoute.Camera>(
        // The send-to sheet rises over the camera, which stays in place under it.
        exitTransition = { if (targetState.destination.hasRoute<AppRoute.SendTo>()) ExitTransition.KeepUntilTransitionsFinished else null },
        popEnterTransition = { if (initialState.destination.hasRoute<AppRoute.SendTo>()) EnterTransition.None else null },
    ) { entry ->
        val route = entry.toRoute<AppRoute.Camera>()
        CameraRoute(
            groupId = route.groupId,
            replyToPostId = entry.savedStateHandle.get<String>(SocialHandoff.REPLY_TO_POST_ID),
            onOpenSendTo = { navController.navigate(AppRoute.SendTo) { launchSingleTop = true } },
            // The view model already claimed the session's single prompt (SessionPromptGate).
            onOpenPaywall = { navController.navigate(AppRoute.Paywall) },
        )
    }
    composable<AppRoute.SendTo>(
        enterTransition = { SheetMotion.enter(navController.context) },
        popExitTransition = { SheetMotion.exit(navController.context) },
    ) {
        SendToRoute(
            onClose = { navController.popBackStack() },
            // Sent: the modal closes (camera.sendto → Out: back to the screen the camera was opened from); the
            // toast is a platform toast, so it outlives the navigation.
            onSent = {
                val popped = navController.popBackStack<AppRoute.Camera>(inclusive = true)
                if (!popped || navController.currentBackStackEntry == null) navController.navigate(DeepLinkRouting.home)
            },
            onCreateGroup = { navController.navigate(AppRoute.GroupCreate) },
            onOpenPaywall = { navController.navigate(AppRoute.Paywall) },
        )
    }
    composable<AppRoute.DailyCapture> { entry ->
        val route = entry.toRoute<AppRoute.DailyCapture>()
        DailyCaptureRoute(groupId = route.groupId, invitationId = route.invitationId, onDismiss = { navController.popBackStack() })
    }
    composable<AppRoute.Collage> { entry ->
        val route = entry.toRoute<AppRoute.Collage>()
        CollageRoute(
            groupId = route.groupId,
            invitationId = route.invitationId,
            onBack = { navController.popBackStack() },
            onOpenCamera = { navController.navigate(AppRoute.Camera(route.groupId)) },
        )
    }
}

/**
 * capture → `camera.sendto` (camera.capture.md → Motion): a full-screen modal rising from the bottom with
 * `spring.global.sheetPresent` (Retro's measured sheet presentation) and leaving the same way; Reduce Motion
 * cross-fades over `duration.global.sheetPresent`.
 */
internal object SheetMotion {
    fun enter(context: Context): EnterTransition =
        if (ReduceMotion.isEnabled(context)) {
            fadeIn(tween(Tokens.Durations.globalSheetPresent))
        } else {
            slideInVertically(Tokens.Springs.globalSheetPresent.spec()) { height -> height }
        }

    fun exit(context: Context): ExitTransition =
        if (ReduceMotion.isEnabled(context)) {
            fadeOut(tween(Tokens.Durations.globalSheetPresent))
        } else {
            slideOutVertically(Tokens.Springs.globalSheetPresent.spec()) { height -> height }
        }
}
