package app.data.integration

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.data.DataGraph
import app.data.error.DataError
import app.data.error.StorageFailure
import app.data.media.StoragePaths
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import java.util.UUID
import kotlin.time.Duration.Companion.seconds

/** Storage rules through storage-kt (docs/API.md §7): insert-only, own folders only, typed failures. */
@RunWith(AndroidJUnit4::class)
class StorageIntegrationTest {
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

    @Test fun uploadsAreInsertOnlyInYourOwnFolderAndFailTyped() = runBlocking {
        val tag = uniqueTag()
        val account = admin.createUser("Storage $tag")
        val other = admin.createUser("Other $tag")
        val graph = graphs.signIn(account).also(signedIn::add)
        val jpeg = tinyJpegFile(tmp.root, "a.jpg", padTo = 64 * 1024)

        val path = StoragePaths.original(account.id, UUID.randomUUID().toString(), "jpg")
        val progress = mutableListOf<Long>()
        graph.storage.upload(path, jpeg, "image/jpeg") { sent, total -> progress += sent; assertEquals(jpeg.length(), total) }
        assertEquals(jpeg.length(), progress.last())
        assertArrayEquals(jpeg.readBytes(), graph.storage.download(path))
        // No overwrite: the same path again is "already exists" (what the upload worker treats as done).
        val again = expectDataError { graph.storage.upload(path, jpeg, "image/jpeg") { _, _ -> } }
        assertEquals(StorageFailure.AlreadyExists, (again as DataError.Storage).kind)
        // Someone else's folder: refused by storage RLS.
        val foreign = expectDataError { graph.storage.upload(StoragePaths.original(other.id, UUID.randomUUID().toString(), "jpg"), jpeg, "image/jpeg") { _, _ -> } }
        assertEquals(StorageFailure.Forbidden, (foreign as DataError.Storage).kind)

        // Avatars may be replaced: the old object is deleted by its owner.
        val first = graph.profiles.setAvatar(jpeg).avatarPath!!
        val second = graph.profiles.setAvatar(tinyJpegFile(tmp.root, "b.jpg")).avatarPath!!
        assertNotEquals(first, second)
        assertTrue(graph.storage.sign(listOf(first), 60.seconds).isEmpty())
        assertEquals(setOf(second), graph.storage.sign(listOf(second), 60.seconds).keys)
    }
}
