import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Supabase

/// The stable error codes of docs/API.md §3 (`message` of a PostgREST error raised by an RPC or
/// trigger). Screens branch on these and map them to copy keys; nothing user-facing lives here.
public enum APIErrorCode: String, CaseIterable, Sendable {
    case notAuthenticated = "not_authenticated"
    case notGroupMember = "not_group_member"
    case notGroupAdmin = "not_group_admin"
    case notAlbumOwner = "not_album_owner"
    case postNotEligible = "post_not_eligible"
    case underMinimumAge = "under_minimum_age"
    case premiumRequired = "premium_required"
    case videoTooLong = "video_too_long"
    case postNotFound = "post_not_found"
    case mediaNotFound = "media_not_found"
    case messageNotFound = "message_not_found"
    case memberNotFound = "member_not_found"
    case userNotFound = "user_not_found"
    case inviteNotFound = "invite_not_found"
    case recapNotFound = "recap_not_found"
    case albumNotFound = "album_not_found"
    case requestNotFound = "request_not_found"
    case targetNotFound = "target_not_found"
    case inviteRevoked = "invite_revoked"
    case inviteExpired = "invite_expired"
    case groupFull = "group_full"
    case alreadyPosted = "already_posted"
    case recapNotReady = "recap_not_ready"
    case tributeClosed = "tribute_closed"
    case ageGateNotConfigured = "age_gate_not_configured"
    case invalidName = "invalid_name"
    case invalidKind = "invalid_kind"
    case invalidTimeZone = "invalid_time_zone"
    case invalidWakingWindow = "invalid_waking_window"
    case invalidPath = "invalid_path"
    case invalidCaption = "invalid_caption"
    case invalidVoice = "invalid_voice"
    case invalidBody = "invalid_body"
    case invalidEmoji = "invalid_emoji"
    case invalidItems = "invalid_items"
    case invalidText = "invalid_text"
    case invalidLine = "invalid_line"
    case invalidReason = "invalid_reason"
    case invalidPlatform = "invalid_platform"
    case invalidToken = "invalid_token"
    case invalidQuietHours = "invalid_quiet_hours"
    case invalidBirthday = "invalid_birthday"
    case invalidBirthdate = "invalid_birthdate"
    case replyGroupMismatch = "reply_group_mismatch"
    case cannotTargetSelf = "cannot_target_self"
    case noGroups = "no_groups"
    case invalidArgument = "invalid_argument"
}

/// Every error AppData throws. Screens switch over it to pick a copy key and a state
/// (retry, offline, sign in again, …).
public enum DataError: Error, Equatable, Sendable {
    /// An error code of docs/API.md §3. `details` is diagnostic context (e.g. a group id); never shown.
    case api(APIErrorCode, details: String? = nil)
    /// A Postgres / PostgREST error without a stable API code: `42501` permission denied (RLS),
    /// `23514` check constraint, `23505` unique violation, `22P02` invalid input, `PGRST…`.
    case database(code: String, message: String)
    case storage(StorageFailure)
    case auth(AuthFailure)
    /// No connection, timeout, DNS, TLS: the request did not reach the server or got no answer.
    case offline
    /// HTTP failure without a decodable error body.
    case http(status: Int)
    /// config/app.json has no Supabase URL / anon key yet (owner values, BLOCKED).
    case notConfigured
    /// The call needs a signed-in user and there is none.
    case notSignedIn
    /// The realtime channel could not be joined (e.g. the private `group:<id>` topic for a non-member).
    case realtimeSubscriptionFailed(topic: String)
    /// The response could not be decoded into the expected model.
    case decoding(String)
    /// A local file (upload source, cache) could not be read or written.
    case localFile(String)

    /// Storage API failures (`statusCode` of the storage error body).
    public enum StorageFailure: Equatable, Sendable {
        /// The object already exists (uploads never overwrite, docs/API.md §7).
        case alreadyExists
        case notFound
        /// RLS refused the read or write (wrong folder, not a member, blocked).
        case unauthorized
        case tooLarge
        case invalidContentType
        case other(status: Int, message: String)
    }

    public enum AuthFailure: Equatable, Sendable {
        /// Wrong or expired SMS code.
        case invalidOTP
        case rateLimited
        case smsSendFailed
        case invalidPhone
        case sessionExpired
        case signupDisabled
        case other(code: String)
    }

