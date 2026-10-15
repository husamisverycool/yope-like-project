import AppData
import AppModels
import Foundation
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
