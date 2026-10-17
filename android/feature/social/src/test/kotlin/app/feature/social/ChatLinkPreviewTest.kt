package app.feature.social

import androidx.compose.ui.test.assertContentDescriptionEquals
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.data.model.LinkPreview
import app.data.model.MessageKind
import app.data.model.PublicAppConfig
import app.feature.social.FakeSocialData.Companion.BASE
import app.feature.social.FakeSocialData.Companion.BEN
import app.feature.social.FakeSocialData.Companion.GROUP
import app.feature.social.chat.ChatEffect
import app.feature.social.chat.ChatLinkPreviews
import app.feature.social.chat.ChatNav
import app.feature.social.chat.ChatScreen
import app.feature.social.chat.ChatViewModel
import app.feature.social.chat.LinkPreviewBuilder
import app.feature.social.data.LinkImageEncoder
import app.feature.social.data.LinkPage
import app.feature.social.data.LinkPageReader
import app.feature.social.data.LinkPreviewDraft
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
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

/**
 * `chat.thread.layout.linkPreview` (migration 0053): which link gets a preview (Linkify, hence Robolectric), the pipeline
 * read → downscale → draft over fakes, the view model's best-effort, silent flow, and the card's semantics (no image
 * captures: baselines are recorded by hand only).
 */
@RunWith(AndroidJUnit4::class)
@Config(qualifiers = "w393dp-h852dp-xhdpi")
@OptIn(ExperimentalCoroutinesApi::class)
class ChatLinkPreviewTest {
    @get:Rule val compose = createComposeRule()
    private val effects = CoroutineScope(SupervisorJob() + UnconfinedTestDispatcher())

    @Before fun setUp() {
        fixLocale()
        Dispatchers.setMain(UnconfinedTestDispatcher())
    }

    @After fun tearDown() {
        effects.cancel()
        Dispatchers.resetMain()
    }

    private class FakeReader(private val page: LinkPage?) : LinkPageReader {
        val asked = ArrayList<String>()
        override suspend fun read(url: String): LinkPage? {
            asked += url
            return page
        }
    }

    private class FakeEncoder(private val out: ByteArray?) : LinkImageEncoder {
        val inputs = ArrayList<ByteArray>()
        override suspend fun jpeg(image: ByteArray): ByteArray? {
            inputs += image
            return out
        }
    }

    private fun chatConfig() =
        PublicAppConfig(invitationWindowSeconds = null, maxGroupMembers = null, weekStartIsodow = null, freeHistoryDays = null, minAgeYears = null, messageEditWindowSeconds = 900, typingTtlSeconds = null)

    // ---- which link ----

    @Test fun theFirstLinkWrittenWithItsSchemeIsTheCandidate() {
        val body = "menu at www.example.org or https://example.com/menu?day=fri and http://example.net"
        assertEquals("https://example.com/menu?day=fri", ChatLinkPreviews.candidate(body)?.text)
        assertEquals("HTTPS://Example.com/A", ChatLinkPreviews.candidate("HTTPS://Example.com/A")?.text)
        assertNull("the completed http://www.example.org is not in the text", ChatLinkPreviews.candidate("see www.example.org"))
        assertNull(ChatLinkPreviews.candidate("mail me@example.com"))
        assertNull(ChatLinkPreviews.candidate("no links here"))
        assertNull(ChatLinkPreviews.candidate(""))
    }

    @Test fun textIsTrimmedAndCutToTheServersLimitsAndTheHostLosesWww() {
        assertNull(ChatLinkPreviews.clip("  \n ", 10))
        assertEquals("A page", ChatLinkPreviews.clip("  A page  ", 10))
        val long = "é".repeat(400)
        assertEquals(ChatLinkPreviews.TITLE_MAX, ChatLinkPreviews.clip(long, ChatLinkPreviews.TITLE_MAX)?.let { it.codePointCount(0, it.length) })
        val emoji = "😀".repeat(150) // two UTF-16 units each: the server counts code points
        assertEquals(ChatLinkPreviews.SITE_MAX, ChatLinkPreviews.clip(emoji, ChatLinkPreviews.SITE_MAX)?.let { it.codePointCount(0, it.length) })
        assertEquals("example.com", ChatLinkPreviews.host("https://www.example.com/a"))
        assertEquals("news.example.com", ChatLinkPreviews.host("https://news.example.com"))
        val preview = LinkPreview("https://example.com/a", "A")
        assertEquals(preview, ChatLinkPreviews.keeps(preview, "see https://example.com/a"))
        assertNull(ChatLinkPreviews.keeps(preview, "never mind"))
    }

    // ---- pipeline ----

    @Test fun theBuilderReadsThePageOnceAndDownscalesItsImage() = runBlocking {
        val reader = FakeReader(LinkPage(title = "  Friday menu ", site = "Example Eats", image = byteArrayOf(1, 2, 3)))
        val encoder = FakeEncoder(byteArrayOf(9))
        val draft = LinkPreviewBuilder(reader, encoder).build("tonight? https://www.example.com/menu")
        assertEquals(LinkPreviewDraft("https://www.example.com/menu", "Friday menu", "Example Eats", byteArrayOf(9)), draft)
        assertEquals(listOf("https://www.example.com/menu"), reader.asked)
        assertTrue(encoder.inputs.single().contentEquals(byteArrayOf(1, 2, 3)))

        val imageOnly = LinkPreviewBuilder(FakeReader(LinkPage(image = byteArrayOf(1))), FakeEncoder(byteArrayOf(2))).build("https://www.example.com/p")
        assertEquals("without a site name, the host", LinkPreviewDraft("https://www.example.com/p", null, "example.com", byteArrayOf(2)), imageOnly)
    }

