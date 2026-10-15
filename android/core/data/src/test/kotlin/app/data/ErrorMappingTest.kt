package app.data

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.data.error.ApiError
import app.data.error.AuthFailure
import app.data.error.DataError
import app.data.error.DataErrorCodec
import app.data.error.DataException
import app.data.error.DbFailure
import app.data.error.StorageFailure
import app.data.integration.expectDataError
import io.ktor.http.HttpStatusCode
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import java.io.File
import java.io.IOException
import kotlin.time.Duration.Companion.seconds

/**
 * Error bodies (copied from the live local stack) → typed [DataError]. Also checks that
 * [ApiError] lists exactly the codes of docs/API.md §3 with their HTTP statuses.
 */
@RunWith(AndroidJUnit4::class)
class ErrorMappingTest {
    @get:Rule val tmp = TemporaryFolder()

    private val context: Context = ApplicationProvider.getApplicationContext()
    private var status = HttpStatusCode.OK
    private var body = "{}"
    private var failWith: Throwable? = null
    private lateinit var mock: MockSupabase

    @Before fun setUp() {
        mock = MockSupabase(context, tmp.root) { _, _ ->
            failWith?.let { throw it }
            json(body, status)
        }
    }

    @After fun tearDown() = runBlocking { mock.graph.close() }

    private fun answer(code: Int, text: String) {
        status = HttpStatusCode.fromValue(code)
        body = text
    }

    @Test fun everyRpcErrorCodeMapsToItsTypedCode() = runBlocking {
        for (code in ApiError.entries - ApiError.Unknown) {
            answer(code.httpStatus, """{"code":"PT${code.httpStatus}","details":"ctx","hint":null,"message":"${code.wire}"}""")
            val error = expectDataError { mock.graph.groups.invitePreview("token") }
            assertEquals(DataError.Api(code, code.wire, code.httpStatus, "ctx"), error)
            assertEquals(error, DataErrorCodec.decode(DataErrorCodec.encode(error))!!.let { (it as DataError.Api).copy(details = "ctx") })
        }
        answer(418, """{"code":"PT418","details":null,"hint":null,"message":"brand_new_code"}""")
        assertEquals(DataError.Api(ApiError.Unknown, "brand_new_code", 418, null), expectDataError { mock.graph.groups.invitePreview("t") })
    }

    @Test fun postgresAndPostgrestErrorsMapToDatabaseKinds() = runBlocking {
        val cases = mapOf(
            """{"code":"42501","details":null,"hint":"Grant…","message":"permission denied for table jobs"}""" to DbFailure.PermissionDenied,
            """{"code":"23505","details":null,"hint":null,"message":"duplicate key value violates unique constraint"}""" to DbFailure.UniqueViolation,
            """{"code":"23514","details":null,"hint":null,"message":"new row violates check constraint"}""" to DbFailure.CheckViolation,
            """{"code":"22P02","details":null,"hint":null,"message":"invalid input syntax for type uuid"}""" to DbFailure.InvalidInput,
            """{"code":"PGRST204","details":null,"hint":null,"message":"Could not find the column"}""" to DbFailure.Request,
        )
        for ((json, kind) in cases) {
            answer(400, json)
            val error = expectDataError { mock.graph.appConfig.publicConfig() }
            assertTrue("$error", error is DataError.Database && error.kind == kind)
        }
        answer(401, """{"code":"PGRST301","details":null,"hint":null,"message":"Expected 3 parts in JWT; got 1"}""")
        assertEquals(DataError.Auth(AuthFailure.SessionExpired, "PGRST301"), expectDataError { mock.graph.appConfig.publicConfig() })
    }

    @Test fun transportFailuresAreNetwork() = runBlocking {
        failWith = IOException("connection reset")
        assertEquals(DataError.Network, expectDataError { mock.graph.appConfig.publicConfig() })
        failWith = null
        answer(503, "upstream unavailable")
        val error = expectDataError { mock.graph.appConfig.publicConfig() }
        assertTrue("$error", error == DataError.Network || (error is DataError.Database && error.httpStatus == 503))
    }

    @Test fun authErrorsMapToFailures() = runBlocking {
        answer(403, """{"code":403,"error_code":"otp_expired","msg":"Token has expired or is invalid"}""")
        assertEquals(AuthFailure.InvalidOrExpiredCode, (expectDataError { mock.graph.auth.verifyOtp("+15550000000", "123456") } as DataError.Auth).kind)
        answer(422, """{"code":422,"error_code":"sms_send_failed","msg":"Error sending confirmation OTP to provider"}""")
        assertEquals(AuthFailure.SmsSendFailed, (expectDataError { mock.graph.auth.requestOtp("+15550000000") } as DataError.Auth).kind)
        answer(429, """{"code":429,"error_code":"over_sms_send_rate_limit","msg":"For security purposes…"}""")
        assertEquals(AuthFailure.RateLimited, (expectDataError { mock.graph.auth.requestOtp("+15550000000") } as DataError.Auth).kind)
        // Validated locally, nothing sent.
        val sent = mock.requests.size
        assertEquals(AuthFailure.InvalidPhone, (expectDataError { mock.graph.auth.requestOtp("555 1234") } as DataError.Auth).kind)
        assertEquals(AuthFailure.InvalidOrExpiredCode, (expectDataError { mock.graph.auth.verifyOtp("+15550000000", "12") } as DataError.Auth).kind)
        assertEquals(sent, mock.requests.size)
        assertEquals("+15551234567", app.data.repo.AuthRepository.normalizePhone(" +1 (555) 123-4567 "))
    }

