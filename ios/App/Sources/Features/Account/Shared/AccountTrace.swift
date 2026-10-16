// Account group — a DEBUG-only trace of the sign-up steps for diagnosing UI-test runs: CI reads it from the simulator's
// unified log (subsystem `app.account.trace`, the "ios ui tests" job's `sim-account.log`). Release builds keep the call
// sites and log nothing. No personal data: steps, flags and object identities only.
import os

enum AccountTrace {
    #if DEBUG
    private static let logger = Logger(subsystem: "app.account.trace", category: "signup") // provenance-ok: log subsystem, not user-facing
    #endif

    static func log(_ message: @autoclosure () -> String) {
        #if DEBUG
        let text = message()
        logger.notice("\(text, privacy: .public)")
        #endif
    }

    /// A short identity for an object (which instance a step talks to).
    static func id(_ object: AnyObject) -> String {
        String(UInt(bitPattern: ObjectIdentifier(object).hashValue), radix: 16)
    }
}