    @Test fun noPreviewWithoutALinkAPageOrSomethingToShow() = runBlocking {
        val unread = FakeReader(null)
        val builder = LinkPreviewBuilder(unread, FakeEncoder(byteArrayOf(2)))
        assertNull(builder.build("no link"))
        assertTrue("no link → the page is never read", unread.asked.isEmpty())
        assertNull("the page could not be read", builder.build("https://example.com"))
        assertNull("neither a title nor an image", LinkPreviewBuilder(FakeReader(LinkPage(site = "Example")), FakeEncoder(byteArrayOf(2))).build("https://example.com"))
        val titleOnly = LinkPreviewBuilder(FakeReader(LinkPage(title = "T", image = byteArrayOf(1))), FakeEncoder(null)).build("https://example.com")
        assertEquals("an image that cannot be encoded is left out", LinkPreviewDraft("https://example.com", "T", "example.com", null), titleOnly)
    }

    // ---- view model ----

    private fun previewing(reader: LinkPageReader, data: FakeSocialData) =
        ChatViewModel(data, GROUP, MutableClock(BASE.plusSeconds(360)), LinkPreviewBuilder(reader, FakeEncoder(byteArrayOf(7))))

    @Test fun sendingALinkBuildsItsPreviewAfterTheMessageIsSent() {
        val data = FakeSocialData().apply { seedChat() }
        val vm = previewing(FakeReader(LinkPage(title = "Friday menu", image = byteArrayOf(1))), data)
        vm.setDraft("dinner? https://example.com/menu")
        vm.send()
        val row = vm.state.value.rows.last()
        assertEquals("dinner? https://example.com/menu", row.message.body)
        assertEquals(LinkPreview("https://example.com/menu", "Friday menu", "example.com", "u/${FakeSocialData.ME}/links/l1.jpg"), row.linkPreview)
        val sent = data.calls.indexOfFirst { it.startsWith("sendText") }
        val previewed = data.calls.indexOfFirst { it.startsWith("setLinkPreview") }
        assertTrue("set_link_preview after send_message", sent in 0 until previewed)
        assertTrue(data.linkPreviewsSent.single().jpeg!!.contentEquals(byteArrayOf(7)))
    }

    @Test fun aFailedPreviewIsSilentAndLeavesTheMessageAlone() {
        // The fake's write names: "setLinkPreview:<the id sendText gives the new message>:<url>".
        val data = FakeSocialData().apply { seedChat(); failNext += "setLinkPreview:m-sent-${messages.size}:https://example.com" }
        val vm = previewing(FakeReader(LinkPage(title = "T")), data)
        val seen = ArrayList<ChatEffect>()
        effects.launch { vm.effects.collect { seen += it } }
        vm.setDraft("https://example.com")
        vm.send()
        val row = vm.state.value.rows.last()
        assertTrue(data.calls.any { it.startsWith("setLinkPreview") })
        assertNull(row.linkPreview)
        assertFalse(row.failed)
        assertEquals("only the send's own effect", listOf<ChatEffect>(ChatEffect.Sent), seen)
    }

    @Test fun noPreviewIsAskedForWithoutALinkOrWithoutABuilder() {
        val data = FakeSocialData().apply { seedChat() }
        val reader = FakeReader(LinkPage(title = "T"))
        val vm = previewing(reader, data)
        vm.setDraft("see you at 8")
        vm.send()
        assertTrue(reader.asked.isEmpty())

        val plain = ChatViewModel(data, GROUP)
        plain.setDraft("https://example.com")
        plain.send()
        assertFalse(data.calls.any { it.startsWith("setLinkPreview") })
    }

    @Test fun anEditThatDropsTheAddressDropsThePreviewAtOnce() {
        val data = FakeSocialData().apply {
            seedChat()
            config = chatConfig()
            val i = messages.indexOfFirst { it.id == "m-5" }
            messages[i] = messages[i].copy(body = "no way https://example.com/a", linkPreview = LinkPreview("https://example.com/a", "A"))
        }
        val vm = ChatViewModel(data, GROUP, MutableClock(BASE.plusSeconds(360)))
        val mine = vm.state.value.rows.first { it.id == "m-5" }
        assertEquals("A", mine.linkPreview?.title)
        vm.startEdit(mine)
        vm.setDraft("no way")
        vm.send()
        assertNull(vm.state.value.rows.first { it.id == "m-5" }.linkPreview)
    }

    @Test fun someoneElsesPreviewArrivesWithTheirMessage() {
        val data = FakeSocialData().apply { seedChat() }
        val vm = ChatViewModel(data, GROUP)
        val theirs = data.messages.first { it.id == "m-2" }
        runBlocking {
            vm.onEvent(app.data.realtime.GroupEvent.MessageUpdated(GROUP, theirs.copy(body = "${theirs.body} https://example.com/x", linkPreview = LinkPreview("https://example.com/x", "X", "Example"))))
        }
        assertEquals("X", vm.state.value.rows.first { it.id == "m-2" }.linkPreview?.title)
    }

    // ---- the card ----

    @Test fun theCardIsReadAsItsTitleAndSite() {
        val data = FakeSocialData().apply {
            seedChat()
            messages += FakeSocialData.message("m-9", GROUP, BEN, MessageKind.Text, body = "menu: https://example.com/menu", at = BASE.plusSeconds(500))
                .copy(linkPreview = LinkPreview("https://example.com/menu", "Friday menu", "Example Eats", null))
        }
        val vm = ChatViewModel(data, GROUP)
        compose.setContent { TestScreen(data) { ChatScreen(vm, null, ChatNav({}, {}, {}, {}, {}, { _, _ -> }, {})) } }
        compose.waitForIdle()
        compose.onNodeWithTag("chat.linkPreview").assertContentDescriptionEquals("Friday menu, Example Eats")
    }
}
