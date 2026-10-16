package app.ui

import android.content.Context
import android.content.res.Configuration
import android.view.HapticFeedbackConstants
import androidx.compose.material3.LocalMinimumInteractiveComponentSize
import androidx.compose.foundation.layout.height
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalViewConfiguration
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertIsNotSelected
import androidx.compose.ui.test.assertIsSelected
import androidx.compose.ui.test.assertTouchHeightIsEqualTo
import androidx.compose.ui.test.assertTouchWidthIsEqualTo
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.sp
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.designsystem.LocalDsDarkTheme
import app.designsystem.generated.Tokens
import app.designsystem.toFontFamily
import app.ui.components.CircleIconButton
import app.ui.components.HeaderIconButton
import app.ui.components.PrimaryButton
import app.ui.components.SegmentedControl
import app.ui.components.TabBar
import app.ui.components.TabBarItem
import app.ui.components.ViewerPhoto
import app.ui.haptics.LocalHapticsOverride
import app.ui.text.TextRoles
import app.ui.theme.AppTheme
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.util.Locale

/** Interaction, accessibility and theme behaviour of the components (Robolectric Compose tests). */
@RunWith(AndroidJUnit4::class)
class ComponentBehaviourTest {
    @get:Rule val compose = createComposeRule()
    private val context get() = ApplicationProvider.getApplicationContext<Context>()

    /** Records the haptic constants the components play (resolved for the test SDK). */
    private fun recorder(log: MutableList<String>): (Int) -> Unit = { log += "haptic:$it" }

    @Test fun appThemeAppliesTheAppearanceAndTouchTarget() {
        var dark: Boolean? = null
        var target: Float? = null
        var touch: Float? = null
        compose.setContent {
            AppTheme(dark = true) {
                dark = LocalDsDarkTheme.current
                target = LocalMinimumInteractiveComponentSize.current.value
                touch = LocalViewConfiguration.current.minimumTouchTargetSize.width.value
            }
        }
        compose.waitForIdle()
        assertEquals(true, dark)
        assertEquals(Tokens.Sizes.globalMinTouchTargetAndroid.value, target)
        assertEquals(Tokens.Sizes.globalMinTouchTargetAndroid.value, touch)
    }

    @Test fun tapHapticPlaysBeforeTheAction() {
        val log = mutableListOf<String>()
        compose.setContent {
            CompositionLocalProvider(LocalHapticsOverride provides recorder(log)) {
                AppTheme(dark = false) { PrimaryButton("Get started", { log += "click" }) }
            }
        }
        compose.onNodeWithText("Get started").performClick()
        assertEquals(listOf("haptic:${HapticFeedbackConstants.VIRTUAL_KEY}", "click"), log)
    }

    @Test fun smallControlsHaveTheMinimumTouchTarget() {
        compose.setContent {
            AppTheme(dark = false) {
                androidx.compose.foundation.layout.Row {
                    CircleIconButton(Tokens.Icons.globalClose, "Close", {})
                    HeaderIconButton(Tokens.Icons.globalMore, "More", {})
                }
            }
        }
        val min = Tokens.Sizes.globalMinTouchTargetAndroid
        // The 36 dp circle draws at 36 but is touchable over 48 dp.
        compose.onNodeWithContentDescription("Close").assertTouchWidthIsEqualTo(min).assertTouchHeightIsEqualTo(min)
        compose.onNodeWithContentDescription("More").assertTouchWidthIsEqualTo(min).assertTouchHeightIsEqualTo(min)
    }

    @Test fun tabBarItemsAreSelectableTabsWithLabelsAndUnreadValue() {
        val log = mutableListOf<String>()
        var selected by mutableIntStateOf(0)
        compose.setContent {
            CompositionLocalProvider(LocalHapticsOverride provides recorder(log)) {
                AppTheme(dark = false) {
                    TabBar(
                        listOf(TabBarItem(Tokens.Icons.globalHome, "Home"), TabBarItem(Tokens.Icons.globalActivity, "Activity", unread = true, unreadDescription = "new activity")),
                        selected,
                        { selected = it },
                    )
                }
            }
        }
        compose.onNodeWithContentDescription("Home").assertIsSelected()
        compose.onNodeWithContentDescription("Activity").assertIsNotSelected()
            .assert(SemanticsMatcher.expectValue(SemanticsProperties.StateDescription, "new activity"))
            .performClick()
        compose.onNodeWithContentDescription("Activity").assertIsSelected()
        assertEquals(1, selected)
        assertEquals(listOf("haptic:${HapticFeedbackConstants.VIRTUAL_KEY}"), log)
    }

