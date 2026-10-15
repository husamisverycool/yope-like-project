package app.feature.social

import app.data.repo.ReactionEntry
import app.feature.social.FakeSocialData.Companion.ANA
import app.feature.social.FakeSocialData.Companion.BEN
import app.feature.social.FakeSocialData.Companion.GROUP
import app.feature.social.chat.ChatContent
import app.feature.social.chat.ChatNav
import app.feature.social.chat.ChatState
import app.feature.social.chat.ChatUiState
import app.feature.social.chat.ChatViewModel
import app.feature.social.chat.Recording
import app.feature.social.chat.VoiceControls
import app.feature.social.data.RecordedVoice
import app.feature.social.data.VoicePlayback
import app.feature.social.reactions.ReactionFlights
import app.feature.social.FakeSocialData.Companion.ME
import org.junit.Test

/** chat.thread (+ chat.composer, chat.voice, chat.reactions) per state. */
class ChatSnapshotTest : SnapshotBase() {
    private val nav = ChatNav({}, {}, {}, {}, {}, {}, {}, { _, _ -> })

    private fun chat(state: ChatState, ui: ChatUiState = ChatUiState(), data: FakeSocialData = FakeSocialData(), playback: VoicePlayback = VoicePlayback(null, false), recorder: VoiceControls = VoiceControls(null), approximations: Boolean = true, screen: Boolean = false) =
        snap(data, approximations, screen) { content(state, ui, playback, recorder) }

    @androidx.compose.runtime.Composable
    private fun content(state: ChatState, ui: ChatUiState, playback: VoicePlayback = VoicePlayback(null, false), recorder: VoiceControls = VoiceControls(null), flights: ReactionFlights = androidx.compose.runtime.remember { ReactionFlights() }) =
        ChatContent(
            state = state, ui = ui, nav = nav, focusMessageId = null, voice = testVoice, playback = playback, recorder = recorder,
            onDraft = {}, onSend = {}, onRetry = {}, onLoadOlder = {}, onReact = { _, _ -> }, onUnreact = { _, _ -> }, onRetrySend = {}, onDelete = {}, onMicCard = {}, onPlay = {},
            flights = flights,
        )

    private fun loaded(): Pair<FakeSocialData, ChatState> {
        val data = FakeSocialData().apply { seedChat() }
        return data to ChatViewModel(data, GROUP).state.value
    }

    @Test fun content() {
        val (data, state) = loaded()
        chat(state, data = data)
    }

    /** Release builds: everything but the Activity sheet tap (`chat.reactions.layout.activitySheet` BLOCKED). */
    @Test fun contentRelease() {
        val (data, state) = loaded()
        chat(state, data = data, approximations = false)
    }

    @Test fun loading() = chat(ChatState(phase = ChatState.Phase.Loading))

    @Test fun emptyCreator() {
        val data = FakeSocialData().apply { seedGroup() }
        chat(ChatState(phase = ChatState.Phase.Ready, group = data.groups[GROUP], iAmCreator = true, addedNames = listOf("Ana", "Ben")), data = data)
    }

    @Test fun emptyMember() {
        val data = FakeSocialData().apply { seedGroup() }
        chat(ChatState(phase = ChatState.Phase.Ready, group = data.groups[GROUP], creatorName = "Ana", addedNames = listOf("Sam", "Ben")), data = data)
    }

    @Test fun error() = chat(ChatState(phase = ChatState.Phase.Error))

    @Test fun offlineNothingCached() = chat(ChatState(phase = ChatState.Phase.OfflineEmpty))

    /** Offline with cached messages: the cached page stays (no offline banner in the spec). */
    @Test fun offlineCached() {
        val data = FakeSocialData().apply { seedChat() }
        data.chatCache[GROUP] = data.messages.sortedByDescending { it.createdAt }
        data.offline = true
        chat(ChatViewModel(data, GROUP).state.value, data = data)
    }

    /** `chat.composer.layout.typingState`: the mic circle's slot shows the lime send circle. */
    @Test fun composerTyping() {
        val (data, state) = loaded()
        chat(state.copy(draft = "on my way"), data = data)
    }

    /** `chat.voice.layout.recording`, holding: red dot · time · ‹ slide to cancel, the lock above the mic. */
    @Test fun composerRecordingHolding() {
        val (data, state) = loaded()
        chat(state, data = data, recorder = VoiceControls(Recording.Holding(0L), elapsedMs = RECORDED_MS))
    }

    /** Locked (hands-free): pause in the hint's place, the send circle in the mic's slot. */
    @Test fun composerRecordingLocked() {
        val (data, state) = loaded()
        chat(state, data = data, recorder = VoiceControls(Recording.Locked(0L), elapsedMs = RECORDED_MS))
    }

    /** Paused: the draft plays like a voice message; send sends it. */
    @Test fun composerRecordingDraft() {
        val (data, state) = loaded()
        val draft = Recording.Draft(RecordedVoice(java.io.File("draft.m4a"), RECORDED_MS.toInt()), listOf(0.1f, 0.5f, 0.9f, 0.3f, 0.7f, 0.2f, 0.8f, 0.4f, 0.6f, 0.3f))
        chat(state, data = data, recorder = VoiceControls(draft, draftPlaying = true, draftProgress = 0.4f))
    }

