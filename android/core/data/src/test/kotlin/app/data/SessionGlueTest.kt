package app.data

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.data.glue.BillingBridge
import app.data.glue.GlueBridges
import app.data.glue.PushTokenBridge
import app.data.glue.SessionGlue
import app.data.glue.WidgetBridge
import app.data.integration.eventually
import app.data.model.Message
import app.data.model.MessageKind
import app.data.model.Post
import app.data.offline.CacheKey
import app.data.realtime.ChannelHandle
import app.data.realtime.GroupEvent
import app.data.realtime.GroupRealtime
import app.data.realtime.RealtimeChannels
import app.data.repo.AuthState
import app.model.QuietHours
import app.push.QuietHoursSource
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
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
import java.time.LocalTime
import java.time.ZoneId
import java.util.concurrent.CopyOnWriteArrayList

/** The session glue on a mocked server: sign-in hand-offs, widgets, cache upkeep, sign-out order. */
@RunWith(AndroidJUnit4::class)
class SessionGlueTest {
    @get:Rule val tmp = TemporaryFolder()

    private val context: Context = ApplicationProvider.getApplicationContext()
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private val userId = "9f0c2b7e-1111-4111-8111-111111111111"
    private val now = "2026-10-15T13:35:09.329469+00:00"

    private class Push : PushTokenBridge {
        @Volatile var current: ((String) -> Unit)? = null
        @Volatile var deleted = false
        override fun setSink(sink: ((String) -> Unit)?) { current = sink }
        override suspend fun fetch(): String = "fcm-1"
        override fun lastKnown(): String = "fcm-1"
        override suspend fun delete() { deleted = true }
    }

    private class Billing : BillingBridge {
        val calls = CopyOnWriteArrayList<String>()
        override suspend fun identify(userId: String) { calls += "identify:$userId" }
        override suspend fun reset() { calls += "reset" }
    }

    private class Widgets : WidgetBridge {
        val retained = CopyOnWriteArrayList<Set<String>>()
        val removed = CopyOnWriteArrayList<Pair<String, String>>()
        override suspend fun retainGroups(groupIds: Set<String>) { retained += groupIds }
        override suspend fun removeIfShowing(groupId: String, sourceId: String) { removed += groupId to sourceId }
    }

    private class Channels : RealtimeChannels {
        val sinks = CopyOnWriteArrayList<Pair<String, (GroupEvent) -> Unit>>()
        override suspend fun open(groupId: String, stream: GroupEvent.Stream, sink: (GroupEvent) -> Unit): ChannelHandle {
            sinks += groupId to sink
            return object : ChannelHandle {
                override val live: StateFlow<Boolean> = MutableStateFlow(true)
                override suspend fun close() {}
            }
        }
    }

    private lateinit var mock: MockSupabase

    @Before fun setUp() {
        mock = MockSupabase(context, tmp.root) { _, seen ->
            when {
                seen.path.endsWith("/rpc/register_device") -> {
                    val token = Json.parseToJsonElement(seen.body).jsonObject["p_push_token"]!!.jsonPrimitive.content
                    json("""{"id":"d1","user_id":"$userId","platform":"android","push_token":"$token","push_to_start_token":null,"widget_push_token":null,"created_at":"$now","updated_at":"$now"}""")
                }
                seen.path.endsWith("/rpc/unregister_device") -> noContent()
                seen.path.endsWith("/notification_settings") ->
                    json("""[{"user_id":"$userId","quiet_start":"22:00:00","quiet_end":"07:00:00","time_zone":"Europe/Paris","updated_at":"$now"}]""")
                seen.path.endsWith("/rest/v1/groups") -> json("[" + listOf("g1", "g2").joinToString(",") { id ->
                    """{"id":"$id","name":"$id","kind":"friends","cover_path":null,"time_zone":"UTC","waking_start":null,"waking_end":null,"invitation_paused":false,"created_by":null,"created_at":"$now","updated_at":"$now"}"""
                } + "]")
                seen.path.endsWith("/auth/v1/logout") -> noContent()
                else -> json("[]")
            }
        }
    }

    @After fun tearDown() = runBlocking {
        scope.cancel()
        mock.graph.close()
        QuietHoursSource.current = QuietHoursSource { null }
    }

