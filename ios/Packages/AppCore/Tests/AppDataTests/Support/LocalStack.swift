import AppModels
import Crypto
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
@testable import AppData

/// The local Supabase stack the integration tests run against
/// (`cd backend && npm run db:start`; values from `npx -y supabase@2.121.0 status -o json`).
/// Defaults are the Supabase CLI's local development values, the same as backend/tests/helpers.ts;
/// override with SUPABASE_URL / SUPABASE_ANON_KEY / SUPABASE_SERVICE_ROLE_KEY / SUPABASE_JWT_SECRET.
/// Set APPDATA_INTEGRATION=0 to skip them even when the stack is up.
enum LocalStack {
    static let environment = ProcessInfo.processInfo.environment
    static let url = URL(string: environment["SUPABASE_URL"] ?? "http://127.0.0.1:54321")!
    static let anonKey = environment["SUPABASE_ANON_KEY"]
        ?? "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"
    static let serviceRoleKey = environment["SUPABASE_SERVICE_ROLE_KEY"]
        ?? "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU"
    static let jwtSecret = environment["SUPABASE_JWT_SECRET"] ?? "super-secret-jwt-token-with-at-least-32-characters-long"

    static var configuration: DataConfiguration { DataConfiguration(url: url, anonKey: anonKey) }

    /// Realtime tuned so a refused join reports failure within a few seconds.
    static let realtimeTuning = RealtimeTuning(reconnectDelay: 1, timeout: 4, maxJoinAttempts: 1)

    private static let probe = ReachabilityProbe()

    /// Skips the calling test (printing why) when the stack is not reachable.
    static func require() async throws {
        if environment["APPDATA_INTEGRATION"] == "0" {
            let reason = "APPDATA_INTEGRATION=0: local Supabase integration tests disabled"
            print("[AppDataTests] skipped: \(reason)")
            throw XCTSkip(reason)
        }
        if let reason = await probe.unavailableReason() {
            print("[AppDataTests] skipped: \(reason)")
            throw XCTSkip(reason)
        }
    }

    /// Checks `/auth/v1/health` once per process.
    private actor ReachabilityProbe {
        private var result: String??

        func unavailableReason() async -> String? {
            if let result { return result }
            var request = URLRequest(url: LocalStack.url.appendingPathComponent("auth/v1/health"))
            request.setValue(LocalStack.anonKey, forHTTPHeaderField: "apikey")
            request.timeoutInterval = 3
            let reason: String?
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                reason = status == 200 ? nil
                    : "local Supabase stack at \(LocalStack.url) answered \(status) on /auth/v1/health (start it with `cd backend && npm run db:start`)"
            } catch {
                reason = "local Supabase stack not reachable at \(LocalStack.url) (\(error.localizedDescription)); start it with `cd backend && npm run db:start`"
            }
            result = .some(reason)
            return reason
        }
    }

    // MARK: Tokens

    /// HS256 access token signed with the local JWT secret, like backend/tests/helpers.ts `mintJwt`.
    static func mintJWT(subject: String, ttl: TimeInterval = 3600) -> String {
        func base64URL(_ data: Data) -> String {
            data.base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        }
        let now = Int(Date().timeIntervalSince1970)
        let header = #"{"alg":"HS256","typ":"JWT"}"#
        let payload = """
        {"sub":"\(subject)","role":"authenticated","aud":"authenticated","iss":"\(url.absoluteString)/auth/v1",\
        "iat":\(now),"exp":\(now + Int(ttl)),"aal":"aal1","session_id":"\(UUID().uuidString.lowercased())"}
        """
        let signingInput = base64URL(Data(header.utf8)) + "." + base64URL(Data(payload.utf8))
        let signature = HMAC<SHA256>.authenticationCode(for: Data(signingInput.utf8), using: SymmetricKey(data: Data(jwtSecret.utf8)))
        return signingInput + "." + base64URL(Data(signature))
    }

    // MARK: Service role (admin API and fixtures the worker would write)

    struct HTTPFailure: Error, CustomStringConvertible {
        let status: Int
        let body: String
        var description: String { "HTTP \(status): \(body)" }
    }

    @discardableResult
    static func serviceRequest(_ method: String, _ path: String, json: Any? = nil, prefer: String? = nil) async throws -> Data {
        var request = URLRequest(url: URL(string: url.absoluteString + path)!)
        request.httpMethod = method
        request.setValue(serviceRoleKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(serviceRoleKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let prefer { request.setValue(prefer, forHTTPHeaderField: "Prefer") }
        if let json { request.httpBody = try JSONSerialization.data(withJSONObject: json) }
        request.timeoutInterval = 30
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw HTTPFailure(status: status, body: String(decoding: data, as: UTF8.self))
        }
        return data
    }

    /// Inserts a row as the service role and returns it.
    static func insert(_ table: String, _ row: [String: Any]) async throws -> [String: Any] {
        let data = try await serviceRequest("POST", "/rest/v1/\(table)", json: row, prefer: "return=representation")
        let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        return rows?.first ?? [:]
    }

    static func update(_ table: String, id: String, _ values: [String: Any]) async throws {
        try await serviceRequest("PATCH", "/rest/v1/\(table)?id=eq.\(id)", json: values, prefer: "return=minimal")
    }

    static func createAuthUser(phone: String, password: String, displayName: String) async throws -> String {
        let data = try await serviceRequest("POST", "/auth/v1/admin/users", json: [
            "phone": phone,
            "password": password,
            "phone_confirm": true,
            "user_metadata": ["display_name": displayName],
        ])
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let id = object?["id"] as? String else { throw HTTPFailure(status: 0, body: "no id") }
        return id.lowercased()
    }

    static func deleteAuthUser(_ id: String) async {
        _ = try? await serviceRequest("DELETE", "/auth/v1/admin/users/\(id)")
    }

    private static let phoneCounter = Counter()

    /// A unique `+1 555 …` test number.
    static func nextPhone() async -> String {
        let n = await phoneCounter.next()
        let stamp = Int(Date().timeIntervalSince1970 * 1000) % 1_000_000
        return "1555" + String(format: "%06d", stamp) + String(format: "%03d", n % 1000)
    }

    private actor Counter {
        private var value = Int.random(in: 0..<1000)
        func next() -> Int {
            value += 1
            return value
        }
    }
}

