package app.feature.social

import androidx.compose.runtime.Composable
import androidx.compose.ui.text.input.TextFieldValue
import app.data.model.MessageKind
import app.feature.social.FakeSocialData.Companion.BASE
import app.feature.social.FakeSocialData.Companion.BEN
import app.feature.social.FakeSocialData.Companion.GROUP
import app.feature.social.FakeSocialData.Companion.ME
import app.feature.social.chat.ChatContent
import app.feature.social.chat.ChatNav
import app.feature.social.chat.ChatState
import app.feature.social.chat.ChatUiState
import app.feature.social.chat.ChatViewModel
import app.feature.social.chat.RecorderControls
import app.feature.social.chat.Recording
import app.feature.social.chat.VoiceUi
import app.feature.social.data.VoicePlayback
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.onAllNodesWithText
import org.junit.Test
import java.time.LocalDate
import java.time.ZoneOffset

/** chat.thread (+ chat.composer, chat.voice, chat.reactions) per state; the primary state also in dark. */
class ChatSnapshotTest : SnapshotBase() {
    private val nav = ChatNav({}, {}, {}, {}, {}, { _, _ -> }, {})

    private fun chat(
        state: ChatState,
        ui: ChatUiState = ChatUiState(),
        data: FakeSocialData = FakeSocialData(),
        voice: VoiceUi = VoiceUi.Idle,
        recorder: RecorderControls = RecorderControls(),
        screen: Boolean = false,
        dark: Boolean = false,
    ) = snap(data, screen, dark) { Content(state, ui, voice, recorder) }

    @Composable
    private fun Content(state: ChatState, ui: ChatUiState, voice: VoiceUi, recorder: RecorderControls) = ChatContent(
        state = state, ui = ui, nav = nav, focusMessageId = null, voice = voice, recorder = recorder,
        onDraft = {}, onSend = {}, onRetry = {}, onLoadOlder = {}, onReact = { _, _ -> }, onUnreact = { _, _ -> }, onRetrySend = {},
        onReply = {}, onCancelReply = {}, onCopy = {}, onSave = {}, onUnsend = {}, onDeletePhoto = {}, onOpenMicSettings = {},
        zone = ZoneOffset.UTC, today = TODAY,
    )

    private fun loaded(): Pair<FakeSocialData, ChatState> {
        val data = FakeSocialData().apply { seedThread() }
        return data to ChatViewModel(data, GROUP).state.value
    }

    @Test fun content() {
        val (data, state) = loaded()
        chat(state, data = data)
    }

    @Test fun contentDark() {
        val (data, state) = loaded()
        chat(state, data = data, dark = true)
    }

    /** A post with a front photo in the thread: core:ui daily.dualimage in the card's corners. */
    @Test fun dualPhoto() {
        val data = FakeSocialData().apply {
            seedGroup()
            val photo = addPhoto("p-1", FakeSocialData.ANA, BASE, caption = "face masks night")
            makeDual(photo.id)
            reactions[photo.id] = mutableListOf(app.data.repo.ReactionEntry(BEN, "😍"), app.data.repo.ReactionEntry(ME, "🔥"))
            messages += FakeSocialData.message("m-1", GROUP, FakeSocialData.ANA, MessageKind.Photo, postId = photo.id, at = BASE)
            messages += FakeSocialData.message("m-2", GROUP, BEN, MessageKind.Text, body = "the selfie in the corner 😂", at = BASE.plusSeconds(120))
        }
        chat(ChatViewModel(data, GROUP).state.value, data = data)
    }

    @Test fun loading() = chat(ChatState(phase = ChatState.Phase.Loading))

    @Test fun empty() {
        val data = FakeSocialData().apply { seedGroup() }
        chat(ChatState(phase = ChatState.Phase.Ready, group = data.groups[GROUP]), data = data)
    }

    @Test fun error() {
        val data = FakeSocialData().apply { seedGroup() }
        chat(ChatState(phase = ChatState.Phase.Error, group = data.groups[GROUP]), data = data)
    }

    @Test fun offlineNothingCached() {
        val data = FakeSocialData().apply { seedGroup() }
        chat(ChatState(phase = ChatState.Phase.OfflineEmpty, group = data.groups[GROUP]), data = data)
    }

    /** Offline with cached messages: the cached page stays; a send shows "Sending", then "Couldn't send. Tap to retry". */
    @Test fun offlineCachedSendFailed() {
        val data = FakeSocialData().apply { seedThread() }
        data.chatCache[GROUP] = data.messages.sortedByDescending { it.createdAt }
        val vm = ChatViewModel(data, GROUP, CLOCK)
        data.offline = true
        vm.setDraft("running late, sorry")
        vm.send()
        chat(vm.state.value, data = data)
    }

