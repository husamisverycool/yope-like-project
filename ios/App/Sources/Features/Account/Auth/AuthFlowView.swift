// Account group — the sign-up / onboarding navigation stack (auth.phone → auth.code → auth.agegate → auth.profile →
// onboarding.permission.notifications → onboarding.widget). Native pushes (`easing.global.native.navigationPush`;
// Yope's measured 100 ms push cannot be applied to a native push, F-11). Steps after the code have no back.
import DesignSystem
import SwiftUI

struct AuthFlowView: View {
    @Bindable var session: AccountSession
    @Environment(AccountDependencies.self) private var dependencies

    var body: some View {
        NavigationStack(path: $session.path) {
            root
                .navigationDestination(for: AccountSession.Step.self) { step in
                    destination(step)
                }
        }
    }

    @ViewBuilder
    private var root: some View {
        switch session.root {
        case .phone:
            PhoneScreen(model: PhoneModel(data: dependencies.data))
        case .ageGate:
            AgeGateScreen(model: AgeGateModel(data: dependencies.data))
        case .profile:
            ProfileScreen(model: ProfileModel(data: dependencies.data))
        case .resolving:
            SignUpStateView(title: nil, detail: nil)
                .loadingHUD(true)
        case .resolveFailed:
            SignUpStateView(
                title: Copy.authPhoneOfflineTitle,
                detail: Copy.authPhoneOfflineDetail,
                retry: EmptyStateView.Action(Copy.authPhoneOfflineRetry) { session.retryResolve() }
            )
        }
    }

    @ViewBuilder
    private func destination(_ step: AccountSession.Step) -> some View {
        switch step {
        case let .code(phone, sentAt):
            CodeScreen(
                model: CodeModel(phone: phone, data: dependencies.data, codeSentAt: sentAt),
                network: dependencies.network,
                toasts: dependencies.toasts,
                onVerified: { userID in await session.didVerify(userID) },
                onBack: { if !session.path.isEmpty { session.path.removeLast() } }
            )
        case .ageGate:
            AgeGateScreen(model: AgeGateModel(data: dependencies.data))
        case .profile:
            ProfileScreen(model: ProfileModel(data: dependencies.data))
        case .notifications:
            NotificationsPermissionScreen(notifications: dependencies.notifications) {
                session.notificationsAnswered()
            }
        case .widget:
            WidgetGuideScreen {
                session.finishOnboarding()
            }
        }
    }
}
