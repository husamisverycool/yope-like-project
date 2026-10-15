import AppModels
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Supabase

/// Where the backend is: `config/app.json` → `supabase.url` / `supabase.anonKey` (docs/API.md §1).
public struct DataConfiguration: Hashable, Sendable {
    public var url: URL
    /// The anon (publishable) key. The apps never hold the service role key.
    public var anonKey: String
    /// The one private bucket (docs/API.md §7).
    public var bucket: String

    public init(url: URL, anonKey: String, bucket: String = "media") {
        self.url = url
        self.anonKey = anonKey
        self.bucket = bucket
    }

    /// Throws `DataError.notConfigured` while the owner has not provided the values (BLOCKED).
    public init(_ app: AppConfiguration) throws {
        guard let url = app.supabaseURL, let key = app.supabaseAnonKey else { throw DataError.notConfigured }
        self.init(url: url, anonKey: key)
    }

    var storageURL: URL { url.appendingPathComponent("storage/v1") }
}

/// Realtime socket tuning. A join the server refuses (the private `group:<id>` topic for a
/// non-member) gets no error callback from supabase-swift: it times out and is retried, so
/// `timeout × maxJoinAttempts` bounds how long a refused subscription takes to report failure.
public struct RealtimeTuning: Hashable, Sendable {
    /// Base delay before reconnecting a dropped socket; supabase-swift backs off exponentially (≤ 30 s).
    public var reconnectDelay: TimeInterval
    /// Seconds to wait for a server reply (join, heartbeat).
    public var timeout: TimeInterval
    public var maxJoinAttempts: Int

    public init(reconnectDelay: TimeInterval = 2, timeout: TimeInterval = 10, maxJoinAttempts: Int = 3) {
        self.reconnectDelay = reconnectDelay
        self.timeout = timeout
        self.maxJoinAttempts = maxJoinAttempts
    }
}

/// The configured `SupabaseClient` plus the JSON conventions, error mapping and identity helpers
/// every repository uses. One instance per process.
///
/// Two modes:
/// - **Supabase Auth** (the app, the App Clip): phone OTP sessions persisted in `sessionStorage`
///   (the Keychain on Apple platforms) and refreshed automatically.
/// - **External token** (tests, or an extension that is handed a token): every request carries
///   the token returned by `accessToken`; `supabase.auth` must not be used in this mode.
public final class DataClient: Sendable {
    public let configuration: DataConfiguration
    public let supabase: SupabaseClient
    private let externalToken: (@Sendable () async throws -> String?)?

    /// Supabase Auth mode.
    /// - Parameters:
    ///   - sessionStorage: where the session lives. Defaults to `SessionStorage.platformDefault()`
    ///     (Keychain on Apple platforms, a file under Application Support elsewhere).
    ///   - urlSession: transport for REST, Storage and Auth requests.
    public init(
        configuration: DataConfiguration,
        sessionStorage: (any AuthLocalStorage)? = nil,
        storageKey: String? = nil,
        urlSession: URLSession = .shared,
        realtime: RealtimeTuning = RealtimeTuning()
    ) {
        self.configuration = configuration
        self.externalToken = nil
        let auth = SupabaseClientOptions.AuthOptions(
            storage: sessionStorage ?? SessionStorage.platformDefault(),
            storageKey: storageKey,
            flowType: .pkce,
            encoder: AuthClient.Configuration.jsonEncoder,
            decoder: AuthClient.Configuration.jsonDecoder,
            autoRefreshToken: true,
            // Offline launches show cached content right away instead of waiting for a refresh.
            emitLocalSessionAsInitialSession: true
        )
        supabase = SupabaseClient(
            supabaseURL: configuration.url,
            supabaseKey: configuration.anonKey,
            options: Self.options(auth: auth, urlSession: urlSession, realtime: realtime)
        )
    }

    /// External token mode: `accessToken` returns the user's JWT (or nil for anonymous calls).
    public init(
        configuration: DataConfiguration,
        urlSession: URLSession = .shared,
        realtime: RealtimeTuning = RealtimeTuning(),
        accessToken: @escaping @Sendable () async throws -> String?
    ) {
        self.configuration = configuration
        self.externalToken = accessToken
        let auth = SupabaseClientOptions.AuthOptions(
            storage: SessionStorage.InMemory(),
            autoRefreshToken: false,
            accessToken: accessToken
        )
        supabase = SupabaseClient(
            supabaseURL: configuration.url,
            supabaseKey: configuration.anonKey,
            options: Self.options(auth: auth, urlSession: urlSession, realtime: realtime)
        )
    }

