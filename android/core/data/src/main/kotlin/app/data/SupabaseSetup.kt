package app.data

import app.data.auth.EncryptedSessionManager
import app.data.model.DataJson
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.annotations.SupabaseInternal
import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.auth.FlowType
import io.github.jan.supabase.auth.MemoryCodeVerifierCache
import io.github.jan.supabase.auth.SessionManager
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.logging.LogLevel
import io.github.jan.supabase.postgrest.Postgrest
import io.github.jan.supabase.realtime.Realtime
import io.github.jan.supabase.serializer.KotlinXSerializer
import io.github.jan.supabase.storage.Storage
import io.ktor.client.engine.HttpClientEngine
import io.ktor.client.engine.okhttp.OkHttp
import kotlin.time.Duration
import kotlin.time.Duration.Companion.seconds

/** Supabase project URL + anon (publishable) key. The service role key never ships in the app. */
data class SupabaseConfig(val url: String, val anonKey: String) {
    init {
        require(url.startsWith("https://") || url.startsWith("http://")) { "Supabase URL must be http(s)" }
        require(anonKey.isNotBlank()) { "anon key is blank" }
    }

    companion object {
        /** From `config/app.json` via BuildConfig; null while the owner has not set them. */
        fun fromBuildConfig(): SupabaseConfig? {
            val url = BuildConfig.SUPABASE_URL?.takeIf { it.isNotBlank() } ?: return null
            val key = BuildConfig.SUPABASE_ANON_KEY?.takeIf { it.isNotBlank() } ?: return null
            return SupabaseConfig(url.trimEnd('/'), key)
        }
    }
}

/** Client knobs; the defaults are the app's, tests override a few. */
data class ClientOptions(
    /** Where the session is kept. The app uses [EncryptedSessionManager]. */
    val sessionManager: SessionManager,
    /** Stop / resume token refresh with the process lifecycle (Android `ProcessLifecycleOwner`). */
    val lifecycleCallbacks: Boolean = true,
    val autoRefresh: Boolean = true,
    val requestTimeout: Duration = 30.seconds,
    /** Realtime: delay before reconnecting the socket and rejoining channels. */
    val realtimeReconnectDelay: Duration = 3.seconds,
    val logLevel: LogLevel = LogLevel.WARNING,
    /** Replaces the OkHttp engine (unit tests use Ktor's MockEngine). */
    val engine: HttpClientEngine? = null,
)

object SupabaseSetup {

    @OptIn(SupabaseInternal::class)
    fun createClient(config: SupabaseConfig, options: ClientOptions): SupabaseClient =
        createSupabaseClient(config.url, config.anonKey) {
            httpEngine = options.engine ?: OkHttp.create()
            defaultSerializer = KotlinXSerializer(DataJson)
            defaultLogLevel = options.logLevel
            requestTimeout = options.requestTimeout
            install(Auth) {
                sessionManager = options.sessionManager
                // Phone OTP does not use PKCE; an in-memory cache keeps multiplatform-settings out.
                codeVerifierCache = MemoryCodeVerifierCache()
                flowType = FlowType.IMPLICIT
                alwaysAutoRefresh = options.autoRefresh
                autoLoadFromStorage = true
                autoSaveToStorage = true
                enableLifecycleCallbacks = options.lifecycleCallbacks
            }
            install(Postgrest)
            install(Storage)
            install(Realtime) {
                reconnectDelay = options.realtimeReconnectDelay
                rejoinDelay = 2.seconds
                maxAttempts = 5
            }
        }
}
