package app.data.integration

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.data.DataGraph
import app.data.error.ApiError
import app.data.media.upload.NewPost
import app.data.media.upload.UploadOutcome
import app.data.model.GroupKind
import app.data.model.MediaKind
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import kotlin.time.Duration.Companion.seconds

/** Security invariant 1 through the client: an outsider gets nothing of a group, from any repository. */
@RunWith(AndroidJUnit4::class)
class IsolationIntegrationTest {
    @get:Rule val tmp = TemporaryFolder()

    private val context: Context = ApplicationProvider.getApplicationContext()
    private lateinit var admin: Admin
    private lateinit var graphs: Graphs
    private val signedIn = mutableListOf<DataGraph>()

    @Before fun setUp() {
        LocalStack.assumeReachable()
        initTestWorkManager(context)
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

    @Test fun anOutsiderSeesNothingOfAGroup() = runBlocking {
        val tag = uniqueTag()
        val files = tmp.newFolder("files")
        val owner = admin.createUser("Owner $tag")
        val friend = admin.createUser("Friend $tag")
        val stranger = admin.createUser("Stranger $tag")
        val a = graphs.signIn(owner).also(signedIn::add)
        val f = graphs.signIn(friend).also(signedIn::add)
        val s = graphs.signIn(stranger).also(signedIn::add)

        val group = a.groups.createGroup("it-$tag private", GroupKind.Friends, "UTC")
        f.groups.joinGroup(a.groups.createInvite(group.id).token)
        val draft = a.uploads.enqueue(NewPost(kind = MediaKind.Photo, original = tinyJpegFile(files, "p.jpg"), groupIds = listOf(group.id), caption = "secret"))
        val post = a.posts.post((a.uploader.run(draft) as UploadOutcome.Done).postIds.single())!!
        val media = a.posts.mediaOf(post)!!
        val message = a.chat.sendText(group.id, "secret text")
        f.reactions.react(post.id, "🔥")
        f.tags.tagSelf(post.id)
        val album = a.albums.saveAlbum(group.id, "Album $tag", listOf(post.id))
        admin.insert("weekly_recaps", buildJsonObject {
            put("group_id", group.id); put("week_start", LocalDate.now(ZoneId.of("UTC")).toString()); put("status", "ready")
            put("items", JsonArray(listOf(JsonPrimitive(post.id))))
        })
        val now = Instant.now()
        admin.upsert("daily_invitations", buildJsonObject {
            put("group_id", group.id); put("local_date", LocalDate.now(ZoneId.of("UTC")).toString()); put("status", "fired")
            put("fires_at", now.minusSeconds(5).toString()); put("closes_at", now.plusSeconds(115).toString())
        }, "group_id,local_date")

        // The member sees it all …
        assertEquals(listOf(post.id), f.posts.feed(group.id).map { it.id })
        assertTrue(f.invitations.currentInvitation(group.id) != null)

        // … the stranger nothing: no rows, no files, no RPC results.
        assertTrue(s.groups.myGroups().none { it.id == group.id })
        assertNull(s.groups.group(group.id))
        assertTrue(s.groups.members(group.id).isEmpty())
        assertTrue(s.groups.activeInvites(group.id).isEmpty())
        assertTrue(s.posts.feed(group.id).isEmpty())
        assertNull(s.posts.post(post.id))
        assertTrue(s.posts.media(listOf(media.id)).isEmpty())
        assertTrue(s.chat.messages(group.id).isEmpty())
        assertNull(s.chat.message(message.id))
        assertTrue(s.reactions.reactions(post.id).isEmpty())
        assertTrue(s.tags.tags(post.id).isEmpty())
        assertTrue(s.albums.albums(group.id).isEmpty())
        assertTrue(s.albums.items(album.id).isEmpty())
        assertTrue(s.recaps.recaps(group.id).isEmpty())
        assertNull(s.invitations.currentInvitation(group.id))
        assertTrue(s.browse.wall(owner.id).isEmpty())
        assertTrue(s.storage.sign(listOf(media.originalPath), 60.seconds).isEmpty())
        assertNull(s.signedUrls.url(media.originalPath))
        expectApi(ApiError.NotGroupMember) { s.browse.historyWeeks(group.id) }
        expectApi(ApiError.NotGroupMember) { s.browse.onThisDay(group.id, LocalDate.now()) }
        expectApi(ApiError.NotGroupMember) { s.groups.createInvite(group.id) }
        expectApi(ApiError.NotGroupMember) { s.chat.sendText(group.id, "hi") }
        expectApi(ApiError.NotGroupMember) { s.groups.setMuted(group.id, true) }
        expectApi(ApiError.PostNotFound) { s.reactions.react(post.id, "🔥") }
        expectApi(ApiError.PostNotFound) { s.tags.tagSelf(post.id) }
        expectApi(ApiError.NotGroupMember) { s.albums.saveAlbum(group.id, "x", listOf(post.id)) }
        // Posting someone else's media, or into a foreign group, fails typed.
        expectApi(ApiError.MediaNotFound) { s.posts.createPost(media.id, listOf(group.id)) }
        val own = s.uploads.enqueue(NewPost(kind = MediaKind.Photo, original = tinyJpegFile(files, "s.jpg"), groupIds = listOf(group.id)))
        val refused = s.uploader.run(own) as UploadOutcome.Failed
        assertEquals(ApiError.NotGroupMember, (refused.error as app.data.error.DataError.Api).code)
    }
}
