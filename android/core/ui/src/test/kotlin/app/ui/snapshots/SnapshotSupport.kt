package app.ui.snapshots

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.unit.Dp
import app.designsystem.LocalReduceMotionOverride
import app.designsystem.generated.Tokens
import app.testing.SamplePhotos
import app.ui.theme.AppTheme
import com.github.takahirom.roborazzi.captureRoboImage
import com.github.takahirom.roborazzi.captureScreenRoboImage
import org.junit.Rule
import org.junit.runner.RunWith
import org.robolectric.ParameterizedRobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/** What a component is drawn on in its snapshot. */
enum class Surface { Page, Media, Photo }

/** The appearances every component is recorded in (design/components.md: "a snapshot per state in light and dark"). */
enum class Appearance(val dark: Boolean) { Light(false), Dark(true) }

/**
 * Snapshot host for core:ui components: every test runs once per [Appearance] (light AND dark), inside
 * [AppTheme] (which provides `DsTheme`), on the surface the component belongs on. One test = one component
 * state. Baselines: `src/test/snapshots/components/<component>/<state>-<light|dark>.png` (record:
 * `./gradlew :core:ui:testDebugUnitTest -Proborazzi.test.verify=false -Proborazzi.test.record=true`; plain
 * `testDebugUnitTest` verifies). Texts in tests are test data, not copy; photos are the real sample photos
 * (`app.testing.SamplePhotos`, fixtures/photos/INDEX.md).
 */
@RunWith(ParameterizedRobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(qualifiers = "w393dp-h852dp-xhdpi")
abstract class SnapshotTest(private val appearance: Appearance) {
    @get:Rule val compose = createComposeRule()

    /** Records [content] as `<component>/<state>`, cropped to the content on [surface], [width] wide (null = wrap). */
    fun snap(
        component: String,
        state: String,
        surface: Surface = Surface.Page,
        fontScale: Float = 1f,
        width: Dp? = SCREEN_WIDTH,
        content: @Composable () -> Unit,
    ) {
        compose.setContent {
            Host(appearance, fontScale) {
                Box(
                    Modifier
                        .testTag(TAG)
                        .then(if (width != null) Modifier.width(width) else Modifier)
                        .background(surface.color())
                        .padding(vertical = Tokens.Sizes.globalScreenMargin),
                ) { content() }
            }
        }
        compose.waitForIdle()
        compose.onNodeWithTag(TAG, useUnmergedTree = true).captureRoboImage(path(component, state))
    }

    /** Records the whole screen (windows, dialogs, sheets, popups) with [content] on [surface]. */
    fun snapScreen(component: String, state: String, surface: Surface = Surface.Page, content: @Composable () -> Unit) {
        compose.setContent {
            Host(appearance, 1f) { Box(Modifier.fillMaxSize().background(surface.color())) { content() } }
        }
        compose.waitForIdle()
        captureScreenRoboImage(path(component, state))
    }

    /** Several states stacked in one column, each `size.global.listGap` apart (for small controls). */
    @Composable
    fun Stack(content: @Composable () -> Unit) {
        Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalListGap)) { content() }
    }

    @Composable
    private fun Host(appearance: Appearance, fontScale: Float, content: @Composable () -> Unit) {
        AppTheme(dark = appearance.dark) {
            val density = LocalDensity.current
            CompositionLocalProvider(
                LocalReduceMotionOverride provides false,
                LocalDensity provides Density(density.density, fontScale),
                content = content,
            )
        }
    }

    @Composable
    private fun Surface.color(): Color = when (this) {
        Surface.Page -> Tokens.Colors.globalBackgroundAndroid
        Surface.Media, Surface.Photo -> Tokens.Colors.globalBackgroundDeep
    }

    private fun path(component: String, state: String) =
        "src/test/snapshots/components/$component/$state-${appearance.name.lowercase()}.png"

    companion object {
        private const val TAG = "snapshot"
        val SCREEN_WIDTH = 393.dp

        @JvmStatic
        @ParameterizedRobolectricTestRunner.Parameters(name = "{0}")
        fun appearances(): List<Array<Any>> = Appearance.entries.map { arrayOf(it) }

        /** Sample photos (fixtures/photos) at the shapes the components draw. */
        fun portrait(i: Int) = SamplePhotos.painter(SamplePhotos.pick(i, SamplePhotos.Shape.Portrait), 3, 4)
        fun card(i: Int) = SamplePhotos.painter(SamplePhotos.pick(i, SamplePhotos.Shape.Portrait), 2, 3)
        fun square(i: Int) = SamplePhotos.painter(SamplePhotos.pick(i, SamplePhotos.Shape.Square), 1, 1)
        fun story(i: Int) = SamplePhotos.painter(SamplePhotos.pick(i, SamplePhotos.Shape.Story), 9, 16)
        fun landscape(i: Int) = SamplePhotos.painter(SamplePhotos.pick(i, SamplePhotos.Shape.Landscape), 4, 3)
        fun avatar(i: Int) = SamplePhotos.painter(SamplePhotos.avatar(i))
    }
}
