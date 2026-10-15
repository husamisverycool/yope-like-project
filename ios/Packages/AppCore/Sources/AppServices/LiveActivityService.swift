#if os(iOS)
import ActivityKit
import AppModels
import Foundation

/// The daily invitation Live Activity (`daily.liveactivity`).
///
/// The worker starts it on every member's device at the same moment with an ActivityKit
/// push-to-start push (iOS 17.2+), so this service mainly reports tokens:
/// - the push-to-start token (→ `devices.push_to_start_token`),
/// - each activity's update token (for the worker's update / end pushes).
/// It also ends activities locally once their window has closed, whenever the app runs.
@MainActor
public final class LiveActivityService {
    public struct ActivityToken: Hashable, Sendable {
        public let activityID: String
        public let groupID: String
        public let invitationID: String
        /// Lowercase hex.
        public let token: String
    }

    public var onPushToStartToken: ((String) -> Void)?
    public var onActivityToken: ((ActivityToken) -> Void)?

    private var observers: [Task<Void, Never>] = []
    private var activityTasks: [String: [Task<Void, Never>]] = [:]

    /// Lives for the app's lifetime (owned by the app environment); its tasks hold it weakly.
    public init() {}

    /// Whether the user allows Live Activities for the app (Settings).
    public var areActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// Starts reporting tokens and tracking activities. Safe to call more than once.
    public func startObserving() {
        guard observers.isEmpty else { return }
        if let token = Activity<DailyInvitationAttributes>.pushToStartToken {
            onPushToStartToken?(PushToken.hex(token))
        }
        observers.append(Task { [weak self] in
            for await token in Activity<DailyInvitationAttributes>.pushToStartTokenUpdates {
                self?.onPushToStartToken?(PushToken.hex(token))
            }
        })
        observers.append(Task { [weak self] in
            for await activity in Activity<DailyInvitationAttributes>.activityUpdates {
                self?.track(activity)
            }
        })
        for activity in Activity<DailyInvitationAttributes>.activities {
            track(activity)
        }
    }

    /// Ends every activity whose window has closed (call when the app becomes active).
    public func endClosedActivities(now: Date = Date()) async {
        for activity in Activity<DailyInvitationAttributes>.activities
        where activity.content.state.closesAt <= now {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    /// Starts an activity from the app (the server normally starts it by push). Returns its id.
    @discardableResult
    public func start(attributes: DailyInvitationAttributes, state: DailyInvitationAttributes.ContentState) throws -> String {
        let content = ActivityContent(state: state, staleDate: state.closesAt)
        let activity = try Activity.request(attributes: attributes, content: content, pushType: .token)
        track(activity)
        return activity.id
    }

    private func track(_ activity: Activity<DailyInvitationAttributes>) {
        guard activityTasks[activity.id] == nil else { return }
        let id = activity.id
        let attributes = activity.attributes

        let tokens = Task { [weak self] in
            for await token in activity.pushTokenUpdates {
                self?.onActivityToken?(ActivityToken(
                    activityID: id,
                    groupID: attributes.groupID,
                    invitationID: attributes.invitationID,
                    token: PushToken.hex(token)
                ))
            }
        }

        // End locally at closesAt; re-reads the state after each wait in case an update moved it.
        let ending = Task {
            while !Task.isCancelled {
                let remaining = activity.content.state.closesAt.timeIntervalSinceNow
                if remaining <= 0 {
                    await activity.end(nil, dismissalPolicy: .immediate)
                    return
                }
                do {
                    try await Task.sleep(for: .seconds(remaining))
                } catch {
                    return
                }
            }
        }

        let lifecycle = Task { [weak self] in
            for await state in activity.activityStateUpdates where state == .ended || state == .dismissed {
                self?.forget(id)
                return
            }
        }

        activityTasks[id] = [tokens, ending, lifecycle]
    }

    private func forget(_ id: String) {
        activityTasks[id]?.forEach { $0.cancel() }
        activityTasks[id] = nil
    }
}
#endif
