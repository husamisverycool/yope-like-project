package app.feature.social

import android.Manifest
import android.app.Application
import androidx.compose.material3.Text
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.semantics.getOrNull
import androidx.compose.ui.test.hasSetTextAction
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.longClick
import androidx.compose.ui.test.onAllNodesWithContentDescription
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onFirst
import androidx.compose.ui.test.onLast
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performImeAction
import androidx.compose.ui.test.performTextInput
import androidx.compose.ui.test.performTouchInput
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.data.repo.ReactionEntry
import app.feature.social.FakeSocialData.Companion.ANA
import app.feature.social.FakeSocialData.Companion.BASE
import app.feature.social.FakeSocialData.Companion.BEN
import app.feature.social.FakeSocialData.Companion.GROUP
import app.feature.social.FakeSocialData.Companion.ME
import app.feature.social.chat.ChatNav
import app.feature.social.chat.ChatScreen
import app.feature.social.chat.ChatViewModel
import app.feature.social.week.WeekEditSheet
import app.feature.social.week.WeekEditViewModel
import app.model.AppRoute
import app.model.PhotoContext
import app.model.PhotoViewerIn
import app.model.SocialHandoff
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Shadows
import org.robolectric.annotation.Config
import java.time.LocalDate

/** The social group's flows end to end on Robolectric, over [FakeSocialData]. */
@RunWith(AndroidJUnit4::class)
@Config(qualifiers = "w393dp-h852dp-xhdpi")
@OptIn(ExperimentalCoroutinesApi::class)
class SocialFlowTest {
    @get:Rule val compose = createComposeRule()
    private val chatNav = ChatNav({}, {}, {}, {}, {}, {}, {}, { _, _ -> })

    @Before fun setUp() {
        fixLocale()
        Dispatchers.setMain(UnconfinedTestDispatcher())
        app.feature.social.week.RecapEdits.pending.value = emptyMap()
    }

    @After fun tearDown() = Dispatchers.resetMain()

    private fun chat(data: FakeSocialData): ChatViewModel {
        val vm = ChatViewModel(data, GROUP)
        compose.setContent { TestScreen(data) { ChatScreen(vm, null, chatNav) } }
        compose.waitForIdle()
        return vm
    }

    @Test fun sendText() {
        val data = FakeSocialData().apply { seedChat() }
        chat(data)
        compose.onNode(hasSetTextAction()).performTextInput("on my way")
        compose.onNode(hasSetTextAction()).performImeAction()
        compose.waitForIdle()
        assertTrue(data.calls.contains("sendText:on my way:"))
        compose.onNodeWithContentDescription("you, on my way").assertExists()
    }

    @Test fun sendVoice() {
        Shadows.shadowOf(ApplicationProvider.getApplicationContext<Application>()).grantPermissions(Manifest.permission.RECORD_AUDIO)
        val data = FakeSocialData().apply { seedChat() }
        chat(data)
        compose.onNodeWithContentDescription("record a voice message").performClick()
        assertTrue(testVoice.recording)
        compose.onNodeWithContentDescription("record a voice message").performClick()
        compose.waitForIdle()
        assertFalse(testVoice.recording)
        assertTrue(data.calls.contains("sendVoice:${FakeVoice.DURATION_MS}"))
    }

    @Test fun reactFromTheThread() {
        val data = FakeSocialData().apply { seedChat() }
        chat(data)
        compose.onNodeWithContentDescription("Ana’s pic, 8:01 PM", substring = true).performTouchInput { longClick() }
        compose.waitForIdle()
        compose.onAllNodesWithContentDescription("fire").onFirst().performClick()
        compose.waitForIdle()
        assertTrue(data.calls.contains("react:p-1:🔥"))
    }

    /** Tenet 2: reaction labels name emoji, never a number (cluster labels, TalkBack). */
    @Test fun noCountsInReactionLabels() {
        val data = FakeSocialData().apply { seedChat() }
        data.reactions["p-1"] = (1..9).map { i -> ReactionEntry(if (i % 2 == 0) ANA else BEN, if (i % 3 == 0) "🔥" else "😍") }.toMutableList()
        chat(data)
        val labels = compose.onAllNodesWithContentDescription("Reactions:", substring = true).fetchSemanticsNodes()
            .flatMap { it.config.getOrNull(SemanticsProperties.ContentDescription).orEmpty() }
        assertTrue(labels.isNotEmpty())
        labels.forEach { label ->
            val reactions = label.substringAfter("Reactions:")
            assertFalse("no number in \"$reactions\"", reactions.any(Char::isDigit))
        }
        assertTrue(compose.onAllNodesWithText("9").fetchSemanticsNodes().isEmpty())
    }

