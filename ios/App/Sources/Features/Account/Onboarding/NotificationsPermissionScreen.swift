// Surface: onboarding.permission.notifications — in-context notifications ask. Reference app: Yope (pre-prompt structure)
// under the HIG pre-alert rule (design/surfaces/onboarding.permission.notifications.md). Reference images:
// references/auto/yope/frames/a-virgi-7686278541255642390-t7.23-notif-preprompt-es.png (NP), …-t9.23-notif-system-alert-es.png
// (NA), …-t11.23-widget-preprompt-es.png (WP), a-chuongxetank-7694968408424582452-t7.73-posted-toast-contacts-card.png (CC).
import AppModels
import DesignSystem
import SwiftUI

/// iOS pre-alert (`onboarding.permission.notifications.layout.preAlert`): one button, no skip, close or back. Whatever
/// the answer, the person goes on to onboarding.widget. A grant registers with APNs; the token reaches
/// `register_device` through the session glue.
struct NotificationsPermissionScreen: View {
    let notifications: NotificationAuthorizing
    let onAnswered: () -> Void

    @State private var isAsking = false

    var body: some View {
        VStack(spacing: 0) {
            OnboardingTitleBlock(
                title: Copy.onboardingPermissionNotificationsTitle,
                subtitle: Copy.onboardingPermissionNotificationsDetail
            )
            .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
            .padding(.top, Tokens.Sizes.groupsCreateSizeSheetTopToTitle)
            // Yope's illustration area: its art is do-not-copy and none is sourced (empty).
            Spacer(minLength: 0)
            PrimaryButton(Copy.onboardingPermissionNotificationsContinue, height: .sheet, isEnabled: !isAsking) {
                ask()
            }
            .accessibilityIdentifier("onboarding.notifications.continue")
            .padding(.horizontal, Tokens.Sizes.globalButtonMarginHSheet)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Tokens.Colors.globalBackgroundDeep.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
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
