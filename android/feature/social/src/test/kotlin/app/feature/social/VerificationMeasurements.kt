package app.feature.social

import android.graphics.Bitmap
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.semantics.SemanticsNode
import androidx.compose.ui.test.SemanticsNodeInteraction
import androidx.compose.ui.test.captureToImage
import androidx.compose.ui.test.getBoundsInRoot
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onAllNodesWithContentDescription
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onFirst
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.unit.DpRect
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.data.repo.ReactionEntry
import app.feature.social.FakeSocialData.Companion.ANA
import app.feature.social.FakeSocialData.Companion.BASE
import app.feature.social.FakeSocialData.Companion.BEN
import app.feature.social.FakeSocialData.Companion.GROUP
import app.feature.social.FakeSocialData.Companion.ME
import app.feature.social.albums.AlbumViewContent
import app.feature.social.albums.AlbumViewModel
import app.feature.social.albums.AlbumsListContent
import app.feature.social.albums.AlbumsViewModel
import app.feature.social.chat.ChatContent
import app.feature.social.chat.ChatNav
import app.feature.social.chat.ChatUiState
import app.feature.social.chat.ChatViewModel
import app.feature.social.chat.VoiceControls
import app.feature.social.data.VoicePlayback
import app.feature.social.viewer.PhotoViewerContent
import app.feature.social.viewer.PhotoViewerViewModel
import app.feature.social.viewer.ViewerNav
import app.feature.social.viewer.ViewerUiState
import app.feature.social.walls.BrowseViewModel
import app.feature.social.walls.WallMemberContent
import app.feature.social.walls.WallMineContent
import app.feature.social.walls.WallNav
import app.feature.social.walls.WallViewModel
import app.feature.social.walls.WallsBrowseContent
import app.feature.social.week.HistoryNav
import app.feature.social.week.HistoryViewModel
import app.feature.social.week.RecapNav
import app.feature.social.week.RecapViewModel
import app.feature.social.week.WeekEditContent
import app.feature.social.week.WeekEditViewModel
import app.feature.social.week.WeekHistoryContent
import app.feature.social.week.WeekRecapContent
import app.model.PhotoContext
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

