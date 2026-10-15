import XCTest

/// Launch smoke test. Screen-level UI tests come with the screens pass (each screen container
/// carries its surface id as accessibility identifier).
final class AppLaunchUITests: XCTestCase {
    @MainActor
    func testLaunches() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30))
    }
}