    /// The API error code, when this is one.
    public var apiCode: APIErrorCode? {
        if case let .api(code, _) = self { return code }
        return nil
    }

    /// Worth retrying later without changing anything (offline, server hiccup, rate limit).
    public var isTransient: Bool {
        switch self {
        case .offline: return true
        case let .http(status): return status == 408 || status == 429 || status >= 500
        case let .storage(.other(status, _)): return status == 408 || status == 429 || status >= 500
        case .auth(.rateLimited): return true
        default: return false
        }
    }
}

extension DataError {
    /// Maps any error thrown by supabase-swift, URLSession or decoding into `DataError`.
    public static func from(_ error: Error) -> DataError {
        if let error = error as? DataError { return error }
        if let error = error as? PostgrestError { return from(postgrest: error) }
        if let error = error as? StorageError { return from(storage: error) }
        if let error = error as? AuthError { return from(auth: error) }
        if let error = error as? URLError { return from(urlError: error) }
        if let error = error as? HTTPError {
            if let decoded = try? JSONDecoder().decode(PostgrestError.self, from: error.data) {
                return from(postgrest: decoded)
            }
            return .http(status: error.response.statusCode)
        }
        if error is DecodingError { return .decoding(String(describing: error)) }
        if error is CancellationError { return .offline }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain { return .offline }
        return .decoding(String(describing: error))
    }

    static func from(postgrest error: PostgrestError) -> DataError {
        if let code = APIErrorCode(rawValue: error.message) {
            return .api(code, details: error.details)
        }
        // Signed out (anon role): RPCs are granted to `authenticated` only, so PostgREST refuses
        // before the function's own `not_authenticated` check runs.
        if error.code == "42501", error.message.hasPrefix("permission denied for function") {
            return .api(.notAuthenticated, details: error.message)
        }
        return .database(code: error.code ?? "", message: error.message)
    }

    static func from(storage error: StorageError) -> DataError {
        let status = Int(error.statusCode ?? "") ?? 0
        let text = (error.error ?? "") + " " + error.message
        return .storage(storageFailure(status: status, text: text))
    }

    static func storageFailure(status: Int, text: String) -> StorageFailure {
        let lower = text.lowercased()
        if status == 409 || lower.contains("duplicate") || lower.contains("already exists") { return .alreadyExists }
        if status == 413 || lower.contains("payload too large") || lower.contains("maximum allowed size") { return .tooLarge }
        if status == 415 || lower.contains("mime type") || lower.contains("invalid_mime_type") { return .invalidContentType }
        if status == 404 || lower.contains("not found") { return .notFound }
        if status == 401 || status == 403 || lower.contains("row-level security") || lower.contains("unauthorized") {
            return .unauthorized
        }
        return .other(status: status, message: text.trimmingCharacters(in: .whitespaces))
    }

    static func from(auth error: AuthError) -> DataError {
        switch error {
        case .sessionMissing:
            return .notSignedIn
        default:
            break
        }
        let code = error.errorCode.rawValue
        switch code {
        case "otp_expired", "invalid_credentials", "bad_code_verifier": return .auth(.invalidOTP)
        case "over_request_rate_limit", "over_sms_send_rate_limit": return .auth(.rateLimited)
        case "sms_send_failed": return .auth(.smsSendFailed)
        case "validation_failed": return .auth(.invalidPhone)
        case "session_not_found", "session_expired", "refresh_token_not_found", "refresh_token_already_used",
             "bad_jwt", "invalid_jwt":
            return .auth(.sessionExpired)
        case "signup_disabled", "phone_provider_disabled", "provider_disabled": return .auth(.signupDisabled)
        default:
            if case let .api(_, _, _, response) = error, response.statusCode == 429 { return .auth(.rateLimited) }
            return .auth(.other(code: code))
        }
    }

    static func from(urlError: URLError) -> DataError {
        switch urlError.code {
        case .cancelled: return .offline
        case .badServerResponse: return .http(status: 0)
        case .fileDoesNotExist, .noPermissionsToReadFile: return .localFile(urlError.localizedDescription)
        default: return .offline
        }
    }
}

/// Runs `body`, converting every thrown error into `DataError`.
@inline(__always)
func mapErrors<T>(_ body: () async throws -> T) async throws -> T {
    do {
        return try await body()
    } catch {
        throw DataError.from(error)
    }
}
