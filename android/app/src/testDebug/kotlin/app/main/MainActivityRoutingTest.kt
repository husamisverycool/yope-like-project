package app.main

import android.content.Intent
import android.net.Uri
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
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric

/** Widget and notification taps are explicit intents to MainActivity that land on their screen. */
@RunWith(AndroidJUnit4::class)
class MainActivityRoutingTest {
    @get:Rule val compose = createEmptyComposeRule()

    private val app = ApplicationProvider.getApplicationContext<App>()

    @Before fun signedInMember() {
        val backend = FakeAccountBackend().apply {
            signIn(); ageConfirmed = true; profile(meId, "Ana Lima")
            group("g1", "Sunday dinners"); member("g1", meId, MemberRole.Admin)
        }
        AccountEnvironments.override(fakeEnvironment(backend, FakeStores().apply { onboarded += backend.meId }))
    }

    @After fun reset() = AccountEnvironments.override(null)

    @Test fun widgetTapOpensTheCameraForThatGroup() {
        val intent: Intent = DeepLinkIntents.intent(app, DeepLink.Camera("g9"))!!
        assertEquals(MainActivity::class.java.name, intent.component!!.className)
        assertEquals(Uri.parse("app://camera?group=g9"), intent.data)
        ActivityScenario.launch<MainActivity>(intent).use { scenario ->
            compose.waitForIdle()
            scenario.onActivity { assertTrue(it.navController!!.currentDestination!!.hasRoute<AppRoute.Camera>()) }
        }
    }

    @Test fun notificationTapWhileRunningRoutesThroughOnNewIntent() {
        val controller = Robolectric.buildActivity(MainActivity::class.java).setup()
        compose.waitForIdle()
        assertTrue(controller.get().navController!!.currentDestination!!.hasRoute<AppRoute.GroupsList>())
        val tap = DeepLinkIntents.intent(app, DeepLink.DailyInvitation("g1", "inv1"))!!
        controller.newIntent(tap)
        compose.waitForIdle()
        assertTrue(controller.get().navController!!.currentDestination!!.hasRoute<AppRoute.DailyCapture>())
        controller.pause().stop().destroy()
    }

    @Test fun inviteAppLinkIsIgnoredWhileTheDomainIsUnset() {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://unset.invalid/i/token"))
            .setClass(app, MainActivity::class.java)
        ActivityScenario.launch<MainActivity>(intent).use { scenario ->
            compose.waitForIdle()
            scenario.onActivity { assertTrue(it.navController!!.currentDestination!!.hasRoute<AppRoute.GroupsList>()) }
        }
    }
}
