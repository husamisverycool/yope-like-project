import AppData
import AppModels
import Foundation
import Supabase
import XCTest

/// Apple-only parts of AppData that the Linux `swift test` job cannot reach (Keychain session
/// storage, background `URLSession` uploads, `NWPathMonitor`). Runs on a simulator without network.
/// The integration tests against the local Supabase stack live in the package
/// (`Packages/AppCore/Tests/AppDataTests`, run with `swift test` on a machine with the stack).
final class AppDataSimulatorTests: XCTestCase {
    func testLiveEnvironmentNeedsTheSupabaseConfiguration() {
        XCTAssertThrowsError(try DataEnvironment.live(configuration: AppConfiguration(), backgroundUploads: false)) { error in
            XCTAssertEqual(error as? DataError, .notConfigured)
        }
    }

    func testSessionsLiveInTheKeychainOnApplePlatforms() {
        let storage = SessionStorage.platformDefault()
        XCTAssertTrue(String(describing: type(of: storage)).contains("Keychain"), "\(type(of: storage))")
    }

    /// The session supabase-swift writes after the code is read back from the Keychain. A simulator build signed without
    /// entitlements (CODE_SIGNING_ALLOWED=NO) gets errSecMissingEntitlement here, supabase-swift only logs it, and every
    /// sign-in is lost right after the code (run 102's "ios e2e": "You're offline" after auth.code); CI signs the app
    /// ad hoc for the simulator.
    func testTheSessionRoundTripsThroughTheKeychain() throws {
        let storage = SessionStorage.platformDefault(service: "app.session.tests.\(UUID().uuidString)")
        let key = "session"
        let value = Data(#"{"access_token":"token"}"#.utf8)
        defer { try? storage.remove(key: key) }
        try storage.store(key: key, value: value)
        XCTAssertEqual(try storage.retrieve(key: key), value)
        try storage.remove(key: key)
        // A missing item: nil, or errSecItemNotFound from supabase-swift's Keychain (its session storage reads both as none).
        XCTAssertNil(try? storage.retrieve(key: key))
    }

    func testDefaultUploadsUseABackgroundSession() throws {
        let configuration = DataConfiguration(url: try XCTUnwrap(URL(string: "https://example.invalid")), anonKey: "anon")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("AppDataSimulatorTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let data = DataEnvironment(client: DataClient(configuration: configuration) { nil }, directories: .under(root))
        XCTAssertTrue(data.uploader.transport is BackgroundUploadTransport)
        var handled = false
        XCTAssertFalse(data.handleBackgroundURLSessionEvents(identifier: "someone.else") { handled = true })
        XCTAssertTrue(data.handleBackgroundURLSessionEvents(identifier: BackgroundUploadTransport.defaultIdentifier) {})
        XCTAssertFalse(handled)
    }

    func testReachabilityReportsAStatus() async {
        let reachability = Reachability()
        var iterator = reachability.updates().makeAsyncIterator()
        let first = await iterator.next()
        XCTAssertNotNil(first)
        _ = reachability.currentStatus
    }

    func testOfflineCacheRoundTripWithFileProtection() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("AppDataCache-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = OfflineCache(directory: directory)
        let ids = [PostID("p1"), PostID("p2")]
        await cache.write(ids, for: CacheKey("test"))
        let cached = await cache.read([PostID].self, for: CacheKey("test"))
        XCTAssertEqual(cached?.value, ids)
        let values = try directory.appendingPathComponent("test.json").resourceValues(forKeys: [.isExcludedFromBackupKey])
        XCTAssertEqual(values.isExcludedFromBackup, true)
    }
}
