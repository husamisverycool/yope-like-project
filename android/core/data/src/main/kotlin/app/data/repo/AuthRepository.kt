package app.data.repo

import app.data.error.AuthFailure
import app.data.error.DataError
import app.data.error.DataException
import app.data.error.dataCall
import app.data.remote.Api
import io.github.jan.supabase.auth.OtpType
import io.github.jan.supabase.auth.SignOutScope
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.providers.builtin.OTP
import io.github.jan.supabase.auth.status.SessionStatus
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.withTimeoutOrNull
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import java.util.concurrent.CopyOnWriteArrayList
import kotlin.time.Duration.Companion.seconds

/** Who is signed in on this device. */
sealed interface AuthState {
    /** The stored session is being loaded / refreshed. */
    data object Initializing : AuthState
    data object SignedOut : AuthState
    data class SignedIn(val userId: String) : AuthState
}

/**
 * Phone OTP sign-in (docs/API.md §2; Twilio Verify on the server), session state and sign-out.
 * The session is persisted by the client's SessionManager (encrypted on device) and refreshed
 * automatically.
 */
class AuthRepository(private val api: Api, scope: CoroutineScope) {
    private val auth get() = api.client.auth
    @Volatile private var lastUserId: String? = null
    private val signOutHooks = CopyOnWriteArrayList<suspend () -> Unit>()

    val authState: StateFlow<AuthState> = auth.sessionStatus
        .map(::toState)
        .stateIn(scope, SharingStarted.Eagerly, toState(auth.sessionStatus.value))

    val currentUserId: String? get() = api.currentUserId

    /**
     * Sends the code by SMS. [displayName] is stored as `user_metadata.display_name`, which becomes
     * `profiles.display_name` when the account is created (§2). Creates the account if needed.
     */
    suspend fun requestOtp(phone: String, displayName: String? = null) {
        val e164 = normalizePhone(phone)
        dataCall {
            auth.signInWith(OTP) {
                this.phone = e164
                createUser = true
                if (displayName != null) data = buildJsonObject { put("display_name", displayName) }
            }
        }
    }

    /** Sends the SMS again (GoTrue rate limits apply: [AuthFailure.RateLimited]). */
    suspend fun resendOtp(phone: String) {
        val e164 = normalizePhone(phone)
        dataCall { auth.resendPhone(OtpType.Phone.SMS, e164) }
    }

    /** Verifies the SMS code; on success the session is stored and [authState] turns [AuthState.SignedIn]. */
    suspend fun verifyOtp(phone: String, code: String): String {
        val e164 = normalizePhone(phone)
        val token = code.trim()
        if (!CODE.matches(token)) throw DataException(DataError.Auth(AuthFailure.InvalidOrExpiredCode, null))
        dataCall { auth.verifyPhoneOtp(type = OtpType.Phone.SMS, phone = e164, token = token) }
        return awaitSignedIn()
    }

    /** Waits until a session is active (e.g. after a sign-in done elsewhere on [api]'s client). */
    suspend fun awaitSignedIn(): String {
        val state = withTimeoutOrNull(SIGN_IN_WAIT) { authState.first { it is AuthState.SignedIn } }
        return (state as? AuthState.SignedIn)?.userId ?: throw DataException(DataError.NotSignedIn)
    }

    /** Runs before the session is dropped (e.g. `unregister_device`, docs/API.md §2). */
    fun addSignOutHook(hook: suspend () -> Unit) {
        signOutHooks += hook
    }

    /**
     * Signs out: runs the hooks (best effort, bounded), revokes the session on the server, and
     * always clears it locally, even offline.
     */
    suspend fun signOut() {
        for (hook in signOutHooks) {
            try {
                withTimeoutOrNull(HOOK_TIMEOUT) { hook() }
            } catch (e: CancellationException) {
                throw e
            } catch (_: Exception) {
            }
        }
        try {
            auth.signOut(SignOutScope.LOCAL)
        } catch (e: CancellationException) {
            throw e
        } catch (_: Exception) {
            auth.clearSession()
        }
    }

    /** After `delete_account`: the session no longer works; drop it without calling the server. */
    suspend fun clearLocalSession() {
        auth.clearSession()
    }

    private fun toState(status: SessionStatus): AuthState = when (status) {
        is SessionStatus.Authenticated -> {
            val id = status.session.user?.id ?: Api.jwtSubject(status.session.accessToken)
            if (id == null) AuthState.Initializing else AuthState.SignedIn(id).also { lastUserId = id }
        }
        is SessionStatus.NotAuthenticated -> AuthState.SignedOut.also { lastUserId = null }
        // A refresh failed for network reasons: the session is still there; keep the person signed in.
        is SessionStatus.RefreshFailure -> lastUserId?.let(AuthState::SignedIn) ?: AuthState.Initializing
        SessionStatus.Initializing -> AuthState.Initializing
    }

    companion object {
        private val E164 = Regex("^\\+[1-9][0-9]{6,14}$")
        private val CODE = Regex("^[0-9A-Za-z]{4,10}$")
        private val SIGN_IN_WAIT = 10.seconds
        private val HOOK_TIMEOUT = 5.seconds

        /** `+` and 7–15 digits; spaces, dashes, dots and parentheses are dropped. */
        fun normalizePhone(phone: String): String {
            val compact = phone.trim().filterNot { it == ' ' || it == '-' || it == '.' || it == '(' || it == ')' }
            if (!E164.matches(compact)) throw DataException(DataError.Auth(AuthFailure.InvalidPhone, null))
            return compact
        }
    }
}
