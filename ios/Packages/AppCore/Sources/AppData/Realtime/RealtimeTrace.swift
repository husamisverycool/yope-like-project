import Foundation
#if canImport(os)
import os
#endif

/// A DEBUG-only trace of the Realtime channels for diagnosing runs against a real server: CI's "ios e2e" job reads it
/// from the simulator's unified log (subsystem `app.data.realtime`). Release builds and Linux log nothing. No personal
/// data: topics, statuses, errors and event kinds only.
enum RealtimeTrace {
    #if DEBUG && canImport(os)
    private static let logger = Logger(subsystem: "app.data.realtime", category: "hub") // provenance-ok: log subsystem, not user-facing
    #endif

    static func log(_ message: @autoclosure () -> String) {
        #if DEBUG && canImport(os)
        let text = message()
        logger.notice("\(text, privacy: .public)")
        #endif
    }

    /// An event's case name without its payload (`postInserted`, `plansChanged`, …).
    static func kind(_ event: GroupEvent) -> String {
        String(String(describing: event).prefix { $0 != "(" })
    }
}
