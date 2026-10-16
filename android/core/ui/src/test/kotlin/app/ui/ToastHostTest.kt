package app.ui

import android.widget.Toast
import androidx.compose.runtime.snapshots.Snapshot
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.ui.components.PlatformToast
import app.ui.components.ToastHost
import app.ui.components.ToastState
import app.ui.theme.AppTheme
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.shadows.ShadowToast

/** C-26: confirmations are platform toasts, `LENGTH_SHORT` (Retro's 48 `Toast.makeText(…, LENGTH_SHORT)` calls). */
@RunWith(AndroidJUnit4::class)
class ToastHostTest {
    @get:Rule val compose = createComposeRule()

    @Test fun platformToastIsShortWithTheText() {
        PlatformToast.show(ApplicationProvider.getApplicationContext(), "Saved!")
        assertEquals("Saved!", ShadowToast.getTextOfLatestToast())
        assertEquals(Toast.LENGTH_SHORT, ShadowToast.getLatestToast().duration)
    }

    @Test fun hostTurnsEachMessageIntoOnePlatformToast() {
        val state = ToastState()
        compose.setContent { AppTheme(dark = false) { ToastHost(state) } }
        compose.waitForIdle()
        compose.runOnIdle { state.show("Copied!"); Snapshot.sendApplyNotifications() }
        compose.waitForIdle()
        assertEquals("Copied!", ShadowToast.getTextOfLatestToast())
        assertNull(state.current)
        compose.runOnIdle { state.show("Invite link copied to clipboard"); Snapshot.sendApplyNotifications() }
        compose.waitForIdle()
        assertEquals("Invite link copied to clipboard", ShadowToast.getTextOfLatestToast())
        assertEquals(2, ShadowToast.shownToastCount())
    }
}
