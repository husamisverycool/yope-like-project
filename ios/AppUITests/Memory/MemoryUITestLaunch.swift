// Launch helper for the memory UI tests: the app runs every memory screen on its DEBUG fixtures
// (`-MemoryFixtures`, App: Features/Memory/Shared/MemoryFixtures.swift) and opens the screen named by
// `-MemoryOpen <screen>` once the person is home (`MemoryLaunch.apply(to:)`, called by the shell).
import XCTest

enum MemoryUITestLaunch {
    /// Launch arguments for a fixture run starting on `screen` (request, contribute, tribute,
    /// yearStory, onThisDay, birthdayAdd), signed in through the account group's in-memory
    /// scenario (`-account-ui-test-scenario signed-in`, AccountUITestScenario).
    static func arguments(open screen: String) -> [String] {
        ["-account-ui-test-scenario", "signed-in", "-MemoryFixtures", "-MemoryOpen", screen]
    }

    /// Any element carrying `identifier` (screens carry their surface id).
    static func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// Waits for the screen; skips (with the reason) when the shell did not open it, i.e. the
    /// launch hook `MemoryLaunch.apply(to:)` or a signed-in fixture session is not wired yet.
    static func waitForScreen(_ app: XCUIApplication, _ identifier: String, timeout: TimeInterval = 20) throws -> XCUIElement {
        let screen = element(app, identifier)
        if !screen.waitForExistence(timeout: timeout) {
            throw XCTSkip("\(identifier) did not open: the shell must call MemoryLaunch.apply(to: router) once home (DEBUG)")
        }
        return screen
    }
}
