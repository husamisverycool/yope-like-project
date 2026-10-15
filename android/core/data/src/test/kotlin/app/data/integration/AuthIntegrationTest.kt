package app.data.integration

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.data.DataGraph
import app.data.error.ApiError
import app.data.error.AuthFailure
import app.data.error.DataError
import app.data.repo.AuthState
import io.github.jan.supabase.auth.auth
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import java.io.File
import java.time.LocalDate

/**
 * Auth against the local GoTrue: OTP request / verification fail typed (no Twilio locally, as
 * docs/API.md §13 notes), the session persists encrypted and restores in a new process, sign-out
 * clears it, and the age gate reports its state typed.
 */
@RunWith(AndroidJUnit4::class)
class AuthIntegrationTest {
    @get:Rule val tmp = TemporaryFolder()

    private val context: Context = ApplicationProvider.getApplicationContext()
    private lateinit var admin: Admin
    private lateinit var graphs: Graphs
    private val signedIn = mutableListOf<DataGraph>()

    @Before fun setUp() {
        LocalStack.assumeReachable()
        admin = Admin()
        graphs = Graphs(context, tmp.newFolder("graphs"))
    }

    @After fun tearDown() = runBlocking {
        if (!::admin.isInitialized) return@runBlocking
        for (graph in signedIn) runCatching { if (graph.auth.currentUserId != null) graph.account.deleteAccount() }
        for (account in admin.created) runCatching { admin.deleteUser(account.id) }
        graphs.close()
        admin.close()
    }

    @Test fun otpRequestAndVerificationFailTypedWithoutAnSmsProvider() = runBlocking {
        val tag = uniqueTag()
        val graph = graphs.create("otp-$tag")
        graph.awaitSessionLoaded()
        assertEquals(AuthState.SignedOut, graph.auth.authState.value)
        assertEquals(DataError.Auth(AuthFailure.InvalidPhone, null), expectDataError { graph.auth.requestOtp("12345") })

        val phone = "+1555" + (10_000_000 + java.security.SecureRandom().nextInt(89_999_999))
        val name = "Otp Probe $tag"
        try {
            graph.auth.requestOtp(phone, displayName = name)
            println("requestOtp succeeded: an SMS provider is configured on this stack")
        } catch (e: app.data.error.DataException) {
            val error = e.error
            assertTrue("$error", error is DataError.Auth)
            assertEquals(AuthFailure.SmsSendFailed, (error as DataError.Auth).kind)
        } finally {
            // GoTrue may have created the user before the SMS failed: remove it.
            admin.select("profiles", "display_name=eq.${name.replace(" ", "%20")}&select=id").forEach {
                admin.deleteUser(it.jsonObject["id"]!!.jsonPrimitive.content)
            }
        }

        val account = admin.createUser("Verify $tag")
        val wrong = expectDataError { graph.auth.verifyOtp(account.phone, "000000") }
        assertEquals(AuthFailure.InvalidOrExpiredCode, (wrong as DataError.Auth).kind)
        assertEquals(AuthState.SignedOut, graph.auth.authState.value)
    }

    @Test fun sessionIsEncryptedRestoresInANewProcessAndSignOutClearsIt() = runBlocking {
        val tag = uniqueTag()
        val account = admin.createUser("Session $tag")
        val first = graphs.signIn(account, name = "session-$tag").also(signedIn::add)
        assertEquals(AuthState.SignedIn(account.id), first.auth.authState.value)
        val accessToken = first.client.auth.currentAccessTokenOrNull()!!
        val sessionFile = File(tmp.root, "graphs/session-$tag/session.bin")
        eventually { sessionFile.isFile }
        val stored = String(sessionFile.readBytes(), Charsets.ISO_8859_1)
        assertFalse("the stored session must not contain the token in clear", stored.contains(accessToken.substring(0, 40)))
        assertFalse(stored.contains("refresh_token"))

        // A new process (new client) with the same storage restores the session.
        val second = graphs.create("session-$tag")
        second.awaitSessionLoaded()
        eventually { second.auth.authState.value == AuthState.SignedIn(account.id) }
        assertEquals(account.id, second.profiles.me().id)
        assertEquals(account.id, second.auth.currentUserId)

        second.auth.signOut()
        eventually { second.auth.authState.value == AuthState.SignedOut }
        assertFalse(sessionFile.exists())
        assertEquals(DataError.NotSignedIn, expectDataError { second.profiles.me() })

        // A file that no longer decrypts reads as signed out (and is removed).
        sessionFile.parentFile!!.mkdirs()
        sessionFile.writeBytes(ByteArray(64) { 1 })
        val third = graphs.create("session-$tag")
        third.awaitSessionLoaded()
        // authState follows the client's session status asynchronously (Initializing first), as above.
        eventually { third.auth.authState.value == AuthState.SignedOut }
        assertFalse(sessionFile.exists())
    }

    @Test fun ageGateAndProfileAreTyped() = runBlocking {
        val tag = uniqueTag()
        val account = admin.createUser("Age Gate $tag")
        val graph = graphs.signIn(account).also(signedIn::add)
        assertEquals("Age Gate $tag", graph.profiles.me().displayName)
        assertEquals("Age", graph.profiles.me().firstName)
        val private = graph.profiles.privateProfile()
        assertNotNull(private)
        assertFalse(private!!.birthdayOptIn)
        try {
            val confirmed = graph.profiles.confirmAge(LocalDate.of(1990, 1, 1))
            assertNotNull(confirmed.ageConfirmedAt)
        } catch (e: app.data.error.DataException) {
            // min_age_years is NULL until sourced: the gate fails closed (docs/API.md §2).
            val error = e.error as DataError.Api
            assertEquals(ApiError.AgeGateNotConfigured, error.code)
            assertEquals(503, error.httpStatus)
        }
        expectApi(ApiError.InvalidBirthday) { graph.profiles.setBirthday(LocalDate.now().plusDays(3), optIn = true) }
        val withBirthday = graph.profiles.setBirthday(LocalDate.of(1991, 2, 28), optIn = true)
        assertTrue(withBirthday.birthdayOptIn)
        assertEquals(LocalDate.of(1991, 2, 28), withBirthday.birthday)
    }
}
