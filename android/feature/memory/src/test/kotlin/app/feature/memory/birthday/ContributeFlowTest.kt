package app.feature.memory.birthday

import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.assertIsSelected
import androidx.compose.ui.test.hasClickAction
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTextInput
import app.feature.memory.FakeMemoryBackend
import app.feature.memory.MemoryTestContent
import app.feature.memory.Scenario
import app.feature.memory.SnapshotTest
import app.feature.memory.common.MemoryCache
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.robolectric.shadows.ShadowToast

/** Robolectric flow: request → choose an eligible photo → composer → "Add a Message" → Add to video → own block. */
class ContributeFlowTest : SnapshotTest() {
    private fun open(backend: FakeMemoryBackend, requestId: String = "r-1", onOpenGroup: (String) -> Unit = {}) {
        MemoryCache.shared.remove(MemoryCache.key(backend, "birthday.request", requestId))
        MemoryCache.shared.remove(MemoryCache.key(backend, "birthday.eligible", FakeMemoryBackend.GROUP))
        compose.setContent {
            MemoryTestContent(backend) {
                BirthdayRequestDestination(FakeMemoryBackend.GROUP, requestId, onClose = {}, onOpenGroup = onOpenGroup, backend = backend, clock = Scenario.clock)
            }
        }
    }

    @Test fun contributeAPhotoAndALine() {
        val backend = Scenario.backend()
        open(backend)
        compose.onNodeWithText("Ana's birthday video").assertExists()
        compose.onNodeWithText("What do you appreciate most about Ana?").assertExists()
        compose.onNodeWithText("Add your photo").performScrollTo().performClick()
        compose.waitForIdle()
        compose.onNodeWithText("Choose a Photo").assertExists()
        // Only photos I posted or I'm tagged in.
        compose.onNodeWithTag(ContributeTags.cell("p-tagged")).assertExists()
        compose.onNodeWithTag(ContributeTags.cell("p-mine1")).assertExists()
        compose.onNodeWithTag(ContributeTags.cell("p-other")).assertDoesNotExist()
        compose.onNode(hasText("Next") and hasClickAction()).assertIsNotEnabled()
        compose.onNodeWithTag(ContributeTags.cell("p-tagged")).performClick().assertIsSelected()
        compose.onNodeWithText("Next").performClick()
        compose.waitForIdle()
        compose.onNodeWithText("Birthday Video").assertExists()
        compose.onNodeWithTag(ContributeTags.SUBMIT).assertIsNotEnabled()
        compose.onNodeWithText("Add a message").performClick()
        compose.waitForIdle()
        compose.onNodeWithText("Add a Message").assertExists()
        compose.onNodeWithTag(ContributeTags.FIELD).performTextInput("  You make every Sunday better  ")
        compose.onNodeWithText("Done").performClick()
        compose.waitForIdle()
        compose.onNodeWithText("Edit message").assertExists()
        compose.onNodeWithTag(ContributeTags.SUBMIT).performClick()
        compose.waitForIdle()
        assertEquals("You make every Sunday better", backend.lastContributedLine)
        assertEquals("p-tagged", backend.contributions.values.single().postId)
        compose.onNodeWithText("You added a photo").assertExists()
        compose.onNodeWithText("You make every Sunday better").assertExists()
        compose.onNodeWithText("Add your photo").assertDoesNotExist()
        assertEquals("Added to video!", ShadowToast.getTextOfLatestToast())
    }

    @Test fun removeTheContributionAfterConfirming() {
        val backend = Scenario.backend()
        backend.contributions["c-1"] = app.data.model.TributeContribution("c-1", "r-1", FakeMemoryBackend.ME, "p-mine1", "Hi Ana", FakeMemoryBackend.NOW, FakeMemoryBackend.NOW)
        open(backend)
        compose.onNodeWithText("Hi Ana").assertExists()
        compose.onNodeWithTag(BirthdayRequestTags.REMOVE).performScrollTo().performClick()
        compose.onNodeWithText("Remove your photo?").assertExists()
        compose.onNodeWithText("Yes, remove").performClick()
        compose.waitForIdle()
        compose.onNodeWithText("Add your photo").assertExists()
        assertTrue(backend.contributions.isEmpty())
        assertEquals("Removed", ShadowToast.getTextOfLatestToast())
    }

    @Test fun noEligiblePhotosOffersTheGroup() {
        val backend = Scenario.backend().apply {
            posts.values.removeAll { it.authorId == FakeMemoryBackend.ME }
            tags.clear()
        }
        var opened: String? = null
        open(backend, onOpenGroup = { opened = it })
        compose.onNodeWithText("Add your photo").performScrollTo().performClick()
        compose.waitForIdle()
        compose.onNodeWithText("Nothing to see here yet").assertExists()
        compose.onNodeWithText("View Sunday Lunch").performClick()
        assertEquals(FakeMemoryBackend.GROUP, opened)
    }

    @Test fun theHonoreeNeverSeesTheirRequest() {
        open(Scenario.backend(), requestId = "r-mine")
        compose.onNodeWithText("Couldn't find request").assertExists()
        compose.onNodeWithText("Add your photo").assertDoesNotExist()
    }
}