    /** In flight: `chat.thread.sending` under your message. */
    @Test fun sending() {
        val data = FakeSocialData().apply { seedThread() }
        val vm = ChatViewModel(data, GROUP, CLOCK)
        data.gate = kotlinx.coroutines.CompletableDeferred()
        vm.setDraft("on my way")
        vm.send()
        chat(vm.state.value, data = data)
    }

    /** Replying: the reply bar ("Replying to Ana") above the field, placeholder "Reply…". */
    @Test fun replying() {
        val data = FakeSocialData().apply { seedThread() }
        val vm = ChatViewModel(data, GROUP)
        vm.startReply(vm.state.value.rows.first { it.message.id == "m-2" })
        chat(vm.state.value, data = data)
    }

    /** `chat.composer.layout.typingState`: the send glyph in place of camera + mic. */
    @Test fun composerTyping() {
        val (data, state) = loaded()
        chat(state, ChatUiState(draft = TextFieldValue("on my way")), data)
    }

    /** `chat.voice.layout.recording`, holding: red mic · time · ‹ Slide to cancel; the lock circle over the mic. */
    @Test fun recordingHolding() {
        val (data, state) = loaded()
        chat(state, ChatUiState(recording = Recording.Holding), data, recorder = RecorderControls(elapsedMs = RECORDED_MS))
    }

    /** Locked (`chat.voice.layout.locked`): red mic · time · live waveform in the field; delete · pause · send under it. */
    @Test fun recordingLocked() {
        val (data, state) = loaded()
        chat(state, ChatUiState(recording = Recording.Locked), data, recorder = RecorderControls(elapsedMs = RECORDED_MS, levels = FakeVoice.LEVELS))
    }

    @Test fun recordingLockedDark() {
        val (data, state) = loaded()
        chat(state, ChatUiState(recording = Recording.Locked), data, dark = true, recorder = RecorderControls(elapsedMs = RECORDED_MS, levels = FakeVoice.LEVELS))
    }

    /** Paused draft, previewing part-way: preview glyph · played / unplayed bars · elapsed; delete · continue · send. */
    @Test fun recordingPaused() {
        val (data, state) = loaded()
        chat(state, ChatUiState(recording = Recording.Paused), data, recorder = RecorderControls(elapsedMs = PAUSED_MS, levels = NOTE_LEVELS, previewProgress = PREVIEW))
    }

    @Test fun recordingPausedDark() {
        val (data, state) = loaded()
        chat(state, ChatUiState(recording = Recording.Paused), data, dark = true, recorder = RecorderControls(elapsedMs = PAUSED_MS, levels = NOTE_LEVELS, previewProgress = PREVIEW))
    }

    /** A voice message playing: pause glyph and the elapsed time. */
    @Test fun voicePlaying() {
        val (data, state) = loaded()
        val path = state.rows.first { it.message.id == "m-7" }.message.voicePath
        chat(state, data = data, voice = VoiceUi(VoicePlayback(path, true, PROGRESS), null, emptySet()) { _, _ -> })
    }

    /** A voice message whose file failed to load: the error line in the capsule. */
    @Test fun voiceError() {
        val (data, state) = loaded()
        val path = state.rows.first { it.message.id == "m-7" }.message.voicePath.orEmpty()
        chat(state, data = data, voice = VoiceUi(VoicePlayback(null, false), null, setOf(path)) { _, _ -> })
    }

    @Test fun micPermissionDenied() {
        val (data, state) = loaded()
        chat(state, ChatUiState(micDenied = true), data, screen = true)
    }

    /** Long press on your own text: Reply · Copy · Unsend. */
    @Test fun contextMenuOwnMessage() {
        val (data, state) = loaded()
        chat(state, ChatUiState(menuFor = "m-5"), data, screen = true)
    }

    /** Long press on Ana's photo: the quick-reaction row (🔥 💖 +) then Reply · Report Message — no Save (owner decision 12). */
    @Test fun contextMenuPhoto() {
        val (data, state) = loaded()
        chat(state, ChatUiState(menuFor = "m-1"), data, screen = true)
        compose.onAllNodesWithText("Save").assertCountEquals(0)
    }

    @Test fun unsendConfirmation() {
        val (data, state) = loaded()
        chat(state, ChatUiState(confirmUnsend = "m-5"), data, screen = true)
    }

    /** The Reactions sheet, newest first (`chat.reactions.layout.listOrder`). */
    @Test fun reactionsSheet() {
        val (data, state) = loaded()
        chat(state, ChatUiState(reactionsFor = "p-1"), data, screen = true)
    }

