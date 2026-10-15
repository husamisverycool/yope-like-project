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
import androidx.test.core.app.ApplicationProvider
import app.feature.memory.FakeMemoryBackend
import app.feature.memory.MemoryTestContent
import app.feature.memory.Scenario
import app.feature.memory.SnapshotTest
import app.feature.memory.TestImages
import app.feature.memory.resetFileProviderCache
import app.feature.memory.share.MemoryFiles
import app.designsystem.generated.Tokens
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Test
import org.robolectric.Shadows.shadowOf
import java.io.File
import java.time.LocalDate

/** Every card of a full story, in order (synthetic photos and collages). */
internal val sampleCards: List<StoryCard> = listOf(
    StoryCard.Intro,
    StoryCard.MomentsSetup,
    StoryCard.Moments("Sunday Lunch", 1284),
    StoryCard.BusiestMonth(7),
    StoryCard.MostReactedSetup,
    StoryCard.MostReactedPhoto("p1", TestImages.url("r1", 3, 4), "Ana", LocalDate.of(2026, 2, 25)),
    StoryCard.MostReactedPhoto("p2", TestImages.url("r2", 4, 3), "Ben", LocalDate.of(2026, 3, 14)),
    StoryCard.TogetherSetup,
    StoryCard.TogetherDay("c1", TestImages.url("collage1", 4, 5), LocalDate.of(2026, 4, 2), listOf("p1")),
    StoryCard.Teaser,
    StoryCard.Outro,
    StoryCard.Summary,
)

private fun cardName(card: StoryCard): String = when (card) {
    StoryCard.Intro -> "01-intro"
    StoryCard.MomentsSetup -> "02-moments-setup"
    is StoryCard.Moments -> "03-moments"
    is StoryCard.BusiestMonth -> "04-busiest-month"
    StoryCard.MostReactedSetup -> "05-most-reacted-setup"
    is StoryCard.MostReactedPhoto -> "06-most-reacted-photo-${card.postId}"
    StoryCard.TogetherSetup -> "07-together-setup"
    is StoryCard.TogetherDay -> "08-together-day"
    StoryCard.Teaser -> "09-teaser"
    StoryCard.Outro -> "10-outro"
    StoryCard.Summary -> "11-summary"
}

class YearStorySnapshotTest : SnapshotTest() {
    private fun story(state: String, s: YearStoryState) = snap("year.story", state) { YearStoryScreen(s, {}, {}, {}, {}, {}, {}) }

    private fun card(index: Int) = story("card-" + cardName(sampleCards[index]), YearStoryState.Story(sampleCards, index))

    @Test fun loading() = story("loading", YearStoryState.Loading)
    @Test fun error() = story("error", YearStoryState.Failed(offline = false))
    @Test fun offline() = story("offline", YearStoryState.Failed(offline = true))
    @Test fun intro() = card(0)
    @Test fun momentsSetup() = card(1)
    @Test fun moments() = card(2)
    @Test fun busiestMonth() = card(3)
    @Test fun mostReactedSetup() = card(4)
    @Test fun mostReactedPhoto() = card(5)
    @Test fun mostReactedPhotoLandscape() = card(6)
    @Test fun togetherSetup() = card(7)
    @Test fun togetherDay() = card(8)
    @Test fun teaser() = card(9)
    @Test fun outro() = card(10)
    @Test fun summary() = card(11)
}

/** Share images: each fact card rendered off screen at 1080 × 1920 (`layout.year.story.shareCard`). */
class YearStoryShareImageTest : SnapshotTest() {
    @Test fun factCardsRenderToShareImages() {
        resetFileProviderCache()
        val exporter = ShareCardExporter()
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val facts = sampleCards.filter { it.shareable }
        val uris = mutableListOf<Uri?>()
        compose.setContent {
            MemoryTestContent {
                YearStoryScreen(YearStoryState.Story(sampleCards, 0), {}, {}, {}, {}, {}, {}, shareHost = { width -> ShareCardHost(exporter, width) })
                LaunchedEffect(Unit) { for (card in facts) uris += exporter.export(context, card, "share-" + cardName(card)) }
            }
        }
        compose.waitUntil(30_000) { uris.size == facts.size }
        val out = File("src/test/snapshots/year.story/share").apply { mkdirs() }
        facts.forEachIndexed { i, card ->
            assertNotNull("rendered ${cardName(card)}", uris[i])
            val file = File(MemoryFiles.dir(context), "share-${cardName(card)}.png")
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(file.path, bounds)
            assertEquals(1080, bounds.outWidth)
            assertEquals(1920, bounds.outHeight)
            file.copyTo(File(out, "share-${cardName(card)}.png"), overwrite = true)
        }
    }
}

