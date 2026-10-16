package app.data

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.data.error.DataError
import app.data.error.DataException
import app.data.media.upload.NewPost
import app.data.media.upload.PostDraft
import app.data.media.upload.PostRemote
import app.data.media.upload.PostUploader
import app.data.media.upload.UploadOutcome
import app.data.media.upload.UploadStore
import app.data.media.upload.DraftFile
import app.data.model.CurrentQuestion
import app.data.model.DataJson
import app.data.model.DevelopingPost
import app.data.model.Group
import app.data.model.MediaKind
import app.data.model.NewMedia
import app.data.model.NextPlan
import app.data.model.Plan
import app.data.model.PlanAnswerKind
import app.data.model.Post
import app.data.remote.Rpc
import app.data.remote.rpcArgs
import app.data.repo.PostOptions
import io.ktor.http.HttpStatusCode
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.toList
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
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
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import java.io.File
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

/** Plans, the weekly question and a group's developing state (docs/API.md §14.2–§14.4): rows, RPC arguments, calls, the question link. */
@RunWith(AndroidJUnit4::class)
class PlansDataTest {
    @get:Rule val tmp = TemporaryFolder()

    private val context: Context = ApplicationProvider.getApplicationContext()
    private val me = "9f0c2b7e-1111-4111-8111-111111111111"
    private val planRow = """{"id":"p1","group_id":"g1","created_by":"$me","title":"Picnic","starts_at":"2026-10-24T17:30:00+00:00","ends_at":null,
        "all_day":false,"local_date":"2026-10-24","place":"Park","note":null,"cover_path":null,"canceled_at":null,"canceled_by":null,
        "created_at":"2026-10-16T10:00:00+00:00","updated_at":"2026-10-16T10:00:00+00:00"}"""

    @Test fun rowsDecode() {
        val plan = DataJson.decodeFromString(Plan.serializer(), planRow)
        assertEquals(LocalDate.parse("2026-10-24"), plan.localDate)
        assertFalse(plan.canceled)
        val utc = ZoneId.of("UTC")
        assertFalse(plan.isOver(Instant.parse("2026-10-24T23:59:59Z"), utc))
        assertTrue(plan.isOver(Instant.parse("2026-10-25T00:00:00Z"), utc))
        // A day ends in the group's time zone, not the device's.
        assertFalse(plan.isOver(Instant.parse("2026-10-25T03:00:00Z"), ZoneId.of("America/Los_Angeles")))

        val next = DataJson.decodeFromString(ListSerializer(NextPlan.serializer()), """[{"id":"p1","group_id":"g1","created_by":null,"title":"Picnic",
            "starts_at":"2026-10-24T00:00:00+00:00","ends_at":null,"all_day":true,"local_date":"2026-10-24","place":null,"cover_path":"u/x/covers/c.jpg","my_answer":"cant_go"}]""")
        assertEquals(PlanAnswerKind.CantGo, next.single().myAnswer)
        assertNull(DataJson.decodeFromString(NextPlan.serializer(), """{"id":"p1","group_id":"g1","created_by":null,"title":"t","starts_at":"2026-10-24T00:00:00Z",
            "ends_at":null,"all_day":true,"local_date":"2026-10-24","place":null,"cover_path":null,"my_answer":null}""").myAnswer)

        val question = DataJson.decodeFromString(CurrentQuestion.serializer(), """{"id":"q1","question_key":"question.weekly.q01","week_start":"2026-10-12","hidden_by_me":false}""")
        assertEquals("question.weekly.q01", question.questionKey)

        // groups.weekly_question (default off) and posts.question_id.
        val group = DataJson.decodeFromString(Group.serializer(), """{"id":"g1","name":"n","kind":"friends","cover_path":null,"time_zone":"UTC","waking_start":null,
            "waking_end":null,"invitation_paused":false,"created_by":null,"created_at":"2026-10-15T13:35:09Z","updated_at":"2026-10-15T13:35:09Z","weekly_question":true}""")
        assertTrue(group.weeklyQuestion)
        assertFalse(group.copy(weeklyQuestion = false).weeklyQuestion)
        val post = DataJson.decodeFromString(Post.serializer(), """{"id":"p","media_id":"m","group_id":"g","author_id":"u","caption":null,"voice_path":null,"voice_duration_ms":null,
            "invitation_id":null,"in_window":false,"reply_to_post_id":null,"created_at":"2026-10-15T23:10:00Z","voice_levels":null,"revealed_at":null,"question_id":"q1"}""")
        assertEquals("q1", post.questionId)
    }