    /** `chat.thread.layout.failedMessage`: red "!" circle beside my bubble, the red label under it. */
    @Test fun sendFailed() {
        val data = FakeSocialData().apply { seedChat() }
        val vm = ChatViewModel(data, GROUP)
        data.failNext += "sendText:running late, sorry:"
        vm.setDraft("running late, sorry")
        vm.send()
        chat(vm.state.value, data = data)
    }

    /** `chat.thread.count.emojiOnlyMax` (3) and `.dimension.bubbleMaxWidth` (256): big emoji without a bubble; long text wraps. */
    @Test fun emojiOnlyAndLongText() {
        val data = FakeSocialData().apply { seedChat() }
        data.messages += FakeSocialData.message("m-8", GROUP, BEN, app.data.model.MessageKind.Text, body = "😂🔥😍", at = FakeSocialData.BASE.plusSeconds(500))
        data.messages += FakeSocialData.message("m-9", GROUP, ME, app.data.model.MessageKind.Text, body = "okay but who is bringing the speaker on saturday because mine is dead", at = FakeSocialData.BASE.plusSeconds(560))
        chat(ChatViewModel(data, GROUP).state.value, data = data)
    }

    @Test fun voicePermissionDenied() {
        val (data, state) = loaded()
        chat(state, ChatUiState(showMicCard = true), data)
    }

    @Test fun voicePlaying() {
        val (data, state) = loaded()
        chat(state, data = data, playback = VoicePlayback("u/u-me/voice/v1.m4a", true, 0.4f))
    }

    @Test fun contextMenuOwnMessage() {
        val (data, state) = loaded()
        chat(state, ChatUiState(menuFor = "m-5"), data, screen = true)
    }

    @Test fun contextMenuOthersMessage() {
        val (data, state) = loaded()
        chat(state, ChatUiState(menuFor = "m-3"), data, screen = true)
    }

    @Test fun deleteMessageConfirmation() {
        val (data, state) = loaded()
        chat(state, ChatUiState(confirmDelete = "m-5"), data, screen = true)
    }

    @Test fun reactionsPicker() {
        val (data, state) = loaded()
        chat(state, ChatUiState(pickerFor = "p-1"), data, screen = true)
    }

    @Test fun reactionsActivitySheetDevelopment() {
        val (data, state) = loaded()
        chat(state, ChatUiState(activityFor = "p-1"), data, screen = true)
    }

    @Test fun reactionsManyStickers() {
        val data = FakeSocialData().apply { seedChat() }
        data.reactions["p-1"] = listOf("😍", "🔥", "😂", "🫶", "💖", "😭", "🥹").mapIndexed { i, e -> ReactionEntry(if (i % 2 == 0) ANA else BEN, e) }.toMutableList()
        chat(ChatViewModel(data, GROUP).state.value, data = data)
    }

    /** Emoji rain mid-way (`chat.reactions.easing.rain`): copies behind the messages. */
    @Test fun reactionsRain() {
        val (data, state) = loaded()
        val ui = ChatUiState().apply { rain = "🔥" to 1 }
        compose.mainClock.autoAdvance = false
        compose.setContent { TestScreen(data) { content(state, ui) } }
        compose.mainClock.advanceTimeBy(RAIN_FRAME_MS)
        com.github.takahirom.roborazzi.captureScreenRoboImage()
    }

    /** A reaction mid-flight to the cluster's leading end (`chat.reactions.duration.flyToCluster`); its sticker waits for it. */
    @Test fun reactionsFlyToCluster() {
        val (data, state) = loaded()
        val flights = ReactionFlights()
        compose.mainClock.autoAdvance = false
        compose.setContent { TestScreen(data) { content(state, ChatUiState(), flights = flights) } }
        compose.mainClock.advanceTimeByFrame()
        compose.runOnIdle { org.junit.Assert.assertTrue("the cluster's landing slot is known", flights.launch("p-1", "😂", androidx.compose.ui.geometry.Rect(FLIGHT_START_X, FLIGHT_START_Y, FLIGHT_START_X + FLIGHT_SIZE, FLIGHT_START_Y + FLIGHT_SIZE))) }
        compose.mainClock.advanceTimeBy(FLIGHT_FRAME_MS)
        println("DEBUGFLIGHT " + flights.flight)
        com.github.takahirom.roborazzi.captureScreenRoboImage()
    }

    private companion object {
        const val RAIN_FRAME_MS = 1_200L
        const val RECORDED_MS = 7_000L
        // Test geometry (screen px): a picker cell near the bottom of the screen.
        const val FLIGHT_START_X = 520f
        const val FLIGHT_START_Y = 1500f
        const val FLIGHT_SIZE = 80f
        const val FLIGHT_FRAME_MS = 120L
    }
}
