package app.feature.memory.yearstory

import android.content.Intent
import android.graphics.BitmapFactory
import android.net.Uri
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.test.click
import androidx.compose.ui.test.centerLeft
import androidx.compose.ui.test.centerRight
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.ui.Modifier
import androidx.test.core.app.ApplicationProvider
import app.designsystem.generated.Tokens
import app.feature.memory.FakeMemoryBackend
import app.feature.memory.MemoryTestContent
import app.feature.memory.Scenario
import app.feature.memory.SnapshotTest
import app.feature.memory.TestImages
import app.feature.memory.common.MemoryCache
import app.feature.memory.resetFileProviderCache
import app.feature.memory.share.MemoryFiles
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Test
import org.robolectric.Shadows.shadowOf
import java.io.File
import java.time.LocalDate

/** Every kind of card of a story (sample photos and a collage of them, fixtures/photos/). */
internal val sampleCards: List<StoryCard> = listOf(
    StoryCard.Intro("Sunday Lunch", 2026),
    StoryCard.LookBack,
    StoryCard.Moments("Sunday Lunch", 1284),
    StoryCard.BusiestMonth(7),
    StoryCard.MostReactedSetup,
    StoryCard.MostReactedPhoto("p1", TestImages.url("r1", 3, 4), "Ana", LocalDate.of(2026, 2, 25)),
    StoryCard.MostReactedPhoto("p2", TestImages.url("r2", 4, 3), "Ben", LocalDate.of(2026, 3, 14)),
    StoryCard.TogetherSetup,
    StoryCard.TogetherDay("c1", TestImages.url("collage1", 9, 16), LocalDate.of(2026, 4, 2), listOf("p1")),
    StoryCard.Outro,
    StoryCard.Summary,
)

/** The recap of the sample story: the cover and four rows of photos. */
internal val sampleRecap = StoryRecap(
    groupName = "Sunday Lunch",
    year = 2026,
    coverUrl = TestImages.url("r1", 3, 4),
    photos = (1..16).map { n -> RecapPhoto("y$n", TestImages.url("y$n-thumb", 1, 1), "Ana", LocalDate.of(2026, 1 + n % 12, 1 + n)) },
)

private fun cardName(card: StoryCard): String = when (card) {
    is StoryCard.Intro -> "01-intro"
    StoryCard.LookBack -> "02-look-back"
    is StoryCard.Moments -> "03-moments"
    is StoryCard.BusiestMonth -> "04-busiest-month"
    StoryCard.MostReactedSetup -> "05-most-reacted-setup"
    is StoryCard.MostReactedPhoto -> "06-most-reacted-photo-${card.postId}"
    StoryCard.TogetherSetup -> "07-together-setup"
    is StoryCard.TogetherDay -> "08-together-day"
    StoryCard.Outro -> "09-outro"
    StoryCard.Summary -> "10-summary"
}

class YearStorySnapshotTest : SnapshotTest() {
    private fun story(state: String, s: YearStoryState, dark: Boolean = false) = snap("year.story", state, dark = dark) { YearStoryScreen(s, YearStoryActions()) }

    /** Cards are recorded paused (the frame and the play glyph); the reveal has settled. */
    private fun card(index: Int, dark: Boolean = false) =
        story("card-" + cardName(sampleCards[index]), YearStoryState.Story(sampleCards, index, sampleRecap, paused = index != 0), dark)

    @Test fun loading() = story("loading", YearStoryState.Loading)
    @Test fun error() = story("error", YearStoryState.Failed(offline = false))
    @Test fun offline() = story("offline", YearStoryState.Failed(offline = true))
    @Test fun intro() = card(0)
    @Test fun introDark() = card(0, dark = true)
    @Test fun lookBack() = card(1)
    @Test fun moments() = card(2)
    @Test fun busiestMonth() = card(3)
    @Test fun mostReactedSetup() = card(4)
    @Test fun mostReactedPhoto() = card(5)
    @Test fun mostReactedPhotoLandscape() = card(6)
    @Test fun togetherSetup() = card(7)
    @Test fun togetherDay() = card(8)
    @Test fun outro() = card(9)
    @Test fun summaryCard() = story("summary-card", YearStoryState.Story(sampleCards, 10, sampleRecap, style = 0))
    @Test fun summaryCardDark() = story("summary-card", YearStoryState.Story(sampleCards, 10, sampleRecap, style = 0), dark = true)
    @Test fun summaryCover() = story("summary-cover", YearStoryState.Story(sampleCards, 10, sampleRecap, style = 1))
    @Test fun summaryCoverOnly() = story("summary-cover-only", YearStoryState.Story(sampleCards, 10, sampleRecap.copy(photos = emptyList())))

    /** The public recap card (week.recap reuses it), white in both appearances (L-4). */
    @Test fun recapCardLight() = recapCard(dark = false)
    @Test fun recapCardDark() = recapCard(dark = true)

    private fun recapCard(dark: Boolean) = snap("year.story", "recap-card", dark = dark) {
        Box(Modifier.padding(Tokens.Sizes.globalScreenMargin)) {
            RecapCard(
                sampleRecap.photos.map { RecapCardPhoto(app.feature.memory.common.memoryModel(it.thumbUrl), "photo") },
                "Week 27",
                Modifier.width(RECAP_CARD_WIDTH.dp),
                name = "Sunday Lunch",
                detail = "Jul 3 – 9",
            )
        }
    }

    private companion object {
        /** 82.5 % of a 393-pt frame (`layout.year.story.recapCard.widthRatio`). */
        const val RECAP_CARD_WIDTH = 324
    }
}

