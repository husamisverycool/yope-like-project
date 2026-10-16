package app.data

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.data.media.StoragePaths
import app.data.model.DataJson
import app.data.model.Developing
import app.data.model.DevelopingPost
import app.data.model.NotificationSettings
import app.data.model.Post
import app.data.model.ReportTargetKind
import app.data.model.SelfieReaction
import app.data.realtime.GroupEvent
import app.data.realtime.RealtimeDecoding
import app.data.remote.Rpc
import app.data.remote.rpcArgs
import io.ktor.http.HttpStatusCode
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.jsonObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import java.time.Instant

/** Selfie reactions and overnight photos (docs/API.md §14.1, §14.3): rows, RPC arguments, realtime, and the calls on the wire. */
@RunWith(AndroidJUnit4::class)
class SelfieAndOvernightDataTest {
    @get:Rule val tmp = TemporaryFolder()

    private val context: Context = ApplicationProvider.getApplicationContext()
    private val me = "9f0c2b7e-1111-4111-8111-111111111111"
    private val selfieRow = """{"id":"s1","post_id":"p1","user_id":"u2","group_id":"g1","image_path":"u/u2/selfies/a.jpg","created_at":"2026-10-15T13:35:09.329469+00:00"}"""

    @Test fun rowsDecodeAndRpcArgumentsFollowTheSpec() {
        val selfie = DataJson.decodeFromString(SelfieReaction.serializer(), selfieRow)
        assertEquals(SelfieReaction(id = "s1", postId = "p1", userId = "u2", groupId = "g1", imagePath = "u/u2/selfies/a.jpg", createdAt = Instant.parse("2026-10-15T13:35:09.329469Z")), selfie)

        val developing = DataJson.decodeFromString(ListSerializer(Developing.serializer()), """[{"developing":true,"reveal_at":"2026-10-16T07:00:00+00:00"}]""")
        assertEquals(Developing(true, Instant.parse("2026-10-16T07:00:00Z")), developing.single())
        assertEquals(Developing(false, null), DataJson.decodeFromString(Developing.serializer(), """{"developing":false,"reveal_at":null}"""))
        assertEquals(DevelopingPost("g1", Instant.parse("2026-10-16T07:00:00Z")), DataJson.decodeFromString(DevelopingPost.serializer(), """{"group_id":"g1","develops_at":"2026-10-16T07:00:00+00:00"}"""))

        // notification_settings.overnight (default on) and posts.revealed_at (null for every post that did not develop overnight).
        val settings = DataJson.decodeFromString(NotificationSettings.serializer(), """{"user_id":"u","quiet_start":null,"quiet_end":null,"time_zone":null,"updated_at":"2026-10-15T13:35:09Z","overnight":false}""")
        assertFalse(settings.overnight)
        assertTrue(NotificationSettings("u", null, null, null, Instant.EPOCH).overnight)
        val post = DataJson.decodeFromString(Post.serializer(), """{"id":"p","media_id":"m","group_id":"g","author_id":"u","caption":null,"voice_path":null,"voice_duration_ms":null,
            "invitation_id":null,"in_window":false,"reply_to_post_id":null,"created_at":"2026-10-15T23:10:00Z","voice_levels":null,"revealed_at":"2026-10-16T09:00:00Z"}""")
        assertEquals(Instant.parse("2026-10-16T09:00:00Z"), post.revealedAt)

        assertEquals(setOf("p_post_id"), rpcArgs(Rpc.RemoveSelfieReaction) { put("p_post_id", "p"); opt("p_user_id", null as String?) }.keys)
        assertEquals(JsonPrimitive("u2"), rpcArgs(Rpc.RemoveSelfieReaction) { put("p_post_id", "p"); opt("p_user_id", "u2") }["p_user_id"])
        assertThrows(IllegalArgumentException::class.java) { rpcArgs(Rpc.ReactWithSelfie) { put("p_post_id", "p") } }
        assertTrue(rpcArgs(Rpc.MyDeveloping).isEmpty())
        assertEquals("selfie", ReportTargetKind.Selfie.wire)
        assertEquals("u/$me/selfies/abc-1.jpg", StoragePaths.selfie(me, "abc-1"))
    }

