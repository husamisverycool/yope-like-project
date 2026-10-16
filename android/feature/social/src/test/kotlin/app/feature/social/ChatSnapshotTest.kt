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
        approximations: Boolean = true,
        screen: Boolean = false,
        dark: Boolean = false,
    ) = snap(data, approximations, screen, dark) { Content(state, ui, voice, recorder) }

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
            seedThread()
            makeDual("p-1")
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
        chat(state, ChatUiState(recording = Recording.Holding(0L)), data, recorder = RecorderControls(elapsedMs = RECORDED_MS))
    }

    /** Locked (hands-free): trash and send in the trailing glyphs. */
    @Test fun recordingLocked() {
        val (data, state) = loaded()
        chat(state, ChatUiState(recording = Recording.Locked(0L)), data, recorder = RecorderControls(elapsedMs = RECORDED_MS))
    }

    /** A voice message playing: pause glyph and the elapsed time. */
    @Test fun voicePlaying() {
        val (data, state) = loaded()
        val path = state.rows.first { it.message.id == "m-7" }.message.voicePath
        chat(state, data = data, voice = VoiceUi(VoicePlayback(path, true, PROGRESS), null, emptySet()) {})
    }

    /** A voice message whose file failed to load: the error line in the capsule. */
    @Test fun voiceError() {
        val (data, state) = loaded()
        val path = state.rows.first { it.message.id == "m-7" }.message.voicePath.orEmpty()
        chat(state, data = data, voice = VoiceUi(VoicePlayback(null, false), null, setOf(path)) {})
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

    /** Long press on a photo: the quick-reaction row (🔥 💖 +) then Reply · Save · Report Message. */
    @Test fun contextMenuPhoto() {
        val (data, state) = loaded()
        chat(state, ChatUiState(menuFor = "m-1"), data, screen = true)
    }

    @Test fun unsendConfirmation() {
        val (data, state) = loaded()
        chat(state, ChatUiState(confirmUnsend = "m-5"), data, screen = true)
    }

    /** The Reactions sheet (development order: newest first). */
    @Test fun reactionsSheet() {
        val (data, state) = loaded()
        chat(state, ChatUiState(reactionsFor = "p-1"), data, screen = true)
    }

    /** Release build: the sheet in the data layer's order (`chat.reactions.layout.listOrder` BLOCKED). */
    @Test fun reactionsSheetRelease() {
        val (data, state) = loaded()
        chat(state, ChatUiState(reactionsFor = "p-1"), data, screen = true, approximations = false)
    }

    @Test fun reactionsPicker() {
        val (data, state) = loaded()
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
        const val PROGRESS = 0.4f
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
    messages += FakeSocialData.message("m-7", GROUP, BEN, MessageKind.Voice, voicePath = "u/$BEN/voice/v2.m4a", voiceMs = 12_000, at = t0.plusSeconds(400))
}
