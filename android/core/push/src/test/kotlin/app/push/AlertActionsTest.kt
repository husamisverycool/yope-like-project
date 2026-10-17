package app.push

import android.Manifest
import android.app.Activity
import android.app.Application
import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.os.Bundle
import androidx.core.app.NotificationCompat
import androidx.core.app.RemoteInput
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.links.DeepLinkIntents
import app.model.DeepLinkCodec
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import java.time.Instant

/**
 * notifications.push "Actions": Reply (direct reply), the first quick reaction and "Mute This Group" on photo, reply and
 * reaction alerts; none on the daily invitation, recaps or the memory notification; what a tap sends; success removes the
 * alert, a failure replaces it with the "couldn't send" line. Also the Memories channel of the memory notification.
 */
@RunWith(AndroidJUnit4::class)
@Config(qualifiers = "en-rUS")
class AlertActionsTest {
    private val app = ApplicationProvider.getApplicationContext<Application>()
    private val manager get() = app.getSystemService(NotificationManager::class.java)
    private val handler = PushHandler(app, DeepLinkCodec("example.org")) { Instant.parse("2026-10-17T12:00:00Z") }

    class Host : Activity()

    private class Recorder(var fail: Boolean = false) : AlertActionPerformer {
        val calls = mutableListOf<String>()
        override suspend fun reply(groupId: String, body: String, replyToPostId: String?, replyToMessageId: String?) {
            calls += "reply:$groupId:$body:$replyToPostId:$replyToMessageId"
            if (fail) error("offline")
        }
        override suspend fun react(postId: String, emoji: String) {
            calls += "react:$postId:$emoji"
            if (fail) error("offline")
        }
        override suspend fun muteGroup(groupId: String) {
            calls += "mute:$groupId"
            if (fail) error("offline")
        }
    }

    @Before fun setUp() {
        DeepLinkIntents.targetActivity = Host::class.java
        shadowOf(app).grantPermissions(Manifest.permission.POST_NOTIFICATIONS)
        NotificationAppearance.current = object : NotificationAppearance {
            override val smallIcon = android.R.drawable.ic_dialog_info // test-only stand-in
        }
        ChannelCopy.registerAll(app)
    }

    @After fun tearDown() {
        DeepLinkIntents.targetActivity = null
        NotificationAppearance.current = object : NotificationAppearance {}
        AlertActions.performer = null
    }

    /** Posts the alert and returns the notification it showed (the shade's list is not in posting order). */
    private fun post(vararg kv: Pair<String, String>): Notification {
        val before = shadowOf(manager).allNotifications.toList()
        assertEquals(PushHandler.Outcome.AlertShown, handler.handle(mapOf("title" to "Sunday Dinners", "body" to "b", *kv)))
        return shadowOf(manager).allNotifications.first { n -> before.none { it === n } }
    }

    private fun titles(n: Notification) = n.actions.orEmpty().map { it.title.toString() }

    /** The broadcast the action's PendingIntent sends, with [reply] typed into its RemoteInput. */
    private fun fire(action: Notification.Action, reply: String? = null): AlertActionRequest {
        val intent = Intent(shadowOf(action.actionIntent).savedIntent)
        if (reply != null) {
            val input = RemoteInput.Builder(AlertActions.KEY_REPLY).build()
            RemoteInput.addResultsToIntent(arrayOf(input), intent, Bundle().apply { putCharSequence(AlertActions.KEY_REPLY, reply) })
        }
        return requireNotNull(AlertActions.request(intent))
    }

    @Test fun aNewPhotoOffersReplyTheQuickReactionAndMute() {
        val n = post("type" to "new_post", "group_id" to "g1", "post_id" to "p1", "collapse_key" to "post:p1")
        assertEquals(listOf("Reply", "🔥", "Mute This Group"), titles(n))
        val reply = n.actions[0]
        assertEquals("Reply…", reply.remoteInputs.single().label.toString())
        assertEquals(AlertActions.KEY_REPLY, reply.remoteInputs.single().resultKey)
        assertEquals(Notification.Action.SEMANTIC_ACTION_REPLY, reply.semanticAction)
        assertEquals(Notification.Action.SEMANTIC_ACTION_MUTE, n.actions[2].semanticAction)
        // Every action asks for the unlocked device and runs in the background (a broadcast, no activity).
        n.actions.forEach { assertTrue(it.isAuthenticationRequired) }
        assertTrue(shadowOf(reply.actionIntent).isBroadcastIntent)
        // RemoteInput needs a mutable PendingIntent; the others are immutable.
        assertTrue(shadowOf(reply.actionIntent).flags and PendingIntent.FLAG_MUTABLE != 0)
        assertTrue(shadowOf(n.actions[1].actionIntent).flags and PendingIntent.FLAG_IMMUTABLE != 0)
    }

    @Test fun repliesAndReactionsOfferReplyAndMuteAndOtherAlertsNothing() {
        assertEquals(listOf("Reply", "Mute This Group"), titles(post("type" to "reply", "group_id" to "g1", "message_id" to "m1", "collapse_key" to "reply:m1")))
        assertEquals(listOf("Reply", "Mute This Group"), titles(post("type" to "reaction", "group_id" to "g1", "post_id" to "p2", "collapse_key" to "reaction:p2")))
        assertEquals(emptyList<String>(), titles(post("type" to "recap_ready", "group_id" to "g1", "recap_id" to "r1")))
        assertEquals(emptyList<String>(), titles(post("type" to "memory", "group_id" to "g1", "post_id" to "p3", "collapse_key" to "memory:u:2026-10-17")))
        assertEquals(emptyList<String>(), titles(post("type" to "plan", "group_id" to "g1", "plan_id" to "pl1", "collapse_key" to "plan:pl1")))
        // The daily invitation (an invitation, never a task) has no actions either.
        handler.handle(mapOf("type" to "daily_invitation", "group_id" to "g1", "invitation_id" to "i1", "closes_at" to "2026-10-17T12:02:00Z", "title" to "t"))
        val invitation = shadowOf(manager).allNotifications.first { it.channelId == AppChannel.DailyInvitation.id }
        assertTrue(invitation.actions.isNullOrEmpty())
    }

