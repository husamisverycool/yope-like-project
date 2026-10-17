package app.feature.capture

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import androidx.activity.ComponentActivity
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.data.model.WidgetPerson
import app.feature.capture.widget.CameraShortcuts
import app.feature.capture.widget.WidgetPeoplePickerScreen
import app.feature.capture.widget.WidgetPeopleState
import app.feature.capture.widget.WidgetPickerScreen
import app.feature.capture.widget.WidgetPickerState
import app.feature.capture.widget.WidgetStylePickerScreen
import app.links.DeepLinkIntents
import app.model.WidgetStyle
import app.ui.theme.AppTheme
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.After
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * The widget configuration's new steps (design/surfaces/widget.home.small.md → All Groups, widget.friend.md → configure
 * activity, widget.styles.md → Android style step) as semantics, and the camera's quick ways in (camera.quickaccess.md:
 * the Quick Settings tile, the per-group launcher shortcuts).
 */
@RunWith(AndroidJUnit4::class)
class WidgetConfigureAndQuickAccessTest {
    @get:Rule val compose = createComposeRule()
    private val context: Context get() = ApplicationProvider.getApplicationContext()

    @Before fun setUp() {
        // The shortcuts' intents name the app's activity (the app sets it at start).
        DeepLinkIntents.targetActivity = ComponentActivity::class.java
        CameraShortcuts.clear(context)
    }

    @After fun tearDown() {
        DeepLinkIntents.targetActivity = null
    }

    @Test fun allGroupsIsTheFirstRowOfTheGroupPicker() {
        var all = 0
        val chosen = mutableListOf<String>()
        compose.setContent {
            AppTheme { WidgetPickerScreen(WidgetPickerState.Groups(listOf(group("g1", "Lima family"), group("g2", "Book club"))), onAllGroups = { all++ }) { chosen += it.id } }
        }
        compose.onNodeWithText("See photos from…").assertIsDisplayed()
        compose.onNodeWithTag("widget.configure.all").assertIsDisplayed()
        compose.onNodeWithText("All Groups").performClick()
        compose.onNodeWithTag("widget.configure.g2").performClick()
        assertEquals(1, all)
        assertEquals(listOf("g2"), chosen)
    }

    @Test fun thePersonPickerListsWidgetPeopleOrSaysWhyNot() {
        var state: WidgetPeopleState by androidx.compose.runtime.mutableStateOf(WidgetPeopleState.of(listOf(WidgetPerson("u2", "Ana Lima"), WidgetPerson("u3", "Rui"))))
        val chosen = mutableListOf<String>()
        compose.setContent { AppTheme { WidgetPeoplePickerScreen(state) { chosen += it.userId } } }
        compose.onNodeWithText("Ana Lima").performClick()
        assertEquals(listOf("u2"), chosen)
        state = WidgetPeopleState.of(emptyList())
        compose.onNodeWithText("Join a group to see your friends here.").assertIsDisplayed()
        state = WidgetPeopleState.of(null)
        compose.waitForIdle()
        assertTrue(state is WidgetPeopleState.Error)
    }

    @Test fun theStyleStepMarksPremiumStylesWithoutPremium() {
        var premium by androidx.compose.runtime.mutableStateOf(false)
        val chosen = mutableListOf<WidgetStyle>()
        compose.setContent { AppTheme { WidgetStylePickerScreen(premium) { chosen += it } } }
        compose.onNodeWithText("Select Style").assertIsDisplayed()
        compose.onNodeWithText("Show the photo edge to edge").assertIsDisplayed()
        compose.onAllNodesWithText("Premium").assertCountEquals(2)
        compose.onNodeWithTag("widget.style.frame").performClick()
        assertEquals(listOf(WidgetStyle.Frame), chosen)
        premium = true
        compose.onAllNodesWithText("Premium").assertCountEquals(0)
    }

    @Test fun theTileIsDeclaredAsAQuickSettingsTile() {
        val info = context.packageManager.getServiceInfo(ComponentName(context, CameraTileService::class.java), PackageManager.GET_META_DATA)
        assertEquals("android.permission.BIND_QUICK_SETTINGS_TILE", info.permission)
        assertTrue(info.exported)
        val resolved = context.packageManager.queryIntentServices(Intent("android.service.quicksettings.action.QS_TILE").setPackage(context.packageName), 0)
        assertTrue(resolved.any { it.serviceInfo.name == CameraTileService::class.java.name })
    }

    @Test fun launcherShortcutsFollowTheGroupsRecentlySentTo() = runBlocking {
        val names = mapOf("g1" to "Lima family", "g2" to "Book club", "g3" to "Roommates", "g4" to "Climbing")
        suspend fun send(vararg ids: String) = CameraShortcuts.recordSend(context, ids.toList()) { id -> names[id]?.let { group(id, it) } }
        send("g1")
        send("g2", "g3")
        send("g4")
        assertEquals("newest first, at most 3", listOf("g4", "g2", "g3"), CameraShortcuts.recent(context).map { it.groupId })
        val shortcuts = ShortcutManagerCompat.getDynamicShortcuts(context)
        assertEquals(listOf("Climbing", "Book club", "Roommates"), shortcuts.sortedBy { it.rank }.map { it.shortLabel.toString() })
        assertEquals("Take photo for Climbing", shortcuts.first { it.id == CameraShortcuts.shortcutId("g4") }.longLabel.toString())
        assertEquals("app://camera?group=g4", shortcuts.first { it.id == CameraShortcuts.shortcutId("g4") }.intent.dataString)
        // A group left: its shortcut goes when the group list loads.
        CameraShortcuts.sync(context, setOf("g2", "g4"))
        assertEquals(listOf("g4", "g2"), CameraShortcuts.recent(context).map { it.groupId })
        assertEquals(2, ShortcutManagerCompat.getDynamicShortcuts(context).size)
        CameraShortcuts.clear(context)
        assertTrue(ShortcutManagerCompat.getDynamicShortcuts(context).isEmpty())
    }
}