    @Test fun selfieRowsArriveAsRealtimeEvents() {
        val record = DataJson.parseToJsonElement(selfieRow).jsonObject
        val event = RealtimeDecoding.change("g1", "selfie_reactions", record, update = true) as GroupEvent.SelfieReactionChanged
        assertEquals("s1", event.selfie.id)
        assertNull(RealtimeDecoding.change("g2", "selfie_reactions", record, update = false)) // defence in depth
    }

    @Test fun reactUploadsTheSelfieFirstThenCallsTheRpc() = runBlocking {
        val m = MockSupabase(context, tmp.newFolder("mock")) { _, seen ->
            when {
                seen.path.startsWith("/storage/v1/object/media/") -> json("""{"Key":"media/x","Id":"1"}""")
                seen.path == "/rest/v1/rpc/react_with_selfie" -> json(selfieRow)
                seen.path == "/rest/v1/rpc/remove_selfie_reaction" -> noContent()
                seen.path == "/rest/v1/rpc/my_developing" -> json("""[{"developing":true,"reveal_at":"2026-10-16T07:00:00+00:00"}]""")
                seen.path == "/rest/v1/rpc/create_overnight_post" -> json("""[{"group_id":"g1","develops_at":"2026-10-16T07:00:00+00:00"}]""")
                seen.path == "/rest/v1/rpc/set_overnight_alerts" ->
                    json("""{"user_id":"$me","quiet_start":null,"quiet_end":null,"time_zone":null,"updated_at":"2026-10-15T13:35:09Z","overnight":false}""")
                seen.path == "/rest/v1/selfie_reactions" -> json("[$selfieRow]")
                else -> json("{}", HttpStatusCode.NotFound)
            }
        }
        m.signIn(me)
        val file = tmp.newFile("selfie.jpg").apply { writeBytes(ByteArray(16) { 1 }) }
        val row = m.graph.selfies.react("p1", file)
        assertEquals("s1", row.id)
        val upload = m.requests.indexOfFirst { it.path.startsWith("/storage/v1/object/media/u/$me/selfies/") && it.path.endsWith(".jpg") }
        val rpc = m.requests.indexOfFirst { it.path == "/rest/v1/rpc/react_with_selfie" }
        assertTrue("upload first", upload in 0 until rpc)
        val args = DataJson.parseToJsonElement(m.requests[rpc].body).jsonObject
        assertEquals(JsonPrimitive("p1"), args["p_post_id"])
        assertEquals(m.requests[upload].path.removePrefix("/storage/v1/object/media/"), (args["p_image_path"] as JsonPrimitive).content)

        m.graph.selfies.remove("p1", "u2")
        assertEquals("u2", (DataJson.parseToJsonElement(m.requests.last().body).jsonObject["p_user_id"] as JsonPrimitive).content)
        m.graph.selfies.remove("p1")
        assertFalse(DataJson.parseToJsonElement(m.requests.last().body).jsonObject.containsKey("p_user_id"))

        assertEquals(listOf("s1"), m.graph.selfies.selfiesFor(listOf("p1"))["p1"]?.map { it.id })
        assertFalse("never a count", m.requests.last().query.contains("count"))

        assertEquals(Developing(true, Instant.parse("2026-10-16T07:00:00Z")), m.graph.posts.myDeveloping())
        assertEquals(listOf("g1"), m.graph.posts.createOvernightPost("m1", listOf("g1", "g1")).map { it.groupId })
        assertEquals(JsonPrimitive("m1"), DataJson.parseToJsonElement(m.requests.last().body).jsonObject["p_media_id"])
        assertFalse(m.graph.settings.setOvernightAlerts(false).overnight)
        assertEquals(JsonPrimitive(false), DataJson.parseToJsonElement(m.requests.last().body).jsonObject["p_on"])
        assertTrue(DataJson.parseToJsonElement(m.requests.last().body).jsonObject["p_on"] != JsonNull)
        m.graph.close()
    }
}
