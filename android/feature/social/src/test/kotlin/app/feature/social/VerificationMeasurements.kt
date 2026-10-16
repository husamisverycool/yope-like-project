package app.feature.social

import android.graphics.Bitmap
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.test.SemanticsNodeInteraction
import androidx.compose.ui.test.captureToImage
import androidx.compose.ui.test.getBoundsInRoot
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onAllNodesWithContentDescription
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onFirst
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.unit.DpRect
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.designsystem.generated.Tokens
import app.feature.social.FakeSocialData.Companion.GROUP
import app.feature.social.FakeSocialData.Companion.ME
import app.feature.social.albums.AlbumUiState
import app.feature.social.albums.AlbumViewContent
import app.feature.social.albums.AlbumViewModel
import app.feature.social.albums.AlbumsListContent
import app.feature.social.albums.AlbumsViewModel
import app.feature.social.chat.ChatContent
import app.feature.social.chat.ChatNav
import app.feature.social.chat.ChatUiState
import app.feature.social.chat.ChatViewModel
import app.feature.social.chat.RecorderControls
import app.feature.social.chat.VoiceUi
import app.feature.social.viewer.PhotoViewerContent
import app.feature.social.viewer.PhotoViewerViewModel
import app.feature.social.viewer.ViewerNav
import app.feature.social.viewer.ViewerUiState
import app.feature.social.walls.BrowseViewModel
import app.feature.social.walls.WallMineContent
import app.feature.social.walls.WallNav
import app.feature.social.walls.WallViewModel
import app.feature.social.walls.WallsBrowseContent
import app.feature.social.week.HistoryNav
import app.feature.social.week.HistoryViewModel
import app.feature.social.week.RecapListContent
import app.feature.social.week.RecapListViewModel
import app.feature.social.week.RecapNav
import app.feature.social.week.RecapViewModel
import app.feature.social.week.WeekEditContent
import app.feature.social.week.WeekEditViewModel
import app.feature.social.week.WeekHistoryContent
import app.feature.social.week.WeekRecapPreview
import app.model.PhotoContext
import app.ui.foundation.GlyphInk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import org.junit.After
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.io.File
import java.time.LocalDate
import java.time.ZoneOffset

/**
 * Verification input (docs/SCREENS_BRIEF.md rule 8): element bounds (dp, from semantics and test tags) and pixel
 * colours of the rendered screens, in light and dark, written to `build/verification/<surface>.json` for
 * `android/feature/social/verification/checklists.py`. Nothing is asserted here; the checklists compare with the tokens.
 */
