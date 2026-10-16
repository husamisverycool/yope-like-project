package app.feature.memory

import android.graphics.Bitmap
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.graphics.painter.ColorPainter
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.semantics.SemanticsNode
import androidx.compose.ui.semantics.getOrNull
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.captureToImage
import androidx.compose.ui.test.hasContentDescription
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.unit.dp
import app.designsystem.generated.Tokens
import app.feature.memory.birthday.BirthdayAddScreen
import app.feature.memory.birthday.BirthdayAddState
import app.feature.memory.birthday.BirthdayAddTags
import app.feature.memory.birthday.BirthdayRequestScreen
import app.feature.memory.birthday.BirthdayRequestTags
import app.feature.memory.birthday.ChoosePhotoStep
import app.feature.memory.birthday.ComposerStep
import app.feature.memory.birthday.ContributeState
import app.feature.memory.birthday.ContributeTags
import app.feature.memory.birthday.DateEntryPattern
import app.feature.memory.birthday.LocalTributePlayer
import app.feature.memory.birthday.MessageModal
import app.feature.memory.birthday.OwnContribution
import app.feature.memory.birthday.PhotosState
import app.feature.memory.birthday.RequestActions
import app.feature.memory.birthday.RequestState
import app.feature.memory.birthday.TributeActions
import app.feature.memory.birthday.TributeContent
import app.feature.memory.birthday.TributeScreen
import app.feature.memory.birthday.TributeState
import app.feature.memory.birthday.TributeTags
import app.feature.memory.birthday.sampleInfo
import app.feature.memory.birthday.samplePhotos
import app.feature.memory.common.LocalMemoryImages
import app.feature.memory.onthisday.DialTags
import app.feature.memory.onthisday.OnThisDayActions
import app.feature.memory.onthisday.OnThisDayScreen
import app.feature.memory.onthisday.OnThisDayTags
import app.feature.memory.onthisday.samplePage
import app.feature.memory.tagging.InThisPhotoContent
import app.feature.memory.tagging.TagRun
import app.feature.memory.tagging.TagRunController
import app.feature.memory.tagging.TagRunTags
import app.feature.memory.tagging.TaggedPerson
import app.feature.memory.yearstory.RecapCard
import app.feature.memory.yearstory.RecapCardPhoto
import app.feature.memory.yearstory.YearStoryActions
import app.feature.memory.yearstory.YearStoryScreen
import app.feature.memory.yearstory.YearStoryState
import app.feature.memory.yearstory.YearStoryTags
import app.feature.memory.yearstory.sampleCards
import app.feature.memory.yearstory.sampleRecap
import org.json.JSONObject
import org.junit.Test
import java.io.File

/**
 * Reads back what our screens lay out — the "ours" column of `design/verification/<surface>.android.md`
 * (android/feature/memory/verification/checklists.py). For each probe: its bounds (dp, screen top-left, 393 × 852,
 * no system bars in Robolectric) and, for text, its first and last baselines. Photos are drawn black so the
 * render that goes with it (`build/verification/<name>.png`, 2 px/dp) shows only the chrome for pixel checks
 * (circle sizes, ink, dial ticks).
 */
class MeasurementTest : SnapshotTest() {
    private val black = ColorPainter(Color.Black)

    private fun measure(name: String, probes: Map<String, SemanticsMatcher>, content: @Composable () -> Unit) {
        compose.mainClock.autoAdvance = false
        compose.setContent {
            MemoryTestContent {
                CompositionLocalProvider(
                    LocalMemoryImages provides { _ -> black },
                    LocalTributePlayer provides { _, _, modifier -> Box(modifier.background(Color.Red).testTag(PLAYER)) },
                    content = content,
                )
            }
        }
        compose.mainClock.advanceTimeBy(settleMillis)
        val density = compose.density.density
        fun dp(px: Float) = Math.round(px / density * 100) / 100.0
        val out = JSONObject()
        for ((key, matcher) in probes) {
            val node: SemanticsNode = compose.onAllNodes(matcher, useUnmergedTree = true).fetchSemanticsNodes().firstOrNull()
                ?: compose.onAllNodes(matcher).fetchSemanticsNodes().firstOrNull()
                ?: continue
            val r = node.boundsInRoot
            val o = JSONObject().put("left", dp(r.left)).put("top", dp(r.top)).put("right", dp(r.right)).put("bottom", dp(r.bottom))
                .put("width", dp(r.width)).put("height", dp(r.height))
            val layouts = mutableListOf<TextLayoutResult>()
            node.config.getOrNull(SemanticsActions.GetTextLayoutResult)?.action?.invoke(layouts)
            layouts.firstOrNull()?.let { t ->
                o.put("firstBaseline", dp(r.top + t.firstBaseline)).put("lastBaseline", dp(r.top + t.lastBaseline)).put("lines", t.lineCount)
            }
            out.put(key, o)
        }
        val dir = File("build/verification").apply { mkdirs() }
        File(dir, "$name.json").writeText(out.toString(2))
        val bitmap = compose.onRoot().captureToImage().asAndroidBitmap()
        File(dir, "$name.png").outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
    }

