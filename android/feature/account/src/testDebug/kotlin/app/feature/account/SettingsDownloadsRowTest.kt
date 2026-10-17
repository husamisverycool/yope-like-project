package app.feature.account

import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.designsystem.R
import app.feature.account.platform.LegalLinks
import app.feature.account.settings.PermissionRow
import app.feature.account.settings.SettingsRootActions
import app.feature.account.settings.SettingsRootScreen
import app.feature.account.settings.SettingsRootUiState
import app.feature.account.settings.SubscriptionState
import app.feature.account.testing.fakeEnvironment
import app.ui.theme.AppTheme
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

/** settings.root → Privacy → Download My Photos (owner decision 29, free): the row opens settings.downloads. Semantics only. */
@RunWith(AndroidJUnit4::class)
@Config(qualifiers = "w393dp-h852dp-xhdpi")
class SettingsDownloadsRowTest {
    @get:Rule val compose = createComposeRule()

    @Test fun theDownloadRowSitsInPrivacyAndOpensTheDownloadPage() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        var opened = 0
        compose.setContent {
            CompositionLocalProvider(LocalAccountEnvironment provides fakeEnvironment()) {
                AppTheme(dark = false) {
                    SettingsRootScreen(
                        SettingsRootUiState(name = "Ana Lima", phone = null, avatar = null, subscription = SubscriptionState.None),
                        LegalLinks(null, null, null),
                        listOf(PermissionRow(R.string.settings_root_permissions_camera, false)),
                        "1.0 (1)",
                        SettingsRootActions(onDownloads = { opened++ }),
                    )
                }
            }
        }
        compose.onNodeWithText(context.getString(R.string.settings_root_downloads)).performScrollTo().performClick()
        assertEquals(1, opened)
    }
}
