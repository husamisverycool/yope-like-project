@testable import App
import SwiftUI
import XCTest

/// Proves the snapshot pipeline end to end. The screens pass adds one recording per screen.
final class SnapshotRecorderTests: XCTestCase {
    @MainActor
    func testRecordsRootViewToBuildDirectory() throws {
        let router = AppRouter(parser: .init(universalLinkHosts: []))
        let url = try XCTUnwrap(SnapshotRecorder.record(RootView(router: router), named: "root", group: "Foundation"))
        XCTAssertTrue(url.path.contains("/build/snapshots/Foundation/"))
        XCTAssertGreaterThan(try Data(contentsOf: url).count, 0)
    }
}
