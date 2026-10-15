package app.data.integration

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.data.DataGraph
import app.data.glue.BillingBridge
import app.data.glue.GlueBridges
import app.data.glue.PushTokenBridge
import app.data.glue.WidgetBridge
import app.data.media.upload.NewPost
import app.data.media.upload.UploadOutcome
import app.data.model.GroupKind
import app.data.model.MediaKind
import app.data.model.MessageKind
import app.data.model.Post
import app.data.offline.CacheKey
import app.data.offline.DataState
import app.data.realtime.GroupEvent
import app.data.realtime.ReconnectPolicy
import app.data.repo.AuthState
import io.github.jan.supabase.realtime.realtime
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.last
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.builtins.ListSerializer
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import java.util.concurrent.CopyOnWriteArrayList
import kotlin.time.Duration.Companion.milliseconds
import kotlin.time.Duration.Companion.seconds

/**
 * Realtime as the screens use it (docs/API.md §8): a member gets inserts, updates and the private
 * deletion broadcasts of the group; an outsider subscribed to the same group gets nothing; after a
 * socket drop the stream comes back and says so. Also the session glue on a real session: FCM token
 * registered, billing identified, the widget showing a deleted post cleared, sign-out unregisters.
 */
@RunWith(AndroidJUnit4::class)
class RealtimeIntegrationTest {
    @get:Rule val tmp = TemporaryFolder()

    private val context: Context = ApplicationProvider.getApplicationContext()
    private lateinit var admin: Admin
    private lateinit var graphs: Graphs
    private val signedIn = mutableListOf<DataGraph>()
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    private val policy = ReconnectPolicy(
        subscribeTimeout = 10.seconds, staleAfter = 3.seconds, initialBackoff = 500.milliseconds, maxBackoff = 2.seconds, stopTimeout = 1.seconds,
    )

    private class FakePush(val token: String) : PushTokenBridge {
        var currentSink: ((String) -> Unit)? = null
        var deleted = false
        override fun setSink(sink: ((String) -> Unit)?) { currentSink = sink }
        override suspend fun fetch(): String = token
        override fun lastKnown(): String = token
        override suspend fun delete() { deleted = true }
    }

    private class FakeBilling : BillingBridge {
        val calls = CopyOnWriteArrayList<String>()
        override suspend fun identify(userId: String) { calls += "identify:$userId" }
        override suspend fun reset() { calls += "reset" }
    }

    private class FakeWidgets : WidgetBridge {
        val retained = CopyOnWriteArrayList<Set<String>>()
        val removed = CopyOnWriteArrayList<Pair<String, String>>()
        override suspend fun retainGroups(groupIds: Set<String>) { retained += groupIds }
        override suspend fun removeIfShowing(groupId: String, sourceId: String) { removed += groupId to sourceId }
    }

    @Before fun setUp() {
        LocalStack.assumeReachable()
        initTestWorkManager(context)
        admin = Admin()
        graphs = Graphs(context, tmp.newFolder("graphs"))
    }

    @After fun tearDown() = runBlocking {
        scope.cancel()
        if (!::admin.isInitialized) return@runBlocking
        for (graph in signedIn) runCatching { if (graph.auth.currentUserId != null) graph.account.deleteAccount() }
        for (account in admin.created) runCatching { admin.deleteUser(account.id) }
        graphs.close()
        admin.close()
    }

