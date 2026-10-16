// The real-server UI journey (ios/AppUITests/ServerJourney, CI job "ios e2e"): a DEBUG build reads a test stack's address
// from its launch environment, because config/app.json's Supabase URL, anon key and domain are owner values (BLOCKED)
// and the CI stack runs behind a temporary tunnel. Release builds contain none of this.
#if DEBUG
import AppModels
import Foundation

enum ServerJourneyOverrides {
    /// The test stack's API URL (the tunnel's https address).
    static let supabaseURLKey = "JOLT_E2E_SUPABASE_URL" // provenance-ok: launch environment key, not user-facing
    /// The test stack's anon key.
    static let anonKeyKey = "JOLT_E2E_SUPABASE_ANON_KEY" // provenance-ok: launch environment key, not user-facing
    /// The invite links' host for the run (an RFC 6761 `.test` name: nothing outside the test opens these links).
    static let inviteHostKey = "JOLT_E2E_INVITE_HOST" // provenance-ok: launch environment key, not user-facing

    /// `configuration` with the launch environment's stack (both the URL and the key, or neither) and invite host.
    static func apply(to configuration: AppConfiguration, environment: [String: String] = ProcessInfo.processInfo.environment) -> AppConfiguration {
        var result = configuration
        if let url = environment[supabaseURLKey].flatMap(URL.init(string:)), url.scheme != nil,
           let key = environment[anonKeyKey], !key.isEmpty {
            result.supabaseURL = url
            result.supabaseAnonKey = key
        }
        if let host = environment[inviteHostKey], !host.isEmpty {
            result.domain = host.lowercased()
        }
        return result
    }
}
#endif