    @Test fun rpcArgumentsFollowTheSpec() {
        assertThrows(IllegalArgumentException::class.java) { rpcArgs(Rpc.CreatePlan) { put("p_group_id", "g"); put("p_title", "t") } }
        assertTrue(rpcArgs(Rpc.NextPlans) { opt("p_group_id", null as String?) }.isEmpty())
        // answer_question always sends the question (null unlinks).
        assertThrows(IllegalArgumentException::class.java) { rpcArgs(Rpc.AnswerQuestion) { put("p_post_id", "p") } }
        assertEquals(JsonNull, rpcArgs(Rpc.AnswerQuestion) { put("p_post_id", "p"); put("p_question_id", null as String?) }["p_question_id"])
        assertEquals(setOf("p_group_id"), rpcArgs(Rpc.GroupDeveloping) { put("p_group_id", "g") }.keys)
    }

    private fun body(m: MockSupabase, path: String): JsonObject = DataJson.parseToJsonElement(m.requests.last { it.path == path }.body).jsonObject

    @Test fun planCallsOnTheWire() = runBlocking {
        val m = MockSupabase(context, tmp.newFolder("mock")) { _, seen ->
            when {
                seen.path.startsWith("/storage/v1/object/media/") -> json("""{"Key":"media/x","Id":"1"}""")
                seen.path == "/rest/v1/rpc/create_plan" || seen.path == "/rest/v1/rpc/update_plan" || seen.path == "/rest/v1/rpc/cancel_plan" -> json(planRow)
                seen.path == "/rest/v1/rpc/answer_plan" -> json("""{"plan_id":"p1","user_id":"$me","group_id":"g1","answer":"maybe","answered_at":"2026-10-16T10:00:00+00:00"}""")
                seen.path == "/rest/v1/rpc/clear_answer" -> noContent()
                seen.path == "/rest/v1/rpc/next_plans" -> json("[]")
                seen.path == "/rest/v1/rpc/group_developing" -> json("""[{"developing":true,"reveal_at":"2026-10-17T07:00:00+00:00"}]""")
                seen.path == "/rest/v1/rpc/current_group_question" -> json("[]")
                seen.path == "/rest/v1/plans" -> json("[$planRow]")
                seen.path == "/rest/v1/plan_answers" -> json("[]")
                else -> json("{}", HttpStatusCode.NotFound)
            }
        }
        m.signIn(me)
        val changes = mutableListOf<String>()
        val collector = CoroutineScope(Dispatchers.Unconfined).launch { m.graph.plans.changes.collect { changes += it } }

        val cover = m.graph.plans.uploadCover(tmp.newFile("cover.jpg").apply { writeBytes(ByteArray(8) { 1 }) })
        assertTrue(cover.startsWith("u/$me/covers/"))
        m.graph.plans.create("g1", "Picnic", Instant.parse("2026-10-24T17:30:00Z"), allDay = false, place = "Park", coverPath = cover)
        val create = body(m, "/rest/v1/rpc/create_plan")
        assertEquals(JsonPrimitive(cover), create["p_cover_path"])
        assertFalse("no end time is sent", create.containsKey("p_ends_at"))
        assertFalse("no note: omitted", create.containsKey("p_note"))
        assertEquals(JsonPrimitive(false), create["p_all_day"])

        // update_plan replaces every field: the cover is kept by sending it, a cleared note is JSON null.
        m.graph.plans.update("p1", "Picnic", Instant.parse("2026-10-24T17:30:00Z"), allDay = true, place = null, note = null, coverPath = cover)
        val update = body(m, "/rest/v1/rpc/update_plan")
        assertEquals(JsonPrimitive(cover), update["p_cover_path"])
        assertEquals(JsonNull, update["p_note"])
        assertEquals(JsonNull, update["p_place"])

        assertEquals(PlanAnswerKind.Maybe, m.graph.plans.answer("p1", PlanAnswerKind.Maybe).answer)
        assertEquals(JsonPrimitive("maybe"), body(m, "/rest/v1/rpc/answer_plan")["p_answer"])
        m.graph.plans.clearAnswer("p1")
        m.graph.plans.cancel("p1")
        assertTrue(m.graph.plans.nextPlans().isEmpty())
        assertTrue(body(m, "/rest/v1/rpc/next_plans").isEmpty())
        assertEquals(listOf("p1", "p1", "p1", "p1", "p1"), changes)
        collector.cancel()

        val detail = m.graph.plans.observeDetail("p1").toList().last()
        assertEquals("Picnic", detail.value?.plan?.title)
        assertFalse("never a count", m.requests.last { it.path == "/rest/v1/plan_answers" }.query.contains("count"))

        assertTrue(m.graph.developing.group("g1").developing)
        assertNull("off for the group: no question", m.graph.questions.current("g1"))
        m.graph.close()
    }

