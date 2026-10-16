package app.feature.memory.onthisday

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.test.assertTextEquals
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTouchInput
import app.designsystem.generated.Tokens
import app.feature.memory.FakeMemoryBackend
import app.feature.memory.MemoryTestContent
import app.feature.memory.OnThisDayDestination
import app.feature.memory.Scenario
import app.feature.memory.SnapshotTest
import app.feature.memory.TestImages
import app.feature.memory.TestSeenStore
import app.ui.haptics.LocalHapticsOverride
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import kotlin.math.cos
import kotlin.math.sin

private fun memory(id: String, name: String, date: LocalDate, author: String = "u-$name", w: Int = 3, h: Int = 4) =
    Memory(id, author, name, TestImages.url("$id-display", w, h), "u/$author/$id/original.jpg", date)

/** Four memories of Dec 5 (sample photos, fixtures/photos/), newest first. */
internal val sampleMemories = listOf(
    memory("d", "Maya", LocalDate.of(2022, 7, 22), w = 9, h = 16),
    memory("a", "Ana", LocalDate.of(2021, 12, 5)),
    memory("b", "Ben", LocalDate.of(2019, 12, 5), w = 3, h = 2),
    memory("c", "Jesus", LocalDate.of(2018, 12, 5), author = FakeMemoryBackend.ME),
)

internal val samplePage = OnThisDayState.Page(sampleMemories, index = 0, groupName = "Sunday Lunch")

class OnThisDaySnapshotTest : SnapshotTest() {
    private fun page(state: String, s: OnThisDayState, dark: Boolean = false, intro: Boolean = false, saveDenied: Boolean = false) =
        snap("onthisday", state, dark = dark, screen = intro || saveDenied) {
            OnThisDayScreen(s, OnThisDayActions(), isMine = { it.authorId == FakeMemoryBackend.ME }, showIntro = intro, saveDenied = saveDenied)
        }

    @Test fun paused() = page("paused", samplePage)
    @Test fun pausedDark() = page("paused", samplePage, dark = true)
    @Test fun secondMemory() = page("dial-step-2", samplePage.copy(index = 1))
    @Test fun playing() = page("playing", samplePage.copy(index = 2, playing = true))
    @Test fun shuffle() = page("shuffle", samplePage.copy(memories = listOf(sampleMemories[2]), index = 0, mode = MemoryMode.Shuffle))
    @Test fun loading() = page("loading", OnThisDayState.Loading)
    @Test fun error() = page("error", OnThisDayState.Failed(offline = false))
    @Test fun offline() = page("offline", OnThisDayState.Failed(offline = true))
    @Test fun empty() = page("empty", OnThisDayState.Empty)
    @Test fun intro() = page("intro", samplePage, intro = true)
    @Test fun saveDenied() = page("save-denied", samplePage, saveDenied = true)

    @Test fun menuOnSomeoneElsesMemory() {
        compose.mainClock.autoAdvance = false
        compose.setContent { MemoryTestContent { OnThisDayScreen(samplePage, OnThisDayActions(), isMine = { false }) } }
        compose.mainClock.advanceTimeBy(settleMillis)
        compose.onNodeWithTag(OnThisDayTags.MORE).performClick()
        compose.mainClock.advanceTimeBy(settleMillis)
        compose.onNodeWithText("Save to Camera Roll").assertExists()
        compose.onNodeWithText("Report Post").assertExists()
        compose.onNodeWithText("Delete Post").assertDoesNotExist()
        com.github.takahirom.roborazzi.captureScreenRoboImage("src/test/snapshots/onthisday/menu-light.png")
    }

    @Test fun deleteYourOwnMemoryAsksFirst() {
        compose.mainClock.autoAdvance = false
        compose.setContent { MemoryTestContent { OnThisDayScreen(samplePage.copy(index = 3), OnThisDayActions(), isMine = { it.authorId == FakeMemoryBackend.ME }) } }
        compose.mainClock.advanceTimeBy(settleMillis)
        compose.onNodeWithTag(OnThisDayTags.MORE).performClick()
        compose.mainClock.advanceTimeBy(settleMillis)
        compose.onNodeWithText("Delete Post").performClick()
        compose.mainClock.advanceTimeBy(settleMillis)
        compose.onNodeWithText("Delete this post?").assertExists()
        compose.onNodeWithText("This will permanently delete this photo from Sunday Lunch").assertExists()
        com.github.takahirom.roborazzi.captureScreenRoboImage("src/test/snapshots/onthisday/delete-confirm-light.png")
    }
}