@RunWith(AndroidJUnit4::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(qualifiers = "w393dp-h852dp-xhdpi")
@OptIn(ExperimentalCoroutinesApi::class)
class VerificationMeasurements {
    @get:Rule val compose = createComposeRule()
    private val out = linkedMapOf<String, JsonObject>()
    private var bitmap: Bitmap? = null
    private val density = 2f
    private val current = androidx.compose.runtime.mutableStateOf<(@Composable () -> Unit)?>(null)
    private var started = false

    @Before fun setUp() {
        fixLocale()
        Dispatchers.setMain(UnconfinedTestDispatcher())
        app.feature.social.week.RecapEdits.pending.value = emptyMap()
    }

    @After fun tearDown() = Dispatchers.resetMain()

    /** One setContent per test; later screens replace the content. */
    private fun render(data: FakeSocialData, dark: Boolean = false, content: @Composable () -> Unit) {
        current.value = { TestScreen(data, dark = dark) { content() } }
        if (!started) {
            compose.setContent { current.value?.invoke() }
            started = true
        }
        compose.waitForIdle()
        bitmap = compose.onRoot().captureToImage().asAndroidBitmap()
    }

    private fun desc(text: String, substring: Boolean = true): SemanticsNodeInteraction =
        compose.onAllNodesWithContentDescription(text, substring = substring, useUnmergedTree = true).onFirst()

    private fun text(text: String): SemanticsNodeInteraction = compose.onAllNodesWithText(text, useUnmergedTree = true).onFirst()

    private fun tag(tag: String): SemanticsNodeInteraction = compose.onAllNodesWithTag(tag, useUnmergedTree = true).onFirst()

    private fun box(name: String, n: SemanticsNodeInteraction) {
        val r: DpRect = runCatching { n.getBoundsInRoot() }.getOrNull() ?: return
        out[name] = buildJsonObject {
            put("left", r.left.value); put("top", r.top.value); put("right", r.right.value); put("bottom", r.bottom.value)
            put("width", (r.right - r.left).value); put("height", (r.bottom - r.top).value)
        }
    }

    private fun colour(name: String, xDp: Float, yDp: Float) {
        val b = bitmap ?: return
        val x = (xDp * density).toInt().coerceIn(0, b.width - 1)
        val y = (yDp * density).toInt().coerceIn(0, b.height - 1)
        out[name] = buildJsonObject { put("hex", String.format("#%06X", b.getPixel(x, y) and 0xFFFFFF)); put("x", xDp); put("y", yDp) }
    }

    private fun value(name: String, v: Float) {
        out[name] = buildJsonObject { put("value", v) }
    }

    private fun b(name: String): JsonObject? = out[name]
    private fun JsonObject.f(key: String) = (this[key] as JsonPrimitive).content.toFloat()

    private fun write(surface: String) {
        val dir = File("build/verification").apply { mkdirs() }
        File(dir, "$surface.json").writeText(JsonObject(out).toString())
        out.clear()
    }

    private val chatNav = ChatNav({}, {}, {}, {}, {}, { _, _ -> }, {})

    @Composable
    private fun Chat(data: FakeSocialData) {
        ChatContent(
            ChatViewModel(data, GROUP).state.value, ChatUiState(), chatNav, null, VoiceUi.Idle, RecorderControls(),
            {}, {}, {}, {}, { _, _ -> }, { _, _ -> }, {}, {}, {}, {}, {}, {}, {}, {}, zone = ZoneOffset.UTC, today = LocalDate.parse("2026-10-12"),
        )
    }

    /** chat.thread / chat.composer / chat.voice / chat.reactions. */
    @Test fun chat() {
        val data = FakeSocialData().apply { seedThread() }
        for (dark in listOf(false, true)) {
            val p = if (dark) "dark." else ""
            render(data, dark) { Chat(data) }
            box("${p}back", desc("Back", false))
            box("${p}title", text("Sunday dinners"))
            box("${p}text1", desc("Ben, strictly vibes only tonight", false))
            box("${p}text2", desc("Ben, who's in for sunday?", false))
            box("${p}photo", desc("Ana's photo"))
            box("${p}chip", desc("Reactions:"))
            box("${p}voice", desc("Ben's voice message"))
            box("${p}field", tag("message.field"))
            box("${p}mic", desc("Record a voice message", false))
            box("${p}camera", desc("Take photo", false))
            colour("${p}page", 4f, 300f)
            b("${p}field")?.let { f -> colour("${p}fieldFill", (f.f("left") + f.f("right")) / 2, f.f("top") + 4f) }
            b("${p}voice")?.let { v -> colour("${p}voiceFill", v.f("left") + 6f, (v.f("top") + v.f("bottom")) / 2) }
            b("${p}chip")?.let { c -> colour("${p}chipFill", c.f("left") + 3f, c.f("top") + 3f) }
        }
        val box = Tokens.Sizes.globalIcon
        val hit = maxOf(Tokens.Sizes.globalHeaderButton, Tokens.Sizes.globalMinTouchTargetAndroid)
        // The mic glyph's ink edge: its hit box's right less half the hit box's extra width, less the glyph's trailing padding.
        value("micInkTrailingPad", (GlyphInk.trailing(Tokens.Icons.globalMic, box) + (hit - box) / 2).value)
        write("chat")
    }

    /** photo.viewer (dark in both appearances). */
    @Test fun viewer() {
        val data = viewerData()
        val nav = ViewerNav({}, { _, _ -> }, { _, _ -> }, { _, _ -> }, {})
        for (dark in listOf(false, true)) {
            val p = if (dark) "dark." else ""
            render(data, dark) {
                PhotoViewerContent(PhotoViewerViewModel(data, GROUP, "v-1", PhotoContext.Album, "a-v", null).state.value, ViewerUiState(), nav, VoiceUi.Idle, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {})
            }
            box("${p}header", text("Ana Lima"))
            box("${p}pill", desc("1 of 3", false))
            box("${p}close", desc("Close", false))
            box("${p}photo", tag("viewer.photo"))
            box("${p}divider", tag("viewer.divider"))
            box("${p}comment", desc("Ben, whoa!", false))
            box("${p}field", tag("message.field"))
            box("${p}chip", desc("Reactions:"))
            box("${p}voice", desc("Ana's voice message"))
            colour("${p}page", 4f, 760f)
            b("${p}field")?.let { f -> colour("${p}fieldFill", (f.f("left") + f.f("right")) / 2, f.f("top") + 4f) }
            b("${p}close")?.let { c -> colour("${p}closeFill", c.f("left") + 3f, (c.f("top") + c.f("bottom")) / 2) }
            b("${p}pill")?.let { c -> colour("${p}pillFill", c.f("left") + 4f, (c.f("top") + c.f("bottom")) / 2) }
            b("${p}divider")?.let { d -> colour("${p}dividerInk", (d.f("left") + d.f("right")) / 2, d.f("top") + 0.25f) }
        }
        write("viewer")
    }

    private val wallNav = WallNav({}, {}, { _, _, _ -> }, { _, _ -> }, {}, {}, {}, {}, {})

    /** walls.mine (walls.member shares its layout) and walls.browse. */
    @Test fun walls() {
        val data = FakeSocialData().apply { seedWallWeeks(ME) }
        val state = WallViewModel(data, ME).state.value
        for (dark in listOf(false, true)) {
            val p = if (dark) "dark." else ""
            render(data, dark) { WallMineContent(state, wallNav, {}, {}, zone = ZoneOffset.UTC, today = LocalDate.parse("2026-10-14")) }
            box("${p}name", text("Sam Rivera"))
            box("${p}avatar", tag("wall.avatar"))
            box("${p}settings", desc("Settings", false))
            box("${p}tile1", desc("Your photo, October 12, 2026", false))
            box("${p}tile2", desc("Your photo, October 13, 2026", false))
            box("${p}add", desc("Add photos", false))
            box("${p}header", desc("Week 42"))
            box("${p}header2", desc("Week 41"))
            colour("${p}page", 4f, 400f)
            b("${p}add")?.let { a -> colour("${p}addFill", a.f("left") + 6f, a.f("top") + 6f) }
        }
        val people = FakeSocialData().apply { seedPeople() }
        val browse = BrowseViewModel(people, approximations = false).state.value
        render(people) { WallsBrowseContent(browse, wallNav, {}, {}) }
        box("browse.title", text("Friends"))
        box("browse.search", desc("Search", false))
        box("browse.cell1", desc("Ana Lima's profile", false))
        box("browse.cell2", desc("Ben Okafor's profile", false))
        box("browse.cell4", desc("Chloe Martin's profile", false))
        write("walls")
    }

    /** week.history, the recap list and preview, week.edit. */
    @Test fun week() {
        val data = FakeSocialData().apply { seedRecaps() }
        val history = HistoryViewModel(data, GROUP) { LocalDate.parse("2026-10-14") }.state.value
        val historyNav = HistoryNav({}, { _, _ -> }, {}, {}, {})
        for (dark in listOf(false, true)) {
            val p = if (dark) "dark." else ""
            render(data, dark) { WeekHistoryContent(history, historyNav, {}, {}) }
            box("${p}h.title", text("Sunday dinners"))
            box("${p}h.header", desc("Week 42"))
            box("${p}h.more", desc("More Options", false))
            box("${p}h.tile1", desc("Monday, October 12, 2026", true))
            box("${p}h.tile2", desc("Tuesday, October 13, 2026", true))
            colour("${p}h.page", 4f, 500f)
        }
        val recapNav = RecapNav({}, {}, {}, {}, { _, _ -> }, {})
        val list = RecapListViewModel(data, GROUP).state.value
        render(data) { RecapListContent(list, recapNav, {}) }
        box("r.close", desc("Close", false))
        box("r.title", text("Recaps"))
        box("r.card1", desc("Recap of Week 42"))
        box("r.card2", desc("Recap of Week 41"))
        val preview = RecapViewModel(data, GROUP, "r-w").state.value
        for (dark in listOf(false, true)) {
            val p = if (dark) "dark." else ""
            render(data, dark) { WeekRecapPreview(preview, recapNav, {}) }
            box("${p}p.close", desc("Close", false))
            box("${p}p.pill", text("Save as Album"))
            box("${p}p.thumb", desc("Select photos", false))
            box("${p}p.cell1", desc("Sam's photo"))
            box("${p}p.cell2", desc("Ana's photo"))
            colour("${p}p.page", 4f, 830f)
            b("${p}p.cell1")?.let { c -> colour("${p}p.card", c.f("left") - 1f, c.f("top") - 1f) }
            b("${p}p.pill")?.let { c -> colour("${p}p.pillFill", c.f("left") + 6f, (c.f("top") + c.f("bottom")) / 2) }
        }
        val edit = WeekEditViewModel(data, GROUP, "r-w", null, false).state.value
        render(data) { WeekEditContent(edit, {}, {}, {}, { _, _ -> }, {}, {}) }
        box("e.strip1", desc("Monday, October 12, 2026"))
        box("e.cancel", text("Cancel"))
        box("e.update", text("Update"))
        box("e.message", text("Edit message"))
        box("e.album", text("Save as Album"))
        box("e.header", text("Photos taken in Week 42"))
        write("week")
    }

    /** albums.list and albums.view. */
    @Test fun albums() {
        val data = FakeSocialData().apply { seedAlbums() }
        val list = AlbumsViewModel(data, GROUP).state.value
        for (dark in listOf(false, true)) {
            val p = if (dark) "dark." else ""
            render(data, dark) { AlbumsListContent(list, {}, {}, {}, {}, {}) }
            box("${p}l.title", text("Albums"))
            box("${p}l.search", desc("Search", false))
            box("${p}l.row1", desc("birthday dinner, you created the album", false))
            box("${p}l.row2", desc("lake weekend, Ana created the album", false))
            colour("${p}l.page", 4f, 600f)
        }
        val view = AlbumViewModel(data, GROUP, "a-2").state.value
        for (dark in listOf(false, true)) {
            val p = if (dark) "dark." else ""
            render(data, dark) { AlbumViewContent(view, AlbumUiState(), {}, {}, {}) }
            box("${p}v.cover", desc("Cover of birthday dinner", false))
            box("${p}v.name", text("birthday dinner"))
            box("${p}v.meta", text("you created the album"))
            box("${p}v.rename", text("Rename"))
            box("${p}v.more", desc("More Options", false))
            box("${p}v.cell1", desc("Sam's photo"))
        }
        write("albums")
    }
}
