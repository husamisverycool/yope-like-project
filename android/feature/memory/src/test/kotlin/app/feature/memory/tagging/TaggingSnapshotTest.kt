package app.feature.memory.tagging

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.click
import app.designsystem.generated.Tokens
import app.feature.memory.FakeMemoryBackend
import app.feature.memory.FakeMemoryBackend.Companion.ANA
import app.feature.memory.FakeMemoryBackend.Companion.BEN
import app.feature.memory.FakeMemoryBackend.Companion.ME
import app.feature.memory.MemoryTestContent
import app.feature.memory.Scenario
import app.feature.memory.SnapshotTest
import app.feature.memory.TestImages
import app.feature.memory.common.MediaAppearance
import app.feature.memory.common.MemoryImage
import app.ui.text.TextRoles
import org.junit.Assert.assertTrue
import org.junit.Test

private val ana = TaggedPerson(ANA, "Ana", TestImages.url("ana-avatar", 1, 1))
private val ben = TaggedPerson(BEN, "Ben", TestImages.url("ben-avatar", 1, 1))
private val me = TaggedPerson(ME, "Jesus", TestImages.url("sam-avatar", 1, 1))

/**
 * The viewer's footer as `photo.viewer` lays it out (C-22, test host only): the photo on black, the caption line and
 * the date line with Retro's " · " separator, then the tag run.
 */
@Composable
private fun ViewerFooterHost(controller: TagRunController) {
    MediaAppearance {
        Column(Modifier.fillMaxSize().background(Tokens.Colors.globalBackgroundDeep), verticalArrangement = androidx.compose.foundation.layout.Arrangement.Center) {
            MemoryImage(TestImages.url("viewer-photo", 3, 4), null, Modifier.fillMaxWidth().weight(1f, fill = false), contentScale = ContentScale.FillWidth)
            Column(Modifier.padding(Tokens.Sizes.globalScreenMargin)) {
                Text("Sunday at the lake", style = TextRoles.listTitle, color = Tokens.Colors.globalTextOnMedia)
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("Wednesday, July 5 · ", style = TextRoles.listSubtitle, color = Tokens.Colors.globalTextSecondary, maxLines = 1)
                    TagRun("p-other", controller = controller)
                }
            }
        }
    }
}

class TaggingSnapshotTest : SnapshotTest() {
    @Composable
    private fun controller(people: List<TaggedPerson>, backend: FakeMemoryBackend = Scenario.backend()): TagRunController {
        val scope = rememberCoroutineScope()
        return remember { TagRunController("p-other", backend, scope, people, me) }
    }

    private fun footer(state: String, people: List<TaggedPerson>, dark: Boolean = false) =
        snap("tagging", state, dark = dark) { ViewerFooterHost(controller(people)) }

    @Test fun untagged() = footer("footer-untagged", emptyList())
    @Test fun untaggedDark() = footer("footer-untagged", emptyList(), dark = true)
    @Test fun taggedOthers() = footer("footer-with", listOf(ana, ben))
    @Test fun taggedYou() = footer("footer-with-you", listOf(ana, me))
    @Test fun taggedMany() = footer("footer-with-truncated", listOf(ana, ben, me, TaggedPerson("u-cleo", "Cleo", null), TaggedPerson("u-dan", "Daniela", null)))

    /** The sheet as the run opens it (from inside the viewer's dark subtree; the sheet follows the appearance). */
    private fun sheet(state: String, people: List<TaggedPerson>, dark: Boolean = false) = snap("tagging", state, dark = dark, screen = true) {
        val c = controller(people)
        androidx.compose.runtime.LaunchedEffect(Unit) { c.sheetOpen = true }
        ViewerFooterHost(c)
    }

    @Test fun sheetTagged() = sheet("sheet-tagged", listOf(ana, me))
    @Test fun sheetTaggedDark() = sheet("sheet-tagged", listOf(ana, me), dark = true)
    @Test fun sheetNotTagged() = sheet("sheet-not-tagged", listOf(ana, ben))
    @Test fun sheetEmpty() = sheet("sheet-empty", emptyList())

    /** The run stays one line high but takes taps across `size.global.minTouchTarget.android` (48 dp). */
    @Test fun theRunTakesTapsAboveAndBelowItsLine() {
        val backend = Scenario.backend().apply { tags.clear() }
        compose.setContent {
            MemoryTestContent(backend) {
                val scope = rememberCoroutineScope()
                val c = remember { TagRunController("p-other", backend, scope, emptyList(), me) }
                ViewerFooterHost(c)
            }
        }
        val run = compose.onNodeWithTag(TagRunTags.RUN)
        val bounds = run.fetchSemanticsNode().boundsInRoot
        val slack = (with(compose.density) { Tokens.Sizes.globalMinTouchTargetAndroid.toPx() } - bounds.height) / 2
        assertTrue("a one-line run", slack > 0f)
        // Outside the 48-dp band: nothing.
        run.performTouchInput { click(androidx.compose.ui.geometry.Offset(centerX, -slack - 6f)) }
        compose.waitForIdle()
        assertTrue(("p-other" to ME) !in backend.tags)
        // Just inside the expanded area above the line: tags you.
        run.performTouchInput { click(androidx.compose.ui.geometry.Offset(centerX, -slack + 2f)) }
        compose.waitForIdle()
        assertTrue(("p-other" to ME) in backend.tags)
        // Below the line (inside the expansion) opens the sheet now that you are tagged.
        run.performTouchInput { click(androidx.compose.ui.geometry.Offset(centerX, height + slack - 2f)) }
        compose.waitForIdle()
        compose.onNodeWithText("In this photo").assertExists()
    }

    /** Flow: "I'm in this" tags you at once; the run opens the sheet; "Remove tag" takes you out. */
    @Test fun tagOpenTheSheetAndRemove() {
        val backend = Scenario.backend().apply { tags.clear() }
        compose.setContent {
            MemoryTestContent(backend) {
                val scope = rememberCoroutineScope()
                val c = remember { TagRunController("p-other", backend, scope, emptyList(), me) }
                ViewerFooterHost(c)
            }
        }
        compose.onNodeWithContentDescription("I'm in this").performClick()
        compose.waitForIdle()
        assertTrue(("p-other" to ME) in backend.tags)
        compose.onNodeWithTag(TagRunTags.RUN).assert(SemanticsMatcher.expectValue(SemanticsProperties.StateDescription, "with Jesus"))
        compose.onNodeWithTag(TagRunTags.RUN).performClick()
        compose.waitForIdle()
        compose.onNodeWithText("In this photo").assertExists()
        compose.onNodeWithText("Remove tag").performClick()
        compose.waitForIdle()
        assertTrue(("p-other" to ME) !in backend.tags)
        compose.onNodeWithText("No one is tagged").assertExists()
    }
}