    @Test fun reactionsPicker() {
        val (data, state) = loaded()
        // The device catalog is read off the main thread on first use; read here so the sheet opens with it.
        app.feature.social.reactions.EmojiCatalog.shown(androidx.test.core.app.ApplicationProvider.getApplicationContext())
        chat(state, ChatUiState(pickerFor = "p-1"), data, screen = true)
    }

    /** 1–3 emoji render at the title size; long text wraps in the text column. */
    @Test fun emojiOnlyAndLongText() {
        val data = FakeSocialData().apply { seedThread() }
        data.messages += FakeSocialData.message("m-8", GROUP, BEN, MessageKind.Text, body = "😂🔥😍", at = BASE.plusSeconds(500))
        data.messages += FakeSocialData.message("m-9", GROUP, ME, MessageKind.Text, body = "okay but who is bringing the speaker on saturday because mine is dead", at = BASE.plusSeconds(560))
        chat(ChatViewModel(data, GROUP).state.value, data = data)
    }

    companion object {
        const val RECORDED_MS = 7_000L
        const val PAUSED_MS = 11_000L
        const val PROGRESS = 0.4f
        const val PREVIEW = 0.45f
        val TODAY: LocalDate = LocalDate.parse("2026-10-12")
        /** Optimistic sends are stamped with this clock (ten minutes after the seed thread's start). */
        val CLOCK: java.time.Clock = java.time.Clock.fixed(BASE.plusSeconds(600), ZoneOffset.UTC)
    }
}

/**
 * A thread across two days: yesterday Ana's captioned photo with reactions and a voice note; today Ben's run of two
 * texts, Ana's reply quoting the photo, my reply quoting Ben, my text and voice message, Ben's voice message.
 */
fun FakeSocialData.seedThread() {
    seedGroup()
    val t0 = BASE
    val yesterday = t0.minusSeconds(86_400)
    val photo = addPhoto("p-1", FakeSocialData.ANA, yesterday, caption = "face masks night", voicePath = "u/${FakeSocialData.ANA}/voice/p1.m4a", voiceMs = 9_000)
        .copy(voiceLevels = NOTE_LEVELS)
    posts["p-1"] = photo
    reactions["p-1"] = mutableListOf(
        app.data.repo.ReactionEntry(BEN, "😍"),
        app.data.repo.ReactionEntry(ME, "🔥"),
        app.data.repo.ReactionEntry(FakeSocialData.ANA, "💖"),
    )
    messages += FakeSocialData.message("m-1", GROUP, FakeSocialData.ANA, MessageKind.Photo, postId = photo.id, at = yesterday)
    messages += FakeSocialData.message("m-2", GROUP, BEN, MessageKind.Text, body = "strictly vibes only tonight", at = t0.plusSeconds(120))
    messages += FakeSocialData.message("m-3", GROUP, BEN, MessageKind.Text, body = "who's in for sunday?", at = t0.plusSeconds(130))
    messages += FakeSocialData.message("m-4", GROUP, FakeSocialData.ANA, MessageKind.Text, body = "obsessed with this one", replyToPostId = "p-1", at = t0.plusSeconds(200))
    messages += FakeSocialData.message("m-5", GROUP, ME, MessageKind.Text, body = "me! bringing dessert", at = t0.plusSeconds(300)).copy(replyToMessageId = "m-3")
    messages += FakeSocialData.message("m-6", GROUP, ME, MessageKind.Voice, voicePath = "u/$ME/voice/v1.m4a", voiceMs = 38_000, at = t0.plusSeconds(305))
        .copy(voiceLevels = FakeVoice.LEVELS)
    messages += FakeSocialData.message("m-7", GROUP, BEN, MessageKind.Voice, voicePath = "u/$BEN/voice/v2.m4a", voiceMs = 12_000, at = t0.plusSeconds(400))
        .copy(voiceLevels = NOTE_LEVELS)
}

/** A second sample waveform (100 levels, speech-like), demo data. */
val NOTE_LEVELS = listOf(
    26, 29, 26, 31, 31, 25, 18, 1, 10, 12, 9, 0, 0, 21, 17, 15, 31, 22, 17, 1, 0, 0, 18, 23, 0, 0, 31, 31, 26, 0, 31, 21,
    14, 19, 0, 0, 28, 31, 31, 25, 0, 0, 20, 21, 14, 11, 1, 5, 22, 18, 0, 0, 17, 31, 31, 0, 23, 31, 10, 31, 1, 14, 23, 31,
    20, 31, 21, 28, 19, 0, 0, 28, 31, 18, 0, 18, 31, 11, 0, 17, 17, 30, 18, 31, 0, 0, 17, 31, 31, 15, 1, 0, 0, 22, 25, 0,
    0, 3, 24, 21,
)