    private fun tag(t: String) = hasTestTag(t)
    private fun text(t: String, substring: Boolean = false) = hasText(t, substring = substring)
    private fun label(t: String, substring: Boolean = false) = hasContentDescription(t, substring = substring)

    @Test fun onthisday() = measure(
        "onthisday",
        mapOf(
            "back" to label("Back"), "title" to tag(OnThisDayTags.TITLE), "subtitle" to text("On this day · Maya"),
            "more" to tag(OnThisDayTags.MORE), "share" to tag(OnThisDayTags.SHARE), "random" to tag(OnThisDayTags.SHUFFLE),
            "dial" to tag(DialTags.DIAL), "play" to tag(DialTags.PLAY), "photo" to label("Photo by Maya", substring = true),
        ),
        // Measured as your own memory so the share circle is laid out (owner decision 12 hides it on others').
    ) { OnThisDayScreen(samplePage, OnThisDayActions(), isMine = { true }) }

    private val storyProbes = mapOf(
        "frame" to tag(YearStoryTags.CARD), "close" to label("Close"), "leading" to tag(YearStoryTags.LEADING),
        "share" to text("Share"), "position" to label(" of ", substring = true),
    )

    @Test fun yearStoryText() = measure(
        "year.story-text",
        storyProbes + mapOf("headline" to text("Year in Photos"), "subline" to text("Sunday Lunch · 2026")),
    ) { YearStoryScreen(YearStoryState.Story(sampleCards, 0, sampleRecap, paused = true), YearStoryActions()) }

    @Test fun yearStoryFact() = measure(
        "year.story-fact",
        storyProbes + mapOf("headline" to text("Sunday Lunch shared 1,284 photos this year")),
    ) { YearStoryScreen(YearStoryState.Story(sampleCards, 2, sampleRecap, paused = true), YearStoryActions()) }

    @Test fun yearStoryPhoto() = measure(
        "year.story-photo",
        // Your own photo (the sample's p2): the photo card that keeps its Share pill (owner decision 12).
        storyProbes + mapOf("date" to text("Saturday, March 14"), "name" to text("Post by Jesus")),
    ) { YearStoryScreen(YearStoryState.Story(sampleCards, 6, sampleRecap, paused = true), YearStoryActions()) }

    @Test fun yearStorySummary() = measure(
        "year.story-summary",
        storyProbes + mapOf("year" to text("2026"), "group" to text("Sunday Lunch")),
    ) { YearStoryScreen(YearStoryState.Story(sampleCards, 10, sampleRecap, style = 0), YearStoryActions()) }

    @Test fun recapCard() = measure(
        "year.story-recapcard",
        mapOf("card" to tag("card"), "cell0" to label("photo 0"), "cell1" to label("photo 1"), "cell4" to label("photo 4"), "cell23" to label("photo 23"), "title" to text("Week 27"), "name" to text("Sunday Lunch"), "detail" to text("Jul 3 – 9")),
    ) {
        Box(Modifier.padding(Tokens.Sizes.globalScreenMargin)) {
            RecapCard(
                (0 until 24).map { RecapCardPhoto(null, "photo $it") },
                "Week 27",
                Modifier.width(RECAP_CARD_WIDTH.dp).testTag("card"),
                name = "Sunday Lunch",
                detail = "Jul 3 – 9",
            )
        }
    }

    private val us = DateEntryPattern(listOf('M', 'd', 'y'), '/')

    @Test fun birthdayAdd() = measure(
        "birthday.add",
        mapOf(
            "header" to text("Birthday"), "headline" to text("Want a birthday video?"), "detail" to text("A week before", substring = true),
            "privacy" to text("Only the day", substring = true), "field" to text("07/05/1999"), "confirm" to tag(BirthdayAddTags.CONFIRM),
            "later" to text("Maybe later"),
        ),
    ) { BirthdayAddScreen(BirthdayAddState(loading = false, digits = "07051999"), us, {}, {}, {}, {}, {}, {}) }

    @Test fun birthdayAddManage() = measure(
        "birthday.add-manage",
        mapOf("row" to text("July 5"), "remove" to tag(BirthdayAddTags.REMOVE), "footer" to text("A week before", substring = true)),
    ) { BirthdayAddScreen(BirthdayAddState(loading = false, saved = java.time.LocalDate.of(1999, 7, 5)), us, {}, {}, {}, {}, {}, {}) }

