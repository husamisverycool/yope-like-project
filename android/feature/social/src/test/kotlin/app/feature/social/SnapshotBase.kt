package app.feature.social

import androidx.compose.runtime.Composable
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onRoot
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.feature.social.data.SocialData
import com.github.takahirom.roborazzi.captureRoboImage
import com.github.takahirom.roborazzi.captureScreenRoboImage
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Before
import org.junit.Rule
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * One Roborazzi snapshot per screen per state, on a 393-dp-wide phone (the specs' measurement
 * width) at 2×. Baselines: `src/test/snapshots/` (`./gradlew :feature:social:recordRoborazziDebug`).
 */
@RunWith(AndroidJUnit4::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(qualifiers = "w393dp-h852dp-xhdpi")
@OptIn(ExperimentalCoroutinesApi::class)
abstract class SnapshotBase {
    @get:Rule val compose = createComposeRule()

    @Before fun baseSetUp() {
        fixLocale()
        Dispatchers.setMain(UnconfinedTestDispatcher())
        app.feature.social.week.RecapEdits.pending.value = emptyMap()
    }

    @After fun baseTearDown() {
        Dispatchers.resetMain()
    }

    /**
     * Renders [content] in the light appearance (or [dark]) and records it; [screen] = capture every window (sheets,
     * menus, dialogs).
     */
    fun snap(data: SocialData = FakeSocialData(), screen: Boolean = false, dark: Boolean = false, content: @Composable () -> Unit) {
        compose.setContent { TestScreen(data, dark = dark) { content() } }
        compose.waitForIdle()
        if (screen) captureScreenRoboImage() else compose.onRoot().captureRoboImage()
    }
}