    @Test fun signedInCallsWithoutASessionFailBeforeTheNetwork() = runBlocking {
        assertEquals(DataError.NotSignedIn, expectDataError { mock.graph.groups.createInvite("g") })
        assertEquals(DataError.NotSignedIn, expectDataError { mock.graph.profiles.me() })
        assertTrue(mock.requests.isEmpty())
    }

    @Test fun storageErrorsMapFromTheBodiesStorageReturns() = runBlocking {
        mock.signIn("11111111-1111-4111-8111-111111111111")
        val file = File(tmp.root, "x.jpg").apply { writeBytes(byteArrayOf(1, 2, 3)) }
        val cases = mapOf(
            """{"statusCode":"409","error":"Duplicate","message":"The resource already exists","code":"KeyAlreadyExists"}""" to StorageFailure.AlreadyExists,
            """{"statusCode":"403","error":"Unauthorized","message":"new row violates row-level security policy","code":"AccessDenied"}""" to StorageFailure.Forbidden,
            """{"statusCode":"415","error":"invalid_mime_type","message":"mime type text/plain is not supported","code":"InvalidMimeType"}""" to StorageFailure.UnsupportedType,
            """{"statusCode":"413","error":"Payload too large","message":"The object exceeded the maximum allowed size","code":"EntityTooLarge"}""" to StorageFailure.TooLarge,
            """{"statusCode":"404","error":"not_found","message":"Object not found","code":"NoSuchKey"}""" to StorageFailure.NotFound,
        )
        for ((json, kind) in cases) {
            answer(400, json)
            val error = expectDataError { mock.graph.storage.upload("u/11111111-1111-4111-8111-111111111111/m/original.jpg", file, "image/jpeg") { _, _ -> } }
            assertTrue("$json → $error", error is DataError.Storage && error.kind == kind)
        }
        assertEquals(DataError.FileUnavailable, expectDataError { mock.graph.storage.upload("u/a/b/original.jpg", File(tmp.root, "missing.jpg"), "image/jpeg") { _, _ -> } })
    }

    @Test fun batchSigningLeavesOutUnreadablePaths() = runBlocking {
        mock.signIn("11111111-1111-4111-8111-111111111111")
        val readable = "u/a/m/original.jpg"
        val hidden = "u/b/m/original.jpg"
        val m = MockSupabase(context, tmp.newFolder("sign")) { _, seen ->
            when {
                seen.path.endsWith("/object/sign/media") -> json("""[{"error":null,"path":"$readable","signedURL":"/object/sign/media/$readable?token=t"},{"error":"Either the object does not exist or you do not have access to it","path":"$hidden","signedURL":null}]""")
                seen.path.endsWith("/object/sign/media/$readable") -> json("""{"signedURL":"/object/sign/media/$readable?token=t1"}""")
                else -> json("""{"statusCode":"404","error":"not_found","message":"Object not found"}""", HttpStatusCode.BadRequest)
            }
        }
        m.signIn("11111111-1111-4111-8111-111111111111")
        val urls = m.graph.storage.sign(listOf(readable, hidden), 60.seconds)
        assertEquals(setOf(readable), urls.keys)
        assertTrue(urls.getValue(readable).startsWith("https://project.example/storage/v1/object/sign/media/$readable?token="))
        m.graph.close()
    }

    @Test fun apiErrorListMatchesDocsApiMdSection3() {
        val doc = generateSequence(File("").absoluteFile) { it.parentFile }.map { File(it, "docs/API.md") }.first { it.isFile }.readLines()
        val start = doc.indexOfFirst { it.startsWith("## 3. Errors") }
        val end = doc.indexOfFirst { it.startsWith("## 4.") }
        val rows = doc.subList(start, end).filter { it.startsWith("| `") }
        val documented = rows.flatMap { row ->
            val cells = row.split('|').map { it.trim() }
            val http = cells[2].toInt()
            Regex("`([a-z_]+)`").findAll(cells[1]).map { it.groupValues[1] to http }.toList()
        }.toMap()
        val ours = (ApiError.entries - ApiError.Unknown).associate { it.wire to it.httpStatus }
        assertEquals(documented, ours)
    }

    @Test fun dataExceptionCarriesTheError() {
        val e = DataException(DataError.Network)
        assertEquals(DataError.Network, e.error)
        for (error in listOf(DataError.Network, DataError.NotSignedIn, DataError.NotConfigured, DataError.FileUnavailable,
            DataError.Auth(AuthFailure.RateLimited, null), DataError.Storage(StorageFailure.TooLarge, null, null), DataError.Database(DbFailure.CheckViolation, null, null))) {
            assertEquals(error, DataErrorCodec.decode(DataErrorCodec.encode(error)))
        }
    }
}
