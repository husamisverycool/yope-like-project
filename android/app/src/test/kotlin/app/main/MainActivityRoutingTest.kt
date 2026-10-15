package app.main

import android.content.Intent
import android.net.Uri
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.links.DeepLinkIntents
import app.model.DeepLink
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/** Widget and notification taps are explicit intents to MainActivity that land on their screen. */
@RunWith(AndroidJUnit4::class)
class MainActivityRoutingTest {
    @get:Rule val compose = createEmptyComposeRule()

    private val app = ApplicationProvider.getApplicationContext<App>()

    @Test fun widgetTapOpensTheCameraForThatGroup() {
        val intent: Intent = DeepLinkIntents.intent(app, DeepLink.Camera("g9"))!!
        assertEquals(MainActivity::class.java.name, intent.component!!.className)
        assertEquals(Uri.parse("app://camera?group=g9"), intent.data)
        ActivityScenario.launch<MainActivity>(intent).use {
            compose.onNode(hasTestTag("camera.capture"), useUnmergedTree = true).assertExists()
        }
    }

    @Test fun notificationTapWhileRunningRoutesThroughOnNewIntent() {
        ActivityScenario.launch(MainActivity::class.java).use { scenario ->
            compose.onNode(hasTestTag("groups.list"), useUnmergedTree = true).assertExists()
            val tap = DeepLinkIntents.intent(app, DeepLink.DailyInvitation("g1", "inv1"))!!
            scenario.onActivity { it.onNewIntent(tap) }
            compose.onNode(hasTestTag("daily.capture"), useUnmergedTree = true).assertExists()
        }
    }

    @Test fun inviteAppLinkIsIgnoredWhileTheDomainIsUnset() {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://unset.invalid/i/token"))
            .setClass(app, MainActivity::class.java)
        ActivityScenario.launch<MainActivity>(intent).use {
            compose.onNode(hasTestTag("groups.list"), useUnmergedTree = true).assertExists()
        }
    }
}