    private static func options(
        auth: SupabaseClientOptions.AuthOptions,
        urlSession: URLSession,
        realtime: RealtimeTuning
    ) -> SupabaseClientOptions {
        SupabaseClientOptions(
            db: .init(encoder: DataCoding.makeEncoder(), decoder: DataCoding.makeDecoder()),
            auth: auth,
            global: .init(session: urlSession),
            realtime: RealtimeClientOptions(
                reconnectDelay: realtime.reconnectDelay,
                timeoutInterval: realtime.timeout,
                maxRetryAttempts: realtime.maxJoinAttempts
            )
        )
    }

    public var usesSupabaseAuth: Bool { externalToken == nil }

    // MARK: Identity

    /// The signed-in user, or nil. In Supabase Auth mode this reads the stored session (it may be
    /// expired; it is refreshed on the next request).
    public var currentUserID: UserID? {
        guard externalToken == nil else { return nil }
        return supabase.auth.currentUser.map { UserID($0.id) }
    }

    /// The signed-in user's id; throws `DataError.notSignedIn` when there is none.
    public func requireUserID() async throws -> UserID {
        if let externalToken {
            guard let token = try? await externalToken(), let subject = JWTClaims.subject(of: token) else {
                throw DataError.notSignedIn
            }
            return UserID(subject)
        }
        if let id = currentUserID { return id }
        throw DataError.notSignedIn
    }

    /// A valid access token for hand-made requests (background uploads); refreshed when needed.
    public func accessToken() async throws -> String {
        if let externalToken {
            guard let token = try await externalToken() else { throw DataError.notSignedIn }
            return token
        }
        do {
            return try await supabase.auth.session.accessToken
        } catch {
            throw DataError.from(error)
        }
    }

    // MARK: Requests

    /// Calls an RPC that returns JSON and decodes it.
    func rpc<Result: Decodable>(_ function: String, _ params: JSONObject = [:], as type: Result.Type = Result.self) async throws -> Result {
        try await mapErrors {
            let response = try await supabase.rpc(function, params: params).execute()
            return try DataCoding.makeDecoder().decode(Result.self, from: response.data)
        }
    }

    /// Calls an RPC that returns `void` (HTTP 204, docs/API.md §1).
    func rpcVoid(_ function: String, _ params: JSONObject = [:]) async throws {
        try await mapErrors {
            _ = try await supabase.rpc(function, params: params).execute()
        }
    }

    /// Runs a PostgREST read and decodes the rows.
    func rows<Row: Decodable>(_ type: Row.Type, _ query: () throws -> PostgrestBuilder) async throws -> [Row] {
        try await mapErrors {
            let response = try await query().execute()
            return try DataCoding.makeDecoder().decode([Row].self, from: response.data)
        }
    }

    /// Runs a PostgREST read expected to match at most one row.
    func firstRow<Row: Decodable>(_ type: Row.Type, _ query: () throws -> PostgrestBuilder) async throws -> Row? {
        try await rows(type, query).first
    }

    /// Runs a write and ignores the body.
    func perform(_ query: () throws -> PostgrestBuilder) async throws {
        try await mapErrors {
            _ = try await query().execute()
        }
    }
}

// MARK: - RPC parameter helpers

extension AnyJSON {
    static func id<E>(_ value: Identifier<E>?) -> AnyJSON {
        value.map { .string($0.rawValue) } ?? .null
    }

    static func ids<E>(_ values: [Identifier<E>]) -> AnyJSON {
        .array(values.map { .string($0.rawValue) })
    }

    static func text(_ value: String?) -> AnyJSON {
        value.map { .string($0) } ?? .null
    }

    static func int(_ value: Int?) -> AnyJSON {
        value.map { .integer($0) } ?? .null
    }

    static func flag(_ value: Bool?) -> AnyJSON {
        value.map { .bool($0) } ?? .null
    }

    static func time(_ value: LocalTime?) -> AnyJSON {
        value.map { .string($0.wireValue) } ?? .null
    }

    static func date(_ value: LocalDate?) -> AnyJSON {
        value.map { .string($0.description) } ?? .null
    }

    static func timestamp(_ value: Date?) -> AnyJSON {
        value.map { .string(Timestamp.format($0)) } ?? .null
    }
}

/// Reads the claims of a JWT without verifying it (the server verifies every request).
enum JWTClaims {
    static func payload(of token: String) -> [String: Any]? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var base64 = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64.append("=") }
        guard let data = Data(base64Encoded: base64),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return object
    }

    static func subject(of token: String) -> String? {
        payload(of: token)?["sub"] as? String
    }
}
