package app.data

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.data.model.DataJson
import app.data.model.DayMemory
import app.data.model.PersonPhoto
import app.data.model.WidgetPerson
import io.ktor.http.HttpStatusCode
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.jsonObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

/**
 * The friend and memories widgets' functions (migration 0036, 0038; design/surfaces/widget.friend.md, widget.memories.md):
 * the rows exactly as PostgREST returns the SQL's columns, and the arguments on the wire.
 */
@RunWith(AndroidJUnit4::class)
class WidgetDataTest {
    @get:Rule val tmp = TemporaryFolder()

    private val context: Context = ApplicationProvider.getApplicationContext()
    private val me = "9f0c2b7e-1111-4111-8111-111111111111"
    private val personRow = """{"user_id":"u2","display_name":"Ana Lima","avatar_path":null}"""
    private val photoRow = """{"post_id":"p1","media_id":"m1","group_id":"g1","group_name":"Sunday dinners","author_id":"u3",
        "author_name":"Rui","author_avatar_path":"u/u3/avatar.jpg","widget_path":"u/u3/m1/widget.jpg","caption":null,
        "visible_at":"2026-10-17T09:00:00.123+00:00","via":"tag"}"""
    private val memoryRow = """{"day":"2026-10-17","post_id":"p9","media_id":"m9","group_id":"g1","group_name":"Sunday dinners",
        "author_id":"$me","author_name":"Me","widget_path":null,"taken_at":"2024-10-17T18:30:00+00:00","years_ago":2}"""

    @Test fun rowsDecodeFromTheSqlColumns() {
        assertEquals(WidgetPerson("u2", "Ana Lima", null), DataJson.decodeFromString(WidgetPerson.serializer(), personRow))
        val photo = DataJson.decodeFromString(PersonPhoto.serializer(), photoRow)
        assertEquals("u3", photo.authorId)
        assertEquals(PersonPhoto.VIA_TAG, photo.via)
        assertEquals(Instant.parse("2026-10-17T09:00:00.123Z"), photo.visibleAt)
        assertEquals("u/u3/m1/widget.jpg", photo.widgetPath)
        val memory = DataJson.decodeFromString(DayMemory.serializer(), memoryRow)
        assertEquals(LocalDate.parse("2026-10-17"), memory.day)
        assertEquals(2, memory.yearsAgo)
        assertNull("rendition not made yet", memory.widgetPath)
    }

    @Test fun callsSendTheFunctionsArguments() = runBlocking {
        val m = MockSupabase(context, tmp.newFolder("mock")) { _, seen ->
            when (seen.path) {
                "/rest/v1/rpc/widget_people" -> json("[$personRow]")
                "/rest/v1/rpc/newest_photos_of" -> json("[$photoRow]")
                "/rest/v1/rpc/my_memories" -> json("[$memoryRow]")
                else -> json("{}", HttpStatusCode.NotFound)
            }
        }
        m.signIn(me)
        assertEquals(listOf("u2"), m.graph.widgets.people().map { it.userId })

        assertEquals(listOf("p1"), m.graph.widgets.newestPhotosOf("u2").map { it.postId })
        val newest = DataJson.parseToJsonElement(m.requests.last().body).jsonObject
        assertEquals(JsonPrimitive("u2"), newest["p_user_id"])
        assertEquals(JsonPrimitive(3), newest["p_limit"])

        val days = m.graph.widgets.memories(LocalDate.parse("2026-10-17"), 7, ZoneId.of("Europe/Lisbon"))
        assertEquals(listOf("p9"), days.map { it.postId })
        val memories = DataJson.parseToJsonElement(m.requests.last().body).jsonObject
        assertEquals(JsonPrimitive("2026-10-17"), memories["p_from"])
        assertEquals(JsonPrimitive(7), memories["p_days"])
        assertEquals(JsonPrimitive("Europe/Lisbon"), memories["p_time_zone"])
    }
}
