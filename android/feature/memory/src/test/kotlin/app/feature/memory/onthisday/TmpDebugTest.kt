package app.feature.memory.onthisday

import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.printToString
import app.feature.memory.MemoryTestContent
import app.feature.memory.SnapshotTest
import org.junit.Test

class TmpDebugTest : SnapshotTest() {
    @Test fun debug() {
        compose.mainClock.autoAdvance = false
        compose.setContent { MemoryTestContent { OnThisDayScreen(samplePage, OnThisDayActions(), isMine = { false }) } }
        compose.mainClock.advanceTimeBy(settleMillis)
        println("BEFORE " + compose.onNodeWithTag(OnThisDayTags.MODE, useUnmergedTree = true).printToString())
        compose.onNodeWithTag(OnThisDayTags.MODE).performClick()
        compose.mainClock.advanceTimeBy(settleMillis)
        println("AFTER " + compose.onRoot(useUnmergedTree = true).printToString())
    }
}
