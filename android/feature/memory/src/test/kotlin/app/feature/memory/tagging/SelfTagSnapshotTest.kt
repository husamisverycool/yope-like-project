package app.feature.memory.tagging

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.test.assertIsOff
import androidx.compose.ui.test.assertIsOn
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import app.designsystem.generated.Tokens
import app.feature.memory.FakeMemoryBackend
import app.feature.memory.MemoryTestContent
import app.feature.memory.Scenario
import app.feature.memory.SnapshotTest
import app.feature.memory.TestCoachStore
import app.feature.memory.TestImages
import app.feature.memory.common.MemoryImage
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** The toggle over a photo, in the viewer's top-right slot (`photo.viewer.dimension.actionTrailing` / `.actionCenterTop`). */
@Composable
private fun OnPhoto(content: @Composable (Modifier) -> Unit) {
    Box(Modifier.fillMaxSize().background(Tokens.Colors.globalBackgroundDeep)) {
        MemoryImage(TestImages.url("viewer-photo", 3, 4), null, Modifier.fillMaxSize())
        content(Modifier.align(Alignment.TopEnd).padding(top = Tokens.Sizes.photoViewerDimensionActionCenterTop, end = Tokens.Sizes.photoViewerDimensionActionTrailing))
    }
}

class SelfTagSnapshotTest : SnapshotTest() {
    private val backend = Scenario.backend()
    private val seenCoach = TestCoachStore(mutableSetOf(FakeMemoryBackend.ME))

    @Test fun off() = snap("tagging", "off", backend, coach = seenCoach) {
        OnPhoto { SelfTagToggle("p-other", FakeMemoryBackend.BEN, it, initiallyTagged = false) }
    }

    @Test fun on() = snap("tagging", "on", backend, coach = seenCoach) {
        OnPhoto { SelfTagToggle("p-tagged", FakeMemoryBackend.BEN, it, initiallyTagged = true) }
    }

    @Test fun coach() = snap("tagging", "coach", backend, screen = true) {
        OnPhoto { SelfTagToggle("p-other", FakeMemoryBackend.BEN, it.padding(top = Tokens.Sizes.globalButtonHeight * 2), initiallyTagged = false) }
    }

    /** A failed tag: the toggle reverts and the failure toast shows (no glyph). */
    @Test fun errorToast() {
        val failing = Scenario.backend().apply { failNext["tagSelf"] = app.data.error.DataError.Unexpected("x") }
        snap("tagging", "toast-error", failing, screen = true, coach = seenCoach, settle = toastSettle) {
            OnPhoto { m ->
                val controller = rememberSelfTagController("p-other", initiallyTagged = false)
                androidx.compose.runtime.LaunchedEffect(Unit) { controller.toggle() }
                SelfTagToggle("p-other", FakeMemoryBackend.BEN, m, controller = controller)
            }
        }
    }
}

/** Robolectric flow: tag yourself, untag, coach dismissed for good by the first tap. */
class SelfTagFlowTest : SnapshotTest() {
    @Test fun tagAndUntagYourself() {
        val backend = Scenario.backend()
        val store = TestCoachStore()
        compose.setContent {
            MemoryTestContent(backend, coach = store) { SelfTagToggle("p-other", FakeMemoryBackend.BEN, initiallyTagged = false) }
        }
        compose.onNodeWithTag(SelfTagTags.COACH, useUnmergedTree = true).assertExists()
        val toggle = compose.onNodeWithTag(SelfTagTags.TOGGLE)
        toggle.assertIsOff().performClick()
        toggle.assertIsOn()
        assertTrue(("p-other" to FakeMemoryBackend.ME) in backend.tags)
        assertTrue("coach dismissed for good", store.dismissed(FakeMemoryBackend.ME))
        compose.onNodeWithTag(SelfTagTags.COACH, useUnmergedTree = true).assertDoesNotExist()
        toggle.performClick()
        toggle.assertIsOff()
        assertFalse(("p-other" to FakeMemoryBackend.ME) in backend.tags)
    }

    @Test fun noCoachOnYourOwnPhoto() {
        compose.setContent {
            MemoryTestContent(Scenario.backend()) { SelfTagToggle("p-mine1", FakeMemoryBackend.ME, initiallyTagged = false) }
        }
        compose.onNodeWithTag(SelfTagTags.COACH, useUnmergedTree = true).assertDoesNotExist()
        compose.onNodeWithTag(SelfTagTags.TOGGLE).assertExists()
    }
}
