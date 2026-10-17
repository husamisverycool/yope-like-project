package app.feature.social

import app.data.model.ChatTyping
import app.data.model.MessageReaction
import app.data.model.PublicAppConfig
import app.data.realtime.GroupEvent
import app.data.repo.ReactionEntry
import app.feature.social.FakeSocialData.Companion.ANA
import app.feature.social.FakeSocialData.Companion.BASE
import app.feature.social.FakeSocialData.Companion.BEN
import app.feature.social.FakeSocialData.Companion.GROUP
import app.feature.social.FakeSocialData.Companion.ME
import app.feature.social.chat.ChatEffect
import app.feature.social.chat.ChatViewModel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.time.Clock
import java.time.Instant
import java.time.ZoneId
import java.time.ZoneOffset

/**
 * Owner decision 34 in the chat's view model: reactions on text and voice messages (`chat.reactions.layout.messageReactions`),
 * editing a sent message (`chat.thread.layout.editMessage`) and the typing line (`chat.thread.layout.typingLine`), over
 * [FakeSocialData] (seedChat: m-2/m-3 Ben's texts, m-5 my text "no way" at BASE + 300 s, m-6 my voice message).
 */
@OptIn(ExperimentalCoroutinesApi::class)
class ChatMessageFeaturesTest {
    private val effects = CoroutineScope(SupervisorJob() + UnconfinedTestDispatcher())

    @Before fun setUp() = Dispatchers.setMain(UnconfinedTestDispatcher())

    @After fun tearDown() {
        effects.cancel()
        Dispatchers.resetMain()
    }

    private fun <T> collect(flow: kotlinx.coroutines.flow.Flow<T>): MutableList<T> {
        val out = ArrayList<T>()
        effects.launch { flow.collect { out += it } }
        return out
    }

    private fun chatConfig(window: Int? = null, ttl: Int? = null) =
        PublicAppConfig(invitationWindowSeconds = null, maxGroupMembers = null, weekStartIsodow = null, freeHistoryDays = null, minAgeYears = null, messageEditWindowSeconds = window, typingTtlSeconds = ttl)

    private fun row(vm: ChatViewModel, id: String) = vm.state.value.rows.first { it.id == id }

    // ---- reactions on messages ----

    @Test fun messageReactionsLoadAsRowsOnePerPersonNeverACount() {
        val data = FakeSocialData().apply {
            seedChat()
            messageReactions["m-2"] = mutableListOf(ReactionEntry(ANA, "😂"), ReactionEntry(ME, "🔥"))
        }
        val vm = ChatViewModel(data, GROUP)
        assertEquals(listOf(ReactionEntry(ANA, "😂"), ReactionEntry(ME, "🔥")), row(vm, "m-2").reactions)
        assertTrue("no chip without reactions", row(vm, "m-3").reactions.isEmpty())
        assertTrue("the photo keeps its post's reactions", row(vm, "m-1").reactions.isNotEmpty())
    }

    @Test fun anotherEmojiReplacesMineAndMineAgainTakesItBack() {
        val data = FakeSocialData().apply { seedChat() }
        val vm = ChatViewModel(data, GROUP)
        vm.reactToMessage("m-2", "🔥")
        assertEquals(listOf("🔥"), row(vm, "m-2").reactions.filter { it.userId == ME }.map { it.emoji })
        vm.reactToMessage("m-2", "💖")
        assertEquals("one per person: replaced", listOf("💖"), row(vm, "m-2").reactions.map { it.emoji })
        assertEquals(listOf("💖"), data.messageReactions["m-2"].orEmpty().map { it.emoji })
        vm.reactToMessage("m-2", "💖")
        assertTrue("my own emoji again takes it back", row(vm, "m-2").reactions.isEmpty())
        assertTrue(data.calls.contains("unreactToMessage:m-2"))

        vm.reactToMessage("m-6", "😂")
        assertEquals("voice messages too", listOf("😂"), row(vm, "m-6").reactions.map { it.emoji })
        vm.reactToMessage("m-1", "😂")
        assertFalse("a photo message is reacted to through its post", data.calls.any { it.startsWith("reactToMessage:m-1") })
    }

    @Test fun aFailedMessageReactionIsUndone() {
        val data = FakeSocialData().apply {
            seedChat()
            messageReactions["m-2"] = mutableListOf(ReactionEntry(ME, "🔥"))
        }
        val vm = ChatViewModel(data, GROUP)
        val seen = collect(vm.effects)
        data.failNext += "reactToMessage:m-2:💖"
        vm.reactToMessage("m-2", "💖")
        assertEquals("the earlier emoji is back", listOf(ReactionEntry(ME, "🔥")), row(vm, "m-2").reactions)
        assertTrue(seen.contains(ChatEffect.ReactionFailed))
        data.failNext += "unreactToMessage:m-2"
        vm.unreactToMessage("m-2")
        assertEquals(listOf(ReactionEntry(ME, "🔥")), row(vm, "m-2").reactions)
    }

