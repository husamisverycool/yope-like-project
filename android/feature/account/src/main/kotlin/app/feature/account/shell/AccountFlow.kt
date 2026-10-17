package app.feature.account.shell

import android.Manifest
import app.feature.account.AccountEnvironment
import app.feature.account.groups.GroupsListViewModel
import app.model.AppRoute
import kotlinx.coroutines.flow.first
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
        AppRoute.PermissionNotifications, AppRoute.OnboardingWidget, app.model.OnboardingWidgetFromSettingsRoute,
        AppRoute.PermissionCamera, AppRoute.PermissionContacts, AppRoute.PermissionPhotos,
        -> true
        else -> false
    }

    /**
     * After a successful code (auth.code) or at launch with a session: the first incomplete step.
     * An account with sign-up done (age confirmed, name set) that has not been onboarded on this phone — a returning
     * account's code (auth.code States "success (returning)"), a launch after an invite install — gets this phone's
     * onboarding pages once, as a new account does after auth.profile; none when the phone has shown them
     * ([AccountStores.devicePagesShown]). [justVerified] is kept for the callers' context (auth.code vs launch).
     */
    @Suppress("UNUSED_PARAMETER")
    suspend fun nextAfterSignIn(env: AccountEnvironment, userId: String, justVerified: Boolean): AppRoute {
        val status = env.backend.accountStatus()
        return when {
            !status.ageConfirmed -> AppRoute.AuthAgeGate
            !status.hasName -> AppRoute.AuthProfile
            env.stores.isOnboardingDone(userId) -> home(env)
            env.stores.devicePagesShown -> {
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

    /** End of onboarding (onboarding.widget "Continue"): the phone has now shown its onboarding pages. */
    fun finishOnboarding(env: AccountEnvironment): AppRoute {
        env.backend.currentUserId?.let(env.stores::setOnboardingDone)
        env.stores.devicePagesShown = true
        return home(env)
    }

    /** Whether the person is in a group: the cached list when there is one, else the first answer. */
    suspend fun hasGroups(env: AccountEnvironment): Boolean =
        env.backend.observeMyGroups().first { it.value != null || !it.refreshing }.value?.isNotEmpty() == true

    /**
     * A signed-in session ended: the sign-up session (the number typed, the code's send time), the groups list's row details
     * (kept for the process so the list never reorders) and optimistic leaves belong to the person who left.
     */
    fun sessionEnded(env: AccountEnvironment) {
        env.signUp.clear()
        env.optimistic.leftGroups.value = emptySet()
        GroupsListViewModel.Details.byGroup.clear()
    }

    /** Home, or the pending invite's join first (invite.web install path; the person already chose to join: no second tap). */
    fun home(env: AccountEnvironment): AppRoute = env.stores.pendingInviteToken?.let { AppRoute.InviteJoin(it, join = true) } ?: AppRoute.GroupsList
}