    @Test fun eachNotificationKeepsItsOwnActionExtras() {
        val first = post("type" to "new_post", "group_id" to "g1", "post_id" to "p1", "collapse_key" to "post:p1")
        val second = post("type" to "new_post", "group_id" to "g2", "post_id" to "p2", "collapse_key" to "post:p2")
        assertEquals("p1", fire(first.actions[1]).postId)
        assertEquals("p2", fire(second.actions[1]).postId)
        assertEquals("g2", fire(second.actions[2]).groupId)
    }

    @Test fun aReplyIsSentToTheMessageOrThePhotoAndRemovesTheAlert() = runBlocking {
        val recorder = Recorder()
        AlertActions.performer = recorder
        val message = post("type" to "reply", "group_id" to "g1", "message_id" to "m1", "collapse_key" to "reply:m1")
        assertTrue(AlertActions.perform(app, fire(message.actions[0], reply = "  on my way ")))
        val photo = post("type" to "new_post", "group_id" to "g1", "post_id" to "p1", "collapse_key" to "post:p1")
        assertTrue(AlertActions.perform(app, fire(photo.actions[0], reply = "so good")))
        assertEquals(listOf("reply:g1:on my way:null:m1", "reply:g1:so good:p1:null"), recorder.calls)
        assertTrue(shadowOf(manager).allNotifications.isEmpty())
    }

    @Test fun theReactionAndTheMuteActOnTheAlertsPhotoAndGroup() = runBlocking {
        val recorder = Recorder()
        AlertActions.performer = recorder
        val n = post("type" to "new_post", "group_id" to "g1", "post_id" to "p1", "collapse_key" to "post:p1")
        assertTrue(AlertActions.perform(app, fire(n.actions[1])))
        val again = post("type" to "new_post", "group_id" to "g1", "post_id" to "p1", "collapse_key" to "post:p1")
        assertTrue(AlertActions.perform(app, fire(again.actions[2])))
        assertEquals(listOf("react:p1:🔥", "mute:g1"), recorder.calls)
    }

    @Test fun aFailedReplyShowsCouldntSendInTheAlertsPlace() = runBlocking {
        AlertActions.performer = Recorder(fail = true)
        val n = post("type" to "new_post", "group_id" to "g1", "post_id" to "p1", "collapse_key" to "post:p1")
        assertFalse(AlertActions.perform(app, fire(n.actions[0], reply = "so good")))
        val notice = shadowOf(manager).allNotifications.single()
        assertEquals("Sunday Dinners", notice.extras.getString(Notification.EXTRA_TITLE))
        assertEquals("Couldn't send. Tap to retry", notice.extras.getCharSequence(Notification.EXTRA_TEXT).toString())
        assertTrue(notice.actions.isNullOrEmpty())
        // A tap opens what the alert opened.
        assertEquals("app://post?group=g1&post=p1", shadowOf(notice.contentIntent).savedIntent.dataString)
        assertEquals(NotificationCompat.CATEGORY_ERROR, notice.category)
    }

    @Test fun noBackendOrABlankReplyFails() = runBlocking {
        val n = post("type" to "new_post", "group_id" to "g1", "post_id" to "p1", "collapse_key" to "post:p1")
        assertFalse(AlertActions.perform(app, fire(n.actions[2])))
        assertEquals("There was a problem saving your changes. Please try again.", shadowOf(manager).allNotifications.single().extras.getCharSequence(Notification.EXTRA_TEXT).toString())
        val recorder = Recorder()
        AlertActions.performer = recorder
        val again = post("type" to "new_post", "group_id" to "g1", "post_id" to "p1", "collapse_key" to "post:p1")
        assertFalse(AlertActions.perform(app, fire(again.actions[0], reply = "   ")))
        assertTrue(recorder.calls.isEmpty())
    }

    @Test fun foreignBroadcastsAreIgnored() {
        assertNull(AlertActions.request(Intent()))
        assertNull(AlertActions.request(Intent().putExtra("app.push.action", "reply")))
    }

    @Test fun theQuickReactionIsTheFirstTokenEmoji() {
        assertEquals("🔥", AlertActions.quickReaction)
        assertEquals("💖", AlertActions.firstEmoji("💖 then 🔥"))
        assertNull(AlertActions.firstEmoji("then 🔥"))
    }

    @Test fun theMemoryNotificationHasItsOwnChannelAndOpensThePhoto() {
        val channel = manager.getNotificationChannel("memories")
        assertNotNull(channel)
        assertEquals("Memories", channel.name)
        assertEquals("Your memories from this day over the years", channel.description)
        assertEquals(NotificationManager.IMPORTANCE_DEFAULT, channel.importance)
        val n = post("type" to "memory", "group_id" to "g1", "post_id" to "p9", "collapse_key" to "memory:u:2026-10-17")
        assertEquals("memories", n.channelId)
        assertEquals("app://post?group=g1&post=p9", shadowOf(n.contentIntent).savedIntent.dataString)
    }
}
