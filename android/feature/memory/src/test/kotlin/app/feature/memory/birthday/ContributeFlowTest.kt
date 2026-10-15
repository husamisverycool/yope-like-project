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

/** Robolectric flow: request → pick an eligible photo → write the line → submit → done → own block. */
class ContributeFlowTest : SnapshotTest() {
    private fun open(backend: FakeMemoryBackend, requestId: String = "r-1", onOpenGroup: (String) -> Unit = {}) {
        compose.setContent {
            MemoryTestContent(backend) {
                BirthdayRequestDestination(FakeMemoryBackend.GROUP, requestId, onClose = {}, onOpenGroup = onOpenGroup, backend = backend, clock = Scenario.clock)
            }
        }
    }

    @Test fun contributeAPhotoAndALine() {
        MemoryCache.shared.remove(MemoryCache.key(Scenario.backend(), "birthday.request", "r-1"))
        val backend = Scenario.backend()
        open(backend)
        compose.onNodeWithText("Birthday Video for Ana!").assertExists()
        compose.onNodeWithText("Add Your Photo").performClick()
        compose.onNodeWithText("Let's add a photo for Ana!").assertExists()
        // Only photos I posted or I'm tagged in.
        compose.onNodeWithTag(ContributeTags.cell("p-tagged")).assertExists()
        compose.onNodeWithTag(ContributeTags.cell("p-mine1")).assertExists()
        compose.onNodeWithTag(ContributeTags.cell("p-other")).assertDoesNotExist()
        compose.onNode(hasText("Use Photo") and hasClickAction()).assertIsNotEnabled()
        compose.onNodeWithTag(ContributeTags.cell("p-tagged")).performClick().assertIsSelected()
        compose.onNodeWithText("Use Photo").performClick()
        compose.onNodeWithText("Your Message").assertExists()
        compose.onNode(hasText("Submit") and hasClickAction()).assertIsNotEnabled()
        compose.onNodeWithTag(ContributeTags.FIELD).performTextInput("  you make every Sunday better  ")
        compose.onNodeWithText("Submit").performClick()
        compose.onNodeWithText("Photo Upload Complete!").assertExists()
        compose.onNode(hasText("Done") and hasClickAction()).performClick()
        compose.onNodeWithText("Your Photo").assertExists()
        compose.onNodeWithText("you make every Sunday better").assertExists()
        compose.onNodeWithText("Add Your Photo").assertDoesNotExist()
        assertEquals("you make every Sunday better", backend.lastContributedLine)
        assertEquals("p-tagged", backend.contributions.values.single().postId)
    }

    @Test fun removeTheContributionWithoutConfirmation() {
        val backend = Scenario.backend()
        backend.contributions["c-1"] = app.data.model.TributeContribution("c-1", "r-1", FakeMemoryBackend.ME, "p-mine1", "hi Ana", FakeMemoryBackend.NOW, FakeMemoryBackend.NOW)
        open(backend)
        compose.onNodeWithText("hi Ana").assertExists()
        compose.onNodeWithText("Remove").performScrollTo().performClick()
        compose.onNodeWithText("Add Your Photo").assertExists()
        assertTrue(backend.contributions.isEmpty())
    }

    @Test fun noEligiblePhotosOffersTheGroup() {
        val backend = Scenario.backend().apply {
            posts.values.removeAll { it.authorId == FakeMemoryBackend.ME }
            tags.clear()
        }
        var opened: String? = null
        open(backend, onOpenGroup = { opened = it })
        compose.onNodeWithText("Add Your Photo").performClick()
        compose.onNodeWithText("no pics with you in Sunday Lunch yet").assertExists()
        compose.onNodeWithText("open group").performClick()
        assertEquals(FakeMemoryBackend.GROUP, opened)
    }

    @Test fun theHonoreeNeverSeesTheirRequest() {
        open(Scenario.backend(), requestId = "r-mine")
        compose.onNodeWithText("this request isn't available anymore").assertExists()
        compose.onNodeWithText("Add Your Photo").assertDoesNotExist()
    }
}