    private fun post(id: String) = Post(id, "m-$id", "g1", "u", null, null, null, null, false, null, Instant.parse("2026-10-15T12:00:00Z"))

    @Test fun signInSignOutAndDeletionsDriveTheHandOffs() = runBlocking {
        val graph = mock.graph
        val push = Push()
        val billing = Billing()
        val widgets = Widgets()
        val channels = Channels()
        val outboxEmptied = java.util.concurrent.atomic.AtomicInteger()
        val glue = SessionGlue(graph.auth, graph.groups, graph.devices, graph.settings, GroupRealtime(channels, scope), graph.cache, graph.signedUrls, GlueBridges(push, billing, widgets), scope) { outboxEmptied.incrementAndGet() }
        glue.start()

        mock.signIn(userId)
        eventually { graph.auth.authState.value == AuthState.SignedIn(userId) }
        eventually { billing.calls.contains("identify:$userId") }
        eventually { mock.requests.any { it.path.endsWith("/rpc/register_device") && it.body.contains("\"fcm-1\"") } }
        assertTrue(mock.requests.single { it.path.endsWith("/rpc/register_device") }.body.contains("\"p_platform\":\"android\""))
        eventually { QuietHoursSource.current.current() != null }
        assertEquals(QuietHours(LocalTime.of(22, 0), LocalTime.of(7, 0)) to ZoneId.of("Europe/Paris"), QuietHoursSource.current.current())

        // A new FCM token is registered at once.
        push.current!!("fcm-2")
        eventually { mock.requests.any { it.path.endsWith("/rpc/register_device") && it.body.contains("\"fcm-2\"") } }

        // Group list → widget store; every group's deletion topic is followed.
        graph.groups.myGroups()
        eventually { widgets.retained.lastOrNull() == setOf("g1", "g2") }
        eventually { channels.sinks.map { it.first }.toSet() == setOf("g1", "g2") }

        // Cached pages follow live events; the widget showing a deleted post is cleared.
        val posts = ListSerializer(Post.serializer())
        val messages = ListSerializer(Message.serializer())
        graph.cache.put(CacheKey.feed("g1"), posts, listOf(post("p1"), post("p2")))
        graph.cache.put(CacheKey.chat("g1"), messages, listOf(Message("x", "g1", "u", MessageKind.Photo, null, "p1", null, null, null, null, Instant.EPOCH)))
        channels.sinks.first { it.first == "g1" }.second(GroupEvent.PostDeleted("g1", "p1", "m-p1"))
        eventually { widgets.removed.contains("g1" to "p1") }
        eventually { graph.cache.get(CacheKey.feed("g1"), posts)!!.value.map { it.id } == listOf("p2") }
        assertTrue(graph.cache.get(CacheKey.chat("g1"), messages)!!.value.isEmpty())
        glue.reconcileCache(GroupEvent.PostInserted("g1", post("p3").copy(createdAt = Instant.parse("2026-10-16T00:00:00Z"))))
        assertEquals(listOf("p3", "p2"), graph.cache.get(CacheKey.feed("g1"), posts)!!.value.map { it.id })

        // Sign-out: unregister_device before the session goes, then everything is reset.
        graph.auth.signOut()
        eventually { graph.auth.authState.value == AuthState.SignedOut }
        val unregister = mock.requests.indexOfFirst { it.path.endsWith("/rpc/unregister_device") }
        val logout = mock.requests.indexOfFirst { it.path.endsWith("/auth/v1/logout") }
        assertTrue("unregister $unregister, logout $logout", unregister in 0 until logout)
        eventually { billing.calls.last() == "reset" && push.deleted && widgets.retained.last() == emptySet<String>() }
        // The outbox goes with the session: no unsent post of the person who left stays queued or on disk.
        eventually { outboxEmptied.get() == 1 }
        assertNull(push.current)
        assertNull(QuietHoursSource.current.current())
        assertNull(graph.groups.myGroupIds.value)
        graph.cache.setUser(userId)
        assertNull(graph.cache.get(CacheKey.feed("g1"), posts)) // cleared
        glue.stop()
    }
}
