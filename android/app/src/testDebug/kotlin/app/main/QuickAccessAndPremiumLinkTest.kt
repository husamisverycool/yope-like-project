package app.main

import android.content.Intent
import androidx.compose.ui.test.junit4.v2.createEmptyComposeRule
import androidx.navigation.NavDestination.Companion.hasRoute
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.data.model.MemberRole
import app.feature.account.AccountEnvironments
import app.feature.account.testing.FakeAccountBackend
import app.feature.account.testing.FakeStores
import app.feature.account.testing.fakeEnvironment
import app.links.DeepLinkIntents
import app.model.AppRoute
import app.model.DeepLink
import app.model.DeepLinkCodec
import app.model.PaywallPerkRoute
import app.model.SessionPromptGate
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.xmlpull.v1.XmlPullParser

/**
 * camera.quickaccess: the static launcher shortcut opens the camera as a widget tap does; widget.styles: a locked style's
 * tap (`app://premium?perk=widgets&to=camera&group=…`) opens the paywall over the widget's own place while the session's
 * one prompt is unused, and the place alone afterwards.
 */
@RunWith(AndroidJUnit4::class)
class QuickAccessAndPremiumLinkTest {
    @get:Rule val compose = createEmptyComposeRule()

    private val app = ApplicationProvider.getApplicationContext<App>()
    private val android = "http://schemas.android.com/apk/res/android"

    @Before fun signedInMember() {
        val backend = FakeAccountBackend().apply {
            signIn(); ageConfirmed = true; profile(meId, "Ana Lima")
            group("g1", "Sunday dinners"); member("g1", meId, MemberRole.Admin)
        }
        AccountEnvironments.override(fakeEnvironment(backend, FakeStores().apply { onboarded += backend.meId }))
    }

    @After fun reset() = AccountEnvironments.override(null)

    @Test fun theStaticShortcutOpensTheCameraInThisApp() {
        val parser = app.resources.getXml(R.xml.shortcuts)
        var shortcutId: String? = null
        var data: String? = null
        var targetPackage: String? = null
        var targetClass: String? = null
        while (parser.next() != XmlPullParser.END_DOCUMENT) {
            if (parser.eventType != XmlPullParser.START_TAG) continue
            when (parser.name) {
                "shortcut" -> shortcutId = parser.getAttributeValue(android, "shortcutId")
                "intent" -> {
                    data = parser.getAttributeValue(android, "data")
                    targetClass = parser.getAttributeValue(android, "targetClass")
                    val ref = parser.getAttributeResourceValue(android, "targetPackage", 0)
                    targetPackage = if (ref != 0) app.getString(ref) else parser.getAttributeValue(android, "targetPackage")
                }
            }
        }
        assertEquals("camera", shortcutId)
        assertEquals("app://camera", data)
        assertEquals(MainActivity::class.java.name, targetClass)
        assertEquals(app.packageName, targetPackage)
        assertEquals(DeepLink.Camera(null), DeepLinkCodec(null).parse(data))
    }

    @Test fun aLockedWidgetStyleOpensThePaywallOnceThenThePlace() {
        val promptAvailable = SessionPromptGate.process.canPrompt
        val link = DeepLink.Premium(DeepLinkCodec.PERK_WIDGETS, DeepLink.Camera("g1"))
        val intent: Intent = DeepLinkIntents.intent(app, link)!!
        ActivityScenario.launch<MainActivity>(intent).use { scenario ->
            compose.waitForIdle()
            scenario.onActivity {
                val nav = it.navController!!
                if (promptAvailable) {
                    assertTrue("the paywall at the widgets perk", nav.currentDestination!!.hasRoute<PaywallPerkRoute>())
                    nav.popBackStack()
                }
                assertTrue("then the widget's own place", nav.currentDestination!!.hasRoute<AppRoute.Camera>())
            }
        }
        // The session's prompt is used now: a second tap goes straight to the camera.
        ActivityScenario.launch<MainActivity>(DeepLinkIntents.intent(app, link)!!).use { scenario ->
            compose.waitForIdle()
            scenario.onActivity { assertTrue(it.navController!!.currentDestination!!.hasRoute<AppRoute.Camera>()) }
        }
    }
}
