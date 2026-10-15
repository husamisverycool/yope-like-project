package app.data.error

import io.github.jan.supabase.auth.exception.AuthErrorCode
import io.github.jan.supabase.auth.exception.AuthRestException
import io.github.jan.supabase.auth.exception.AuthSessionMissingException
import io.github.jan.supabase.auth.exception.SessionRequiredException
import io.github.jan.supabase.exceptions.HttpRequestException
import io.github.jan.supabase.exceptions.NotFoundRestException
import io.github.jan.supabase.exceptions.RestException
import io.github.jan.supabase.postgrest.exception.PostgrestRestException
import kotlinx.coroutines.CancellationException
import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonPrimitive
import java.io.IOException

/** Turns whatever supabase-kt / Ktor throws into a [DataError]. */
object ErrorMapping {

    fun map(t: Throwable): DataError = when (t) {
        is DataException -> t.error
        is SessionRequiredException, is AuthSessionMissingException -> DataError.NotSignedIn
        is PostgrestRestException -> postgrest(t)
        is AuthRestException -> auth(t)
        is RestException -> if (t.isStorage()) storage(t) else rest(t)
        is HttpRequestException -> DataError.Network
        is IOException -> DataError.Network // includes Ktor's HttpRequestTimeoutException
        is SerializationException -> DataError.Unexpected("decode: ${t.message}")
        else -> if (t.isNetworkLike()) DataError.Network else DataError.Unexpected(t::class.simpleName + ": " + t.message)
    }

    /** Maps and wraps; cancellation always propagates unchanged. */
    fun wrap(t: Throwable): Throwable = if (t is CancellationException || t is DataException) t else DataException(map(t), t)

    internal fun postgrest(e: PostgrestRestException): DataError {
        val code = e.code
        val status = e.statusCode
        val details = when (val d = e.details) {
            null, JsonNull -> null
            is JsonPrimitive -> d.content
            else -> d.toString()
        }
        return when {
            code != null && code.startsWith("PT") -> DataError.Api(ApiError.fromWire(e.error), e.error, status, details)
            code == "PGRST301" || code == "PGRST302" || code == "PGRST303" -> DataError.Auth(AuthFailure.SessionExpired, code)
            code == "42501" -> DataError.Database(DbFailure.PermissionDenied, code, status)
            code == "23514" -> DataError.Database(DbFailure.CheckViolation, code, status)
            code == "23505" -> DataError.Database(DbFailure.UniqueViolation, code, status)
            code == "22P02" || code == "22007" || code == "22008" || code == "22023" -> DataError.Database(DbFailure.InvalidInput, code, status)
            code != null && code.startsWith("PGRST") -> DataError.Database(DbFailure.Request, code, status)
            // Gateway / PostgREST unavailable (no error code of ours): transient, like a network failure.
            status >= 500 -> DataError.Network
            else -> DataError.Database(DbFailure.Other, code, status)
        }
    }

    internal fun auth(e: AuthRestException): DataError {
        val kind = when (e.errorCode) {
            AuthErrorCode.OtpExpired, AuthErrorCode.OtpDisabled -> AuthFailure.InvalidOrExpiredCode
            AuthErrorCode.SmsSendFailed -> AuthFailure.SmsSendFailed
            AuthErrorCode.OverSmsSendRateLimit, AuthErrorCode.OverRequestRateLimit -> AuthFailure.RateLimited
            AuthErrorCode.PhoneProviderDisabled -> AuthFailure.PhoneSignInDisabled
            AuthErrorCode.SignupDisabled -> AuthFailure.SignupDisabled
            AuthErrorCode.SessionNotFound, AuthErrorCode.RefreshTokenNotFound, AuthErrorCode.RefreshTokenAlreadyUsed,
            AuthErrorCode.BadJwt, AuthErrorCode.SessionExpired, AuthErrorCode.UserNotFound -> AuthFailure.SessionExpired
            AuthErrorCode.InvalidCredentials -> AuthFailure.InvalidCredentials
            AuthErrorCode.ValidationFailed, AuthErrorCode.PhoneExists -> AuthFailure.InvalidPhone
            else -> AuthFailure.Other
        }
        return DataError.Auth(kind, e.error)
    }

    /**
     * Storage answers HTTP 400 with the real status in the body
     * (`{"statusCode":"409","error":"Duplicate",…,"code":"KeyAlreadyExists"}`); storage-kt keeps only
     * part of that body, so classification reads what is left (never shown to anyone).
     */
    internal fun storage(e: RestException): DataError {
        val text = listOfNotNull(e.error, e.description).joinToString(" ").lowercase()
        val kind = when {
            e is NotFoundRestException || "not_found" in text || "object not found" in text || "nosuchkey" in text -> StorageFailure.NotFound
            "already exists" in text || "duplicate" in text || "keyalreadyexists" in text -> StorageFailure.AlreadyExists
            "row-level security" in text || "unauthorized" in text || "accessdenied" in text || e.statusCode == 403 -> StorageFailure.Forbidden
            "mime type" in text || "invalid_mime_type" in text -> StorageFailure.UnsupportedType
            "too large" in text || "maximum allowed size" in text || "entitytoolarge" in text || e.statusCode == 413 -> StorageFailure.TooLarge
            else -> StorageFailure.Other
        }
        return DataError.Storage(kind, e.statusCode, e.error)
    }

    private fun rest(e: RestException): DataError = when (e.statusCode) {
        401 -> DataError.Auth(AuthFailure.SessionExpired, e.error)
        in 500..599 -> DataError.Network
        else -> DataError.Unexpected("HTTP ${e.statusCode}: ${e.error}")
    }

    private fun RestException.isStorage(): Boolean = response.call.request.url.encodedPath.contains("/storage/v1/")

    private fun Throwable.isNetworkLike(): Boolean {
        var cause: Throwable? = this
        while (cause != null) {
            if (cause is IOException || cause is HttpRequestException) return true
            val name = cause::class.qualifiedName.orEmpty()
            if (name.endsWith("TimeoutException") || name.endsWith("UnresolvedAddressException") || name.endsWith("ClosedReceiveChannelException")) return true
            cause = cause.cause
        }
        return false
    }
}

/** Runs [block], rethrowing every failure as a [DataException] (cancellation passes through). */
suspend inline fun <T> dataCall(block: () -> T): T = try {
    block()
} catch (t: Throwable) {
    throw ErrorMapping.wrap(t)
}
