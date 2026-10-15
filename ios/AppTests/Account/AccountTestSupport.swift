// Shared helpers for the account group's tests (AppTests/Account): in-memory data with a signed-in member, a session
// rig, and a wait for work the models start in their own tasks.
@testable import App
import AppData
import AppModels
import Foundation
import XCTest

/// People and groups used across the account tests (fixture data, not user-facing).
@MainActor
struct AccountFixture {
    let data: InMemoryAccountData
    let me: Profile
    let rui: Profile

    /// A signed-in, onboarded member ("Ana Lima") and a second person ("Rui Costa").
    init() {
        let data = InMemoryAccountData()
        let me = data.addProfile("Ana Lima")
        let rui = data.addProfile("Rui Costa")
        data.currentUserID = me.id
        data.privateProfile = ProfilePrivate(
            userID: me.id, birthday: nil, birthdayOptIn: false,
            ageConfirmedAt: Date(timeIntervalSince1970: 1_790_000_000), updatedAt: Date(timeIntervalSince1970: 1_790_000_000)
        )
        self.data = data
        self.me = me
        self.rui = rui
    }

    /// A group Ana created with Rui in it.
    @discardableResult
    func familyGroup(posts: Int = 0) -> PhotoGroup {
        let group = data.addGroup("Lima family", kind: .family, createdBy: me.id, members: [me, rui])
        for index in 0..<posts {
            data.addPost(groupID: group.id, author: index.isMultiple(of: 2) ? rui.id : me.id, minutesAgo: 5 + index * 10)
        }
        return group
    }
}

/// `AccountSession` with in-memory records, a fixed notification answer and a fresh router.
@MainActor
final class AccountSessionRig {
    let data: InMemoryAccountData
    let router = AppRouter(parser: .init(universalLinkHosts: []))
    let refusals = InMemoryAgeGateRefusalStore()
    let defaults: UserDefaults
    let onboarding: OnboardingRecord
    let notifications: StaticNotificationAuthorizer
    let toasts = ToastCenter()
    let shell = ShellState()
    let session: AccountSession

    init(data: InMemoryAccountData? = nil, notificationStatus: PermissionStatus = .notDetermined) {
        let data = data ?? InMemoryAccountData()
        self.data = data
        let suite = "account.tests." + UUID().uuidString
        defaults = UserDefaults(suiteName: suite) ?? .standard
        onboarding = OnboardingRecord(defaults: defaults)
        notifications = StaticNotificationAuthorizer(status: notificationStatus)
        session = AccountSession(
            data: data, router: router, refusals: refusals, onboarding: onboarding,
            notifications: notifications, toasts: toasts, shell: shell
        )
    }
}

/// Waits (on the main actor) until `condition` holds; fails after `timeout`.
@MainActor
func waitUntil(
    timeout: TimeInterval = 2,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ condition: () -> Bool
) async {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition() {
        if Date() > deadline {
            XCTFail("condition not met within \(timeout) s", file: file, line: line)
            return
        }
        try? await Task.sleep(nanoseconds: 5_000_000)
    }
}

private final class RecordingFlag {
    var isSet = false
}

/// Records every distinct value `read` takes while `work` runs (the phases a screen goes through).
@MainActor
func recordStates<Value: Equatable>(of read: @escaping () -> Value, during work: @escaping () async -> Void) async -> [Value] {
    var states = [read()]
    let finished = RecordingFlag()
    let task = Task { @MainActor in
        await work()
        finished.isSet = true
    }
    while !finished.isSet {
        let value = read()
        if value != states.last { states.append(value) }
        await Task.yield()
    }
    _ = await task.value
    let value = read()
    if value != states.last { states.append(value) }
    return states
}