    @Test fun messageReactionsStayLive() = runBlocking {
        val data = FakeSocialData().apply { seedChat() }
        val vm = ChatViewModel(data, GROUP)
        data.emit(GroupEvent.MessageReactionChanged(GROUP, MessageReaction("m-2", ANA, "😂", GROUP, BASE)))
        data.emit(GroupEvent.MessageReactionChanged(GROUP, MessageReaction("m-2", ANA, "🔥", GROUP, BASE.plusSeconds(1))))
        assertEquals("an update replaces Ana's row", listOf("🔥"), row(vm, "m-2").reactions.map { it.emoji })
        // Ana took hers back: the broadcast names only the message; its rows are read again.
        data.emit(GroupEvent.MessageReactionsChanged(GROUP, "m-2"))
        assertTrue(row(vm, "m-2").reactions.isEmpty())
    }

    // ---- editing ----

    @Test fun editIsOfferedOnMyOwnTextInsideTheWindowOnly() {
        val data = FakeSocialData().apply { seedChat(); config = chatConfig(window = 900) }
        val vm = ChatViewModel(data, GROUP, MutableClock(BASE.plusSeconds(360)))
        assertTrue(row(vm, "m-5").canEdit)
        assertFalse("not someone else's", row(vm, "m-2").canEdit)
        assertFalse("not a voice message", row(vm, "m-6").canEdit)

        val late = ChatViewModel(FakeSocialData().apply { seedChat(); config = chatConfig(window = 900) }, GROUP, MutableClock(BASE.plusSeconds(300 + 901)))
        assertFalse("the window has passed", row(late, "m-5").canEdit)
        val unknown = ChatViewModel(FakeSocialData().apply { seedChat() }, GROUP, MutableClock(BASE.plusSeconds(360)))
        assertFalse("no window known → no Edit", row(unknown, "m-5").canEdit)
    }

    @Test fun editingHoldsTheTextAndSavesItAsEdited() {
        val data = FakeSocialData().apply { seedChat(); config = chatConfig(window = 900) }
        val vm = ChatViewModel(data, GROUP, MutableClock(BASE.plusSeconds(360)))
        vm.setDraft("half a thought")
        vm.startReply(row(vm, "m-2"))
        vm.startEdit(row(vm, "m-5"))
        assertEquals("m-5", vm.state.value.editing)
        assertNull("the reply gives way to the edit", vm.state.value.replyTo)
        assertEquals("no way", vm.state.value.draft)

        vm.setDraft("no way!")
        vm.send()
        assertNull(vm.state.value.editing)
        assertEquals("the unsent draft comes back", "half a thought", vm.state.value.draft)
        assertEquals("no way!", row(vm, "m-5").message.body)
        assertTrue("\"Edited\" under it", row(vm, "m-5").edited)
        assertTrue(data.calls.contains("editMessage:m-5:no way!"))
        assertFalse("an edit sends no new message", data.calls.any { it.startsWith("sendText") })
    }

    @Test fun cancellingKeepsTheMessageAndTheSameTextMakesNoCall() {
        val data = FakeSocialData().apply { seedChat(); config = chatConfig(window = 900) }
        val vm = ChatViewModel(data, GROUP, MutableClock(BASE.plusSeconds(360)))
        vm.setDraft("draft")
        vm.startEdit(row(vm, "m-5"))
        vm.setDraft("something else")
        vm.cancelEdit()
        assertNull(vm.state.value.editing)
        assertEquals("draft", vm.state.value.draft)
        assertEquals("no way", row(vm, "m-5").message.body)

        vm.startEdit(row(vm, "m-5"))
        vm.send()
        assertNull(vm.state.value.editing)
        assertFalse(data.calls.any { it.startsWith("editMessage") })
    }

    @Test fun aFailedEditPutsTheTextBack() {
        val data = FakeSocialData().apply { seedChat(); config = chatConfig(window = 900) }
        val vm = ChatViewModel(data, GROUP, MutableClock(BASE.plusSeconds(360)))
        val seen = collect(vm.effects)
        vm.startEdit(row(vm, "m-5"))
        vm.setDraft("nope")
        data.failNext += "editMessage:m-5:nope"
        vm.send()
        assertEquals("the message gets its text back", "no way", row(vm, "m-5").message.body)
        assertFalse(row(vm, "m-5").edited)
        assertEquals("the composer holds the edit again", "m-5", vm.state.value.editing)
        assertEquals("nope", vm.state.value.draft)
        assertTrue(seen.contains(ChatEffect.EditFailed))
    }

