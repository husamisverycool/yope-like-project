package app.feature.social

import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.semantics.getOrNull
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assertIsSelected
import androidx.compose.ui.test.hasSetTextAction
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.longClick
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextReplacement
import androidx.compose.ui.test.performTouchInput
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.data.model.ChatTyping
import app.data.model.MessageKind
import app.data.model.PublicAppConfig
import app.feature.social.FakeSocialData.Companion.ANA
import app.feature.social.FakeSocialData.Companion.BASE
import app.feature.social.FakeSocialData.Companion.BEN
import app.feature.social.FakeSocialData.Companion.GROUP
import app.feature.social.chat.ChatLinks
import app.feature.social.chat.ChatNav
import app.feature.social.chat.ChatScreen
import app.feature.social.chat.ChatViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

/**
 * Owner decision 34 on screen (Robolectric, semantics only — no image captures): the quick-reaction row on a text
 * message, Edit and the edit bar, "Edited", the typing line and tappable links.
 */
@RunWith(AndroidJUnit4::class)
@Config(qualifiers = "w393dp-h852dp-xhdpi")
@OptIn(ExperimentalCoroutinesApi::class)
class ChatMessageFeaturesUiTest {
    @get:Rule val compose = createComposeRule()
    private val chatNav = ChatNav({}, {}, {}, {}, {}, { _, _ -> }, {})
    /** One minute after my "no way" (seedChat m-5, BASE + 300 s): inside the edit window. */
    private val clock = MutableClock(BASE.plusSeconds(360))

    @Before fun setUp() {
        fixLocale()
        Dispatchers.setMain(UnconfinedTestDispatcher())
    }

    @After fun tearDown() = Dispatchers.resetMain()

    private fun chat(data: FakeSocialData): ChatViewModel {
        val vm = ChatViewModel(data, GROUP, clock)
        compose.setContent { TestScreen(data) { ChatScreen(vm, null, chatNav) } }
        compose.waitForIdle()
        return vm
    }

    private fun data(configure: FakeSocialData.() -> Unit = {}) = FakeSocialData().apply {
        seedChat()
        config = PublicAppConfig(invitationWindowSeconds = null, maxGroupMembers = null, weekStartIsodow = null, freeHistoryDays = null, minAgeYears = null, messageEditWindowSeconds = 900, typingTtlSeconds = 6)
        configure()
    }

    /** `chat.reactions.layout.messageReactions`: long press on Ben's text → the quick row; the chip names the emoji. */
    @Test fun aTextMessageTakesAReactionFromTheQuickRow() {
        val data = data()
        chat(data)
        compose.onNodeWithContentDescription("Ben, strictly vibes only tonight").performTouchInput { longClick() }
        compose.waitForIdle()
        compose.onNodeWithContentDescription("React with fire").performClick()
        compose.waitForIdle()
        assertTrue(data.calls.contains("reactToMessage:m-2:🔥"))
        compose.onNodeWithContentDescription("Reactions: fire").assertExists()

        compose.onNodeWithContentDescription("Ben, strictly vibes only tonight").performTouchInput { longClick() }
        compose.waitForIdle()
        compose.onNodeWithContentDescription("React with fire").assertIsSelected().performClick()
        compose.waitForIdle()
        assertTrue("my own emoji again takes it back", data.calls.contains("unreactToMessage:m-2"))
        compose.onNodeWithContentDescription("Reactions: fire").assertDoesNotExist()
    }

    /** `chat.thread.layout.editMessage`: Edit on my text → the edit bar holds it; send saves; "Edited" is read with it. */
    @Test fun editingMyMessage() {
        val data = data()
        chat(data)
        compose.onNodeWithContentDescription("Ben, strictly vibes only tonight").performTouchInput { longClick() }
        compose.waitForIdle()
        compose.onNodeWithText("Edit").assertDoesNotExist()
        compose.onNodeWithText("Reply").performClick()
        compose.waitForIdle()

        compose.onNodeWithContentDescription("You, no way").performTouchInput { longClick() }
        compose.waitForIdle()
        compose.onNodeWithText("Edit").performClick()
        compose.waitForIdle()
        compose.onNodeWithText("Edit message").assertExists()
        compose.onNodeWithText("Replying to Ben").assertDoesNotExist()
        compose.onNode(hasSetTextAction()).performTextReplacement("no way!")
        compose.waitForIdle()
        compose.onNodeWithContentDescription("Send").performClick()
        compose.waitForIdle()
        assertTrue(data.calls.contains("editMessage:m-5:no way!"))
        compose.onNodeWithText("Edit message").assertDoesNotExist()
        compose.onNodeWithContentDescription("You, no way!")
            .assert(SemanticsMatcher.expectValue(SemanticsProperties.StateDescription, "Edited"))
    }

    @Test fun cancellingAnEdit() {
        val data = data()
        chat(data)
        compose.onNodeWithContentDescription("You, no way").performTouchInput { longClick() }
        compose.waitForIdle()
        compose.onNodeWithText("Edit").performClick()
        compose.waitForIdle()
        compose.onNodeWithContentDescription("Cancel edit").performClick()
        compose.waitForIdle()
        compose.onNodeWithText("Edit message").assertDoesNotExist()
        assertTrue(data.calls.none { it.startsWith("editMessage") })
    }

    /** `chat.thread.layout.typingLine`: names only, above the composer. */
    @Test fun theTypingLineNamesWhoIsTyping() {
        val data = data {
            typingNow = clock.now
            typingRows += ChatTyping(GROUP, ANA, clock.now.plusSeconds(6))
            typingRows += ChatTyping(GROUP, BEN, clock.now.plusSeconds(6))
        }
        chat(data)
        compose.onNodeWithTag("chat.typing").assertExists()
        compose.onNodeWithText("Ana and Ben are typing…").assertExists()
    }

    /** `chat.thread.layout.links`: the platform's detector, http(s) only; each link is an action of the message. */
    @Test fun linksInATextMessage() {
        val text = "menu at https://example.com/menu and www.example.org, mail me@example.com"
        val links = ChatLinks.find(text)
        assertEquals(listOf("https://example.com/menu", "http://www.example.org"), links.map { it.url })
        assertEquals(listOf("https://example.com/menu", "www.example.org"), links.map { text.substring(it.start, it.end) })
        assertTrue(ChatLinks.find("no way").isEmpty())

        val data = data {
            messages += FakeSocialData.message("m-9", GROUP, BEN, MessageKind.Text, body = "menu: https://example.com/menu", at = BASE.plusSeconds(500))
        }
        chat(data)
        compose.onNodeWithContentDescription("Ben, menu: https://example.com/menu").assert(
            SemanticsMatcher("has the link as an action") { node ->
                node.config.getOrNull(SemanticsActions.CustomActions)?.any { it.label == "https://example.com/menu" } == true
            },
        )
    }
}
