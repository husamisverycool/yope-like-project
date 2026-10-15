package app.feature.account.shell

import android.Manifest
import app.feature.account.AccountEnvironment
import app.model.AppRoute
import app.ui.permissions.PermissionChecks

/**
 * The sign-up → onboarding → home order (design/surfaces auth.* and onboarding.*; docs/API.md §9.1):
 * auth.phone → auth.code → auth.agegate (age not confirmed) → auth.profile (no name) →
 * onboarding.permission.notifications (Android 13+ and not granted) → onboarding.widget → the
 * pending invite's join (invite.web install path) or groups.list.
 *
 * onboarding.permission.camera / .photos / .contacts have no screen of their own (their specs): the
 * camera is asked in camera.capture, photos need no permission, contacts are offered in
 * groups.invite.
 */
object AccountFlow {
    /** Routes that belong to sign-up / onboarding (the premium prompt is blocked while one shows). */
    fun isOnboarding(route: AppRoute?): Boolean = when (route) {
        AppRoute.AuthPhone, AppRoute.AuthCode, AppRoute.AuthAgeGate, AppRoute.AuthProfile,
        AppRoute.PermissionNotifications, AppRoute.OnboardingWidget,
        AppRoute.PermissionCamera, AppRoute.PermissionContacts, AppRoute.PermissionPhotos,
        -> true
        else -> false
    }

    /**
     * After a successful code (auth.code) or at launch with a session: the first incomplete step.
     * [justVerified] = auth.code success: a returning account (age confirmed, name set) skips the
     * device-local onboarding steps (auth.code States "success (returning)").
     */
    suspend fun nextAfterSignIn(env: AccountEnvironment, userId: String, justVerified: Boolean): AppRoute {
        val status = env.backend.accountStatus()
        return when {
            !status.ageConfirmed -> AppRoute.AuthAgeGate
            !status.hasName -> AppRoute.AuthProfile
            env.stores.isOnboardingDone(userId) -> home(env)
            justVerified -> {
                env.stores.setOnboardingDone(userId)
                home(env)
            }
            else -> firstOnboardingStep(env)
        }
    }

    /** After auth.profile: the notifications pre-alert when Android needs a runtime request, else the widget step. */
    fun firstOnboardingStep(env: AccountEnvironment): AppRoute =
        if (notificationsPromptNeeded(env)) AppRoute.PermissionNotifications else AppRoute.OnboardingWidget

    fun notificationsPromptNeeded(env: AccountEnvironment): Boolean =
        PermissionChecks.notificationsNeedRuntimeRequest(env.sdkInt) && !env.isGranted(Manifest.permission.POST_NOTIFICATIONS)

    /** End of onboarding (onboarding.widget "Continue"). */
    fun finishOnboarding(env: AccountEnvironment): AppRoute {
        env.backend.currentUserId?.let(env.stores::setOnboardingDone)
        return home(env)
    }

    /** Home, or the pending invite's join first (invite.web install path). */
    fun home(env: AccountEnvironment): AppRoute = env.stores.pendingInviteToken?.let(AppRoute::InviteJoin) ?: AppRoute.GroupsList
}
