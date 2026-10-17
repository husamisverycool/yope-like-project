package app.data.integration

import android.content.Context
import app.data.ClientOptions
import app.data.DataGraph
import app.data.DataOptions
import app.data.SupabaseConfig
import app.data.auth.AesGcmSessionCipher
import app.data.auth.EncryptedSessionManager
import app.data.realtime.ReconnectPolicy
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.providers.builtin.Phone
import io.github.jan.supabase.logging.LogLevel
import io.ktor.client.HttpClient
import io.ktor.client.engine.okhttp.OkHttp
import io.ktor.client.request.header
import io.ktor.client.request.request
import io.ktor.client.request.setBody
import io.ktor.client.statement.bodyAsText
import io.ktor.http.ContentType
import io.ktor.http.HttpMethod
import io.ktor.http.contentType
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonObject
import org.junit.Assume
import java.io.File
import java.net.HttpURLConnection
import java.net.URI
import java.security.SecureRandom
import java.util.Base64
import javax.crypto.KeyGenerator
import kotlin.time.Duration.Companion.seconds

/**
 * The local Supabase stack (`cd backend && npm run db:start`), as backend/tests use it: the CLI's
 * local URL and demo keys unless overridden (`-PsupabaseTestUrl` … or SUPABASE_URL …).
 * Integration tests call [assumeReachable] first: without the stack they are skipped, with the
 * reason printed. CI starts the stack and sets ANDROID_INTEGRATION_REQUIRED=1 (job `android`): there an unreachable
 * stack fails them instead, so they can never pass by not running.
 */
object LocalStack {
    val url: String = (System.getProperty("supabase.test.url") ?: System.getenv("SUPABASE_URL") ?: "http://127.0.0.1:54321").trimEnd('/')
    val anonKey: String = System.getProperty("supabase.test.anonKey") ?: System.getenv("SUPABASE_ANON_KEY") ?: DEMO_ANON_KEY
    val serviceKey: String = System.getProperty("supabase.test.serviceKey") ?: System.getenv("SUPABASE_SERVICE_ROLE_KEY") ?: DEMO_SERVICE_KEY

    val config: SupabaseConfig get() = SupabaseConfig(url, anonKey)

    /** Null when reachable; otherwise why not. */
    val unreachableReason: String? by lazy { probe() }

    /** ANDROID_INTEGRATION_REQUIRED=1: the integration tests must run (CI). */
    val required: Boolean = System.getenv("ANDROID_INTEGRATION_REQUIRED") == "1"

    fun assumeReachable() {
        val reason = unreachableReason ?: return
        if (required) throw AssertionError("ANDROID_INTEGRATION_REQUIRED=1 but the local Supabase stack is not reachable at $url: $reason")
        val message = "SKIPPED (local Supabase stack not reachable at $url: $reason). Start it with `cd backend && npm run db:start`."
        println(message)
        Assume.assumeTrue(message, false)
    }

    private fun probe(): String? = try {
        val health = get("$url/auth/v1/health")
        val rest = get("$url/rest/v1/public_app_config?select=key&limit=1")
        when {
            health != 200 -> "auth health HTTP $health"
            rest != 200 -> "PostgREST HTTP $rest"
            else -> null
        }
    } catch (e: Exception) {
        "${e::class.simpleName}: ${e.message}"
    }

    private fun get(target: String): Int {
        val connection = URI(target).toURL().openConnection() as HttpURLConnection
        connection.connectTimeout = 2_000
        connection.readTimeout = 3_000
        connection.setRequestProperty("apikey", anonKey)
        return try {
            connection.responseCode
        } finally {
            connection.disconnect()
        }
    }

    // Supabase CLI local-development defaults (same as backend/tests/helpers.ts).
    private const val DEMO_ANON_KEY =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"
    private const val DEMO_SERVICE_KEY =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU"
}

/** A test account: confirmed phone user created with the admin API, with a password for sign-in. */
data class TestAccount(val id: String, val phone: String, val password: String, val name: String)

/**
 * Service-role HTTP (like backend/tests' `admin` client): creating / deleting auth users and
 * writing rows only the worker writes (recaps, collages, tributes …). Never used by app code.
 */
class Admin : AutoCloseable {
    private val http = HttpClient(OkHttp)
    private val json = Json { ignoreUnknownKeys = true }
    private val random = SecureRandom()
    val created = mutableListOf<TestAccount>()

    suspend fun call(method: HttpMethod, path: String, body: JsonElement? = null, prefer: String? = null): Pair<Int, String> {
        val response = http.request("${LocalStack.url}$path") {
            this.method = method
            header("apikey", LocalStack.serviceKey)
            header("Authorization", "Bearer ${LocalStack.serviceKey}")
            prefer?.let { header("Prefer", it) }
            if (body != null) {
                contentType(ContentType.Application.Json)
                setBody(body.toString())
            }
        }
        return response.status.value to response.bodyAsText()
    }

    private suspend fun ok(method: HttpMethod, path: String, body: JsonElement? = null, prefer: String? = null): String {
        val (status, text) = call(method, path, body, prefer)
        check(status in 200..299) { "$method $path → HTTP $status: $text" }
        return text
    }