    @Test fun membersGetLiveEventsOutsidersNothingAndStreamsResume() = runBlocking {
        val tag = uniqueTag()
        val files = tmp.newFolder("files")
        val ana = admin.createUser("Ana $tag")
        val rui = admin.createUser("Rui $tag")
        val olga = admin.createUser("Olga $tag")
        val a = graphs.signIn(ana).also(signedIn::add)
        val b = graphs.signIn(rui, policy = policy).also(signedIn::add)
        val c = graphs.signIn(olga, policy = policy).also(signedIn::add)
        val group = a.groups.createGroup("it-$tag live", GroupKind.Friends, "UTC")
        b.groups.joinGroup(a.groups.createInvite(group.id).token)

        // Glue on Rui's session.
        val push = FakePush("it-fcm-$tag-${uniqueTag()}")
        val billing = FakeBilling()
        val widgets = FakeWidgets()
        b.startGlue(GlueBridges(push, billing, widgets))
        eventually { b.devices.devices().any { it.pushToken == push.token } }
        assertTrue(billing.calls.contains("identify:${rui.id}"))
        assertEquals(listOf(group.id), b.groups.myGroups().map { it.id })
        eventually { widgets.retained.lastOrNull() == setOf(group.id) }
        b.posts.observeFeed(group.id).last() // fills the offline cache

        val memberEvents = CopyOnWriteArrayList<GroupEvent>()
        val outsiderEvents = CopyOnWriteArrayList<GroupEvent>()
        scope.launch { b.realtime.events(group.id).collect { memberEvents += it } }
        scope.launch { c.realtime.events(group.id).collect { outsiderEvents += it } }
        eventually(20.seconds) {
            memberEvents.filterIsInstance<GroupEvent.Subscribed>().map { it.stream }.toSet() == GroupEvent.Stream.entries.toSet()
        }

        // Postgres-changes subscriptions register asynchronously: probe until one arrives.
        var probes = 0
        eventually(30.seconds, step = 1_000) {
            a.chat.sendText(group.id, "probe-${probes++}")
            memberEvents.any { it is GroupEvent.MessageInserted && it.message.body?.startsWith("probe-") == true }
        }

        val draft = a.uploads.enqueue(NewPost(kind = MediaKind.Photo, original = tinyJpegFile(files, "live.jpg"), groupIds = listOf(group.id)))
        val post = a.posts.post((a.uploader.run(draft) as UploadOutcome.Done).postIds.single())!!
        val text = a.chat.sendText(group.id, "hello $tag")
        val reply = a.chat.sendText(group.id, "look", replyToPostId = post.id)
        a.reactions.react(post.id, "🌅")
        eventually(20.seconds) {
            memberEvents.any { it is GroupEvent.PostInserted && it.post.id == post.id } &&
                memberEvents.any { it is GroupEvent.MessageInserted && it.message.id == text.id } &&
                memberEvents.any { it is GroupEvent.MessageInserted && it.message.kind == MessageKind.Photo && it.message.postId == post.id } &&
                memberEvents.any { it is GroupEvent.ReactionAdded && it.reaction.postId == post.id && it.reaction.emoji == "🌅" }
        }

        a.reactions.unreact(post.id, "🌅")
        a.chat.deleteMessage(text.id)
        a.posts.deletePost(post.id)
        eventually(20.seconds) {
            memberEvents.any { it is GroupEvent.ReactionsChanged && it.postId == post.id } &&
                memberEvents.any { it is GroupEvent.MessageDeleted && it.messageId == text.id } &&
                memberEvents.any { it is GroupEvent.PostDeleted && it.postId == post.id && it.mediaId == post.mediaId } &&
                memberEvents.any { it is GroupEvent.MessageUpdated && it.message.id == reply.id && it.message.replyToPostId == null }
        }
        // Glue: the widget showing the deleted post is cleared; the cached feed page drops it.
        eventually { widgets.removed.contains(group.id to post.id) }
        eventually {
            b.cache.get(CacheKey.feed(group.id), ListSerializer(Post.serializer()))?.value?.none { it.id == post.id } ?: true
        }

        // The outsider: nothing but subscription state; the private deletion topic is refused.
        eventually(20.seconds) { outsiderEvents.any { it is GroupEvent.Unavailable && it.stream == GroupEvent.Stream.Deletions } }
        assertTrue(
            "outsider received ${outsiderEvents.filterNot { it is GroupEvent.Subscribed || it is GroupEvent.Unavailable }}",
            outsiderEvents.all { it is GroupEvent.Subscribed || it is GroupEvent.Unavailable },
        )

        // A dropped socket: the streams re-subscribe (resumed = refetch) and events flow again.
        val resumedBefore = memberEvents.count { it is GroupEvent.Subscribed && it.resumed }
        b.client.realtime.disconnect()
        eventually(30.seconds) { memberEvents.count { it is GroupEvent.Subscribed && it.resumed } >= resumedBefore + 2 }
        var after = 0
        eventually(30.seconds, step = 1_000) {
            a.chat.sendText(group.id, "after-drop-${after++}")
            memberEvents.any { it is GroupEvent.MessageInserted && it.message.body?.startsWith("after-drop-") == true }
        }

        // Sign-out through the glue: device unregistered first, billing reset, widgets and cache cleared.
        b.auth.signOut()
        eventually { b.auth.authState.value == AuthState.SignedOut }
        eventually { billing.calls.contains("reset") && push.deleted && widgets.retained.lastOrNull() == emptySet<String>() }
        assertTrue(admin.select("devices", "push_token=eq.${push.token}&select=id").isEmpty())
        assertEquals(null, b.cache.get(CacheKey.feed(group.id), ListSerializer(Post.serializer())))
        delay(100)
        assertTrue(b.posts.observeFeed(group.id).last().source != DataState.Source.Cache)
    }
}