    @Test fun someoneElsesEditArrivesInPlace() = runBlocking {
        val data = FakeSocialData().apply { seedChat() }
        val vm = ChatViewModel(data, GROUP)
        val before = vm.state.value.rows.map { it.id }
        val edited = row(vm, "m-2").message.copy(body = "strictly vibes only", editedAt = BASE.plusSeconds(200))
        data.emit(GroupEvent.MessageUpdated(GROUP, edited))
        assertEquals("strictly vibes only", row(vm, "m-2").message.body)
        assertTrue(row(vm, "m-2").edited)
        assertEquals("in place", before, vm.state.value.rows.map { it.id })
    }

    // ---- typing ----

    @Test fun typingIsSentAtMostEveryHalfTtlAndStopsWhenEmptiedOrSent() {
        val clock = MutableClock(BASE.plusSeconds(3_600))
        val data = FakeSocialData().apply { seedChat(); config = chatConfig(ttl = 6) }
        val vm = ChatViewModel(data, GROUP, clock)
        vm.setDraft("o")
        clock.now = clock.now.plusSeconds(2)
        vm.setDraft("on")
        assertEquals("not again before half the TTL", listOf(true), data.typingCalls)
        clock.now = clock.now.plusSeconds(1)
        vm.setDraft("on my")
        assertEquals(listOf(true, true), data.typingCalls)
        vm.setDraft("")
        assertEquals("the field emptied", listOf(true, true, false), data.typingCalls)
        vm.setDraft("on my way")
        vm.send()
        assertEquals("sent", listOf(true, true, false, true, false), data.typingCalls)
        vm.stopTyping()
        assertEquals("nothing more once stopped", 5, data.typingCalls.size)
    }

    @Test fun noTypingWithoutATtlOrWhileEditing() {
        val data = FakeSocialData().apply { seedChat() }
        val vm = ChatViewModel(data, GROUP)
        vm.setDraft("hello")
        assertTrue("typing_ttl_s unknown", data.typingCalls.isEmpty())

        val editing = FakeSocialData().apply { seedChat(); config = chatConfig(window = 900, ttl = 6) }
        val edit = ChatViewModel(editing, GROUP, MutableClock(BASE.plusSeconds(360)))
        edit.startEdit(row(edit, "m-5"))
        edit.setDraft("no way!")
        assertTrue("editing a sent message is not typing", editing.typingCalls.isEmpty())
    }

    @Test fun theTypingLineNamesPeopleInTheOrderTheyStartedAndExpires() = runBlocking {
        val clock = MutableClock(BASE.plusSeconds(3_600))
        val data = FakeSocialData().apply {
            seedChat()
            typingNow = clock.now
            typingRows += ChatTyping(GROUP, ANA, clock.now.plusSeconds(4))
        }
        val vm = ChatViewModel(data, GROUP, clock)
        assertEquals("read when the thread opens", listOf("Ana"), vm.state.value.typing)
        data.emit(GroupEvent.TypingChanged(GROUP, ChatTyping(GROUP, BEN, clock.now.plusSeconds(6))))
        data.emit(GroupEvent.TypingChanged(GROUP, ChatTyping(GROUP, ME, clock.now.plusSeconds(6))))
        data.emit(GroupEvent.TypingChanged(GROUP, ChatTyping(GROUP, ANA, clock.now.plusSeconds(6))))
        assertEquals("a renewal keeps its place; mine never shows", listOf("Ana", "Ben"), vm.state.value.typing)
        data.emit(GroupEvent.TypingChanged(GROUP, ChatTyping(GROUP, ANA, clock.now)))
        assertEquals("stopped", listOf("Ben"), vm.state.value.typing)
        clock.now = clock.now.plusSeconds(7)
        vm.pruneTyping()
        assertTrue("until passed, with no event", vm.state.value.typing.isEmpty())
        data.emit(GroupEvent.TypingChanged(GROUP, ChatTyping("g-other", BEN, clock.now.plusSeconds(6))))
        assertTrue(vm.state.value.typing.isEmpty())
    }
}

/** A clock the tests move by hand. */
class MutableClock(@Volatile var now: Instant) : Clock() {
    override fun getZone(): ZoneId = ZoneOffset.UTC
    override fun withZone(zone: ZoneId?): Clock = this
    override fun instant(): Instant = now
}
