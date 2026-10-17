package app.feature.account

import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.data.model.Group
import app.data.model.GroupKind
import app.designsystem.LocalReduceMotionOverride
import app.feature.account.groups.GroupFeedScreen
import app.feature.account.groups.GroupFeedUiState
import app.feature.account.groups.GroupScreenActions
import app.feature.account.groups.OpenInvitationRow
import app.feature.account.testing.fakeEnvironment
import app.ui.format.InvitationCountdown
import app.testing.SamplePhotos
import app.ui.theme.AppTheme
import coil3.SingletonImageLoader
import com.github.takahirom.roborazzi.captureScreenRoboImage
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.time.Instant
import java.time.LocalTime
import java.time.ZoneId

/**
 * groups.screen while the group's daily invitation is open (migration 0035): the row with its countdown above the week,
 * leading the dated entries; a tap opens the daily capture. Recorded as `groups.screen/openInvitation-<light|dark>.png`.
 */
@RunWith(AndroidJUnit4::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(qualifiers = "w393dp-h852dp-xhdpi")
class OpenInvitationRowTest {
    @get:Rule val compose = createComposeRule()

    private val now = Instant.parse("2026-10-15T17:00:00Z")
    private val group = Group("g1", "Sunday Dinners", GroupKind.Friends, null, "UTC", LocalTime.of(9, 0), LocalTime.of(21, 0), false, "u-me", now.minusSeconds(40 * 86400L), now)

    @Before fun photos() = SingletonImageLoader.setUnsafe(SamplePhotos.imageLoader(ApplicationProvider.getApplicationContext()))

    @After fun resetPhotos() = SingletonImageLoader.reset()

    private fun render(dark: Boolean, onOpen: () -> Unit = {}) {
        compose.mainClock.autoAdvance = false
        compose.setContent {
            CompositionLocalProvider(LocalAccountEnvironment provides fakeEnvironment(), LocalReduceMotionOverride provides false) {
                AppTheme(dark = dark) { screen(onOpen) }
            }
        }
        compose.mainClock.advanceTimeBy(FRAME_MS)
    }

    @Composable
    private fun screen(onOpen: () -> Unit) {
        GroupFeedScreen(
            GroupFeedUiState(group = group, photos = emptyList(), isCreator = false),
            now,
            ZoneId.of("UTC"),
            GroupScreenActions(),
            invitationRow = { OpenInvitationRow(seconds = 88, onClick = onOpen) },
        )
    }

    @Test fun openInvitation() {
        render(dark = false)
        captureScreenRoboImage("src/test/snapshots/groups.screen/openInvitation-light.png")
    }

    @Test fun openInvitationDark() {
        render(dark = true)
        captureScreenRoboImage("src/test/snapshots/groups.screen/openInvitation-dark.png")
    }

    @Test fun tapOpensTheDailyCapture() {
        var opened = 0
        render(dark = false) { opened++ }
        compose.onNodeWithTag("groups.screen.invitation").assertIsDisplayed().performClick()
        assertEquals(1, opened)
    }

    @Test fun countdownFormatAndSpokenValue() {
        compose.setContent { assertEquals("01:28", InvitationCountdown.text(88)) }
        assertEquals("01:28", InvitationCountdown.spoken(88))
    }

    private companion object {
        const val FRAME_MS = 16L
    }
}