    @Test fun aMissingPlanReadsAsNotFound() = runBlocking {
        val m = MockSupabase(context, tmp.newFolder("mock")) { _, seen ->
            if (seen.path == "/rest/v1/plans") json("[]") else json("{}", HttpStatusCode.NotFound)
        }
        m.signIn(me)
        val last = m.graph.plans.observeDetail("gone").toList().last()
        assertNull(last.value)
        assertNull(last.error)
        assertFalse(last.refreshing)
        m.graph.close()
    }

    /** Records the question link; the remote's other steps succeed. */
    private class QuestionRemote : PostRemote {
        val answered = mutableListOf<Pair<String, String>>()
        var failAnswer: DataError? = null
        override suspend fun upload(path: String, file: File, contentType: String, onProgress: (Long, Long) -> Unit) = Unit
        override suspend fun insertMedia(media: NewMedia) = Unit
        override suspend fun createPost(mediaId: String, groupIds: List<String>, options: PostOptions): List<Post> =
            groupIds.map { Post("post-$it", mediaId, it, "u", null, null, null, null, false, null, Instant.EPOCH) }
        override suspend fun postsOfMedia(mediaId: String): List<Post> = emptyList()
        override suspend fun createOvernightPost(mediaId: String, groupIds: List<String>): List<DevelopingPost> = emptyList()
        override suspend fun answerQuestion(postId: String, questionId: String) {
            failAnswer?.let { throw DataException(it) }
            answered += postId to questionId
        }
    }

    private fun draft(store: UploadStore, questionId: String?, questionGroupId: String?): String {
        val local = tmp.newFile().apply { writeBytes(ByteArray(4) { 1 }) }
        val d = PostDraft(
            mediaId = "m-" + System.nanoTime(),
            ownerId = me,
            kind = MediaKind.Photo,
            original = DraftFile(local.path, "u/$me/m/original.jpg", "image/jpeg", 4),
            groupIds = listOf("g1", "g2"),
            questionId = questionId,
            questionGroupId = questionGroupId,
        )
        store.save(d)
        return d.id
    }

    @Test fun onlyThePostInTheQuestionsGroupIsLinkedAndAFailedLinkIsNotAFailedUpload() = runBlocking {
        val store = UploadStore(tmp.newFolder("uploads"))
        val remote = QuestionRemote()
        val uploader = PostUploader(remote, store)
        assertEquals(UploadOutcome.Done(listOf("post-g1", "post-g2")), uploader.run(draft(store, "q1", "g2")))
        assertEquals(listOf("post-g2" to "q1"), remote.answered)
        // No question: nothing is linked.
        uploader.run(draft(store, null, null))
        assertEquals(1, remote.answered.size)
        // The week ended meanwhile (question_closed): the photo is still posted.
        remote.failAnswer = DataError.Unexpected("question_closed")
        assertTrue(uploader.run(draft(store, "q1", "g1")) is UploadOutcome.Done)
    }

    @Test fun newPostKeepsTheQuestionOnlyForOneOfItsGroups() {
        val file = tmp.newFile("x.jpg").apply { writeBytes(ByteArray(4) { 1 }) }
        val post = NewPost(MediaKind.Photo, file, groupIds = listOf("g1"), questionId = "q1", questionGroupId = "g1")
        assertEquals("q1", post.questionId)
        assertEquals("g1", post.questionGroupId)
    }
}