    @Test fun birthdayRequest() = measure(
        "birthday.request",
        mapOf(
            "close" to label("Close"), "avatar" to tag(BirthdayRequestTags.AVATAR), "headline" to text("Ana's birthday video"),
            "body" to text("You're invited", substring = true), "card" to tag(BirthdayRequestTags.CTA), "cardTitle" to text("Message ideas"),
            "cardDetail" to text("Pick a photo", substring = true), "prompt1" to text("What do you appreciate most about Ana?"),
            "prompt2" to text("How has Ana impacted your life?"), "marker1" to text("1"), "marker2" to text("2"),
            "cta" to text("Add your photo"), "due" to text("Add yours by", substring = true),
        ),
    ) { BirthdayRequestScreen(RequestState.Ready(sampleInfo, contribution = null, closed = false), RequestActions()) }

    @Test fun birthdayRequestContributed() = measure(
        "birthday.request-contributed",
        mapOf(
            "card" to tag(BirthdayRequestTags.CTA), "title" to text("You added a photo"), "line" to text("You make every Sunday better"),
            "thumb" to tag(BirthdayRequestTags.THUMB), "change" to tag(BirthdayRequestTags.CHANGE), "remove" to tag(BirthdayRequestTags.REMOVE),
        ),
    ) {
        BirthdayRequestScreen(
            RequestState.Ready(sampleInfo, contribution = OwnContribution("p2", TestImages.url("p2-d", 4, 3), 4f / 3, "You make every Sunday better"), closed = false),
            RequestActions(),
        )
    }

    @Test fun contributePicker() = measure(
        "birthday.contribute-picker",
        mapOf(
            "cancel" to text("Cancel"), "title" to text("Choose a Photo"), "next" to text("Next"), "subtitle" to text("Photos you posted or are in"),
            "grid" to tag(ContributeTags.GRID), "cell0" to tag(ContributeTags.cell("p1")), "cell1" to tag(ContributeTags.cell("p2")), "cell4" to tag(ContributeTags.cell("p5")),
        ),
    ) { ChoosePhotoStep(sampleInfo, ContributeState(photos = PhotosState.Loaded(samplePhotos), selected = "p2"), {}, {}, {}, {}, {}) }

    @Test fun contributeComposer() = measure(
        "birthday.contribute-composer",
        mapOf(
            "title" to text("Birthday Video"), "close" to label("Close"), "photo" to tag(ContributeTags.PHOTO),
            "pill" to tag(ContributeTags.PILL), "line" to text("You make every Sunday better"), "submit" to tag(ContributeTags.SUBMIT),
        ),
    ) { ComposerStep(sampleInfo, ContributeState(photos = PhotosState.Loaded(samplePhotos), selected = "p1", line = "You make every Sunday better"), {}, {}, {}, {}) }

    @Test fun contributeMessage() = measure(
        "birthday.contribute-message",
        mapOf("title" to text("Add a Message"), "done" to tag(ContributeTags.DONE), "field" to tag(ContributeTags.FIELD), "counter" to text("28/110")),
    ) { MessageModal("You make every Sunday better", {}, {}) }

    @Test fun tribute() = measure(
        "birthday.tribute",
        mapOf(
            "title" to text("Your birthday video"), "group" to text("Sunday Lunch"), "close" to label("Close"), "player" to tag(PLAYER),
            "save" to tag(TributeTags.SAVE), "share" to text("Share"),
        ),
    ) {
        // The honoree's view: the only one with save and Share (owner decision 12).
        TributeScreen(
            TributeState(TributeContent.Ready("https://video.test/t.mp4", TestImages.url("poster", 16, 9)), groupName = "Sunday Lunch", forMe = true),
            autoplay = false,
            player = null,
            actions = TributeActions(),
        )
    }

    private val ana = TaggedPerson(FakeMemoryBackend.ANA, "Ana", null)
    private val me = TaggedPerson(FakeMemoryBackend.ME, "Jesus", null)

    @Composable
    private fun controller(people: List<TaggedPerson>): TagRunController {
        val scope = rememberCoroutineScope()
        return remember { TagRunController("p-other", Scenario.backend(), scope, people, me) }
    }

    @Test fun taggingRun() = measure("tagging-run", mapOf("run" to tag(TagRunTags.RUN))) {
        Box(Modifier.fillMaxSize().background(Color.Black)) { TagRun("p-other", controller = controller(listOf(ana, me))) }
    }

    @Test fun taggingSheet() = measure(
        "tagging-sheet",
        mapOf("sheet" to tag(TagRunTags.SHEET), "title" to text("In this photo"), "close" to label("Close"), "ana" to text("Ana"), "me" to text("Jesus"), "remove" to text("Remove tag")),
    ) { InThisPhotoContent(controller(listOf(ana, me))) {} }

    @Test fun taggingSheetUntagged() = measure(
        "tagging-sheet-untagged",
        mapOf("sheet" to tag(TagRunTags.SHEET), "toggle" to text("I'm in this"), "ana" to text("Ana")),
    ) { InThisPhotoContent(controller(listOf(ana))) {} }

    private companion object {
        const val PLAYER = "measure.player"

        /** 82.5 % of a 393-dp frame (`layout.year.story.recapCard.widthRatio`). */
        const val RECAP_CARD_WIDTH = 324
    }
}
