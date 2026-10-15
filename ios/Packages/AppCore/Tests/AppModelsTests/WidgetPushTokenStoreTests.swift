import Foundation
import XCTest
@testable import AppModels

final class WidgetPushTokenStoreTests: XCTestCase {
    func testRoundTripAndClear() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("WidgetPushTokenStoreTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = WidgetPushTokenStore.resolve(appGroupIdentifier: nil, fallbackDirectory: directory)
        XCTAssertNil(store.load())
        try store.save(tokenData: Data([0xAB, 0x01]))
        XCTAssertEqual(store.load(), "ab01")
        try store.save("CAFE")
        XCTAssertEqual(WidgetPushTokenStore(fileURL: store.fileURL).load(), "cafe")
        try store.save(nil)
        XCTAssertNil(store.load())
    }

    func testSurvivesWidgetStoreReset() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("WidgetPushTokenStoreTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let tokens = WidgetPushTokenStore.resolve(appGroupIdentifier: nil, fallbackDirectory: directory)
        let widgets = WidgetStore.resolve(appGroupIdentifier: nil, fallbackDirectory: directory)
        try tokens.save("beef")
        try widgets.syncGroups([WidgetGroup(id: "g1", name: "Family")])
        try widgets.removeAll()
        XCTAssertEqual(tokens.load(), "beef", "device-level, not cleared with the signed-in user's widgets")
    }
}
