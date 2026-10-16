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
import androidx.compose.ui.test.click
import androidx.compose.ui.test.performTextInput
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.performScrollToNode
import androidx.compose.ui.test.performSemanticsAction
import androidx.compose.ui.test.assertIsSelected
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.data.model.MessageKind
import app.data.repo.ReactionEntry
import app.feature.social.FakeSocialData.Companion.ANA
import app.feature.social.FakeSocialData.Companion.BEN
import app.feature.social.FakeSocialData.Companion.GROUP
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
    private companion object {
        /** Longer than the platform long-press timeout: a hold, not a tap. */
        const val HOLD_MS = 1_000L
        /** Far enough to pass the cancel point / reach the lock (px at xhdpi). */
        const val SLIDE_PX = 500f
    }

    @get:Rule val compose = createComposeRule()
    private val chatNav = ChatNav({}, {}, {}, {}, {}, { _, _ -> }, {})

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

    /**
     * `chat.thread.layout.followNewest`: scrolled up to older messages, someone else's new message leaves the reader where
     * they were; my own (here a reply sent from the photo viewer, arriving by realtime) brings the thread to it.
     */
    @Test fun myNewMessageIsFollowedOthersAreNotWhenScrolledUp() {
        val data = FakeSocialData().apply {
            seedChat()
            repeat(30) { i -> messages += FakeSocialData.message("x-$i", GROUP, if (i % 2 == 0) ANA else BEN, MessageKind.Text, body = "earlier $i", at = FakeSocialData.BASE.minusSeconds(600L * (30 - i))) }
        }
        chat(data)
        compose.onNode(androidx.compose.ui.test.hasScrollToIndexAction())
            .performScrollToNode(androidx.compose.ui.test.hasContentDescription("earlier 0", substring = true))
        compose.waitForIdle()
        fun shown(text: String) = compose.onAllNodesWithContentDescription(text, substring = true).fetchSemanticsNodes().isNotEmpty()
        assertFalse("scrolled up: the newest message is out of view", shown("valid"))

        data.eventsOf(GROUP).tryEmit(app.data.realtime.GroupEvent.MessageInserted(
            GROUP,
            FakeSocialData.message("n-1", GROUP, ANA, MessageKind.Text, body = "while you read", at = FakeSocialData.BASE.plusSeconds(1_000)),
        ))
        compose.waitForIdle()
        assertFalse("someone else's message does not move the list", shown("while you read"))
        assertTrue(shown("earlier 0"))

        data.eventsOf(GROUP).tryEmit(app.data.realtime.GroupEvent.MessageInserted(
            GROUP,
            FakeSocialData.message("n-2", GROUP, FakeSocialData.ME, MessageKind.Text, body = "love this", replyToPostId = "p-1", at = FakeSocialData.BASE.plusSeconds(1_100)),
        ))
        compose.waitForIdle()
        assertTrue("my own message is brought into view", shown("love this"))
    }

    /** Typing swaps camera + mic for the send glyph (`chat.composer.layout.typingState`); send sends and clears. */
    @Test fun sendText() {
        val data = FakeSocialData().apply { seedChat() }
        chat(data)
        compose.onNodeWithContentDescription("Record a voice message").assertExists()
        compose.onNode(hasSetTextAction()).performTextInput("on my way")
        compose.waitForIdle()
        compose.onNodeWithContentDescription("Record a voice message").assertDoesNotExist()
        compose.onNodeWithContentDescription("Send").performClick()
        compose.waitForIdle()
        assertTrue(data.calls.contains("sendText:on my way:"))
        compose.onNodeWithContentDescription("You, on my way").assertExists()
        compose.onNodeWithContentDescription("Record a voice message").assertExists()
    }

    /** A failed send stays with "Couldn't send. Tap to retry"; a tap sends it again. */
    @Test fun failedSendRetries() {
        val data = FakeSocialData().apply { seedChat() }
        chat(data)
        data.failNext += "sendText:on my way:"
        compose.onNode(hasSetTextAction()).performTextInput("on my way")
        compose.waitForIdle()
        compose.onNodeWithContentDescription("Send").performClick()
        compose.waitForIdle()
        compose.onNodeWithText("Couldn't send. Tap to retry").assertExists().performClick()
        compose.waitForIdle()
        assertEquals(2, data.calls.count { it == "sendText:on my way:" })
        compose.onNodeWithText("Couldn't send. Tap to retry").assertDoesNotExist()
    }

    /** Context menu → Reply: the reply bar names the sender; the text goes with `p_reply_to_message_id`. */
    @Test fun replyToAMessage() {
        val data = FakeSocialData().apply { seedChat() }
        chat(data)
        compose.onNodeWithContentDescription("Ben, strictly vibes only tonight").performTouchInput { longClick() }
        compose.waitForIdle()
        compose.onNodeWithText("Reply").performClick()
        compose.waitForIdle()
        compose.onNodeWithText("Replying to Ben").assertExists()
        compose.onNode(hasSetTextAction()).performTextInput("same")
        compose.waitForIdle()
        compose.onNodeWithContentDescription("Send").performClick()
        compose.waitForIdle()
        assertTrue(data.calls.contains("sendText:same::m=m-2"))
        compose.onNodeWithText("Replying to Ben").assertDoesNotExist()
    }

    private fun micGranted() = Shadows.shadowOf(ApplicationProvider.getApplicationContext<Application>()).grantPermissions(Manifest.permission.RECORD_AUDIO)

    /** `chat.voice.layout.recording`: press and hold records, lift sends. */
    @Test fun sendVoice() {
        micGranted()
        val data = FakeSocialData().apply { seedChat() }
        chat(data)
        compose.onNodeWithContentDescription("Record a voice message").performTouchInput { down(center) }
        assertTrue(testVoice.recording)
        compose.onNodeWithText("Slide to cancel").assertExists()
        compose.onNodeWithContentDescription("Keep recording").assertExists()
        compose.onNodeWithContentDescription("Record a voice message").performTouchInput {
            advanceEventTime(HOLD_MS)
            up()
        }
        compose.waitForIdle()
        assertFalse(testVoice.recording)
        assertTrue(data.calls.contains("sendVoice:${FakeVoice.DURATION_MS}"))
    }

    /** Slide left while holding: discarded, nothing sent. A tap (shorter than a hold) records nothing. */
    @Test fun voiceSlideToCancelAndTap() {
        micGranted()
        val data = FakeSocialData().apply { seedChat() }
        chat(data)
        compose.onNodeWithContentDescription("Record a voice message").performTouchInput {
            down(center)
            advanceEventTime(HOLD_MS)
            moveBy(androidx.compose.ui.geometry.Offset(-SLIDE_PX, 0f))
            up()
        }
        compose.waitForIdle()
        assertFalse(testVoice.recording)
        compose.onNodeWithContentDescription("Record a voice message").performClick()
        compose.waitForIdle()
        assertFalse(testVoice.recording)
        assertFalse(data.calls.any { it.startsWith("sendVoice") })
    }

    /** Slide up onto the lock: hands-free; then trash discards or send sends. */
    @Test fun voiceLockAndSend() {
        micGranted()
        val data = FakeSocialData().apply { seedChat() }
        chat(data)
        compose.onNodeWithContentDescription("Record a voice message").performTouchInput {
            down(center)
            advanceEventTime(HOLD_MS)
            moveBy(androidx.compose.ui.geometry.Offset(0f, -SLIDE_PX))
            up()
        }
        compose.waitForIdle()
        assertTrue("locked: still recording after the finger lifts", testVoice.recording)
        compose.onNodeWithContentDescription("Delete recording").assertExists()
        compose.onNodeWithContentDescription("Send").performClick()
        compose.waitForIdle()
        assertFalse(testVoice.recording)
        assertTrue(data.calls.contains("sendVoice:${FakeVoice.DURATION_MS}"))
    }

    /**
     * `chat.voice.layout.locked`: pause keeps a draft (its waveform and length), the draft previews and pauses, continue
     * records on at its end, send sends the whole recording with its waveform (`p_voice_levels`).
     */
    @Test fun voicePausePreviewContinueAndSend() {
        micGranted()
        val data = FakeSocialData().apply { seedChat() }
        chat(data)
        compose.onNodeWithContentDescription("Record a voice message").performSemanticsAction(androidx.compose.ui.semantics.SemanticsActions.OnClick)
        compose.waitForIdle()
        compose.onNodeWithContentDescription("Pause recording").performClick()
        compose.waitForIdle()
        assertTrue("paused: the draft is kept", testVoice.paused && testVoice.recording)
        compose.onNodeWithContentDescription("Continue recording").assertExists()
        compose.onNodeWithTag("chat.composer.preview").performClick()
        compose.waitForIdle()
        assertEquals(1, testVoice.previews)
        compose.onNodeWithContentDescription("Pause").assertExists()
        compose.onNodeWithTag("chat.composer.preview").performClick()
        compose.waitForIdle()
        compose.onNodeWithContentDescription("Continue recording").performClick()
        compose.waitForIdle()
        assertFalse("continue records again", testVoice.paused)
        assertTrue(testVoice.recording)
        compose.onNodeWithContentDescription("Pause recording").assertExists()
        compose.onNodeWithTag("chat.composer.sendRecording").performClick()
        compose.waitForIdle()
        assertFalse(testVoice.recording)
        assertTrue(data.calls.contains("sendVoice:${FakeVoice.DURATION_MS}"))
        assertEquals(FakeVoice.LEVELS, data.sentVoiceLevels.last())
    }

    /** Deleting a paused draft sends nothing. */
    @Test fun voicePausedDraftDeletes() {
        micGranted()
        val data = FakeSocialData().apply { seedChat() }
        chat(data)
        compose.onNodeWithContentDescription("Record a voice message").performSemanticsAction(androidx.compose.ui.semantics.SemanticsActions.OnClick)
        compose.waitForIdle()
        compose.onNodeWithContentDescription("Pause recording").performClick()
        compose.waitForIdle()
        compose.onNodeWithContentDescription("Delete recording").performClick()
        compose.waitForIdle()
        assertFalse(testVoice.recording)
        assertFalse(data.calls.any { it.startsWith("sendVoice") })
        compose.onNodeWithContentDescription("Record a voice message").assertExists()
    }

    /** TalkBack: activating the mic records hands-free (no hold gesture); trash discards. */
    @Test fun voiceWithTalkBack() {
        micGranted()
        val data = FakeSocialData().apply { seedChat() }
        chat(data)
        compose.onNodeWithContentDescription("Record a voice message").performSemanticsAction(androidx.compose.ui.semantics.SemanticsActions.OnClick)
        compose.waitForIdle()
        assertTrue(testVoice.recording)
        compose.onNodeWithContentDescription("Delete recording").performClick()
        compose.waitForIdle()
        assertFalse(testVoice.recording)
        assertFalse(data.calls.any { it.startsWith("sendVoice") })
    }

    /** Long press on a photo: the quick-reaction row reacts at once; an emoji you used shows selected and unreacts. */
    @Test fun quickReactionsReactAndUnreact() {
        val data = FakeSocialData().apply { seedChat() }
        chat(data)
        compose.onNodeWithContentDescription("Ana's photo", substring = true).performTouchInput { longClick() }
        compose.waitForIdle()
        compose.onNodeWithContentDescription("React with sparkling heart").performClick()
        compose.waitForIdle()
        assertTrue(data.calls.contains("react:p-1:💖"))
        compose.onNodeWithContentDescription("Ana's photo", substring = true).performTouchInput { longClick() }
        compose.waitForIdle()
        compose.onNodeWithContentDescription("React with fire").assertIsSelected().performClick()
        compose.waitForIdle()
        assertTrue(data.calls.contains("unreact:p-1:🔥"))
    }

    /** Tenet 2: reaction labels name emoji, never a number. */
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

    private fun viewerHost(data: FakeSocialData, postId: String, context: PhotoContext = PhotoContext.Album, contextId: String = "a-v"): () -> NavHostController {
        lateinit var nav: NavHostController
        compose.setContent {
            TestScreen(data) {
                nav = rememberNavController()
                NavHost(nav, startDestination = PhotoViewerIn(GROUP, postId, context, contextId)) {
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

    /** A comment goes with `p_reply_to_post_id` and joins the list; the camera opens with the reply target. */
    @Test fun commentOnAPhotoAndReplyWithAPhoto() {
        val data = viewerData()
        viewerHost(data, "v-1")
        compose.onNode(hasSetTextAction()).performTextInput("where is this")
        compose.waitForIdle()
        compose.onNodeWithContentDescription("Send").performClick()
        compose.waitForIdle()
        assertTrue(data.calls.contains("sendText:where is this:v-1"))
        compose.onNodeWithContentDescription("You, where is this").assertExists()

        compose.onNodeWithContentDescription("Take photo").performClick()
        compose.waitForIdle()
        compose.onNodeWithTag("camera").assertExists()
        compose.onNodeWithText("v-1").assertExists()
    }

    /** Tap advances (and moves the "N of M" pill); "I'm in this" tags you at once. */
    @Test fun advanceAndTagYourself() {
        val data = viewerData().apply { tagRows.clear() }
        viewerHost(data, "v-1")
        compose.onNodeWithContentDescription("1 of 3").assertExists()
        compose.onNodeWithContentDescription("I'm in this").performClick()
        compose.waitForIdle()
        assertTrue(data.calls.contains("tagSelf:v-1"))
        compose.onNode(androidx.compose.ui.test.hasContentDescription("Ana's photo", substring = true)).performTouchInput { click(androidx.compose.ui.geometry.Offset(width * 0.9f, height / 2f)) }
        compose.waitForIdle()
        compose.onNodeWithContentDescription("2 of 3").assertExists()
    }

    @Test fun deleteEverywhere() {
        val data = viewerData()
        viewerHost(data, "v-2", PhotoContext.Single, "v-2")
        compose.onNodeWithContentDescription("More Options").performClick()
        compose.waitForIdle()
        compose.onNodeWithText("Delete").performClick()
        compose.waitForIdle()
        compose.onNodeWithText("Delete photo?").assertExists()
        compose.onNodeWithText("Yes, delete").performClick()
        compose.waitForIdle()
        assertTrue(data.calls.contains("deleteMedia:md-v-2"))
    }

    @Test fun editRecapAndSaveIt() {
        val data = FakeSocialData().apply { seedWeek() }
        val vm = WeekEditViewModel(data, GROUP, "r-w", null, albumOnly = false)
        var closed = false
        compose.setContent { TestScreen(data) { WeekEditSheet(vm, onClose = { closed = true }) } }
        compose.waitForIdle()
        compose.onAllNodesWithContentDescription("Sunday, October 18, 2026, Ana's photo").onLast().performClick()
        compose.waitForIdle()
        assertTrue("w-7" in vm.state.value.checked)
        compose.onNodeWithText("Update").performClick()
        compose.waitForIdle()
        assertTrue(data.calls.contains("updateRecap:" + (1..7).joinToString(",") { "w-$it" } + ":the best week"))
        assertTrue(closed)
    }

    /** `week.edit.layout.reorder`: touch and hold a strip tile, drag it onto the next slot, drop; the recap keeps the order. */
    @Test fun reorderARecapByDragging() {
        val data = FakeSocialData().apply { seedWeek() }
        val vm = WeekEditViewModel(data, GROUP, "r-w", null, albumOnly = false)
        compose.setContent { TestScreen(data) { WeekEditSheet(vm, onClose = {}) } }
        compose.waitForIdle()
        val first = vm.state.value.checked.first()
        val second = vm.state.value.checked[1]
        compose.onAllNodesWithContentDescription("Monday, October 12, 2026", substring = true).onFirst().performTouchInput {
            down(center)
            advanceEventTime(HOLD_MS)
            moveBy(androidx.compose.ui.geometry.Offset(width.toFloat(), 0f))
            advanceEventTime(HOLD_MS / 10)
            up()
        }
        compose.waitForIdle()
        assertEquals(listOf(second, first), vm.state.value.checked.take(2))
        compose.onNodeWithText("Update").performClick()
        compose.waitForIdle()
        assertTrue(data.calls.any { it.startsWith("updateRecap:$second,$first,") })
    }

    /**
     * `week.edit.a11y.moveLeft` / `.moveRight` (Chrome's tab reorder actions): TalkBack moves a strip tile one place; the
     * first tile has no "left" action (the view-model test covers the last tile's bound through the same index rule).
     */
    @Test fun reorderARecapWithTalkBackActions() {
        val data = FakeSocialData().apply { seedWeek() }
        val vm = WeekEditViewModel(data, GROUP, "r-w", null, albumOnly = false)
        compose.setContent { TestScreen(data) { WeekEditSheet(vm, onClose = {}) } }
        compose.waitForIdle()
        val order = vm.state.value.checked
        val withActions = androidx.compose.ui.test.SemanticsMatcher.keyIsDefined(androidx.compose.ui.semantics.SemanticsActions.CustomActions)
        fun actions(index: Int) = compose.onAllNodes(withActions).fetchSemanticsNodes()
            .map { node -> node.config[androidx.compose.ui.semantics.SemanticsActions.CustomActions].map { it.label } }[index]
        assertEquals(listOf("Move photo right"), actions(0))
        assertEquals(listOf("Move photo left", "Move photo right"), actions(1))
        // "Move photo right" on the first tile swaps it with the second.
        val firstTile = compose.onAllNodes(withActions).onFirst().fetchSemanticsNode()
        compose.runOnIdle { firstTile.config[androidx.compose.ui.semantics.SemanticsActions.CustomActions].single { it.label == "Move photo right" }.action() }
        compose.waitForIdle()
        assertEquals(listOf(order[1], order[0]) + order.drop(2), vm.state.value.checked)
    }

    @Test fun saveAWeekAsANamedAlbum() {
        val data = FakeSocialData().apply { seedWeek() }
        val vm = WeekEditViewModel(data, GROUP, null, LocalDate.parse("2026-10-12"), albumOnly = true)
        var closed = false
        compose.setContent { TestScreen(data) { WeekEditSheet(vm, onClose = { closed = true }) } }
        compose.waitForIdle()
        compose.onNode(hasSetTextAction()).performTextInput("lake week")
        compose.waitForIdle()
        compose.onNodeWithText("Create Album").performClick()
        compose.waitForIdle()
        assertTrue(data.calls.contains("saveAlbum:lake week:" + (1..7).joinToString(",") { "w-$it" }))
        assertTrue(closed)
        assertEquals("lake week", data.albums.values.single().name)
    }
}
