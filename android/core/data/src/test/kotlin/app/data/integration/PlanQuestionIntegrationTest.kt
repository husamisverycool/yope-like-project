package app.data.integration

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.data.DataGraph
import app.data.error.ApiError
import app.data.error.DataError
import app.data.media.upload.NewPost
import app.data.media.upload.UploadOutcome
import app.data.model.GroupKind
import app.data.model.MediaKind
import app.data.model.PlanAnswerKind
import io.ktor.http.HttpMethod
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import java.time.Duration
import java.time.Instant

/**
 * Plans (docs/API.md §14.2), the weekly question (§14.4) and a 9 AM photo's reveal (§14.3) through the data layer against
 * the real local stack, as members of one group: a plan's answers and who reads Can't go, edit / cancel / restore by the
 * maker only; the admin switch, the question of the group week from the catalogue, an answer linked through the upload
 * queue's question, Remove; the scheduler's `due_developed_posts` at the reveal turning the photo into a post.
 */
@RunWith(AndroidJUnit4::class)
class PlanQuestionIntegrationTest {
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
        DataGraph.override(null)
        for (graph in signedIn) runCatching { if (graph.auth.currentUserId != null) graph.account.deleteAccount() }
        for (account in admin.created) runCatching { admin.deleteUser(account.id) }
        graphs.close()
        admin.close()
    }

    @Test fun planAnswersCancelAndRestore() = runBlocking {
        val tag = uniqueTag()
        val maya = graphs.signIn(admin.createUser("Maya $tag")).also(signedIn::add)
        val theo = graphs.signIn(admin.createUser("Theo $tag")).also(signedIn::add)
        val lea = graphs.signIn(admin.createUser("Lea $tag")).also(signedIn::add)
        val group = maya.groups.createGroup("it-$tag plans", GroupKind.Family, "Europe/Paris")
        val invite = maya.groups.createInvite(group.id).token
        theo.groups.joinGroup(invite)
        lea.groups.joinGroup(invite)

        val starts = Instant.now().plus(Duration.ofDays(3))
        val plan = maya.plans.create(group.id, "Dinner $tag", starts, allDay = false, place = "Ours")
        assertEquals(group.id, plan.groupId)
        assertEquals("Ours", plan.place)
        assertNull(plan.canceledAt)
        assertEquals(PlanAnswerKind.Going, maya.plans.nextPlans().first { it.id == plan.id }.myAnswer)
        assertNull(theo.plans.nextPlans(group.id).single { it.id == plan.id }.myAnswer)

        // Going is read by every member; Can't go only by its author and the plan's maker.
        theo.plans.answer(plan.id, PlanAnswerKind.Going)
        assertEquals(setOf(PlanAnswerKind.Going), lea.plans.answers(plan.id).map { it.answer }.toSet())
        assertEquals(2, lea.plans.answers(plan.id).size)
        theo.plans.answer(plan.id, PlanAnswerKind.CantGo)
        assertFalse(lea.plans.answers(plan.id).any { it.answer == PlanAnswerKind.CantGo })
        assertTrue(maya.plans.answers(plan.id).any { it.answer == PlanAnswerKind.CantGo })
        theo.plans.clearAnswer(plan.id)
        assertNull(theo.plans.nextPlans(group.id).single { it.id == plan.id }.myAnswer)
        theo.plans.answer(plan.id, PlanAnswerKind.Maybe)

        // Only the maker (or an admin) edits, cancels, restores.
        assertEquals("not_allowed", (expectDataError { theo.plans.cancel(plan.id) } as DataError.Api).raw)
        val edited = maya.plans.update(plan.id, "Dinner moved $tag", starts, allDay = false, place = "Ours", note = null, coverPath = null)
        assertEquals("Dinner moved $tag", edited.title)
        assertNotNull(maya.plans.cancel(plan.id).canceledAt)
        assertFalse(theo.plans.nextPlans(group.id).any { it.id == plan.id })
        assertEquals("plan_canceled", (expectDataError { lea.plans.answer(plan.id, PlanAnswerKind.Going) } as DataError.Api).raw)
        assertNull(maya.plans.restore(plan.id).canceledAt)
        assertEquals(PlanAnswerKind.Maybe, theo.plans.nextPlans(group.id).single { it.id == plan.id }.myAnswer)
    }

    @Test fun weeklyQuestionSwitchAnswerAndRemove() = runBlocking {
        val tag = uniqueTag()
        val maya = graphs.signIn(admin.createUser("Maya $tag")).also(signedIn::add)
        val theo = graphs.signIn(admin.createUser("Theo $tag")).also(signedIn::add)
        val group = maya.groups.createGroup("it-$tag question", GroupKind.Friends, "Europe/Paris")
        theo.groups.joinGroup(maya.groups.createInvite(group.id).token)

        // The catalogue is an owner setting: set for the test, put back after.
        val previous = config("weekly_question_keys")
        try {
            setConfig("weekly_question_keys", JsonArray(listOf(JsonPrimitive("question.weekly.q01"), JsonPrimitive("question.weekly.q02"))))
            assertNull(theo.questions.current(group.id)) // off by default
            expectApi(ApiError.NotGroupAdmin) { theo.questions.setWeekly(group.id, true) }
            maya.questions.setWeekly(group.id, true)
            val question = theo.questions.current(group.id)!!
            assertEquals("question.weekly.q01", question.questionKey)
            assertFalse(question.hiddenByMe)
            assertEquals(question.id, maya.questions.current(group.id)!!.id)

            // Theo answers from the camera: the queue posts the photo and links it to the question.
            DataGraph.override(theo)
            val files = tmp.newFolder("files")
            val draft = theo.uploads.enqueue(
                NewPost(kind = MediaKind.Photo, original = tinyJpegFile(files, "answer.jpg"), groupIds = listOf(group.id), questionId = question.id, questionGroupId = group.id),
            )
            val posted = (theo.uploader.run(draft) as UploadOutcome.Done).postIds.single()
            assertEquals(listOf(posted), maya.questions.answers(question.id).map { it.id })
            expectApi(ApiError.PostNotFound) { maya.questions.answer(posted, question.id) } // only the author links a post

            // Remove: gone for Maya this week, still there for Theo; switched off: no question.
            maya.questions.hide(question.id)
            assertTrue(maya.questions.current(group.id)!!.hiddenByMe)
            assertFalse(theo.questions.current(group.id)!!.hiddenByMe)
            maya.questions.setWeekly(group.id, false)
            assertNull(theo.questions.current(group.id))
        } finally {
            setConfig("weekly_question_keys", previous)
        }
    }

    @Test fun overnightPhotoRevealsAsAPostOfTheGroup() = runBlocking {
        val tag = uniqueTag()
        val maya = graphs.signIn(admin.createUser("Maya $tag")).also(signedIn::add)
        val theo = graphs.signIn(admin.createUser("Theo $tag")).also(signedIn::add)
        val group = maya.groups.createGroup("it-$tag overnight", GroupKind.Friends, "Europe/Paris")
        theo.groups.joinGroup(maya.groups.createInvite(group.id).token)

        DataGraph.override(maya)
        val files = tmp.newFolder("files")
        val draft = maya.uploads.enqueue(NewPost(kind = MediaKind.Photo, original = tinyJpegFile(files, "night.jpg"), width = 1, height = 1, groupIds = listOf(group.id), overnight = true))
        assertEquals(androidx.work.WorkInfo.State.SUCCEEDED, runUploadWork(context, draft).state)
        val second = maya.uploads.enqueue(NewPost(kind = MediaKind.Photo, original = tinyJpegFile(files, "later.jpg"), width = 1, height = 1, groupIds = listOf(group.id), overnight = true))
        assertEquals(androidx.work.WorkInfo.State.SUCCEEDED, runUploadWork(context, second).state)
        val developing = theo.developing.group(group.id)
        assertTrue(developing.developing)
        val reveal = developing.revealAt!!
        assertTrue(theo.posts.feed(group.id).none { it.authorId == maya.auth.currentUserId })

        // What the worker's scheduler does every minute, run at the reveal time.
        val (status, body) = admin.call(HttpMethod.Post, "/rest/v1/rpc/due_developed_posts", JsonObject(mapOf("p_now" to JsonPrimitive(reveal.toString()))))
        assertTrue("due_developed_posts: $status $body", status in 200..299)

        val revealed = theo.posts.feed(group.id).filter { it.authorId == maya.auth.currentUserId }.sortedBy { it.createdAt }
        assertEquals(2, revealed.size)
        assertTrue(revealed.all { it.revealedAt == reveal })
        assertTrue("they keep the time they were taken", revealed.all { it.createdAt < reveal })
        // The reveal push opens the photos revealed together, oldest first (camera.overnight C).
        assertEquals(revealed.map { it.id }, theo.posts.revealed(group.id, reveal).map { it.id })
        assertTrue(theo.posts.revealed(group.id, reveal.plusSeconds(1)).isEmpty())
        assertFalse(theo.developing.group(group.id).developing)
        assertFalse(maya.posts.myDeveloping().developing)
    }

    /** `app_config.value` of [key] (service role). */
    private suspend fun config(key: String): kotlinx.serialization.json.JsonElement {
        val (status, body) = admin.call(HttpMethod.Get, "/rest/v1/app_config?select=value&key=eq.$key")
        assertTrue("app_config: $status $body", status in 200..299)
        return kotlinx.serialization.json.Json.parseToJsonElement(body).jsonArray.firstOrNull()?.jsonObject?.get("value") ?: JsonNull
    }

    private suspend fun setConfig(key: String, value: kotlinx.serialization.json.JsonElement) {
        val (status, body) = admin.call(HttpMethod.Patch, "/rest/v1/app_config?key=eq.$key", JsonObject(mapOf("value" to value)), prefer = "return=minimal")
        assertTrue("app_config: $status $body", status in 200..299)
    }
}
