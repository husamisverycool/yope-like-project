package app.push

import android.Manifest
import android.app.Activity
import android.app.Application
import android.app.Notification
import android.app.NotificationManager
import androidx.core.app.NotificationCompat
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.work.WorkManager
import androidx.work.testing.WorkManagerTestInitHelper
import app.links.DeepLinkIntents
import app.model.DeepLinkCodec
import app.model.QuietHours
import app.widget.WidgetUpdateScheduler
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Shadows.shadowOf
import java.time.Instant
import java.time.LocalTime
import java.time.ZoneOffset

@RunWith(AndroidJUnit4::class)
class PushHandlerTest {
    private val app = ApplicationProvider.getApplicationContext<Application>()
    private val manager get() = app.getSystemService(NotificationManager::class.java)
    private val now = Instant.parse("2026-10-15T12:00:00Z")
    private val handler = PushHandler(app, DeepLinkCodec("example.org")) { now }

    class Host : Activity()

    @Before fun setUp() {
        DeepLinkIntents.targetActivity = Host::class.java
        shadowOf(app).grantPermissions(Manifest.permission.POST_NOTIFICATIONS)
        NotificationAppearance.current = object : NotificationAppearance {
            override val smallIcon = android.R.drawable.ic_dialog_info // test-only stand-in
        }
    }

    @After fun tearDown() {
        DeepLinkIntents.targetActivity = null
        NotificationAppearance.current = object : NotificationAppearance {}
        QuietHoursSource.current = QuietHoursSource { null }
    }

    private fun registerChannels() = NotificationChannels.register(app, name = { it.id })

    private val daily = mapOf(
        "type" to "daily_invitation", "group_id" to "g1", "invitation_id" to "inv1",
        "closes_at" to "2026-10-15T12:02:00Z", "title" to "server title", "body" to "server body",
    )

    @Test fun channelsAreRegisteredByTheCallerWithItsCopy() {
        assertFalse(NotificationChannels.isRegistered(app, AppChannel.DailyInvitation))
        NotificationChannels.register(app, name = { "name:${it.id}" }, description = { "desc" })
        AppChannel.entries.forEach { assertTrue(NotificationChannels.isRegistered(app, it)) }
        val channel = manager.getNotificationChannel(AppChannel.DailyInvitation.id)
        assertEquals("name:daily_invitation", channel.name)
        assertEquals(NotificationManager.IMPORTANCE_HIGH, channel.importance)
    }

    @Test fun nothingIsPostedBeforeChannelsExist() {
        assertEquals(PushHandler.Outcome.NotShown, handler.handle(daily))
        assertTrue(shadowOf(manager).allNotifications.isEmpty())
    }

    @Test fun dailyInvitationIsADismissibleCountdownUntilClosesAt() {
        registerChannels()
        assertEquals(PushHandler.Outcome.CountdownShown, handler.handle(daily))
        val n: Notification = shadowOf(manager).allNotifications.single()
        val closesAt = Instant.parse("2026-10-15T12:02:00Z").toEpochMilli()
        // daily.ongoing: not ongoing (swipe dismisses), removed on tap, never promoted (C-11).
        assertTrue(n.flags and Notification.FLAG_ONGOING_EVENT == 0)
        assertTrue(n.flags and Notification.FLAG_AUTO_CANCEL != 0)
        assertFalse(n.extras.getBoolean(NotificationCompat.EXTRA_REQUEST_PROMOTED_ONGOING))
        assertEquals(closesAt, n.`when`)
        assertTrue(n.extras.getBoolean(Notification.EXTRA_SHOW_CHRONOMETER))
        assertTrue(n.extras.getBoolean(Notification.EXTRA_CHRONOMETER_COUNT_DOWN))
        assertEquals(120_000L, n.timeoutAfter)
        assertEquals(AppChannel.DailyInvitation.id, n.channelId)
        assertEquals("server title", n.extras.getString(Notification.EXTRA_TITLE))
        assertEquals("app://daily?group=g1&invitation=inv1", shadowOf(n.contentIntent).savedIntent.dataString)
    }

