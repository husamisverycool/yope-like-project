// Account group — App Clip → full app hand-off of a joined invite (invite.appclip "Data & actions" 4;
// docs/PLATFORM_CONSTRAINTS.md §3: shared App Group container + UserDefaults(suiteName:)). Only the invite token and
// the joined group id are stored, never credentials.
import AppModels
import Foundation

/// What the App Clip leaves for the full app after a join.
struct InviteHandoff: Codable, Hashable, Sendable {
    var token: String
    var joinedGroupID: String?

    private static let key = "invite.handoff" // provenance-ok: UserDefaults key, not user-facing

    /// The App Group defaults (`AppGroupIdentifier` in Info.plist); nil when the build has no App Group.
    static func defaults(bundle: Bundle = .main) -> UserDefaults? {
        AppGroup.identifier(in: bundle).flatMap { UserDefaults(suiteName: $0) }
    }

    /// Written by the App Clip after `join_group` succeeds.
    func save(to defaults: UserDefaults?) {
        guard let defaults, let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.key)
    }

    /// Read (and removed) by the full app at launch.
    static func take(from defaults: UserDefaults?) -> InviteHandoff? {
        guard let defaults, let data = defaults.data(forKey: key) else { return nil }
        defaults.removeObject(forKey: key)
        return try? JSONDecoder().decode(InviteHandoff.self, from: data)
    }
}
