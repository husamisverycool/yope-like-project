// The Jolt demo: a DEBUG build compiled with `-D DEMO` (CI's "ios demo build", the `jolt-demo` artifact) runs the whole
// app on one built-in sample world, signed in, with no backend and no account. It turns on each feature's fakes as if
// the app had been launched with their arguments, and keys them to one world: the social demo's people and groups
// ("roommates", "climbing") with their posts, chat, recaps and albums (`SocialDemo`), the same groups and people in
// the account data (`AccountUITestScenario.demo`), the memory scenario on "roommates" (`MemoryFixtureIDs`) and the
// camera's groups (`CaptureFakes`). Photos are the sample photos (`DemoPhotos`); dates follow the day it runs.
// Every other build has `isOn == false` and reads the launch arguments unchanged.
import Foundation

enum DemoMode {
    static let isOn: Bool = {
        #if DEMO
        return true
        #else
        return false
        #endif
    }()

    /// Each feature's fakes, as launch arguments.
    static let arguments = [
        "-account-ui-test-scenario", "demo", // provenance-ok: launch arguments, not user-facing
        "-SocialFakes", "-capture-fakes", "-MemoryFixtures", // provenance-ok: launch arguments, not user-facing
    ]

    /// The process's launch arguments, plus the demo's in the demo build.
    static var launchArguments: [String] {
        ProcessInfo.processInfo.arguments + (isOn ? arguments : [])
    }

    /// When the demo world was built: its dates are placed around it.
    static let launchDate = Date()

    /// The start of the week the demo runs in (Monday 00:00, the device's calendar and time zone).
    static var weekStart: Date {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        return calendar.dateInterval(of: .weekOfYear, for: launchDate)?.start ?? launchDate
    }
}
