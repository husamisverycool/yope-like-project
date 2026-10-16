package app.main

import android.graphics.drawable.ColorDrawable
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.test.junit4.v2.createEmptyComposeRule
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.data.model.MemberRole
import app.designsystem.generated.Tokens
import app.feature.account.AccountEnvironments
import app.feature.account.testing.FakeAccountBackend
import app.feature.account.testing.FakeStores
import app.feature.account.testing.fakeEnvironment
import app.ui.theme.AppearanceSettings
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.annotation.Config

/**
 * Settings → True Black (Android, owner decision 21): a device setting the activity reads at start and follows while it
 * runs — the window background is `color.global.background.android.trueBlack` in dark, Retro's default
 * `color.global.background.android` otherwise; light is untouched.
 */
@RunWith(AndroidJUnit4::class)
class TrueBlackWindowTest {
    @get:Rule val compose = createEmptyComposeRule()

    private val app = ApplicationProvider.getApplicationContext<App>()
    private val appearance get() = AppearanceSettings.device(app)

    @Before fun signedInMember() {
        val backend = FakeAccountBackend().apply {
            signIn(); ageConfirmed = true; profile(meId, "Ana Lima")
            group("g1", "Sunday dinners"); member("g1", meId, MemberRole.Admin)
        }
        AccountEnvironments.override(fakeEnvironment(backend, FakeStores().apply { onboarded += backend.meId }, launchToCamera = false))
    }

    @After fun reset() {
        appearance.setTrueBlack(false)
        AccountEnvironments.override(null)
    }

    private fun windowColour(): Int {
        val controller = Robolectric.buildActivity(MainActivity::class.java).setup()
        compose.waitForIdle()
        val colour = (controller.get().window.decorView.background as ColorDrawable).color
        controller.pause().stop().destroy()
        return colour
    }

    @Test @Config(qualifiers = "night")
    fun darkWindowFollowsTheSetting() {
        appearance.setTrueBlack(false)
        assertEquals(Tokens.ColorsDark.globalBackgroundAndroid.toArgb(), windowColour())
        appearance.setTrueBlack(true)
        assertEquals(Tokens.ColorsDark.globalBackgroundAndroidTrueBlack.toArgb(), windowColour())
        // Kept on the device: a new settings object reads the same value back.
        assertEquals(true, app.getSharedPreferences("appearance", android.content.Context.MODE_PRIVATE).getBoolean("true_black", false))
    }

    @Test @Config(qualifiers = "notnight")
    fun lightWindowIgnoresIt() {
        appearance.setTrueBlack(true)
        assertEquals(Tokens.ColorsLight.globalBackgroundAndroid.toArgb(), windowColour())
    }
}
