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
import app.feature.social.data.VoicePlayback
import org.junit.Test

/** chat.thread (+ chat.composer, chat.voice, chat.reactions) per state. */
class ChatSnapshotTest : SnapshotBase() {
    private val nav = ChatNav({}, {}, {}, {}, {}, {}, {}, { _, _ -> })

    private fun chat(state: ChatState, ui: ChatUiState = ChatUiState(), data: FakeSocialData = FakeSocialData(), playback: VoicePlayback = VoicePlayback(null, false), levels: List<Float>? = null, approximations: Boolean = true, screen: Boolean = false) =
        snap(data, approximations, screen) {
            ChatContent(
                state = state, ui = ui, nav = nav, focusMessageId = null, voice = testVoice, playback = playback, recordingLevels = levels,
                onDraft = {}, onSend = {}, onRetry = {}, onLoadOlder = {}, onReact = { _, _ -> }, onDelete = {}, onMic = if (approximations) ({}) else null, onMicCard = {}, onPlay = {},
            )
        }

    private fun loaded(): Pair<FakeSocialData, ChatState> {
        val data = FakeSocialData().apply { seedChat() }
        return data to ChatViewModel(data, GROUP).state.value
    }

    @Test fun content() {
        val (data, state) = loaded()
        chat(state, data = data)
    }

    /** Release builds: no mic circle (recording UI BLOCKED), no Activity sheet tap. */
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

    @Test fun composerTyping() {
        val (data, state) = loaded()
        chat(state.copy(draft = "on my way"), data = data)
    }

    @Test fun composerRecordingDevelopment() {
        val (data, state) = loaded()
        chat(state, data = data, levels = listOf(0.1f, 0.5f, 0.9f, 0.3f, 0.7f, 0.2f, 0.8f, 0.4f))
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

    /** Emoji rain mid-way (development builds; the curve is BLOCKED): copies behind the messages. */
    @Test fun reactionsRainDevelopment() {
        val (data, state) = loaded()
        val ui = ChatUiState().apply { rain = "🔥" to 1 }
        compose.mainClock.autoAdvance = false
        compose.setContent {
            TestScreen(data) {
                ChatContent(state, ui, nav, null, testVoice, VoicePlayback(null, false), null, {}, {}, {}, {}, { _, _ -> }, {}, {}, {}, {})
            }
        }
        compose.mainClock.advanceTimeBy(RAIN_FRAME_MS)
        com.github.takahirom.roborazzi.captureScreenRoboImage()
    }

    private companion object {
        const val RAIN_FRAME_MS = 1_200L
    }
}