/// A test user acting through AppData with a minted token (external-token mode).
struct TestUser: Sendable {
    let id: UserID
    let name: String
    let phone: String
    let password: String
    let data: DataEnvironment

    var client: DataClient { data.client }
}

/// Creates users for one test and deletes everything they own afterwards
/// (`delete_account` as each user, then the auth user), so tests never assume an empty
/// database and leave nothing behind in the shared local stack.
final class TestUsers: @unchecked Sendable {
    private let lock = NSLock()
    private var users: [TestUser] = []
    private var directories: [URL] = []
    let runID = String(UUID().uuidString.prefix(8)).lowercased()

    func make(_ name: String, widgetStore: WidgetStore? = nil, hooks: SessionHooks = SessionHooks()) async throws -> TestUser {
        let phone = await LocalStack.nextPhone()
        let password = "pw-\(UUID().uuidString)"
        let id = try await LocalStack.createAuthUser(phone: phone, password: password, displayName: "\(name) Test\(runID)")
        let token = LocalStack.mintJWT(subject: id)
        let client = DataClient(configuration: LocalStack.configuration, realtime: LocalStack.realtimeTuning) { token }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("AppDataTests-\(UUID().uuidString)", isDirectory: true)
        let data = DataEnvironment(
            client: client,
            directories: .under(root),
            uploadTransport: FoundationUploadTransport(),
            widgetStore: widgetStore,
            hooks: hooks
        )
        let user = TestUser(id: UserID(id), name: name, phone: phone, password: password, data: data)
        lock.lock()
        users.append(user)
        directories.append(root)
        lock.unlock()
        return user
    }

    /// Registers an auth user created elsewhere (password sign-in tests) for cleanup.
    func track(authUserID: String, environment: DataEnvironment?) {
        guard let environment else { return }
        lock.lock()
        users.append(TestUser(id: UserID(authUserID), name: "", phone: "", password: "", data: environment))
        lock.unlock()
    }

    func cleanUp() async {
        lock.lock()
        let all = users
        let folders = directories
        users.removeAll()
        directories.removeAll()
        lock.unlock()
        for user in all {
            await user.data.realtime.stopAll()
            try? await user.data.account.deleteAccount()
            await LocalStack.deleteAuthUser(user.id.rawValue)
        }
        for folder in folders { try? FileManager.default.removeItem(at: folder) }
    }
}

/// A JPEG of 1×1 pixel (same bytes as backend/tests/helpers.ts `TINY_JPEG`).
let tinyJPEG = Data(base64Encoded:
    "/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////wAALCAABAAEBAREA/8QAFAABAAAAAAAAAAAAAAAAAAAAA//EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AN//Z")!

extension XCTestCase {
    /// Writes `data` to a temporary file.
    func temporaryFile(_ data: Data, extension ext: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).\(ext)")
        try data.write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    /// Asserts that `body` throws `expected`.
    func assertThrows<T>(
        _ expected: DataError,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ body: () async throws -> T
    ) async {
        do {
            _ = try await body()
            XCTFail("expected \(expected), got success", file: file, line: line)
        } catch let error as DataError {
            switch (expected, error) {
            case let (.api(expectedCode, _), .api(code, _)):
                XCTAssertEqual(code, expectedCode, file: file, line: line)
            default:
                XCTAssertEqual(error, expected, file: file, line: line)
            }
        } catch {
            XCTFail("expected DataError \(expected), got \(error)", file: file, line: line)
        }
    }

    /// Polls `condition` until it holds or `timeout` passes.
    func eventually(timeout: TimeInterval = 15, _ condition: () async -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if await condition() { return true }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        return await condition()
    }
}

/// Collects a realtime stream in the background.
final class EventRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [GroupEvent] = []
    private var task: Task<Void, Never>?

    init(_ stream: AsyncStream<GroupEvent>) {
        task = Task { [weak self] in
            for await event in stream {
                self?.append(event)
            }
        }
    }

    private func append(_ event: GroupEvent) {
        lock.lock()
        storage.append(event)
        lock.unlock()
    }

    var events: [GroupEvent] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func contains(_ predicate: (GroupEvent) -> Bool) -> Bool {
        events.contains(where: predicate)
    }

    func stop() {
        task?.cancel()
    }
}
