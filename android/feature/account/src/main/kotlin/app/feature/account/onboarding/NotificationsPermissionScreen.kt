// Surface: onboarding.permission.notifications — in-context notifications ask (pre-alert).
// Spec: design/surfaces/onboarding.permission.notifications.md.
// References: references/auto/yope/frames/a-virgi-7686278541255642390-t7.23-notif-preprompt-es.png (NP),
// -t9.23-notif-system-alert-es.png (NA), -t11.23-widget-preprompt-es.png (WP), -t31.23-signup-es.png (S26).
package app.feature.account.onboarding

import android.Manifest
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.navigation.NavController
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.account.LocalAccountEnvironment
import app.feature.account.common.navigateAccount
import app.feature.account.common.AccountEvent
import app.model.AppRoute
import app.ui.components.OnboardingTitle
import app.ui.components.PrimaryButton
import app.ui.components.PrimaryButtonSize
import app.ui.permissions.PermissionChecks
import app.ui.text.TextRoles

/**
 * Android 13+: "continue" asks POST_NOTIFICATIONS (system dialog), then goes on to
 * onboarding.widget whatever the answer; "maybe later" goes on without asking. Android ≤ 12 never
 * shows this screen (AccountFlow). A grant needs no extra call here: the session glue
 * (core:data `SessionGlue`) registers the FCM token with `register_device` at sign-in and on every
 * new token.
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

/** `onboarding.permission.notifications.layout.preAlert` (android). */
@Composable
fun NotificationsPermissionScreen(showSkip: Boolean, onContinue: () -> Unit, onSkip: () -> Unit) {
    Column(
        Modifier.fillMaxSize().background(Tokens.Colors.globalBackgroundDeep).windowInsetsPadding(WindowInsets.safeDrawing),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Column(Modifier.fillMaxWidth().padding(horizontal = Tokens.Sizes.globalButtonMarginH)) {
            Spacer(Modifier.height(Tokens.Sizes.groupsCreateSizeSheetTopToTitle))
            OnboardingTitle(stringResource(R.string.onboarding_permission_notifications_title))
            Text(stringResource(R.string.onboarding_permission_notifications_detail), style = TextRoles.onboardingSubtitle, modifier = Modifier.fillMaxWidth())
        }
        // Flexible space: Yope's illustration area (its art is do-not-copy; none sourced).
        Spacer(Modifier.weight(1f))
        Column(Modifier.fillMaxWidth().padding(horizontal = Tokens.Sizes.globalButtonMarginHSheet)) {
            if (showSkip) {
                SecondaryDarkButton(stringResource(R.string.onboarding_permission_notifications_skip), onSkip)
                Spacer(Modifier.height(Tokens.Sizes.onboardingPermissionNotificationsSizeButtonGap))
            }
            PrimaryButton(stringResource(R.string.onboarding_permission_notifications_continue), onContinue, size = PrimaryButtonSize.Sheet)
        }
    }
}

/**
 * The dark secondary button ("maybe later"): `onboarding.permission.notifications.color.secondaryButton`,
 * `size.global.buttonHeightSheet`, `radius.global.button`, label `color.global.textPrimary` text role `button`.
 */
@Composable
private fun SecondaryDarkButton(text: String, onClick: () -> Unit) {
    val shape = RoundedCornerShape(Tokens.Radii.globalButton)
    Box(
        Modifier
            .fillMaxWidth()
            .heightIn(min = Tokens.Sizes.globalButtonHeightSheet)
            .clip(shape)
            .background(Tokens.Colors.onboardingPermissionNotificationsColorSecondaryButton, shape)
            .clickable(role = Role.Button, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Text(text, style = TextRoles.button, color = Tokens.Colors.globalTextPrimary)
    }
}