/**
 * Verification input (docs/SCREENS_BRIEF.md rule 8): element bounds (dp, from semantics) and pixel
 * colours of the rendered screens, written to `build/verification/<surface>.json` for
 * `design/verification/<surface>.md`. Nothing is asserted here; the checklists compare.
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

    @Before fun setUp() {
        fixLocale()
        Dispatchers.setMain(UnconfinedTestDispatcher())
    }

    @After fun tearDown() = Dispatchers.resetMain()

    private val current = androidx.compose.runtime.mutableStateOf<(@Composable () -> Unit)?>(null)
    private var started = false

    /** One setContent per test; later screens replace the content. */
    private fun render(data: FakeSocialData, content: @Composable () -> Unit) {
        current.value = { TestScreen(data) { content() } }
        if (!started) {
            compose.setContent { current.value?.invoke() }
            started = true
        }
        compose.waitForIdle()
        bitmap = compose.onRoot().captureToImage().asAndroidBitmap()
    }

    private fun node(desc: String, substring: Boolean = false, text: Boolean = false, merged: Boolean = false): SemanticsNodeInteraction =
        if (text) compose.onAllNodesWithText(desc, substring = substring, useUnmergedTree = !merged).onFirst()
        else compose.onAllNodesWithContentDescription(desc, substring = substring, useUnmergedTree = true).onFirst()

    private fun box(name: String, n: SemanticsNodeInteraction) {
        val r: DpRect = n.getBoundsInRoot()
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

    private fun boundsOf(name: String): JsonObject = out.getValue(name)
    private fun JsonObject.f(key: String) = (this[key] as JsonPrimitive).content.toFloat()

    private fun write(surface: String) {
        val dir = File("build/verification").apply { mkdirs() }
        File(dir, "$surface.json").writeText(JsonObject(out).toString())
        out.clear()
    }

    @Test fun chat() {
        val data = FakeSocialData().apply { seedChat() }
        val state = ChatViewModel(data, GROUP).state.value
        val nav = ChatNav({}, {}, {}, {}, {}, {}, {}, { _, _ -> })
        render(data) {
            ChatContent(state, ChatUiState(), nav, null, testVoice, VoicePlayback(null, false), VoiceControls(null), {}, {}, {}, {}, { _, _ -> }, { _, _ -> }, {}, {}, {}, {})
        }
        box("back", node("back"))
        box("capsule", node("Sunday dinners, group info"))
        box("recap", node("view recap"))
        box("photo", node("Ana’s pic, 8:01 PM"))
        box("theirBubble", node("Ben, valid"))
        box("theirBubble2", node("Ben, strictly vibes only tonight"))
        box("myBubble", node("you, no way"))
        box("reply", node("reply to Ana’s pic"))
        box("voiceMine", node("your voice message", substring = true))
        box("voiceTheirs", node("Ben’s voice message", substring = true))
        box("playMine", node("play voice message", substring = true))
        box("camera", node("send a pic"))
        box("field", node("message"))
        box("mic", node("record a voice message"))
        box("cluster", node("Reactions:", substring = true))
        box("caption", node("caption: face masks night"))
        val their = boundsOf("theirBubble")
        val mine = boundsOf("myBubble")
        val voice = boundsOf("voiceMine")
        val camera = boundsOf("camera")
        val mic = boundsOf("mic")
        val field = boundsOf("field")
        val reply = boundsOf("reply")
        val cap = boundsOf("capsule")
        colour("background", 5f, 300f)
        colour("theirBubbleFill", their.f("left") + 4f, (their.f("top") + their.f("bottom")) / 2)
        colour("myBubbleFill", mine.f("left") + 4f, (mine.f("top") + mine.f("bottom")) / 2)
        colour("voiceFill", voice.f("right") - 3f, voice.f("top") + 6f)
        colour("cameraFill", camera.f("left") + 4f, (camera.f("top") + camera.f("bottom")) / 2)
        colour("micFill", mic.f("left") + 4f, (mic.f("top") + mic.f("bottom")) / 2)
        colour("fieldFill", (field.f("left") + field.f("right")) / 2 + 60f, (field.f("top") + field.f("bottom")) / 2)
        colour("quoteFill", reply.f("left") + 6f, reply.f("top") + 40f)
        colour("controlFill", cap.f("right") - 6f, (cap.f("top") + cap.f("bottom")) / 2)
        val theirVoice = boundsOf("voiceTheirs")
        colour("voiceTheirsFill", theirVoice.f("right") - 3f, theirVoice.f("top") + 6f)
        out["screen"] = buildJsonObject { put("height", (bitmap!!.height / density)); put("width", (bitmap!!.width / density)) }

        // Typing: the send circle in the mic's slot; a failed send: indicator + label.
        data.failNext += "sendText:running late, sorry:"
        val vm = ChatViewModel(data, GROUP)
        vm.setDraft("running late, sorry")
        vm.send()
        val failedState = vm.state.value.copy(draft = "hi")
        render(data) {
            ChatContent(failedState, ChatUiState(), nav, null, testVoice, VoicePlayback(null, false), VoiceControls(null), {}, {}, {}, {}, { _, _ -> }, { _, _ -> }, {}, {}, {}, {})
        }
        box("send", node("send"))
        val send = boundsOf("send")
        colour("sendFill", send.f("left") + 4f, (send.f("top") + send.f("bottom")) / 2)
        box("failedBubble", node("you, running late, sorry"))
        box("failedLabel", node("couldn’t send — tap to try again", text = true))
        val fb = boundsOf("failedBubble")
        // Indicator: the red ring's leftmost ink, scanning right of the bubble on its centre line.
        val b = bitmap!!
        val cy = ((fb.f("top") + fb.f("bottom")) / 2 * density).toInt()
        val start = (fb.f("right") * density).toInt()
        val ink = (start until b.width).filter { x -> val c = b.getPixel(x, cy); android.graphics.Color.red(c) > 200 && android.graphics.Color.green(c) < 120 }
        if (ink.isNotEmpty()) out["indicatorInk"] = buildJsonObject { put("left", ink.first() / density); put("right", ink.last() / density); put("hex", String.format("#%06X", b.getPixel(ink.first() + 1, cy) and 0xFFFFFF)) }
        write("chat")
    }

    @Test fun viewer() {
        val data = FakeSocialData().apply {
            seedGroup()
            addPhoto("v-1", ANA, BASE.minusSeconds(86_400 * 2), caption = "sunday sunsets", voicePath = "u/$ANA/md-v-1/voice.m4a", voiceMs = 21_000)
            reactions["v-1"] = mutableListOf(ReactionEntry(BEN, "🔥"), ReactionEntry(ME, "💖"))
        }
        val state = PhotoViewerViewModel(data, GROUP, "v-1", PhotoContext.Single, "v-1", null).state.value
        render(data) {
            PhotoViewerContent(state, ViewerUiState(coach = false), ViewerNav({}, { _, _ -> }, { _, _ -> }, { _, _ -> }, {}), testVoice, VoicePlayback(null, false), {}, {}, {}, {}, {}, {}, {}, {}, {}, {})
        }
        box("close", node("close"))
        box("more", node("more"))
        box("titleLine1", node("Ana sent to Sunday dinners", text = true))
        box("date", node("Oct 10 2026", text = true))
        box("photo", node("Ana’s pic, Oct 10 2026"))
        box("sender", node("Ana"))
        box("toggle", node("i'm in this"))
        box("cluster", node("Reactions:", substring = true))
        box("voice", node("Ana’s voice message", substring = true))
        box("field", node("message"))
        box("camera", node("send a pic"))
        box("quickFire", node("React with fire"))
        colour("background", 5f, 60f)
        val toggle = boundsOf("toggle")
        colour("toggleFill", toggle.f("right") - 4f, (toggle.f("top") + toggle.f("bottom")) / 2)
        write("viewer")
    }

    @Test fun walls() {
        val data = FakeSocialData().apply { seedWall(ME, 14) }
        val nav = WallNav({}, {}, { _, _, _ -> }, { _, _ -> }, {}, {})
        val wall = WallViewModel(data, ME).state.value
        render(data) { WallMineContent(wall, null, nav) }
        box("settings", node("settings"))
        box("title", node("my wall", text = true))
        box("tile1", node("your pic", substring = true))
        val tiles = compose.onAllNodesWithContentDescription("your pic", substring = true, useUnmergedTree = true).fetchSemanticsNodes()
        record("tile2", tiles[1])
        record("tile4", tiles[3])
        colour("background", 5f, 400f)
        val s = boundsOf("settings")
        colour("settingsFill", s.f("left") + 4f, (s.f("top") + s.f("bottom")) / 2)
        write("walls.mine")

        val memberData = FakeSocialData().apply { seedWall(ANA, 8) }
        render(memberData) { WallMemberContent(WallViewModel(memberData, ANA).state.value, null, nav) }
        box("back", node("back"))
        val memberTiles = compose.onAllNodesWithContentDescription("Ana’s pic", substring = true, useUnmergedTree = true).fetchSemanticsNodes()
        record("tile1", memberTiles[0])
        record("tile2", memberTiles[1])
        val back = boundsOf("back")
        colour("backFill", back.f("left") + 4f, (back.f("top") + back.f("bottom")) / 2)
        colour("background", 5f, 400f)
        write("walls.member")

        val browse = BrowseViewModel(FakeSocialData().apply { seedWall(ME, 10) })
        val loader = browse.wall.value!!
        render(data) { WallsBrowseContent(browse.state.value, loader, loader.state.value, nav, {}, {}) }
        box("title", node("me & friends", text = true))
        box("me", node("my wall"))
        box("ana", node("Ana’s wall"))
        box("tile1", node("your pic", substring = true))
        write("walls.browse")
    }

    private fun record(name: String, n: SemanticsNode) {
        val r = n.boundsInRoot
        out[name] = buildJsonObject {
            put("left", r.left / density); put("top", r.top / density); put("right", r.right / density); put("bottom", r.bottom / density)
            put("width", r.width / density); put("height", r.height / density)
        }
    }

    @Test fun week() {
        val data = FakeSocialData().apply { seedWeek() }
        val recap = RecapViewModel(data, GROUP, "r-w").state.value
        render(data) { WeekRecapContent(recap, RecapNav({}, {}, { _, _ -> }, { _, _ -> }, {}), {}) }
        box("back", node("back"))
        box("edit", node("edit"))
        box("title", node("12 oct-18 oct", text = true))
        box("card", node("recap of 12 oct-18 oct"))
        box("recapSegment", node("recap", text = true))
        box("picsSegment", node("pics", text = true))
        val pics = compose.onAllNodesWithContentDescription("pic, Oct", substring = true, useUnmergedTree = true).fetchSemanticsNodes()
        record("cardTile1", pics[0])
        record("cardTile2", pics[1])
        record("picTile1", pics[6])
        record("picTile2", pics[7])
        colour("background", 5f, 120f)
        write("week.recap")

        val edit = WeekEditViewModel(data, GROUP, "r-w", null, false).state.value
        render(data) { WeekEditContent(edit, {}, {}, { _, _ -> }, {}, {}, {}) }
        box("close", node("close"))
        box("title", node("edit recap", text = true))
        box("save", node("save", text = true))
        box("tile1", node("pic, Oct 12 2026", substring = true))
        colour("background", 5f, 700f)
        val save = boundsOf("save")
        colour("saveFill", save.f("left") - 20f, (save.f("top") + save.f("bottom")) / 2)
        write("week.edit")

        val history = HistoryViewModel(data, GROUP) { LocalDate.parse("2026-10-21") }.state.value
        render(data) { WeekHistoryContent(history, HistoryNav({}, { _, _ -> }, {}, {}, {}), {}, {}) }
        box("title", node("Sunday dinners", text = true))
        box("week43", node("Week 43", text = true))
        box("week42", node("Week 42", text = true))
        box("range42", node("Oct 12", substring = true, text = true))
        val tiles = compose.onAllNodesWithContentDescription("photo", substring = true, useUnmergedTree = true).fetchSemanticsNodes()
        record("tile1", tiles[0])
        record("tile2", tiles[1])
        box("mon", node("Mon", text = true))
        box("add", node("Add Photos"))
        val add = boundsOf("add")
        colour("addFill", add.f("left") + 6f, add.f("top") + 6f)
        val empty = compose.onAllNodesWithContentDescription("no photos", substring = true, useUnmergedTree = true).fetchSemanticsNodes()
        record("emptyDay1", empty[0])
        val e = boundsOf("emptyDay1")
        colour("emptyFill", e.f("left") + 6f, e.f("top") + 6f)
        colour("background", 5f, 700f)
        write("week.history")
    }

    @Test fun albums() {
        val data = FakeSocialData().apply { seedAlbums() }
        val list = AlbumsViewModel(data, GROUP).state.value
        render(data) { AlbumsListContent(list, {}, {}, {}, {}) }
        box("title", node("memory albums", text = true))
        box("cover1", node("birthday dinner", text = true, merged = true))
        box("cover2", node("lake weekend", text = true, merged = true))
        box("name1", node("birthday dinner", text = true))
        val covers = compose.onAllNodesWithContentDescription("saved by", substring = true).fetchSemanticsNodes()
        out["coverCount"] = buildJsonObject { put("n", covers.size) }
        colour("background", 5f, 700f)
        write("albums.list")

        val album = AlbumViewModel(data, GROUP, "a-2").state.value
        render(data) { AlbumViewContent(album, {}, {}, {}, {}, {}) }
        box("title", node("birthday dinner", text = true))
        box("more", node("more"))
        val tiles = compose.onAllNodesWithContentDescription("pic, Oct", substring = true, useUnmergedTree = true).fetchSemanticsNodes()
        record("tile1", tiles[0])
        record("tile2", tiles[1])
        record("tile4", tiles[3])
        colour("background", 5f, 700f)
        write("albums.view")
    }
}