/**
 * Robolectric flow: tap through the story (both directions), share a card, replay from the summary.
 * The clock is driven by hand: the story advances on its own every `duration.year.story.card`.
 */
class YearStoryFlowTest : SnapshotTest() {
    private fun step(ms: Long = 100) = compose.mainClock.advanceTimeBy(ms)

    private fun open(backend: FakeMemoryBackend) {
        compose.mainClock.autoAdvance = false
        compose.setContent {
            MemoryTestContent(backend) {
                YearStoryDestination(FakeMemoryBackend.GROUP, 2026, onClose = {}, backend = backend, clock = Scenario.clock)
            }
        }
        step()
    }

    private fun tap(right: Boolean) {
        compose.onNodeWithTag(YearStoryTags.CANVAS).performTouchInput { click(if (right) centerRight else centerLeft) }
        step()
    }

    @Test fun tapThroughShareAndReplay() {
        resetFileProviderCache()
        val backend = Scenario.backend()
        open(backend)
        compose.onNodeWithText("We're ready for you.").assertExists()
        tap(right = false)
        compose.onNodeWithText("We're ready for you.").assertExists()
        tap(right = true)
        compose.onNodeWithText("You shared. We saved.").assertExists()
        compose.onNodeWithTag(YearStoryTags.SHARE_ROW).assertDoesNotExist()
        tap(right = true)
        compose.onNodeWithText("Sunday Lunch shared 1,284 moments this year.").assertExists()
        tap(right = false)
        compose.onNodeWithText("You shared. We saved.").assertExists()
        tap(right = true)

        // Share this story → a 9:16 PNG to the system share sheet (rendered off screen, encoded off the main thread).
        compose.onNodeWithTag(YearStoryTags.SHARE_ROW).performClick()
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
        @Suppress("DEPRECATION")
        val stream = send.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)!!
        assertEquals("content", stream.scheme)

        // Most-reacted photos: names and dates only, in order; to the summary; replay.
        repeat(3) { tap(right = true) }
        compose.onNodeWithText("Ana shared this on February 25").assertExists()
        repeat(20) { tap(right = true) }
        compose.onNodeWithTag(YearStoryTags.REPLAY).performClick()
        step()
        compose.onNodeWithText("We're ready for you.").assertExists()
    }

    @Test fun advancesOnItsOwnAndPauses() {
        open(Scenario.backend())
        compose.onNodeWithText("We're ready for you.").assertExists()
        step(Tokens.Durations.yearStoryCard.toLong())
        step()
        compose.onNodeWithText("You shared. We saved.").assertExists()
        compose.onNodeWithContentDescription("Pause").performClick()
        step(Tokens.Durations.yearStoryCard * 2L)
        compose.onNodeWithText("You shared. We saved.").assertExists()
        compose.onNodeWithContentDescription("Play").performClick()
        step(Tokens.Durations.yearStoryCard.toLong())
        step()
        compose.onNodeWithText("Sunday Lunch shared 1,284 moments this year.").assertExists()
    }
}

/** Reopening shows the cached story at once: no loading state flashes before the refresh. */
class YearStoryNoFlashTest : SnapshotTest() {
    @Test fun reopenPaintsCachedCardsWithoutLoading() {
        val backend = Scenario.backend().apply { gates["yearStory"] = kotlinx.coroutines.CompletableDeferred() }
        app.feature.memory.common.MemoryCache.shared.put(app.feature.memory.common.MemoryCache.key(backend, "yearstory", FakeMemoryBackend.GROUP, "2026"), sampleCards)
        compose.mainClock.autoAdvance = false
        compose.setContent {
            MemoryTestContent(backend) { YearStoryDestination(FakeMemoryBackend.GROUP, 2026, onClose = {}, backend = backend, clock = Scenario.clock) }
        }
        compose.mainClock.advanceTimeByFrame()
        compose.onNodeWithText("Loading").assertDoesNotExist()
        compose.onNodeWithText("We're ready for you.").assertExists()
        backend.gates.getValue("yearStory").complete(Unit)
        compose.mainClock.advanceTimeBy(1_000)
        compose.onNodeWithText("Loading").assertDoesNotExist()
        compose.onNodeWithText("We're ready for you.").assertExists()
    }
}