    @Test fun skewedDeviceClockIsCorrectedFromServerSendTime() {
        registerChannels()
        // Device clock is 5 minutes behind the server.
        PushHandler(app, DeepLinkCodec(null)) { now.minusSeconds(300) }.handle(daily + ("sent_at" to "2026-10-15T12:00:00Z"))
        val n = shadowOf(manager).allNotifications.single()
        assertEquals(Instant.parse("2026-10-15T11:57:00Z").toEpochMilli(), n.`when`)
        assertEquals(120_000L, n.timeoutAfter)
    }

    @Test fun closedWindowShowsNothingAndEndedRemovesTheCountdown() {
        registerChannels()
        assertEquals(PushHandler.Outcome.NotShown, handler.handle(daily + ("closes_at" to "2026-10-15T11:59:59Z")))
        handler.handle(daily)
        assertEquals(1, shadowOf(manager).allNotifications.size)
        assertEquals(
            PushHandler.Outcome.CountdownEnded,
            handler.handle(mapOf("type" to "daily_invitation_ended", "group_id" to "g1", "invitation_id" to "inv1")),
        )
        assertTrue(shadowOf(manager).allNotifications.isEmpty())
    }

    @Test fun withoutNotificationPermissionNothingIsPosted() {
        registerChannels()
        shadowOf(app).denyPermissions(Manifest.permission.POST_NOTIFICATIONS)
        assertEquals(PushHandler.Outcome.NotShown, handler.handle(daily))
    }

    @Test fun widgetMessageQueuesAnExpeditedRefresh() {
        WorkManagerTestInitHelper.initializeTestWorkManager(app)
        val outcome = handler.handle(
            mapOf("type" to "widget", "group_id" to "g1", "rendition_url" to "https://s.example/w.jpg", "posted_at" to "2026-10-15T12:00:00Z"),
        )
        assertEquals(PushHandler.Outcome.WidgetRefreshQueued, outcome)
        val infos = WorkManager.getInstance(app).getWorkInfosForUniqueWork(WidgetUpdateScheduler.uniqueWorkName("g1")).get()
        assertEquals(1, infos.size)
        assertTrue(shadowOf(manager).allNotifications.isEmpty())
    }

    @Test fun alertsGoToTheirChannelAndDeepLink() {
        registerChannels()
        val outcome = handler.handle(mapOf("type" to "reply", "group_id" to "g1", "message_id" to "m1", "title" to "t", "body" to "b"))
        assertEquals(PushHandler.Outcome.AlertShown, outcome)
        val n = shadowOf(manager).allNotifications.single()
        assertEquals(AppChannel.ReactionsAndReplies.id, n.channelId)
        assertTrue(n.flags and Notification.FLAG_AUTO_CANCEL != 0)
        assertEquals("app://chat?group=g1&message=m1", shadowOf(n.contentIntent).savedIntent.dataString)
    }

    @Test fun quietHoursMakeAlertsSilentNotDropped() {
        registerChannels()
        QuietHoursSource.current = QuietHoursSource { QuietHours(LocalTime.of(11, 0), LocalTime.of(13, 0)) to ZoneOffset.UTC }
        handler.handle(mapOf("type" to "new_post", "group_id" to "g1", "post_id" to "p1", "title" to "t"))
        val quiet = shadowOf(manager).allNotifications.single()
        assertEquals(Notification.GROUP_ALERT_SUMMARY, quiet.groupAlertBehavior)

        QuietHoursSource.current = QuietHoursSource { null }
        handler.handle(mapOf("type" to "new_post", "group_id" to "g1", "post_id" to "p2", "title" to "t"))
        val loud = shadowOf(manager).allNotifications.first { it !== quiet && it.extras.getString(Notification.EXTRA_TITLE) == "t" && it.groupAlertBehavior != Notification.GROUP_ALERT_SUMMARY }
        assertNotEquals(Notification.GROUP_ALERT_SUMMARY, loud.groupAlertBehavior)
    }

    @Test fun unknownMessagesAreIgnored() {
        assertEquals(PushHandler.Outcome.Ignored, handler.handle(mapOf("type" to "streak_reminder", "title" to "x")))
    }

    @Test fun tokensAreHandedToTheSink() {
        val received = mutableListOf<String>()
        PushTokens.sink = PushTokenSink { received += it }
        PushTokens.onNewToken(app, "tok-1")
        assertEquals(listOf("tok-1"), received)
        assertEquals("tok-1", PushTokens.lastKnown(app))
        PushTokens.sink = null
    }
}
