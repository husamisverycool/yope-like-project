package app.feature.memory.onthisday

import androidx.compose.ui.test.assertTextEquals
import androidx.compose.ui.test.click
import androidx.compose.ui.test.centerLeft
import androidx.compose.ui.test.centerRight
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performTouchInput
import app.feature.memory.FakeMemoryBackend
import app.feature.memory.MemoryTestContent
import app.feature.memory.OnThisDayDestination
import app.feature.memory.Scenario
import app.feature.memory.SnapshotTest
import app.feature.memory.TestImages
import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.Instant
import java.time.ZoneId

private val paris = ZoneId.of("Europe/Paris")

private fun photo(id: String, name: String, at: String, w: Int = 3, h: Int = 4, avatar: Boolean = true) = MemoryPhoto(
    postId = id,
    displayUrl = TestImages.url("$id-display", w, h),
    thumbUrl = TestImages.url("$id-thumb", w, h),
    aspectRatio = w.toFloat() / h,
    authorName = name,
    avatarUrl = if (avatar) TestImages.url("$name-avatar", 1, 1) else null,
    createdAt = Instant.parse(at),
)

/** One photo 1 year ago; five photos of mixed shapes 3 years ago. */
internal val sampleDay = OnThisDayState.Day(
    years = listOf(
        MemoryYear(1, listOf(photo("a", "Ana", "2025-12-05T21:34:00Z"))),
        MemoryYear(
            3,
            listOf(
                photo("b", "Ben", "2023-12-05T19:10:00Z", 4, 3, avatar = false),
                photo("c", "Ana", "2023-12-05T12:02:00Z", 3, 4),
                photo("d", "Cleo", "2023-12-05T11:00:00Z", 9, 16),
                photo("e", "Ben", "2023-12-05T10:00:00Z", 1, 1),
                photo("f", "Ana", "2023-12-05T09:45:00Z", 4, 3),
            ),
        ),
    ),
    index = 0,
    zone = paris,
)

class OnThisDaySnapshotTest : SnapshotTest() {
    private fun screen(state: OnThisDayState) = snap("onthisday", name(state)) { OnThisDayScreen(state, {}, {}, {}, {}) }

    private fun name(state: OnThisDayState) = when (state) {
        OnThisDayState.Loading -> "loading"
        is OnThisDayState.Failed -> if (state.offline) "offline" else "error"
        is OnThisDayState.Day -> if (state.year.photos.size == 1) "single-photo" else "grid"
        OnThisDayState.Finished -> "finished"
    }

    @Test fun loading() = screen(OnThisDayState.Loading)
    @Test fun error() = screen(OnThisDayState.Failed(offline = false))
    @Test fun offline() = screen(OnThisDayState.Failed(offline = true))
    @Test fun singlePhoto() = screen(sampleDay)
    @Test fun grid() = screen(sampleDay.copy(index = 1))
    @Test fun singlePhotoNoAvatar() = snap("onthisday", "single-photo-no-avatar") {
        OnThisDayScreen(sampleDay.copy(years = listOf(MemoryYear(2, listOf(photo("z", "Ben", "2024-12-05T08:00:00Z", avatar = false))))), {}, {}, {}, {})
    }
}

/** Robolectric flow: the day taps through its years and closes after the oldest. */
class OnThisDayFlowTest : SnapshotTest() {
    @Test fun tapThroughYearsThenClose() {
        val backend = Scenario.backend()
        var closed = 0
        compose.setContent {
            MemoryTestContent(backend) {
                OnThisDayDestination(FakeMemoryBackend.GROUP, onClose = { closed++ }, backend = backend, clock = Scenario.clock)
            }
        }
        val label = compose.onNodeWithTag(OnThisDayTags.LABEL, useUnmergedTree = true)
        label.assertTextEquals("1 YEAR AGO")
        compose.onNodeWithTag(OnThisDayTags.CONTENT).performTouchInput { click(centerLeft) }
        label.assertTextEquals("1 YEAR AGO")
        compose.onNodeWithTag(OnThisDayTags.CONTENT).performTouchInput { click(centerRight) }
        label.assertTextEquals("3 YEARS AGO")
        compose.onNodeWithTag(OnThisDayTags.CONTENT).performTouchInput { click(centerLeft) }
        label.assertTextEquals("1 YEAR AGO")
        compose.onNodeWithTag(OnThisDayTags.CONTENT).performTouchInput { click(centerRight) }
        compose.onNodeWithTag(OnThisDayTags.CONTENT).performTouchInput { click(centerRight) }
        compose.waitForIdle()
        assertEquals(1, closed)
        assertEquals(listOf("group", "onThisDay"), backend.calls.take(2))
    }
}
