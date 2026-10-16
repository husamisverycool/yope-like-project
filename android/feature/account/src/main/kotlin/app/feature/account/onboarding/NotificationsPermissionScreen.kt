// Surface: onboarding.permission.notifications — in-context notifications ask (pre-alert page).
// Spec: design/surfaces/onboarding.permission.notifications.md.
// References: references/auto/retro/apk/retro-android-2026.10.1150-strings.txt (APK-S: onboarding_notification_permission_retry_*,
// activity_enable_push_upsell_cta, media_viewer_suggested_tag_maybe_later), references/auto/retro/lazyweb/retro-lazyweb-20251119-social.png
// (LAND: capsule and secondary link geometry). Composition of C-33 (onboarding page title), C-05, C-08 in Retro's onboarding order.
package app.feature.account.onboarding

import android.Manifest
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.navigation.NavController
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.account.LocalAccountEnvironment
import app.feature.account.common.AccountEvent
import app.feature.account.common.OnboardingForm
import app.feature.account.common.navigateAccount
import app.model.AppRoute
import app.ui.components.PrimaryButton
import app.ui.components.TextLink
import app.ui.permissions.PermissionChecks
import app.ui.text.CapTop
import app.ui.text.TextRoles
import app.ui.text.capTopAt

/**
 * Android 13+: "Enable notifications" asks POST_NOTIFICATIONS (system dialog), then goes on to onboarding.widget whatever
 * the answer (no retry loop); "Maybe later" goes on without asking. Android ≤ 12 never shows this page (AccountFlow).
 * A grant needs no extra call here: the session glue (core:data `SessionGlue`) registers the FCM token with
 * `register_device` at sign-in and on every new token.
 */
@Composable
fun NotificationsPermissionRoute(nav: NavController) {
    val env = LocalAccountEnvironment.current
    val next = { nav.navigateAccount(AccountEvent.Navigate(AppRoute.OnboardingWidget, popCurrent = true)) }
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { next() }
    NotificationsPermissionScreen(
        showSkip = PermissionChecks.notificationsNeedRuntimeRequest(env.sdkInt),
        onContinue = {
            if (PermissionChecks.notificationsNeedRuntimeRequest(env.sdkInt)) launcher.launch(Manifest.permission.POST_NOTIFICATIONS) else next()
        },
        onSkip = next,
    )
}

/**
 * `onboarding.permission.notifications.layout.preAlert`: the onboarding page ([OnboardingForm], no header row) — display
 * title at `size.global.titleTop`, the explanation under it, flexible space (Retro's onboarding art is do-not-copy), then
 * C-05 "Enable notifications" `size.global.buttonMarginH` above the bottom safe area and, on Android 13+, the C-08 link
 * "Maybe later" `auth.phone.size.capsuleToLink` (ink) under it (the capsule moves up by the link's height + gap).
 */
@Composable
fun NotificationsPermissionScreen(showSkip: Boolean, onContinue: () -> Unit, onSkip: () -> Unit) {
    OnboardingForm(
        title = stringResource(R.string.onboarding_permission_notifications_title),
        explanation = stringResource(R.string.onboarding_permission_notifications_detail),
        scrollable = false,
        bottom = {
            PrimaryButton(stringResource(R.string.onboarding_permission_notifications_continue), onContinue)
            if (showSkip) {
                TextLink(
                    stringResource(R.string.onboarding_permission_notifications_skip),
                    onSkip,
                    Modifier.capTopAt(Tokens.Sizes.authPhoneSizeCapsuleToLink, CapTop.height(TextRoles.listTitle)),
                )
            }
        },
    )
}
