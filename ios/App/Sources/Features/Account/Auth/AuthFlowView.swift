// Account group — the sign-up / onboarding navigation stack (auth.phone → auth.code → auth.agegate → auth.profile →
// onboarding.permission.notifications → onboarding.widget). Pushes are native (`easing.global.native.navigationPush`,
// Retro's push not captured, R-14); the landing ↔ phone form and the profile steps change with the onboarding page
// transition inside their screens. Steps after the code have no back.
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
        // A session that ended starts a new sign-up: fresh screen state (no previous number, landing first).
        .id(session.signUpGeneration)
    }

    @ViewBuilder
    private var root: some View {
        switch session.root {
        case .phone:
            PhoneScreen(model: PhoneModel(data: dependencies.data))
        case .ageGate:
            AgeGateScreen(model: AgeGateModel(data: dependencies.data))
        case .profile:
            ProfileScreen(model: ProfileModel(data: dependencies.data, prepareImage: UploadImage.jpeg(from:)))
        case .notifications:
            NotificationsPermissionScreen(notifications: dependencies.notifications) {
                session.notificationsAnswered()
            }
        case .widget:
            WidgetGuideRoute(onBack: nil) {
                session.finishOnboarding()
            }
        case .resolving:
            SignUpStateView(title: nil, detail: nil)
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
            ProfileScreen(model: ProfileModel(data: dependencies.data, prepareImage: UploadImage.jpeg(from:)))
        case .notifications:
            NotificationsPermissionScreen(notifications: dependencies.notifications) {
                session.notificationsAnswered()
            }
        case .widget:
            WidgetGuideRoute(onBack: nil) {
                session.finishOnboarding()
            }
        }
    }
}

/// onboarding.widget with its preview: the newest photo from the person's groups (cached data; the empty tile until it
/// is read or when there is none).
struct WidgetGuideRoute: View {
    var onBack: (() -> Void)?
    var onContinue: (() -> Void)?
    @Environment(AccountDependencies.self) private var dependencies
    @State private var preview: WidgetPreviewContent?

    var body: some View {
        WidgetGuideScreen(preview: preview, onBack: onBack, onContinue: onContinue)
            .task {
                guard let newest = await NewestGroupPhoto.load(from: dependencies.data) else { return }
                preview = WidgetPreviewContent(photo: .storage(newest.path), firstName: newest.firstName)
            }
    }
}
