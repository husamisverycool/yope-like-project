package app.data.error

/**
 * Every failure the data layer reports. Screens map these to string resources; no message text
 * from the server is ever shown (docs/API.md §3: "Display nothing from it to users").
 */
sealed interface DataError {
    /** A stable error code raised by our RPCs / triggers (docs/API.md §3). */
    data class Api(val code: ApiError, val raw: String, val httpStatus: Int?, val details: String?) : DataError

    /** A Postgres / PostgREST error that is not one of ours (permission, constraint, bad input, request). */
    data class Database(val kind: DbFailure, val sqlState: String?, val httpStatus: Int?) : DataError

    /** Supabase Auth (GoTrue): OTP request / verification, session refresh. */
    data class Auth(val kind: AuthFailure, val raw: String?) : DataError

    /** Supabase Storage (upload, signed URL). */
    data class Storage(val kind: StorageFailure, val httpStatus: Int?, val raw: String?) : DataError

    /** No network, timeout, DNS, TLS, connection reset. Retry later; render cached content. */
    data object Network : DataError

    /** The call needs a signed-in user and there is no session on this device. */
    data object NotSignedIn : DataError

    /** `config/app.json` has no Supabase URL / anon key yet. */
    data object NotConfigured : DataError

    /** A local file to upload is missing or unreadable. */
    data object FileUnavailable : DataError

    /** Anything else (a bug or an unexpected response). */
    data class Unexpected(val description: String?) : DataError
}

/** Thrown by every suspend function of the data layer; [error] is the typed reason. */
class DataException(val error: DataError, cause: Throwable? = null) : Exception(error.toString(), cause)

/** The error codes of docs/API.md §3 (the `message` of a PostgREST error body). */
enum class ApiError(val wire: String, val httpStatus: Int) {
    NotAuthenticated("not_authenticated", 401),
    NotGroupMember("not_group_member", 403),
    NotGroupAdmin("not_group_admin", 403),
    NotAlbumOwner("not_album_owner", 403),
    NotAllowed("not_allowed", 403),
    PostNotEligible("post_not_eligible", 403),
    UnderMinimumAge("under_minimum_age", 403),
    PremiumRequired("premium_required", 402),
    VideoTooLong("video_too_long", 400),
    PostNotFound("post_not_found", 404),
    MediaNotFound("media_not_found", 404),
    MessageNotFound("message_not_found", 404),
    MemberNotFound("member_not_found", 404),
    UserNotFound("user_not_found", 404),
    InviteNotFound("invite_not_found", 404),
    RecapNotFound("recap_not_found", 404),
    AlbumNotFound("album_not_found", 404),
    RequestNotFound("request_not_found", 404),
    TargetNotFound("target_not_found", 404),
    InviteRevoked("invite_revoked", 410),
    InviteExpired("invite_expired", 410),
    GroupFull("group_full", 409),
    AlreadyPosted("already_posted", 409),
    RecapNotReady("recap_not_ready", 409),
    MediaNotReady("media_not_ready", 409),
    /** Migration 0054: `set_member_role` would leave the group without an admin. */
    LastAdmin("last_admin", 409),
    EditWindowClosed("edit_window_closed", 409),
    TributeClosed("tribute_closed", 409),
    AgeGateNotConfigured("age_gate_not_configured", 503),
    InvalidName("invalid_name", 400),
    InvalidKind("invalid_kind", 400),
    InvalidTimeZone("invalid_time_zone", 400),
    InvalidWakingWindow("invalid_waking_window", 400),
    InvalidPath("invalid_path", 400),
    InvalidCaption("invalid_caption", 400),
    InvalidVoice("invalid_voice", 400),
    InvalidBody("invalid_body", 400),
    InvalidEmoji("invalid_emoji", 400),
    InvalidItems("invalid_items", 400),
    InvalidText("invalid_text", 400),
    InvalidLine("invalid_line", 400),
    InvalidReason("invalid_reason", 400),
    InvalidPlatform("invalid_platform", 400),
    InvalidToken("invalid_token", 400),
    InvalidQuietHours("invalid_quiet_hours", 400),
    InvalidBirthday("invalid_birthday", 400),
    InvalidBirthdate("invalid_birthdate", 400),
    ReplyGroupMismatch("reply_group_mismatch", 400),
    CannotTargetSelf("cannot_target_self", 400),
    NoGroups("no_groups", 400),
    InvalidArgument("invalid_argument", 400),

    /** A `PT…` error whose code this app version does not know. */
    Unknown("", 0),
    ;

    companion object {
        private val byWire = entries.filter { it != Unknown }.associateBy { it.wire }
        fun fromWire(code: String?): ApiError = code?.let(byWire::get) ?: Unknown
    }
}

enum class DbFailure {
    /** `42501`: no grant, or an RLS `WITH CHECK` failure. */
    PermissionDenied,
    /** `23514`: check constraint (e.g. a path outside your folder). */
    CheckViolation,
    /** `23505`: unique violation. */
    UniqueViolation,
    /** `22P02` / `22007` / `22008`: invalid input (bad uuid / enum / date). */
    InvalidInput,
    /** `PGRST…`: a malformed request (unknown column, function, filter). */
    Request,
    Other,
}

enum class AuthFailure {
    /** The phone number is not E.164 (`+` and 7–15 digits) or GoTrue rejected it. */
    InvalidPhone,
    /** Wrong code, or the code expired (GoTrue reports both as `otp_expired`). */
    InvalidOrExpiredCode,
    /** The SMS provider (Twilio Verify) refused or is not configured. */
    SmsSendFailed,
    /** Too many OTP requests / verifications; wait and retry. */
    RateLimited,
    /** Phone sign-in is disabled on the project. */
    PhoneSignInDisabled,
    /** Sign-ups are disabled. */
    SignupDisabled,
    /** The refresh token / session is no longer valid: sign in again. */
    SessionExpired,
    InvalidCredentials,
    Other,
}

enum class StorageFailure {
    /** The object exists already (uploads never overwrite, docs/API.md §7). */
    AlreadyExists,
    /** Storage RLS refused (path outside `u/<uid>/` / `avatars/<uid>/`, or not readable). */
    Forbidden,
    /** The object does not exist or you cannot read it. */
    NotFound,
    /** Over the bucket's 100 MiB limit. */
    TooLarge,
    /** Content type not allowed by the bucket. */
    UnsupportedType,
    Other,
}
