package app.ui

import androidx.compose.runtime.snapshots.Snapshot
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.designsystem.generated.Tokens
import app.ui.components.ToastDwell
import app.ui.components.ToastHost
import app.ui.components.ToastState
import app.ui.theme.AppTheme
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/** The lime toast stays `safety.block.duration.toast`, then leaves; a newer toast replaces the current one. */
@RunWith(AndroidJUnit4::class)
class ToastHostTest {
    @get:Rule val compose = createComposeRule()

    @Test fun showsForTheDwellThenLeaves() {
        assertEquals(Tokens.Durations.safetyBlockDurationToast.toLong(), ToastDwell.millis)
        val state = ToastState()
        compose.setContent { AppTheme { ToastHost(state) } }
        compose.waitForIdle()
        compose.mainClock.autoAdvance = false
        compose.runOnIdle { state.show("you blocked Sam"); Snapshot.sendApplyNotifications() }
        compose.mainClock.advanceTimeBy(ENTER_MS)
        compose.onNodeWithText("you blocked Sam", useUnmergedTree = true).assertExists()
        compose.runOnIdle { state.show("you unblocked Sam"); Snapshot.sendApplyNotifications() }
        compose.mainClock.advanceTimeBy(ENTER_MS)
        compose.onNodeWithText("you unblocked Sam", useUnmergedTree = true).assertExists()
        compose.onNodeWithText("you blocked Sam").assertDoesNotExist()
        compose.mainClock.advanceTimeBy(ToastDwell.millis!! + SETTLE_MS)
        compose.onNodeWithText("you unblocked Sam").assertDoesNotExist()
        assertEquals(null, state.current)
    }

    private companion object {
        const val ENTER_MS = 500L
        const val SETTLE_MS = 1_000L
    }
}