    @Test fun segmentedChoicePlaysTheTick() {
        val log = mutableListOf<String>()
        var selected by mutableIntStateOf(0)
        compose.setContent {
            CompositionLocalProvider(LocalHapticsOverride provides recorder(log)) {
                AppTheme(dark = false) { SegmentedControl(listOf("Yearly", "Monthly"), selected, { selected = it }) }
            }
        }
        compose.onNodeWithText("Monthly").performClick()
        assertEquals(1, selected)
        // haptic.global.select: SEGMENT_FREQUENT_TICK (API 34+; the test SDK is 36).
        assertEquals(listOf("haptic:${HapticFeedbackConstants.SEGMENT_FREQUENT_TICK}"), log)
        // Choosing the selected segment again does nothing (no tick).
        compose.onNodeWithText("Monthly").performClick()
        assertEquals(1, log.size)
        compose.onNodeWithText("Yearly").performClick()
        assertEquals(0, selected)
        assertEquals(2, log.size)
    }

    @Test fun viewerExposesNextAndPreviousToTalkBack() {
        val log = mutableListOf<String>()
        compose.setContent {
            AppTheme(dark = false) {
                ViewerPhoto(null, "Photo by olson", { log += "next" }, { log += "previous" }, "Next", "Previous", previousFraction = 0.3f, modifier = androidx.compose.ui.Modifier.height(Tokens.Sizes.globalFriendCardHeight))
            }
        }
        val node = compose.onNodeWithContentDescription("Photo by olson")
        val actions = node.fetchSemanticsNode().config[SemanticsActions.CustomActions]
        assertEquals(listOf("Next", "Previous"), actions.map { it.label })
        actions.forEach { it.action() }
        assertEquals(listOf("next", "previous"), log)
        node.performClick() // a tap at the centre advances
        assertEquals("next", log.last())
    }

    @Test fun androidTextRolesUseRetrosAndroidValuesAndLatinOnlyTracking() {
        var latin: TextStyle? = null
        var japanese: TextStyle? = null
        val ja = Configuration(context.resources.configuration).apply { setLocale(Locale.JAPAN) }
        val en = Configuration(context.resources.configuration).apply { setLocale(Locale.US) }
        compose.setContent {
            CompositionLocalProvider(LocalConfiguration provides en) { latin = TextRoles.body }
            CompositionLocalProvider(LocalConfiguration provides ja) { japanese = TextRoles.body }
        }
        compose.waitForIdle()
        val body = latin!!
        assertEquals(Tokens.FontSizes.globalBodyAndroid, body.fontSize)
        assertEquals(Tokens.LineHeights.globalBodyAndroid, body.lineHeight)
        assertEquals(Tokens.Layouts.GlobalVariableWeightAndroid.body.toInt(), body.fontWeight!!.weight)
        assertEquals(Tokens.Tracking.globalBodyAndroid, body.letterSpacing)
        assertEquals(0.sp, japanese!!.letterSpacing)
        assertTrue(body.fontSize.isSp)
    }

    @Test fun displayRolesUseTheBundledDisplayFaces() {
        var header: TextStyle? = null
        var headline: TextStyle? = null
        var title: androidx.compose.ui.text.font.FontFamily? = null
        var narrow: androidx.compose.ui.text.font.FontFamily? = null
        compose.setContent {
            header = TextRoles.headerTitle
            headline = TextRoles.displayMedium
            title = Tokens.Fonts.globalDisplay.toFontFamily()
            narrow = Tokens.Fonts.globalDisplayNarrow.toFontFamily()
        }
        compose.waitForIdle()
        // Both faces are bundled under res/font (L-8), so they resolve to resource fonts, not a device family.
        assertTrue(Tokens.Fonts.globalDisplay is app.designsystem.DSFontFamily.Custom)
        assertTrue(Tokens.Fonts.globalDisplayNarrow is app.designsystem.DSFontFamily.Custom)
        assertEquals(title, header!!.fontFamily)
        assertEquals(narrow, headline!!.fontFamily)
        assertTrue(title != narrow)
        assertEquals(Tokens.FontSizes.globalHeaderTitle, header!!.fontSize)
        assertEquals(Tokens.LineHeights.globalHeaderTitle, header!!.lineHeight)
        assertEquals(Tokens.FontSizes.globalDisplayMedium, headline!!.fontSize)
    }
}
