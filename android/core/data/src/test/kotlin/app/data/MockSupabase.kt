package app.data

import android.content.Context
import app.data.realtime.ReconnectPolicy
import io.github.jan.supabase.auth.MemorySessionManager
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.user.UserSession
import io.github.jan.supabase.logging.LogLevel
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.MockRequestHandleScope
import io.ktor.client.engine.mock.respond
import io.ktor.client.request.HttpRequestData
import io.ktor.client.request.HttpResponseData
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.content.OutgoingContent
import io.ktor.http.headersOf
import java.io.File
import java.util.Base64
import java.util.concurrent.CopyOnWriteArrayList

/** A request the mock server saw. */
data class SeenRequest(val method: String, val path: String, val query: String, val body: String)

/**
 * A [DataGraph] whose HTTP goes to a Ktor MockEngine: unit tests of the data layer without a
 * server. [route] answers each request (default: 404).
 */
class MockSupabase(context: Context, root: File, route: MockRequestHandleScope.(HttpRequestData, SeenRequest) -> HttpResponseData) {
    val requests = CopyOnWriteArrayList<SeenRequest>()

    val engine = MockEngine { request ->
        val body = when (val content = request.body) {
            is OutgoingContent.ByteArrayContent -> String(content.bytes())
            else -> ""
        }
        val seen = SeenRequest(request.method.value, request.url.encodedPath, request.url.encodedQuery, body)
        requests += seen
        route(request, seen)
    }

    val graph = DataGraph(
        context,
        SupabaseConfig("https://project.example", "anon-key"),
        DataOptions(
            client = ClientOptions(sessionManager = MemorySessionManager(), lifecycleCallbacks = false, autoRefresh = false, logLevel = LogLevel.NONE, readRetries = 0, engine = engine),
            cacheDir = File(root, "offline"),
            uploadsDir = File(root, "uploads"),
            reconnect = ReconnectPolicy(),
        ),
    )

    /** Signs [userId] in locally (a token whose `sub` is that id; the mock server accepts anything). */
    suspend fun signIn(userId: String) {
        graph.awaitSessionLoaded()
        graph.client.auth.importSession(UserSession(accessToken = jwt(userId), refreshToken = "refresh", expiresIn = 3600, tokenType = "bearer"), autoRefresh = false)
    }

    companion object {
        fun jwt(sub: String): String {
            val enc = Base64.getUrlEncoder().withoutPadding()
            val header = enc.encodeToString("""{"alg":"HS256","typ":"JWT"}""".toByteArray())
            val payload = enc.encodeToString("""{"sub":"$sub","role":"authenticated","exp":4102444800}""".toByteArray())
            return "$header.$payload.c2lnbmF0dXJl"
        }

        val JSON = headersOf(HttpHeaders.ContentType, "application/json")
    }
}

fun MockRequestHandleScope.json(body: String, status: HttpStatusCode = HttpStatusCode.OK): HttpResponseData = respond(body, status, MockSupabase.JSON)

fun MockRequestHandleScope.noContent(): HttpResponseData = respond("", HttpStatusCode.NoContent)