/** Share images: shareable cards rendered off screen at 1080 × 1920 (`layout.year.story.shareCard`). */
class YearStoryShareImageTest : SnapshotTest() {
    @Test fun shareableCardsRenderToShareImages() {
        resetFileProviderCache()
        val exporter = ShareCardExporter()
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val jobs = sampleCards.filter { it.shareable && it != StoryCard.Summary }.map { it to SummaryStyle.Card } +
            listOf(StoryCard.Summary to SummaryStyle.Card, StoryCard.Summary to SummaryStyle.Cover)
        val uris = mutableListOf<Uri?>()
        fun name(job: Pair<StoryCard, SummaryStyle>) = "share-" + cardName(job.first) + if (job.first == StoryCard.Summary) "-${job.second.name.lowercase()}" else ""
        compose.setContent {
            MemoryTestContent {
                YearStoryScreen(YearStoryState.Story(sampleCards, 0, sampleRecap, paused = true), YearStoryActions(), shareHost = { width -> ShareCardHost(exporter, width) })
                LaunchedEffect(Unit) { for (job in jobs) uris += exporter.export(context, job.first, job.second, sampleRecap, name(job)) }
            }
        }
        compose.waitUntil(60_000) { uris.size == jobs.size }
        val out = File("src/test/snapshots/year.story/share").apply { mkdirs() }
        jobs.forEachIndexed { i, job ->
            assertNotNull("rendered ${name(job)}", uris[i])
            val file = File(MemoryFiles.dir(context), "${name(job)}.png")
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(file.path, bounds)
            assertEquals(1080, bounds.outWidth)
            assertEquals(1920, bounds.outHeight)
            file.copyTo(File(out, "${name(job)}.png"), overwrite = true)
        }
    }
}

/**
 * Robolectric flow: tap through the story (both directions), auto-advance and pause, share a card, the summary
 * pager, replay. The clock is driven by hand: the story advances on its own every `duration.year.story.card`.
 */
class YearStoryFlowTest : SnapshotTest() {
    private fun step(ms: Long = 100) = compose.mainClock.advanceTimeBy(ms)

    private fun open(backend: FakeMemoryBackend) {
        compose.mainClock.autoAdvance = false
        compose.setContent {
            MemoryTestContent(backend) { YearStoryDestination(FakeMemoryBackend.GROUP, 2026, onClose = {}, backend = backend) }
        }
        step()
    }

    private fun tap(right: Boolean) {
        compose.onNodeWithTag(YearStoryTags.CARD).performTouchInput { click(if (right) centerRight else centerLeft) }
        step()
    }

    @Test fun tapThroughShareAndReplay() {
        resetFileProviderCache()
        MemoryCache.shared.remove(MemoryCache.key(Scenario.backend(), "yearstory", FakeMemoryBackend.GROUP, "2026"))
        open(Scenario.backend())
        compose.onNodeWithText("Year in Photos").assertExists()
        compose.onNodeWithText("Sunday Lunch · 2026").assertExists()
        compose.onNodeWithContentDescription("1 of 14").assertExists()
        // Paused, so the cards stay while the share image renders.
        compose.onNodeWithContentDescription("Pause").performClick()
        step()
        compose.onNodeWithText("Share").assertDoesNotExist()
        tap(right = false)
        compose.onNodeWithText("Year in Photos").assertExists()
        tap(right = true)
        compose.onNodeWithText("Let’s look back at your 52 weeks").assertExists()
        tap(right = true)
        compose.onNodeWithText("Sunday Lunch shared 1,284 photos this year").assertExists()

        // Share → a 9:16 PNG to the system share sheet (rendered off screen, encoded off the main thread).
        compose.onNodeWithText("Share").performClick()
        val app = ApplicationProvider.getApplicationContext<android.app.Application>()
        repeat(300) {
            if (shadowOf(app).peekNextStartedActivity() == null) {
                step(16)
                Thread.sleep(5)
            }
        }
        val chooser = shadowOf(app).nextStartedActivity
        assertNotNull("share sheet opened", chooser)
        assertEquals(Intent.ACTION_CHOOSER, chooser.action)
        @Suppress("DEPRECATION")
        val send = chooser.getParcelableExtra<Intent>(Intent.EXTRA_INTENT)!!
        assertEquals(Intent.ACTION_SEND, send.action)
        assertEquals("image/png", send.type)
        assertEquals("2026 Recap", send.getStringExtra(Intent.EXTRA_TITLE))

        // Most-reacted photos: who and when, in order; on to the summary; replay.
        repeat(3) { tap(right = true) }
        compose.onNodeWithText("Post by Ana").assertExists()
        // Photo 1 of 5 → the summary (cards 6 … 14, then the summary takes no taps).
        repeat(9) { tap(right = true) }
        compose.onNodeWithText("2 of 2", substring = false).assertDoesNotExist()
        compose.onNodeWithContentDescription("Watch again").performClick()
        step()
        compose.onNodeWithText("Sunday Lunch · 2026").assertExists()
    }

    @Test fun advancesOnItsOwnAndPauses() {
        MemoryCache.shared.remove(MemoryCache.key(Scenario.backend(), "yearstory", FakeMemoryBackend.GROUP, "2026"))
        open(Scenario.backend())
        compose.onNodeWithText("Sunday Lunch · 2026").assertExists()
        step(Tokens.Durations.yearStoryCard.toLong())
        step()
        compose.onNodeWithText("Let’s look back at your 52 weeks").assertExists()
        compose.onNodeWithContentDescription("Pause").performClick()
        step(Tokens.Durations.yearStoryCard * 2L)
        compose.onNodeWithText("Let’s look back at your 52 weeks").assertExists()
        compose.onNodeWithContentDescription("Play").performClick()
        step(Tokens.Durations.yearStoryCard.toLong())
        step()
        compose.onNodeWithText("Sunday Lunch shared 1,284 photos this year").assertExists()
    }
}
