package app.model

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant

class WidgetSnapshotTest {
    private val base = WidgetSnapshot(
        groupId = "g", groupName = "Roommates", photoFile = "1760000000000-p1.jpg", senderName = "Ana",
        caption = "hi", kind = WidgetSnapshot.Kind.Photo, postedAtEpochMillis = 1_760_000_000_000, sourceId = "p1",
    )

    @Test fun jsonRoundTrip() {
        val json = base.toJson()
        assertTrue(json.contains("\"kind\":\"photo\""))
        assertTrue(json.contains("\"postedAt\":1760000000000"))
        assertEquals(base, WidgetSnapshot.fromJson(json))
    }

    @Test fun toleratesUnknownFieldsAndRejectsGarbage() {
        val json = base.toJson().replace("{", "{\"future\":1,")
        assertEquals(base, WidgetSnapshot.fromJson(json))
        assertNull(WidgetSnapshot.fromJson("{"))
        assertNull(WidgetSnapshot.fromJson("{\"groupId\":\"g\"}"))
    }

    @Test fun newestWins() {
        val older = base.copy(postedAtEpochMillis = base.postedAtEpochMillis - 1, sourceId = "p0")
        val collage = base.copy(kind = WidgetSnapshot.Kind.Collage, postedAtEpochMillis = base.postedAtEpochMillis + 1, sourceId = "c1")
        assertTrue(base.supersedes(null))
        assertTrue(base.supersedes(older))
        assertFalse(older.supersedes(base))
        assertTrue(collage.supersedes(base))
        assertFalse(base.supersedes(base))
        assertEquals(Instant.ofEpochMilli(1_760_000_000_000), base.postedAt)
    }
}

class PushMessageTest {
    private val codec = DeepLinkCodec("example.org")

    @Test fun widgetUpdate() {
        val m = PushMessage.parse(
            mapOf(
                "type" to "widget", "group_id" to "g1", "group_name" to "Family", "rendition_url" to "https://cdn.example/w.jpg?sig=1",
                "kind" to "collage", "posted_at" to "2026-10-15T12:00:00Z", "collage_id" to "c1",
            ),
            codec,
        ) as PushMessage.WidgetUpdate
        assertEquals("g1", m.groupId)
        assertEquals(WidgetSnapshot.Kind.Collage, m.kind)
        assertEquals("c1", m.sourceId)
        assertEquals(Instant.parse("2026-10-15T12:00:00Z"), m.postedAt)
        assertNull(m.senderId)
    }

    /** `sender_id`: the poster, for friend widgets; an unsafe id is dropped, the message still parses. */
    @Test fun widgetUpdateCarriesTheSender() {
        val base = mapOf("type" to "widget", "group_id" to "g1", "rendition_url" to "https://x/y", "posted_at" to "1760000000000", "post_id" to "p1")
        assertEquals("u1", (PushMessage.parse(base + ("sender_id" to "u1"), codec) as PushMessage.WidgetUpdate).senderId)
        assertNull((PushMessage.parse(base + ("sender_id" to "../x"), codec) as PushMessage.WidgetUpdate).senderId)
    }

    @Test fun widgetUpdateRequiresHttpsAndKnownKind() {
        val ok = mapOf("type" to "widget", "group_id" to "g1", "rendition_url" to "https://x/y", "posted_at" to "1760000000000")
        assertTrue(PushMessage.parse(ok, codec) is PushMessage.WidgetUpdate)
        assertNull(PushMessage.parse(ok + ("rendition_url" to "http://x/y"), codec))
        assertNull(PushMessage.parse(ok + ("rendition_url" to "file:///data/x"), codec))
        assertNull(PushMessage.parse(ok + ("kind" to "video"), codec))
        assertNull(PushMessage.parse(ok + ("group_id" to "../g"), codec))
        assertNull(PushMessage.parse(ok - "posted_at", codec))
    }

    @Test fun dailyInvitation() {
        val m = PushMessage.parse(
            mapOf(
                "type" to "daily_invitation", "group_id" to "g", "invitation_id" to "i", "closes_at" to "2026-10-15T12:02:00Z",
                "title" to "t", "body" to "b", "sent_at" to "2026-10-15T12:00:00Z",
            ),
            codec,
        ) as PushMessage.DailyInvitation
        assertEquals(Instant.parse("2026-10-15T12:02:00Z"), m.closesAt)
        assertEquals(DeepLink.DailyInvitation("g", "i"), m.link)
        assertNull(PushMessage.parse(mapOf("type" to "daily_invitation", "group_id" to "g", "invitation_id" to "i", "title" to "t"), codec))
        assertEquals(
            PushMessage.DailyInvitationEnded("g", "i"),
            PushMessage.parse(mapOf("type" to "daily_invitation_ended", "group_id" to "g", "invitation_id" to "i"), codec),
        )
    }

    @Test fun alertsDeriveTheirRoute() {
        fun alert(vararg kv: Pair<String, String>) = PushMessage.parse(mapOf("title" to "t", "group_id" to "g", *kv), codec) as PushMessage.Alert
        assertEquals(DeepLink.Post("g", "p"), alert("type" to "new_post", "post_id" to "p").link)
        assertEquals(DeepLink.Post("g", "p"), alert("type" to "reaction", "post_id" to "p").link)
        assertEquals(DeepLink.ChatMessage("g", "m"), alert("type" to "reply", "post_id" to "p", "message_id" to "m").link)
        assertEquals(DeepLink.Recap("g", "r"), alert("type" to "recap_ready", "recap_id" to "r").link)
        assertEquals(DeepLink.BirthdayRequest("g", "r"), alert("type" to "birthday_request", "request_id" to "r").link)
        assertEquals(DeepLink.Tribute("g", "t"), alert("type" to "tribute", "tribute_id" to "t").link)
        assertEquals(DeepLink.YearStory("g", 2026), alert("type" to "year_story", "year" to "2026").link)
        assertEquals(PushMessage.AlertKind.TributeForYou, alert("type" to "tribute").kind)
        // the overnight reveal: new_post with revealed_at, opening its first photo
        val reveal = alert("type" to "new_post", "group_id" to "g", "post_id" to "p", "revealed_at" to "2026-10-17T07:00:00Z")
        assertEquals(PushMessage.AlertKind.PhotosDeveloped, reveal.kind)
        assertEquals(DeepLink.Post("g", "p"), reveal.link)
        assertEquals(PushMessage.AlertKind.NewPost, alert("type" to "new_post", "revealed_at" to "not a time").kind)
    }

    @Test fun explicitLinkWinsAndUnknownTypesAreIgnored() {
        val m = PushMessage.parse(
            mapOf("type" to "new_post", "title" to "t", "group_id" to "g", "post_id" to "p", "link" to "app://chat?group=g&message=m"),
            codec,
        ) as PushMessage.Alert
        assertEquals(DeepLink.ChatMessage("g", "m"), m.link)
        assertNull(PushMessage.parse(mapOf("type" to "streak", "title" to "t"), codec))
        assertNull(PushMessage.parse(mapOf("type" to "new_post"), codec))
        assertNull(PushMessage.parse(emptyMap(), codec))
    }

    @Test fun parsesInstants() {
        assertEquals(Instant.ofEpochMilli(5), PushMessage.parseInstant("5"))
        assertEquals(Instant.parse("2026-01-01T00:00:00Z"), PushMessage.parseInstant("2026-01-01T00:00:00Z"))
        assertNull(PushMessage.parseInstant("yesterday"))
        assertNull(PushMessage.parseInstant("99999999999999999999999"))
    }
}