    private fun viewerData() = FakeSocialData().apply {
        seedGroup()
        addPhoto("v-1", ANA, BASE.minusSeconds(86_400))
        addPhoto("v-2", ME, BASE)
    }

    private fun viewerHost(data: FakeSocialData, postId: String): () -> NavHostController {
        lateinit var nav: NavHostController
        compose.setContent {
            TestScreen(data) {
                nav = rememberNavController()
                NavHost(nav, startDestination = PhotoViewerIn(GROUP, postId, PhotoContext.Single, postId)) {
                    socialDestinations(nav)
                    composable<AppRoute.Camera> { entry ->
                        Text(entry.savedStateHandle.get<String>(SocialHandoff.REPLY_TO_POST_ID) ?: "none", Modifier.testTag("camera"))
                    }
                }
            }
        }
        compose.waitForIdle()
        return { nav }
    }

    @Test fun replyToAPhotoWithTextAndWithAPhoto() {
        val data = viewerData()
        viewerHost(data, "v-1")
        compose.onNode(hasSetTextAction()).performTextInput("where is this")
        compose.onNode(hasSetTextAction()).performImeAction()
        compose.waitForIdle()
        assertTrue(data.calls.contains("sendText:where is this:v-1"))

        compose.onNodeWithContentDescription("React with fire").performClick()
        compose.waitForIdle()
        assertTrue(data.calls.contains("react:v-1:🔥"))

        compose.onNodeWithContentDescription("send a pic").performClick()
        compose.waitForIdle()
        compose.onNodeWithTag("camera").assertExists()
        compose.onNodeWithText("v-1").assertExists()
    }

    @Test fun deleteEverywhere() {
        val data = viewerData()
        val nav = viewerHost(data, "v-2")
        compose.onNodeWithContentDescription("more").performClick()
        compose.waitForIdle()
        compose.onNodeWithText("delete").performClick()
        compose.waitForIdle()
        compose.onNodeWithText("delete this pic?").assertExists()
        compose.onAllNodesWithText("delete").onLast().performClick()
        compose.waitForIdle()
        assertTrue(data.calls.contains("deleteMedia:md-v-2"))
        assertFalse("the viewer closed (its only photo is gone)", nav().currentDestination?.route?.contains("PhotoViewerIn") == true && data.posts.containsKey("v-2"))
    }

    @Test fun editRecapAndSaveIt() {
        val data = FakeSocialData().apply { seedWeek() }
        val vm = WeekEditViewModel(data, GROUP, "r-w", null, albumOnly = false)
        var closed = false
        compose.setContent { TestScreen(data) { WeekEditSheet(vm, onClose = { closed = true }) } }
        compose.waitForIdle()
        compose.onNodeWithContentDescription("Ana’s pic, Oct 18 2026").performClick()
        compose.waitForIdle()
        assertTrue("w-7" in vm.state.value.checked)
        compose.onAllNodesWithText("save").onLast().performClick()
        compose.waitForIdle()
        assertTrue(data.calls.contains("updateRecap:" + (1..7).joinToString(",") { "w-$it" } + ":the best week"))
        assertTrue(closed)
    }

    @Test fun saveAWeekAsANamedAlbum() {
        val data = FakeSocialData().apply { seedWeek() }
        val vm = WeekEditViewModel(data, GROUP, null, LocalDate.parse("2026-10-12"), albumOnly = true)
        var closed = false
        compose.setContent { TestScreen(data) { WeekEditSheet(vm, onClose = { closed = true }) } }
        compose.waitForIdle()
        compose.onNode(hasSetTextAction()).performTextInput("lake week")
        compose.onNodeWithText("save").performClick()
        compose.waitForIdle()
        assertTrue(data.calls.contains("saveAlbum:lake week:" + (1..7).joinToString(",") { "w-$it" }))
        assertTrue(closed)
        assertEquals("lake week", data.albums.values.single().name)
    }
}
