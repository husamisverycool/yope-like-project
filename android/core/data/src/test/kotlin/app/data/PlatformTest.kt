package app.data

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.data.auth.AesGcmSessionCipher
import app.data.auth.EncryptedSessionManager
import app.data.offline.Connectivity
import io.github.jan.supabase.auth.exception.NoSessionFoundException
import io.github.jan.supabase.auth.user.UserSession
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import org.robolectric.Shadows.shadowOf
import org.robolectric.shadows.ShadowNetwork
import org.robolectric.shadows.ShadowNetworkCapabilities
import java.io.File
import java.util.concurrent.CopyOnWriteArrayList
import javax.crypto.KeyGenerator

/** Android pieces: encrypted session storage and the connectivity flow (Robolectric). */
@RunWith(AndroidJUnit4::class)
class PlatformTest {
    @get:Rule val tmp = TemporaryFolder()

    private val context: Context = ApplicationProvider.getApplicationContext()
    private fun cipher() = KeyGenerator.getInstance("AES").apply { init(256) }.generateKey().let { key -> AesGcmSessionCipher { key } }
    private val session = UserSession(accessToken = "eyJ.access.token-123", refreshToken = "refresh-456", expiresIn = 3600, tokenType = "bearer")

    @Test fun sessionIsStoredEncryptedAndReadBack() = runBlocking {
        val file = File(tmp.root, "s/session.bin")
        val cipher = cipher()
        val manager = EncryptedSessionManager(file, cipher)
        assertThrows(NoSessionFoundException::class.java) { runBlocking { manager.loadSession() } }
        manager.saveSession(session)
        val raw = String(file.readBytes(), Charsets.ISO_8859_1)
        assertFalse(raw.contains("refresh-456"))
        assertFalse(raw.contains("access.token"))
        val loaded = EncryptedSessionManager(file, cipher).loadSession()
        assertEquals(session.accessToken, loaded.accessToken)
        assertEquals(session.refreshToken, loaded.refreshToken)
        manager.deleteSession()
        assertFalse(file.exists())
    }

    @Test fun aSessionThatDoesNotDecryptReadsAsSignedOutAndIsRemoved() = runBlocking {
        val file = File(tmp.root, "session.bin")
        EncryptedSessionManager(file, cipher()).saveSession(session)
        // Another key (keystore reset / copied to another device), then a tampered file.
        assertEquals(null, EncryptedSessionManager(file, cipher()).loadSessionOrNull())
        assertFalse(file.exists())
        val cipher = cipher()
        EncryptedSessionManager(file, cipher).saveSession(session)
        val bytes = file.readBytes().also { it[it.size - 1] = (it[it.size - 1] + 1).toByte() }
        file.writeBytes(bytes)
        assertEquals(null, EncryptedSessionManager(file, cipher).loadSessionOrNull())
        assertFalse(file.exists())
    }

    @Test fun connectivityFollowsTheDefaultNetworkCallbacks() = runBlocking {
        val manager = context.getSystemService(ConnectivityManager::class.java)
        val shadow = shadowOf(manager)
        val connectivity = Connectivity(context)
        val seen = CopyOnWriteArrayList<Boolean>()
        val job = CoroutineScope(Dispatchers.Default).launch { connectivity.online.collect { seen += it } }
        withTimeout(5_000) { while (shadow.networkCallbacks.isEmpty() || seen.isEmpty()) delay(10) }
        assertEquals(connectivity.isOnline(), seen.first()) // the current state comes first
        val callback = shadow.networkCallbacks.single()
        val network = ShadowNetwork.newInstance(1)
        callback.onCapabilitiesChanged(network, ShadowNetworkCapabilities.newInstance())
        withTimeout(5_000) { while (seen.last()) delay(10) }
        val withInternet = ShadowNetworkCapabilities.newInstance().also { shadowOf(it).addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) }
        callback.onCapabilitiesChanged(network, withInternet)
        callback.onAvailable(network) // duplicate "online": not emitted twice
        withTimeout(5_000) { while (!seen.last()) delay(10) }
        callback.onUnavailable()
        withTimeout(5_000) { while (seen.last()) delay(10) }
        assertTrue(seen.zipWithNext().none { (a, b) -> a == b })
        job.cancel()
        withTimeout(5_000) { while (shadow.networkCallbacks.isNotEmpty()) delay(10) } // unregistered on cancel
    }
}
