// Account group — the root flow: signed out → sign-up (auth.phone → auth.code) → onboarding (auth.agegate →
// auth.profile → onboarding.permission.notifications → onboarding.widget) → home (groups.list). Links that arrive
// meanwhile wait in `AppRouter.pendingLink`; `router.setReady(true)` applies them once the person is home.
import AppData
import AppModels
import DesignSystem
import Foundation
import Observation

@MainActor
@Observable
final class AccountSession {
    /// What the window shows.
    enum Phase: Equatable {
        /// A stored session is being checked (profile_private / profiles).
        case launching
        /// The sign-up and onboarding stack (`AuthFlowView`).
        case signUp
        /// auth.agegate "under age": remembered on the device; no way back.
        case refused
        /// Home (groups.list) and everything after it.
        case ready
    }

    /// First screen of the sign-up stack.
    enum Root: Hashable {
        case phone
        case ageGate
        case profile
        /// Checking where a signed-in person continues (Loading HUD).
        case resolving
        /// That check failed (offline / error): retry.
        case resolveFailed
    }

    /// Screens pushed on the sign-up stack (native pushes; steps after the code cannot go back).
    enum Step: Hashable {
        case code(phone: String, sentAt: Date)
        case ageGate
        case profile
        case notifications
        case widget
    }

    private(set) var phase: Phase = .launching
    var root: Root = .phone
    var path: [Step] = []
    /// The minimum age shown in the refusal (nil when not configured / unknown).
    private(set) var refusalMinAge: Int?

    /// The invite applied right after onboarding (pending link or App Clip hand-off): `InviteScreen` joins it
    /// without showing the preview again (onboarding.widget "Out": pending invite → `join_group` → groups.screen).
    @ObservationIgnored private(set) var autoJoinToken: String?
    @ObservationIgnored private var signedInUser: UserID?
    @ObservationIgnored private var authTask: Task<Void, Never>?

    let data: AccountDataSource
    let router: AppRouter
    let refusals: AgeGateRefusalStoring
    let onboarding: OnboardingRecord
    let notifications: NotificationAuthorizing
    let toasts: ToastCenter

    init(
        data: AccountDataSource,
        router: AppRouter,
        refusals: AgeGateRefusalStoring,
        onboarding: OnboardingRecord,
        notifications: NotificationAuthorizing,
        toasts: ToastCenter
    ) {
        self.data = data
        self.router = router
        self.refusals = refusals
        self.onboarding = onboarding
        self.notifications = notifications
        self.toasts = toasts
    }

    // MARK: Launch

    /// Decides the first screen and follows the auth state. `handoff` is an invite the App Clip joined.
    func start(handoff: InviteHandoff? = nil) {
        if let handoff {
            router.handle(.invite(token: handoff.token))
        }
        observeAuthState()
        if let minAge = refusals.refusal {
            refusalMinAge = minAge > 0 ? minAge : nil
            phase = .refused
            return
        }
        guard let user = data.currentUserID else {
            showSignedOut()
            return
        }
        signedInUser = user
        if onboarding.isComplete(for: user.rawValue) {
            becomeReady(user)
        } else {
            phase = .signUp
            Task { await resolve(user) }
        }
    }

    private func observeAuthState() {
        guard authTask == nil else { return }
        let states = data.authStates()
        authTask = Task { [weak self] in
            for await state in states {
                self?.handle(state)
            }
        }
    }

    private func handle(_ state: AuthState) {
        // Sign-out, account deletion or an expired session while someone was signed in.
        guard case .signedOut = state, signedInUser != nil, phase != .refused else { return }
        showSignedOut()
    }

    /// Where a signed-in person continues: the first onboarding step they have not done, or home.
    func resolve(_ user: UserID) async {
        root = .resolving
        path = []
        do {
            switch try await nextStep() {
            case .ageGate: root = .ageGate
            case .profile: root = .profile
            case .done: becomeReady(user)
            }
        } catch {
            root = .resolveFailed
        }
    }

    /// Retry of the `.resolveFailed` state.
    func retryResolve() {
        guard let user = signedInUser ?? data.currentUserID else {
            showSignedOut()
            return
        }
        Task { await resolve(user) }
    }

    private enum NextStep {
        case ageGate
        case profile
        case done
    }

    /// auth.code "success": `age_confirmed_at` null → auth.agegate; empty `display_name` → auth.profile; else home.
    private func nextStep() async throws -> NextStep {
        let privateProfile = try await data.myPrivateProfile()
        guard privateProfile?.ageConfirmedAt != nil else { return .ageGate }
        let profile = try await data.myProfile()
        guard !profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .profile }
        return .done
    }

    // MARK: Sign-up steps

    /// auth.phone sent the code: push auth.code.
    func codeSent(phone: String, at date: Date = Date()) {
        path.append(.code(phone: phone, sentAt: date))
    }

    /// auth.code verified: new accounts continue with the age gate, returning ones go home.
    func didVerify(_ user: UserID) async {
        signedInUser = user
        do {
            switch try await nextStep() {
            case .ageGate: path.append(.ageGate)
            case .profile: path.append(.profile)
            case .done: becomeReady(user)
            }
        } catch {
            root = .resolveFailed
            path = []
        }
    }

    /// auth.agegate confirmed: push auth.profile.
    func ageConfirmed() {
        path.append(.profile)
    }

    /// auth.profile saved: the notifications ask when the system has not asked yet, else the widget step.
    func profileSaved() async {
        if await notifications.authorizationStatus() == .notDetermined {
            path.append(.notifications)
        } else {
            path.append(.widget)
        }
    }

    /// onboarding.permission.notifications answered (whatever the answer).
    func notificationsAnswered() {
        path.append(.widget)
    }

    /// onboarding.widget "Continue": home (and the pending invite).
    func finishOnboarding() {
        guard let user = signedInUser ?? data.currentUserID else {
            showSignedOut()
            return
        }
        becomeReady(user)
    }

    /// auth.agegate "under age": remember the refusal, delete what was entered (the account), sign out.
    func refuseUnderAge(minAge: Int?) async {
        refusals.recordRefusal(minAge: minAge)
        refusalMinAge = minAge
        signedInUser = nil
        do {
            try await data.deleteAccount()
        } catch {
            await data.signOut()
        }
        phase = .refused
        path = []
        router.setReady(false)
    }

    // MARK: Home

    private func becomeReady(_ user: UserID) {
        signedInUser = user
        onboarding.markComplete(for: user.rawValue)
        autoJoinToken = router.inviteToken
        path = []
        phase = .ready
        router.setReady(true)
    }

    /// True once for the invite being joined right after onboarding.
    func consumeAutoJoin(token: String) -> Bool {
        guard autoJoinToken == token else { return false }
        autoJoinToken = nil
        return true
    }

    // MARK: Leaving

    /// settings.root "Sign Out": `unregister_device`, `auth.signOut()`, local data cleared → auth.phone.
    func signOut() async {
        signedInUser = nil
        await data.signOut()
        showSignedOut()
    }

    /// settings.account deletion finished (`delete_account` + sign-out): auth.phone with the toast
    /// `settings.account.deleted.toast`.
    func accountDeleted() {
        signedInUser = nil
        showSignedOut()
        toasts.show(Copy.settingsAccountDeletedToast)
    }

    private func showSignedOut() {
        signedInUser = nil
        autoJoinToken = nil
        root = .phone
        path = []
        phase = .signUp
        router.setReady(false)
    }
}
