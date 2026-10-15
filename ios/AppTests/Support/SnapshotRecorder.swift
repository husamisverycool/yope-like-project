import SnapshotTesting
import SwiftUI
import XCTest

/// Renders SwiftUI views to PNG files in `ios/build/snapshots/` (uploaded by CI as the
/// `ios-results` artifact) for the side-by-side verification images in design/verification/.
/// Recording never fails a test; tests assert their own expectations.
enum SnapshotRecorder {
    /// <repo>/ios/build/snapshots (this file is <repo>/ios/AppTests/Support/SnapshotRecorder.swift).
    static let directory: URL = URL(fileURLWithPath: "\(#filePath)")
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("build", isDirectory: true)
        .appendingPathComponent("snapshots", isDirectory: true)

    /// Writes `<directory>/<group>/<test name>.<name>.png` and returns its URL when written.
    @MainActor
    @discardableResult
    static func record<V: View>(
        _ view: V,
        named name: String,
        group: String,
        layout: SwiftUISnapshotLayout = .device(config: .iPhone13),
        file: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line
    ) -> URL? {
        let folder = directory.appendingPathComponent(group, isDirectory: true)
        _ = verifySnapshot(
            of: view,
            as: .image(layout: layout),
            named: name,
            record: .all,
            snapshotDirectory: folder.path,
            file: file,
            testName: testName,
            line: line
        )
        let contents = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return contents.first { $0.lastPathComponent.hasSuffix(".\(name).png") }
    }
}
