package app.widget

import app.model.WidgetSnapshot
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File
import java.io.IOException
import java.time.Instant

class WidgetFileStoreTest {
    @get:Rule val tmp = TemporaryFolder()
    private val store by lazy { WidgetFileStore(tmp.newFolder("widgets")) }

    private fun incoming(at: Long, source: String = "p$at", group: String = "g1") = WidgetFileStore.Incoming(
        groupId = group, groupName = "Family", kind = WidgetSnapshot.Kind.Photo,
        postedAt = Instant.ofEpochMilli(at), sourceId = source, senderName = "Ana", caption = null,
    )

    private fun bytes(s: String): (java.io.OutputStream) -> Unit = { it.write(s.toByteArray()) }

    private fun files(group: String = "g1"): List<String> = store.groupDir(group).list()!!.sorted()

    @Test fun writeThenRead() {
        val written = store.write(incoming(1_000), bytes("photo-1"))!!
        val read = store.read("g1")!!
        assertEquals(written, read)
        assertArrayEquals("photo-1".toByteArray(), store.photo(read).readBytes())
        assertEquals(listOf(read.photoFile, WidgetFileStore.SNAPSHOT).sorted(), files())
    }

    @Test fun newestWinsAndOlderOrDuplicateDeliveriesAreIgnored() {
        store.write(incoming(2_000), bytes("new"))!!
        assertFalse(store.accepts(incoming(1_000)))
        assertNull(store.write(incoming(1_000), bytes("old")))
        assertNull(store.write(incoming(2_000), bytes("dup")))
        assertEquals("new", store.photo(store.read("g1")!!).readText())
        assertTrue(store.accepts(incoming(3_000)))
    }

    @Test fun keepsOnePreviousRenditionAndPrunesOlder() {
        val a = store.write(incoming(1_000), bytes("a"))!!
        val b = store.write(incoming(2_000), bytes("b"))!!
        assertTrue(File(store.groupDir("g1"), a.photoFile).exists())
        val c = store.write(incoming(3_000), bytes("c"))!!
        assertFalse(File(store.groupDir("g1"), a.photoFile).exists())
        assertTrue(File(store.groupDir("g1"), b.photoFile).exists())
        assertEquals(c, store.read("g1"))
    }

    @Test fun failedDownloadLeavesTheStoreUnchanged() {
        val a = store.write(incoming(1_000), bytes("a"))!!
        try {
            store.write(incoming(2_000)) { it.write(1); throw IOException("network") }
        } catch (_: IOException) {
        }
        assertEquals(a, store.read("g1"))
        assertEquals(listOf(a.photoFile, WidgetFileStore.SNAPSHOT).sorted(), files())
    }

    @Test(expected = IOException::class) fun emptyRenditionIsRejected() {
        store.write(incoming(1_000)) { }
    }

    @Test fun avatarIsOptionalAndItsFailureDoesNotBlockThePhoto() {
        val s = store.write(incoming(1_000), bytes("p")) { throw IOException("avatar") }!!
        assertNull(s.senderAvatarFile)
        val t = store.write(incoming(2_000), bytes("p2"), bytes("avatar"))!!
        assertEquals("avatar", store.avatar(t)!!.readText())
    }

    @Test fun snapshotWhosePhotoIsMissingReadsAsNone() {
        val s = store.write(incoming(1_000), bytes("p"))!!
        store.photo(s).delete()
        assertNull(store.read("g1"))
    }

    @Test(expected = IllegalArgumentException::class) fun rejectsPathTraversalGroupIds() {
        store.groupDir("../escape")
    }

    @Test fun retainGroupsRemovesGroupsYouLeft() {
        store.write(incoming(1_000, group = "keep"), bytes("k"))
        store.write(incoming(1_000, group = "left"), bytes("l"))
        store.retainGroups(setOf("keep"))
        assertEquals(setOf("keep"), store.groups())
        assertNotNull(store.read("keep"))
    }

    @Test fun pruneRemovesStaleTempFilesOnly() {
        store.write(incoming(1_000), bytes("p"))
        val dir = store.groupDir("g1")
        val stale = File(dir, "tmp-old.part").apply { writeText("x"); setLastModified(0) }
        val fresh = File(dir, "tmp-new.part").apply { writeText("x") }
        store.prune("g1")
        assertFalse(stale.exists())
        assertTrue(fresh.exists())
    }
}
