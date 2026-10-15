package app.main

import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.navigation.NavDestination.Companion.hasRoute
import androidx.navigation.NavHostController
import androidx.navigation.compose.rememberNavController
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.data.model.MemberRole
import app.feature.account.testing.FakeAccountBackend
import app.feature.account.testing.FakeStores
import app.feature.account.testing.fakeEnvironment
import app.model.AppRoute
import app.model.DeepLink
import app.ui.nav.EmptyDestination
import app.ui.theme.AppTheme
import com.github.takahirom.roborazzi.captureRoboImage
import kotlinx.coroutines.flow.MutableSharedFlow
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

@RunWith(AndroidJUnit4::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(qualifiers = "w360dp-h640dp-xhdpi")
class AppTest {
    @get:Rule val compose = createComposeRule()

    /** Proves the Roborazzi pipeline (record/verify) with a token-free composable. */
    @Test fun snapshotPipeline() {
        captureRoboImage { EmptyDestination(AppRoute.GroupsList) }
    }

    @Test fun notificationAndWidgetLinksRebuildTheBackStack() {
        val backend = FakeAccountBackend().apply {
            signIn(); ageConfirmed = true; profile(meId, "Ana Lima")
            group("g1", "Sunday dinners"); member("g1", meId, MemberRole.Admin)
        }
        val env = fakeEnvironment(backend, FakeStores().apply { onboarded += backend.meId })
        val links = MutableSharedFlow<DeepLink>(extraBufferCapacity = 4)
        lateinit var nav: NavHostController
        compose.setContent {
            nav = rememberNavController()
            AppTheme { AppNavHost(links, nav, env) }
        }
        compose.waitForIdle()
        assertTrue(nav.currentDestination!!.hasRoute<AppRoute.GroupsList>())

        links.tryEmit(DeepLink.Post("g1", "p1"))
        compose.waitForIdle()
        assertTrue(nav.currentDestination!!.hasRoute<AppRoute.PhotoViewer>())
        assertTrue(nav.previousBackStackEntry!!.destination.hasRoute<AppRoute.Group>())

        links.tryEmit(DeepLink.Camera("g2"))
        compose.waitForIdle()
        assertTrue(nav.currentDestination!!.hasRoute<AppRoute.Camera>())
        assertTrue(nav.previousBackStackEntry!!.destination.hasRoute<AppRoute.GroupsList>())
    }
}