    /** `+1555…` test numbers, unique per run (backend/tests use the same range). */
    suspend fun createUser(name: String): TestAccount {
        val phone = "1555" + (10_000_000 + random.nextInt(89_999_999)).toString()
        val password = "it-" + Base64.getUrlEncoder().withoutPadding().encodeToString(ByteArray(12).also(random::nextBytes))
        val body = buildJsonObject {
            put("phone", phone)
            put("password", password)
            put("phone_confirm", true)
            putJsonObject("user_metadata") { put("display_name", name) }
        }
        val text = ok(HttpMethod.Post, "/auth/v1/admin/users", body)
        val id = json.parseToJsonElement(text).jsonObject["id"]!!.jsonPrimitive.content
        // Past the age gate: create_group / join_group / create_post require it (backend migration 0055).
        update("profile_private", "user_id=eq.$id", buildJsonObject { put("age_confirmed_at", java.time.Instant.now().toString()) })
        return TestAccount(id, "+$phone", password, name).also { created += it }
    }

    suspend fun deleteUser(id: String) {
        call(HttpMethod.Delete, "/auth/v1/admin/users/$id")
    }

    suspend fun insert(table: String, row: JsonObject): JsonObject =
        (json.parseToJsonElement(ok(HttpMethod.Post, "/rest/v1/$table", JsonArray(listOf(row)), "return=representation")) as JsonArray).first().jsonObject

    suspend fun upsert(table: String, row: JsonObject, onConflict: String): JsonObject =
        (json.parseToJsonElement(ok(HttpMethod.Post, "/rest/v1/$table?on_conflict=$onConflict", JsonArray(listOf(row)), "return=representation,resolution=merge-duplicates")) as JsonArray).first().jsonObject

    suspend fun update(table: String, filter: String, values: JsonObject): JsonArray =
        json.parseToJsonElement(ok(HttpMethod.Patch, "/rest/v1/$table?$filter", values, "return=representation")) as JsonArray

    suspend fun select(table: String, query: String): JsonArray =
        json.parseToJsonElement(ok(HttpMethod.Get, "/rest/v1/$table?$query")) as JsonArray

    suspend fun delete(table: String, filter: String) {
        call(HttpMethod.Delete, "/rest/v1/$table?$filter")
    }

    /**
     * PostgREST's OpenAPI description (tables, columns, enums, RPC parameters). It follows the
     * privileges of the caller: the service role sees everything, [bearer] = a user's access
     * token shows exactly what a signed-in client may call.
     */
    suspend fun openApi(bearer: String = LocalStack.serviceKey, apiKey: String = LocalStack.serviceKey): JsonObject {
        val response = http.request("${LocalStack.url}/rest/v1/") {
            method = HttpMethod.Get
            header("apikey", apiKey)
            header("Authorization", "Bearer $bearer")
            header("Accept", "application/openapi+json")
        }
        return json.parseToJsonElement(response.bodyAsText()).jsonObject
    }

    /** A user's access token (GoTrue password grant). */
    suspend fun accessToken(account: TestAccount): String {
        val response = http.request("${LocalStack.url}/auth/v1/token?grant_type=password") {
            method = HttpMethod.Post
            header("apikey", LocalStack.anonKey)
            contentType(ContentType.Application.Json)
            setBody(buildJsonObject { put("phone", account.phone); put("password", account.password) }.toString())
        }
        return json.parseToJsonElement(response.bodyAsText()).jsonObject["access_token"]!!.jsonPrimitive.content
    }

    override fun close() = http.close()
}

/** Builds data graphs against the local stack, each with its own session file and cache. */
class Graphs(private val context: Context, private val root: File) : AutoCloseable {
    private val open = mutableListOf<DataGraph>()
    private val key = KeyGenerator.getInstance("AES").apply { init(256) }.generateKey()

    /** A software AES key stands in for the Android Keystore (absent under Robolectric). */
    val cipher = AesGcmSessionCipher { key }

    fun create(name: String, policy: ReconnectPolicy = ReconnectPolicy()): DataGraph {
        val dir = File(root, name).apply { mkdirs() }
        val options = DataOptions(
            client = ClientOptions(
                sessionManager = EncryptedSessionManager(File(dir, "session.bin"), cipher),
                lifecycleCallbacks = false,
                logLevel = LogLevel.NONE,
                realtimeReconnectDelay = 1.seconds,
            ),
            cacheDir = File(dir, "offline"),
            uploadsDir = File(dir, "uploads"),
            reconnect = policy,
        )
        return DataGraph(context, LocalStack.config, options).also { open += it }
    }

    /** Signs [account] in with phone + password (OTP needs Twilio; the session is the same kind). */
    suspend fun signIn(account: TestAccount, name: String = account.name.substringBefore(' ') + "-" + account.id.take(8), policy: ReconnectPolicy = ReconnectPolicy()): DataGraph {
        val graph = create(name, policy)
        graph.awaitSessionLoaded()
        graph.client.auth.signInWith(Phone) {
            phone = account.phone
            password = account.password
        }
        graph.auth.awaitSignedIn()
        return graph
    }

    override fun close() = runBlocking {
        open.forEach { runCatching { it.close() } }
    }
}

/** The 1x1 JPEG backend/tests upload (`TINY_JPEG`). */
val TINY_JPEG: ByteArray = Base64.getDecoder().decode(
    "/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////wAALCAABAAEBAREA/8QAFAABAAAAAAAAAAAAAAAAAAAAA//EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AN//Z",
)

fun tinyJpegFile(dir: File, name: String, padTo: Int = 0): File = File(dir, name).apply {
    parentFile?.mkdirs()
    writeBytes(if (padTo > TINY_JPEG.size) TINY_JPEG + ByteArray(padTo - TINY_JPEG.size) else TINY_JPEG)
}

fun uniqueTag(): String = java.lang.Long.toString(System.nanoTime() % 1_000_000_000L, 36) + (1000 + SecureRandom().nextInt(8999))
