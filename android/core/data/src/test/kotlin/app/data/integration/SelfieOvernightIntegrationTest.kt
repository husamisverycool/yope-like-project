package app.data.integration

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.work.WorkInfo
import app.data.DataGraph
import app.data.error.ApiError
import app.data.error.DataError
import app.data.media.upload.NewPost
import app.data.media.upload.UploadOutcome
import app.data.media.upload.UploadProgress
import app.data.media.upload.UploadWorker
import app.data.model.GroupKind
import app.data.model.MediaKind
import app.data.model.ReportTargetKind
import app.data.realtime.GroupEvent
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import java.time.ZoneId
import java.time.ZonedDateTime
import java.util.concurrent.CopyOnWriteArrayList
import kotlin.time.Duration.Companion.seconds

/**
 * Selfie reactions and overnight photos against the real local stack (docs/API.md §14.1, §14.3): the selfie is uploaded and
 * sent, read by the group, replaced, removed by its author and by the post's author, reported, and arrives live; a 9 AM photo
 * goes through the upload queue to `create_overnight_post`, stays unreadable, and shows in `my_developing`; the alerts switch.
 */
@RunWith(AndroidJUnit4::class)
class SelfieOvernightIntegrationTest {
    @get:Rule val tmp = TemporaryFolder()

    private val context: Context = ApplicationProvider.getApplicationContext()
    private lateinit var admin: Admin
    private lateinit var graphs: Graphs
    private val signedIn = mutableListOf<DataGraph>()
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    @Before fun setUp() {
        LocalStack.assumeReachable()
        initTestWorkManager(context)
        admin = Admin()
        graphs = Graphs(context, tmp.newFolder("graphs"))
    }

    @After fun tearDown() = runBlocking {
        scope.cancel()
        if (!::admin.isInitialized) return@runBlocking
        DataGraph.override(null)
        for (graph in signedIn) runCatching { if (graph.auth.currentUserId != null) graph.account.deleteAccount() }
        for (account in admin.created) runCatching { admin.deleteUser(account.id) }
        graphs.close()
        admin.close()
    }

    @Test fun selfiesAndOvernightPhotosThroughTheRealServer() = runBlocking {
        val tag = uniqueTag()
        val files = tmp.newFolder("files")
        val ana = admin.createUser("Ana $tag")
        val rui = admin.createUser("Rui $tag")
        val a = graphs.signIn(ana).also(signedIn::add)
        val b = graphs.signIn(rui).also(signedIn::add)
        val group = a.groups.createGroup("it-$tag selfies", GroupKind.Friends, "Europe/Paris")
        b.groups.joinGroup(a.groups.createInvite(group.id).token)
        val draft = a.uploads.enqueue(NewPost(kind = MediaKind.Photo, original = tinyJpegFile(files, "p.jpg"), groupIds = listOf(group.id)))
        val post = a.posts.post((a.uploader.run(draft) as UploadOutcome.Done).postIds.single())!!

        // Live: Ana's viewer hears Rui's selfie.
        val events = CopyOnWriteArrayList<GroupEvent>()
        scope.launch { a.realtime.events(group.id).collect { events += it } }
        eventually(20.seconds) { events.filterIsInstance<GroupEvent.Subscribed>().size == GroupEvent.Stream.entries.size }

        // Rui reacts: the still is uploaded to u/<uid>/selfies/ first, then react_with_selfie.
        val first = tinyJpegFile(files, "selfie.jpg", padTo = 4 * 1024)
        val row = b.selfies.react(post.id, first)
        assertTrue(row.imagePath.startsWith("u/${rui.id}/selfies/"))
        assertEquals(listOf(rui.id), a.selfies.selfies(post.id).map { it.userId })
        assertArrayEquals(first.readBytes(), download(a.signedUrls.url(row.imagePath)!!)) // readable by whoever reads the row
        eventually(30.seconds, step = 1_000) {
            // Postgres-changes subscriptions register asynchronously: send again until one arrives.
            if (events.none { it is GroupEvent.SelfieReactionChanged }) b.selfies.react(post.id, first)
            events.any { it is GroupEvent.SelfieReactionChanged && it.selfie.postId == post.id && it.selfie.userId == rui.id }
        }

        // One per person: a new selfie replaces Rui's.
        val second = b.selfies.react(post.id, tinyJpegFile(files, "again.jpg"))
        assertEquals(listOf(second.imagePath), a.selfies.selfiesFor(listOf(post.id))[post.id]!!.map { it.imagePath })

        // Never on your own post.
        val own = expectDataError { a.selfies.react(post.id, tinyJpegFile(files, "own.jpg")) }
        assertEquals("own_post", (own as DataError.Api).raw)

        // Ana reports it, then removes it from her photo; the removal arrives as reactions_changed.
        assertTrue(a.safety.report(ReportTargetKind.Selfie, second.id, "Other").isNotBlank())
        val removedNot = expectDataError { b.selfies.remove(post.id, ana.id) }
        assertEquals("not_allowed", (removedNot as DataError.Api).raw)
        a.selfies.remove(post.id, rui.id)
        assertTrue(b.selfies.selfies(post.id).isEmpty())
        eventually(20.seconds) { events.any { it is GroupEvent.ReactionsChanged && it.postId == post.id } }
        // Rui takes his own back.
        b.selfies.react(post.id, tinyJpegFile(files, "third.jpg"))
        b.selfies.remove(post.id)
        assertTrue(a.selfies.selfies(post.id).isEmpty())

        // 9 AM: the queue sends the photo to create_overnight_post; nobody can read it until 09:00 in the group's zone.
        DataGraph.override(b)
        val overnight = b.uploads.enqueue(NewPost(kind = MediaKind.Photo, original = tinyJpegFile(files, "night.jpg"), width = 1, height = 1, groupIds = listOf(group.id), overnight = true))
        val work = runUploadWork(context, overnight)
        assertEquals(work.outputData.getString(UploadWorker.KEY_ERROR), WorkInfo.State.SUCCEEDED, work.state)
        assertEquals(UploadProgress.Done(emptyList()), b.uploads.progress(overnight).first())
        val developing = b.posts.myDeveloping()
        assertTrue(developing.developing)
        val paris = ZoneId.of("Europe/Paris")
        val now = ZonedDateTime.now(paris)
        val nine = now.toLocalDate().atTime(9, 0).atZone(paris).let { if (it.isAfter(now)) it else it.plusDays(1) }
        assertEquals(nine.toInstant(), developing.revealAt)
        assertFalse(a.posts.feed(group.id).any { it.authorId == rui.id }) // not a post until it develops
        assertFalse(a.posts.myDeveloping().developing) // Ana has nothing developing
        expectApi(ApiError.AlreadyPosted) { b.posts.createOvernightPost(overnight, listOf(group.id)) }

        // The reveal push switch (default on).
        assertTrue(a.settings.notificationSettings()?.overnight ?: true)
        assertFalse(a.settings.setOvernightAlerts(false).overnight)
        assertFalse(a.settings.notificationSettings()!!.overnight)
        assertTrue(a.settings.setOvernightAlerts(true).overnight)
    }
}
