package app.data

import app.data.model.Collage
import app.data.model.DataJson
import app.data.model.Entitlement
import app.data.model.Group
import app.data.model.HistoryMonth
import app.data.model.GroupKind
import app.data.model.InstantSerializer
import app.data.model.InvitePreview
import app.data.model.Media
import app.data.model.MediaKind
import app.data.model.Message
import app.data.model.MessageKind
import app.data.model.NewMedia
import app.data.model.PhotoSearchHit
import app.data.model.Post
import app.data.model.Profile
import app.data.model.PublicAppConfig
import app.data.model.PublicAppConfigRow
import app.data.model.WallItem
import app.data.model.WallItemKind
import app.data.realtime.GroupEvent
import app.data.realtime.RealtimeDecoding
import app.data.remote.Api
import app.data.remote.Rpc
import app.data.remote.rpcArgs
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.jsonObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime

/** JSON ↔ models exactly as PostgREST and Realtime send them; RPC argument building. */
class ModelMappingTest {

    @Test fun timestampsInEveryShapePostgresAndRealtimeUse() {
        val expected = Instant.parse("2026-10-15T13:35:09.329469Z")
        for (text in listOf("2026-10-15T13:35:09.329469+00:00", "2026-10-15 13:35:09.329469+00", "2026-10-15T15:35:09.329469+02:00", "2026-10-15T13:35:09.329469Z")) {
            assertEquals(text, expected, InstantSerializer.parse(text))
        }
        assertEquals("2026-10-15T13:35:09.329469Z", InstantSerializer.format(expected.plusNanos(123)))
    }

    @Test fun groupRowDecodesIncludingTimesAndEnums() {
        val group = DataJson.decodeFromString(Group.serializer(), """
            {"id":"g1","name":"Lima family","kind":"family","cover_path":null,"time_zone":"Europe/Paris",
             "waking_start":"09:00:00","waking_end":"21:12:00","invitation_paused":false,"created_by":"u1",
             "created_at":"2026-10-15T13:35:09.329469+00:00","updated_at":"2026-10-15T13:35:09.329469+00:00","some_future_column":1}
        """)
        assertEquals(GroupKind.Family, group.kind)
        assertEquals(LocalTime.of(21, 12), group.wakingEnd)
    }

    @Test fun invitePreviewMatchesTheDocumentedExample() {
        val preview = DataJson.decodeFromString(InvitePreview.serializer(), """
            {"group_name":"Lima family","group_kind":"family","cover_path":"u/9f/covers/1c.jpg","inviter_first_name":"Ana",
             "members":[{"first_name":"Ana","avatar_path":"avatars/9f/a1.jpg"},{"first_name":"Rui","avatar_path":null}]}
        """)
        assertEquals(listOf("Ana", "Rui"), preview.members.map { it.firstName })
        assertNull(preview.members[1].avatarPath)
    }

    @Test fun wallRowsAndPublicConfig() {
        val rows = DataJson.decodeFromString(ListSerializer(WallItem.serializer()), """
            [{"item_kind":"post","post_id":"p","media_id":"m","collage_id":null,"group_ids":["g1","g2"],"created_at":"2026-10-15T13:35:09+00:00"},
             {"item_kind":"collage","post_id":null,"media_id":null,"collage_id":"c","group_ids":["g1"],"created_at":"2026-10-14T13:35:09+00:00"}]
        """)
        assertEquals(listOf(WallItemKind.Post, WallItemKind.Collage), rows.map { it.itemKind })
        val config = PublicAppConfig.from(listOf(
            PublicAppConfigRow("invitation_window_seconds", JsonPrimitive(120)),
            PublicAppConfigRow("min_age_years", JsonNull),
            PublicAppConfigRow("free_history_days", null),
        ))
        assertEquals(120, config.invitationWindowSeconds)
        assertNull(config.minAgeYears)
        assertNull(config.freeHistoryDays)
    }

    @Test fun searchHitsAndHistoryMonthsDecodeAndSearchArgumentsAreOptional() {
        val hits = DataJson.decodeFromString(ListSerializer(PhotoSearchHit.serializer()), """
            [{"post_id":"p1","media_id":"m1","group_id":"g1","author_id":"u1","created_at":"2026-10-15T13:35:09.329469+00:00","matched":["caption","tag"]},
             {"post_id":"p2","media_id":"m2","group_id":"g1","author_id":"u2","created_at":"2026-10-14T13:35:09+00:00","matched":null}]
        """)
        assertEquals(listOf(listOf("caption", "tag"), null), hits.map { it.matched })
        assertTrue(hits[0].createdAt.isAfter(hits[1].createdAt))
        val months = DataJson.decodeFromString(ListSerializer(HistoryMonth.serializer()), """
            [{"month":"2026-10-01","days":["2026-10-03","2026-10-15"],"newest_week":"2026-10-12"},
             {"month":"2026-09-01","days":["2026-09-30"],"newest_week":"2026-09-28"}]
        """)
        assertEquals(listOf(LocalDate.parse("2026-10-01"), LocalDate.parse("2026-09-01")), months.map { it.month })
        assertEquals(listOf(LocalDate.parse("2026-10-03"), LocalDate.parse("2026-10-15")), months[0].days)
        assertEquals(LocalDate.parse("2026-09-28"), months[1].newestWeek)
        // Every search argument is optional (the server asks for at least one criterion); an unknown key is refused.
        val search = rpcArgs(Rpc.SearchPhotos) {
            put("p_text", "snow")
            opt("p_member_id", null as String?)
            put("p_from", LocalDate.parse("2026-10-01"))
            put("p_limit", 60)
        }
        assertEquals(setOf("p_text", "p_from", "p_limit"), search.keys)
        assertEquals(JsonPrimitive("2026-10-01"), search["p_from"])
        assertThrows(IllegalArgumentException::class.java) { rpcArgs(Rpc.SearchPhotos) { put("p_query", "x") } }
        assertEquals(setOf("p_group_id"), rpcArgs(Rpc.GroupHistoryMonths) { put("p_group_id", "g") }.keys)
    }