/** Robolectric flow: drag the dial (one tick per memory), play, shuffle, intro once, back. */
class OnThisDayFlowTest : SnapshotTest() {
    /** A drag around the dial's centre from [fromDeg] to [toDeg] (clockwise positive), in small moves. */
    private fun spin(fromDeg: Float, toDeg: Float) {
        compose.mainClock.autoAdvance = true
        compose.onNodeWithTag(DialTags.DIAL).performTouchInput {
            val c = center
            val r = width * RADIUS_FRACTION
            fun at(deg: Float) = Offset(c.x + r * cos(Math.toRadians(deg.toDouble())).toFloat(), c.y + r * sin(Math.toRadians(deg.toDouble())).toFloat())
            down(at(fromDeg))
            val steps = 40
            for (i in 1..steps) moveTo(at(fromDeg + (toDeg - fromDeg) * i / steps))
            up()
        }
        compose.waitForIdle()
        compose.mainClock.autoAdvance = false
        compose.mainClock.advanceTimeBy(STEP_SETTLE)
    }

    @Test fun dragPlayShuffleAndBack() {
        val backend = Scenario.backend()
        var closed = 0
        val haptics = mutableListOf<Int>()
        val seen = TestSeenStore(everything = false)
        compose.mainClock.autoAdvance = false
        compose.setContent {
            MemoryTestContent(backend, seen = seen) {
                androidx.compose.runtime.CompositionLocalProvider(LocalHapticsOverride provides { haptics += it }) {
                    OnThisDayDestination(FakeMemoryBackend.GROUP, onClose = { closed++ }, onReport = {}, backend = backend, files = FakePhotoFiles(), clock = Scenario.clock)
                }
            }
        }
        compose.mainClock.advanceTimeBy(STEP_SETTLE)
        // First open: the feature intro, once per account.
        compose.onNodeWithText("Introducing On This Day").assertExists()
        compose.onNodeWithText("Try it out").performClick()
        compose.mainClock.advanceTimeBy(STEP_SETTLE)
        assertTrue(seen.seen(FakeMemoryBackend.ME, "onthisday.nux"))
        val title = compose.onNodeWithTag(OnThisDayTags.TITLE, useUnmergedTree = true)
        title.assertTextEquals("Dec 5, 2025")
        compose.onNodeWithText("On this day · Ana").assertExists()
        // Clockwise: two slots (8.18° each) → two memories, one tick each.
        val ticksBefore = haptics.count { it == Tokens.Haptics.globalSelect }
        spin(-60f, -60f + 8.18f * 2 + 1f)
        title.assertTextEquals("Dec 5, 2023")
        compose.onNodeWithText("On this day · Ana").assertExists()
        assertEquals(2, haptics.count { it == Tokens.Haptics.globalSelect } - ticksBefore)
        // Counter-clockwise past the first memory stops there.
        spin(-60f, -60f - 8.18f * 5 - 1f)
        title.assertTextEquals("Dec 5, 2025")
        // Play: the next memory after `duration.onthisday.playHold`; the side circles hide.
        compose.onNodeWithContentDescription("Play").performClick()
        compose.mainClock.advanceTimeBy(Tokens.Durations.onthisdayPlayHold.toLong() + STEP_SETTLE)
        title.assertTextEquals("Dec 5, 2023")
        compose.onNodeWithContentDescription("Pause").performClick()
        compose.mainClock.advanceTimeBy(STEP_SETTLE)
        // The dice: a random memory of the group's history; the subtitle says "Memories".
        compose.onNodeWithTag(OnThisDayTags.SHUFFLE).performClick()
        compose.mainClock.advanceTimeBy(STEP_SETTLE)
        compose.onNodeWithText("Memories · ", substring = true).assertExists()
        compose.onNodeWithContentDescription("Back").performClick()
        assertEquals(1, closed)
    }

    private companion object {
        /** Drag on the ring (the ticks' radius, inside the dial's box). */
        const val RADIUS_FRACTION = 0.42f
        const val STEP_SETTLE = 500L
    }
}
