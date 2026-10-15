package app.designsystem

import android.os.Build
import android.provider.Settings
import android.view.HapticFeedbackConstants
import android.view.View
import androidx.compose.animation.core.SnapSpec
import androidx.compose.animation.core.SpringSpec
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.sp
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class DesignSystemTest {
    @get:Rule val compose = createComposeRule()
    private val context get() = ApplicationProvider.getApplicationContext<android.content.Context>()

    @Test fun hapticFallbacksFollowTheAndroidXTable() {
        val c = HapticFeedbackConstants.CONFIRM
        assertEquals(c, Haptics.resolve(c, Build.VERSION_CODES.R))
        assertEquals(HapticFeedbackConstants.VIRTUAL_KEY, Haptics.resolve(c, Build.VERSION_CODES.Q))
        assertEquals(HapticFeedbackConstants.LONG_PRESS, Haptics.resolve(HapticFeedbackConstants.REJECT, Build.VERSION_CODES.O))
        assertEquals(HapticFeedbackConstants.CONTEXT_CLICK, Haptics.resolve(HapticFeedbackConstants.TOGGLE_ON, Build.VERSION_CODES.TIRAMISU))
        assertEquals(HapticFeedbackConstants.TOGGLE_ON, Haptics.resolve(HapticFeedbackConstants.TOGGLE_ON, Build.VERSION_CODES.UPSIDE_DOWN_CAKE))
        assertEquals(HapticFeedbackConstants.LONG_PRESS, Haptics.resolve(HapticFeedbackConstants.DRAG_START, Build.VERSION_CODES.O))
        assertEquals(Haptics.NO_HAPTICS, Haptics.resolve(HapticFeedbackConstants.TEXT_HANDLE_MOVE, Build.VERSION_CODES.O))
        assertEquals(HapticFeedbackConstants.TEXT_HANDLE_MOVE, Haptics.resolve(HapticFeedbackConstants.TEXT_HANDLE_MOVE, Build.VERSION_CODES.O_MR1))
        assertEquals(Haptics.NO_HAPTICS, Haptics.resolve(Haptics.NO_HAPTICS, Build.VERSION_CODES.BAKLAVA))
    }

    @Test fun hapticsPerformOnTheView() {
        val view = View(context)
        assertTrue(Haptics.perform(view, HapticFeedbackConstants.CONFIRM))
        assertFalse(Haptics.perform(view, Haptics.NO_HAPTICS))
    }

    @Test fun reduceMotionReadsAnimatorDurationScale() {
        val resolver = context.contentResolver
        Settings.Global.putFloat(resolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f)
        assertFalse(ReduceMotion.isEnabled(context))
        Settings.Global.putFloat(resolver, Settings.Global.ANIMATOR_DURATION_SCALE, 0f)
        assertTrue(ReduceMotion.isEnabled(context))
        Settings.Global.putFloat(resolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f)
    }

    @Test fun reducedMotionDropsMovementButKeepsOpacity() {
        val spec = tween<Float>()
        assertTrue(dsMotionSpec(spec, MotionChannel.Movement, reduceMotion = true) is SnapSpec)
        assertSame(spec, dsMotionSpec(spec, MotionChannel.Opacity, reduceMotion = true))
        assertSame(spec, dsMotionSpec(spec, MotionChannel.Movement, reduceMotion = false))

        val fade = tween<Float>()
        val slide = tween<IntOffset>()
        val reduced = dsEnterTransition(true, fade, slide) { IntOffset(0, it.height) }
        val full = dsEnterTransition(false, fade, slide) { IntOffset(0, it.height) }
        assertEquals(fadeIn(fade), reduced)
        assertNotEquals(reduced, full)
    }

    @Test fun reduceMotionOverrideReachesComposables() {
        var seen: Boolean? = null
        compose.setContent {
            CompositionLocalProvider(LocalReduceMotionOverride provides true) { seen = rememberReduceMotion().value }
        }
        compose.waitForIdle()
        assertEquals(true, seen)
    }

    @Test fun springTokenBecomesASpringSpec() {
        val spec = DSSpring(dampingRatio = 0.5f, stiffness = 300f).spec<Float>() as SpringSpec<Float>
        assertEquals(0.5f, spec.dampingRatio)
        assertEquals(300f, spec.stiffness)
    }

    @Test fun customFontResourceName() {
        assertEquals("inter_display", DSFontFamily.Custom("Inter Display").resourceName)
    }

    @Test fun textStyleKeepsSpSoItScalesWithFontSize() {
        val style = dsTextStyle(size = 17.sp, weight = androidx.compose.ui.text.font.FontWeight.Normal)
        assertEquals(17.sp, style.fontSize)
    }
}