    @Test fun mediaPicksRenditionsOnlyOnceReady() {
        val base = Media("m", "u", MediaKind.Photo, "u/u/m/original.jpg", "u/u/m/front.jpg", null, null, null, null, null, null, 1, 1, 1, 1, null, null, Instant.EPOCH)
        assertEquals("u/u/m/original.jpg", base.imagePath(Media.Rendition.Thumb))
        assertEquals("u/u/m/front.jpg", base.frontImagePath(Media.Rendition.Display))
        val ready = base.copy(displayPath = "u/u/m/r/d.jpg", thumbPath = "u/u/m/r/t.jpg", widgetPath = "u/u/m/r/w.jpg", frontThumbPath = "u/u/m/r/ft.jpg", renditionsReadyAt = Instant.EPOCH)
        assertEquals("u/u/m/r/w.jpg", ready.imagePath(Media.Rendition.Widget))
        assertEquals("u/u/m/r/ft.jpg", ready.frontImagePath(Media.Rendition.Thumb))
        assertEquals("u/u/m/front.jpg", ready.frontImagePath(Media.Rendition.Display)) // no front display rendition: original
        // A video's original is the movie: its poster renditions show before the transcode finishes.
        val video = base.copy(kind = MediaKind.Video, originalPath = "u/u/m/original.mp4", frontOriginalPath = null, thumbPath = "u/u/m/r/thumb.jpg")
        assertEquals("u/u/m/r/thumb.jpg", video.imagePath(Media.Rendition.Thumb))
    }

    @Test fun collagePagesFollowPageCount() {
        val collage = Collage("c", "g", null, "B", listOf("p"), "g/g/collages/c/v1/display-1.jpg", null, null, app.data.model.RenderStatus.Ready, null, Instant.EPOCH, pageCount = 3)
        assertEquals(listOf("g/g/collages/c/v1/display-1.jpg", "g/g/collages/c/v1/display-2.jpg", "g/g/collages/c/v1/display-3.jpg"), collage.pagePaths())
        assertTrue(collage.copy(imagePath = null).pagePaths().isEmpty())
        // A row without page_count (before migration 0015) still decodes.
        val old = DataJson.decodeFromString(Collage.serializer(), """{"id":"c","group_id":"g","invitation_id":null,"option":"A","post_ids":[],"image_path":null,"widget_path":null,"share_path":null,"status":"pending","composed_at":null,"created_at":"2026-10-15T13:35:09+00:00"}""")
        assertEquals(1, old.pageCount)
    }

    @Test fun newMediaSendsOnlyTheColumnsClientsMayInsert() {
        val json = DataJson.encodeToJsonElement(NewMedia.serializer(), NewMedia("m", MediaKind.LivePhoto, "u/u/m/original.jpg", motionPath = "u/u/m/motion.mp4", durationMs = 1500)).jsonObject
        assertEquals(setOf("id", "kind", "original_path", "front_original_path", "motion_path", "width", "height", "front_width", "front_height", "duration_ms"), json.keys)
        assertEquals(JsonPrimitive("live_photo"), json["kind"])
    }

    @Test fun profileFirstNameAndEntitlementActivity() {
        val profile = Profile("u", "  Ana   Lima ", null, Instant.EPOCH, Instant.EPOCH)
        assertEquals("Ana", profile.firstName)
        assertNull(profile.copy(displayName = "").firstName)
        val now = Instant.parse("2026-10-15T00:00:00Z")
        assertTrue(Entitlement("u", "premium", null, "revenuecat", now).isActive(now))
        assertFalse(Entitlement("u", "premium", now.minusSeconds(1), "revenuecat", now).isActive(now))
    }

