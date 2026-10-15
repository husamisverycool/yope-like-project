// Account group — sign-in failures of auth.phone / auth.code (and the App Clip join flow) and their copy.
import AppData
import DesignSystem
import Foundation

/// A failed `signInWithOTP` / `verifyOTP`, as the auth specs' States tables name them.
enum AuthFailure: Equatable {
    /// auth.phone "invalid number": not E.164, or Supabase rejected it.
    case invalidNumber
    /// auth.phone "rate limited": a second request within 60 s or the provider's limit.
    case rateLimited
    /// auth.phone "send failed": 5xx / provider error.
    case sendFailed
    /// auth.code "wrong code".
    case wrongCode
    /// auth.code "expired": the code is older than its lifetime.
    case expired
    /// auth.code "too many tries" (HTTP 429).
    case tooManyTries

    /// The state's copy. Its presentation (`auth.phone.layout.inlineError`) is BLOCKED: screens do not draw it; it is
    /// posted as a VoiceOver announcement and kept for tests.
    var message: String {
        switch self {
        case .invalidNumber: return Copy.authPhoneErrorInvalidNumber
        case .rateLimited: return Copy.authPhoneErrorRateLimited
        case .sendFailed: return Copy.authPhoneErrorSendFailed
        case .wrongCode: return Copy.authCodeErrorWrong
        case .expired: return Copy.authCodeErrorExpired
        case .tooManyTries: return Copy.authCodeErrorTooMany
        }
    }

    /// An SMS code expires after one hour (Supabase phone auth default, docs/PLATFORM_CONSTRAINTS.md §7). AppData
    /// reports wrong and expired codes alike (`otp_expired` → `invalidOTP`), so the age of the code decides.
    static let codeLifetime: TimeInterval = 3600

    /// Maps a `signInWithOTP` error; nil for `.offline` (the screen shows its offline state instead).
    static func sending(_ error: Error) -> AuthFailure? {
        switch DataError.from(error) {
        case .offline: return nil
        case .auth(.invalidPhone): return .invalidNumber
        case .auth(.rateLimited), .http(status: 429): return .rateLimited
        default: return .sendFailed
        }
    }

    /// Maps a `verifyOTP` error; nil for `.offline`. `codeAge` = seconds since the code was requested.
    static func verifying(_ error: Error, codeAge: TimeInterval) -> AuthFailure? {
        switch DataError.from(error) {
        case .offline: return nil
        case .auth(.rateLimited), .http(status: 429): return .tooManyTries
        case .auth(.invalidOTP): return codeAge >= codeLifetime ? .expired : .wrongCode
        default: return .wrongCode
        }
    }
}
