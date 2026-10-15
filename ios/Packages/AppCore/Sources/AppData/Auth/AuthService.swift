import Foundation
import Supabase

/// Whether someone is signed in (derived from Supabase Auth events).
public enum AuthState: Hashable, Sendable {
    case signedOut
    case signedIn(UserID)

    public var userID: UserID? {
        if case let .signedIn(id) = self { return id }
        return nil
    }
}

/// Phone OTP sign-in (Twilio Verify, docs/API.md §2 and docs/PLATFORM_CONSTRAINTS.md §7), the
/// session, sign-out and the age gate. Email sign-up is disabled on the server.
public struct AuthService: Sendable {
    public let client: DataClient

    public init(client: DataClient) {
        self.client = client
    }

    // MARK: Sign-in

    /// Sends the SMS code. `phone` is E.164 (`+15551234567`). `displayName`, when given, becomes
    /// `profiles.display_name` if this creates the account.
    /// Errors: `.auth(.rateLimited)` (one code per 60 s by default), `.auth(.smsSendFailed)`,
    /// `.auth(.invalidPhone)`, `.offline`.
    public func signInWithOTP(phone: String, displayName: String? = nil) async throws {
        try requireSupabaseAuth()
        try await mapErrors {
            try await client.supabase.auth.signInWithOTP(
                phone: phone,
                channel: .sms,
                shouldCreateUser: true,
                data: displayName.map { ["display_name": .string($0)] }
            )
        }
    }

    /// Verifies the 6-digit code and starts the session (persisted, refreshed automatically).
    /// Errors: `.auth(.invalidOTP)` for a wrong or expired code.
    @discardableResult
    public func verifyOTP(phone: String, token: String) async throws -> UserID {
        try requireSupabaseAuth()
        return try await mapErrors {
            let response = try await client.supabase.auth.verifyOTP(phone: phone, token: token, type: .sms)
            return UserID(response.user.id)
        }
    }

    /// Signs out locally and on the server. Unregister the device first (`SessionCoordinator.signOut`
    /// does both, in that order, as docs/API.md §2 requires).
    public func signOut() async {
        guard client.usesSupabaseAuth else { return }
        do {
            try await client.supabase.auth.signOut(scope: .local)
        } catch {
            // The local session is removed even when the server call fails (offline).
        }
    }

    // MARK: Session

    public var currentUserID: UserID? { client.currentUserID }

    public var currentState: AuthState {
        currentUserID.map(AuthState.signedIn) ?? .signedOut
    }

    /// Emits the current state immediately (the stored session, possibly expired and about to be
    /// refreshed), then every change. Consecutive duplicates are dropped.
    public func authStates() -> AsyncStream<AuthState> {
        guard client.usesSupabaseAuth else {
            return AsyncStream { continuation in
                Task {
                    let id = try? await client.requireUserID()
                    continuation.yield(id.map(AuthState.signedIn) ?? .signedOut)
                    continuation.finish()
                }
            }
        }
        let changes = client.supabase.auth.authStateChanges
        return AsyncStream { continuation in
            let task = Task {
                var last: AuthState?
                for await change in changes {
                    let state: AuthState
                    switch change.event {
                    case .signedOut, .userDeleted:
                        state = .signedOut
                    default:
                        state = change.session.map { .signedIn(UserID($0.user.id)) } ?? .signedOut
                    }
                    if state != last {
                        last = state
                        continuation.yield(state)
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: Onboarding

    /// `confirm_age(p_birthdate)` (age gate). The birthdate is not stored by the server.
    /// Errors: `.api(.ageGateNotConfigured)` (503, the client must not continue),
    /// `.api(.invalidBirthdate)`, `.api(.underMinimumAge)`.
    @discardableResult
    public func confirmAge(birthdate: LocalDate) async throws -> ProfilePrivate {
        try await client.rpc("confirm_age", ["p_birthdate": .date(birthdate)])
    }

    private func requireSupabaseAuth() throws {
        guard client.usesSupabaseAuth else { throw DataError.notConfigured }
    }
}
