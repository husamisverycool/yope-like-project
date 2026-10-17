import Foundation
import XCTest
@testable import AppData

/// The App Clip's sign-in reaches the full app (`SessionStorage.Migrating`): the app opens signed in, once, and a
/// sign-out in the app is never undone by the clip's copy.
final class SessionHandoffTests: XCTestCase {
    private func record() -> SessionStorage.MigrationRecord {
        let suite = "session.handoff.tests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        return SessionStorage.MigrationRecord(defaults: defaults)
    }

    func testTheClipsSessionMovesIntoTheAppOnce() throws {
        let app = SessionStorage.InMemory()
        let clip = SessionStorage.InMemory()
        try clip.store(key: "sb-auth-token", value: Data("clip session".utf8))
        let storage = SessionStorage.Migrating(primary: app, legacy: clip, record: record())

        XCTAssertEqual(try storage.retrieve(key: "sb-auth-token"), Data("clip session".utf8), "signed in at first launch")
        XCTAssertEqual(try app.retrieve(key: "sb-auth-token"), Data("clip session".utf8), "now the app's own")
        XCTAssertNil(try clip.retrieve(key: "sb-auth-token"), "the clip's copy is removed")
    }

    func testTheAppsOwnSessionWins() throws {
        let app = SessionStorage.InMemory()
        let clip = SessionStorage.InMemory()
        try app.store(key: "k", value: Data("app".utf8))
        try clip.store(key: "k", value: Data("clip".utf8))
        let storage = SessionStorage.Migrating(primary: app, legacy: clip, record: record())
        XCTAssertEqual(try storage.retrieve(key: "k"), Data("app".utf8))
    }

    func testASignOutIsNotUndoneByTheClipsCopy() throws {
        let app = SessionStorage.InMemory()
        let clip = SessionStorage.InMemory()
        let storage = SessionStorage.Migrating(primary: app, legacy: clip, record: record())
        XCTAssertNil(try storage.retrieve(key: "k"), "nothing anywhere")
        // The clip signs in later (the app was deleted and the clip used again would be a new install; here the copy
        // appears after the app already looked): the app does not pick it up again.
        try clip.store(key: "k", value: Data("late".utf8))
        XCTAssertNil(try storage.retrieve(key: "k"))

        let fresh = SessionStorage.Migrating(primary: app, legacy: clip, record: record())
        try fresh.store(key: "s", value: Data("signed in".utf8))
        try clip.store(key: "s", value: Data("clip".utf8))
        try fresh.remove(key: "s")
        XCTAssertNil(try fresh.retrieve(key: "s"), "signed out stays signed out")
        XCTAssertNil(try clip.retrieve(key: "s"))
    }
}
