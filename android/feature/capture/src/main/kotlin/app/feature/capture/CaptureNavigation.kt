package app.feature.capture

import androidx.navigation.NavGraphBuilder
import androidx.navigation.NavHostController
import androidx.navigation.compose.composable
import androidx.navigation.toRoute
import app.feature.capture.camera.CameraRoute
import app.feature.capture.collage.CollageRoute
import app.feature.capture.daily.DailyCaptureRoute
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
    composable<AppRoute.Camera> { entry ->
        val route = entry.toRoute<AppRoute.Camera>()
        CameraRoute(
            groupId = route.groupId,
            replyToPostId = entry.savedStateHandle.get<String>(SocialHandoff.REPLY_TO_POST_ID),
            onOpenSendTo = { navController.navigate(AppRoute.SendTo) { launchSingleTop = true } },
            // The view model already claimed the session's single prompt (SessionPromptGate).
            onOpenPaywall = { navController.navigate(AppRoute.Paywall) },
        )
    }
    composable<AppRoute.SendTo> {
        SendToRoute(
            onClose = { navController.popBackStack() },
            // Sent: the sheet closes at once; Yope returns to the home list with the toast.
            onSent = {
                if (!navController.popBackStack(DeepLinkRouting.home, inclusive = false)) navController.navigate(DeepLinkRouting.home)
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
