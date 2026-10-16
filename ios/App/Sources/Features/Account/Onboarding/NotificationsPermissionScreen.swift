// Surface: onboarding.permission.notifications — in-context notifications ask. Visual reference: Retro's onboarding page
// NOTIFICATION_PERMISSION_RETRY ("Never miss a moment"; references/auto/retro/apk/retro-android-2026.10.1150-strings.txt
// `onboarding_notification_permission_retry_*`) and the landing's capsule (references/auto/retro/lazyweb/
// retro-lazyweb-20251119-social.png), under the HIG pre-alert rule — composition of C-33 (onboarding page title), C-05
// (design/surfaces/onboarding.permission.notifications.md).
import AppModels
import DesignSystem
import SwiftUI

/// iOS pre-alert (`onboarding.permission.notifications.layout.preAlert`): the display title and explanation at the top,
/// one capsule at the bottom; no skip, close or back (HIG). Whatever the answer, the person goes on to
/// onboarding.widget. A grant registers with APNs; the token reaches `register_device` through the session glue.
struct NotificationsPermissionScreen: View {
    let notifications: NotificationAuthorizing
    let onAnswered: () -> Void

    @State private var isAsking = false

    var body: some View {
        SignUpLayout(
            title: Copy.onboardingPermissionNotificationsTitle,
            explanation: Copy.onboardingPermissionNotificationsDetail
        ) {
            // No illustration: Retro's onboarding art is do-not-copy and none is sourced.
            EmptyView()
        } bottom: {
            PrimaryButton(Copy.onboardingPermissionNotificationsContinue, isBusy: isAsking) {
                ask()
            }
            .accessibilityIdentifier("onboarding.notifications.continue")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboarding.permission.notifications")
    }

    private func ask() {
        isAsking = true
        Task {
            _ = await notifications.requestAuthorization()
            isAsking = false
            onAnswered()
        }
    }
}