    @Test fun rpcArgumentsFollowTheSpec() {
        val update = rpcArgs(Rpc.UpdateGroup) {
            put("p_group_id", "g")
            opt("p_name", null as String?)
            put("p_cover_path", "")
        }
        assertEquals(setOf("p_group_id", "p_cover_path"), update.keys) // null = unchanged → omitted
        val hours = rpcArgs(Rpc.SetGroupInvitationHours) {
            put("p_group_id", "g")
            put("p_start", null as LocalTime?)
            put("p_end", null as LocalTime?)
        }
        assertEquals(JsonNull, hours["p_start"]) // both null = back to the default window: sent explicitly
        assertEquals(JsonPrimitive("09:30:00"), rpcArgs(Rpc.SetQuietHours) {
            put("p_start", LocalTime.of(9, 30)); put("p_end", LocalTime.of(7, 0)); put("p_time_zone", "UTC")
        }["p_start"])
        assertThrows(IllegalArgumentException::class.java) { rpcArgs(Rpc.React) { put("p_post_id", "p"); put("p_emojii", "x") } }
        assertThrows(IllegalArgumentException::class.java) { rpcArgs(Rpc.React) { put("p_post_id", "p") } }
        assertEquals(Rpc.entries.size, Rpc.entries.map { it.function }.toSet().size)
    }

    @Test fun jwtSubjectIsReadFromTheAccessToken() {
        assertEquals("abc-123", Api.jwtSubject(MockSupabase.jwt("abc-123")))
        assertNull(Api.jwtSubject("garbage"))
    }

    @Test fun realtimeRecordsDecodeToTypedEvents() {
        val message = JsonObject(mapOf(
            "id" to JsonPrimitive("m1"), "group_id" to JsonPrimitive("g1"), "author_id" to JsonPrimitive("u1"), "kind" to JsonPrimitive("text"),
            "body" to JsonPrimitive("hi"), "post_id" to JsonNull, "voice_path" to JsonNull, "voice_duration_ms" to JsonNull,
            "reply_to_post_id" to JsonNull, "reply_to_message_id" to JsonNull, "created_at" to JsonPrimitive("2026-10-15T13:35:09.329469+00:00"),
        ))
        val inserted = RealtimeDecoding.change("g1", "messages", message, update = false) as GroupEvent.MessageInserted
        assertEquals(MessageKind.Text, inserted.message.kind)
        assertTrue(RealtimeDecoding.change("g1", "messages", message, update = true) is GroupEvent.MessageUpdated)
        assertNull(RealtimeDecoding.change("other-group", "messages", message, update = false)) // defence in depth
        assertNull(RealtimeDecoding.change("g1", "posts", message, update = false)) // wrong shape → dropped

        val bare = JsonObject(mapOf("post_id" to JsonPrimitive("p1"), "media_id" to JsonPrimitive("m1")))
        val wrapped = JsonObject(mapOf("event" to JsonPrimitive("post_deleted"), "type" to JsonPrimitive("broadcast"), "payload" to bare))
        assertEquals(GroupEvent.PostDeleted("g1", "p1", "m1"), RealtimeDecoding.broadcast("g1", "post_deleted", bare))
        assertEquals(GroupEvent.PostDeleted("g1", "p1", "m1"), RealtimeDecoding.broadcast("g1", "post_deleted", wrapped))
        assertEquals(GroupEvent.MessageDeleted("g1", "m9"), RealtimeDecoding.broadcast("g1", "message_deleted", JsonObject(mapOf("message_id" to JsonPrimitive("m9")))))
        assertEquals(GroupEvent.ReactionsChanged("g1", "p1"), RealtimeDecoding.broadcast("g1", "reactions_changed", bare))
        // create_overnight_post and due_developed_posts send it with an empty payload.
        assertEquals(GroupEvent.DevelopingChanged("g1"), RealtimeDecoding.broadcast("g1", "developing_changed", JsonObject(emptyMap())))
        assertNull(RealtimeDecoding.broadcast("g1", "unknown_event", bare))
    }

    @Test fun postAndMessageRowsRoundTrip() {
        val post = Post("p", "m", "g", "u", "cap", null, null, null, true, null, Instant.parse("2026-10-15T13:35:09.329469Z"))
        assertEquals(post, DataJson.decodeFromString(Post.serializer(), DataJson.encodeToString(Post.serializer(), post)))
        val message = Message("x", "g", "u", MessageKind.Photo, null, "p", null, null, null, null, Instant.EPOCH)
        assertEquals(message, DataJson.decodeFromString(Message.serializer(), DataJson.encodeToString(Message.serializer(), message)))
    }

    @Test fun anOvernightPhotoIsVisibleFromItsRevealOthersFromWhenTaken() {
        val taken = Instant.parse("2026-10-11T21:30:00Z")
        val shared = Post("p", "m", "g", "u", null, null, null, null, false, null, taken)
        assertEquals(taken, shared.visibleAt)
        // the server's generated visible_at column is ignored (computed the same way on the client)
        val row = """{"id":"p","media_id":"m","group_id":"g","author_id":"u","caption":null,"voice_path":null,"voice_duration_ms":null,
            "invitation_id":null,"in_window":false,"reply_to_post_id":null,"created_at":"2026-10-11T21:30:00Z",
            "revealed_at":"2026-10-12T07:00:00Z","visible_at":"2026-10-12T07:00:00Z"}"""
        val overnight = DataJson.decodeFromString(Post.serializer(), row)
        assertEquals(Instant.parse("2026-10-12T07:00:00Z"), overnight.visibleAt)
        assertEquals(taken, overnight.createdAt)
    }
}
