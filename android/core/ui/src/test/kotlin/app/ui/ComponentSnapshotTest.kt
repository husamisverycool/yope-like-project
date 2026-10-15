package app.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.painter.ColorPainter
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.text.input.TextFieldValue
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.designsystem.LocalReduceMotionOverride
import app.designsystem.generated.Tokens
import app.ui.components.AccentTitle
import app.ui.components.AppTab
import app.ui.components.Avatar
import app.ui.components.CheckRow
import app.ui.components.EmptyState
import app.ui.components.EmptyStateAction
import app.ui.components.FloatingTabBar
import app.ui.components.FormTextField
import app.ui.components.HeaderCircleButton
import app.ui.components.HeaderCircleFill
import app.ui.components.LightPill
import app.ui.components.LightPillShape
import app.ui.components.LimeToast
import app.ui.components.LoadingHud
import app.ui.components.OnboardingTitle
import app.ui.components.PermissionCard
import app.ui.components.PrimaryButton
import app.ui.components.PrimaryButtonSize
import app.ui.components.SegmentedControl
import app.ui.components.TabLabels
import app.ui.components.TextLink
import app.ui.system.SystemAlertDialog
import app.ui.system.SystemDivider
import app.ui.system.SystemEmpty
import app.ui.system.SystemRow
import app.ui.system.SystemSectionFooter
import app.ui.system.SystemSectionHeader
import app.ui.system.SystemSwitchRow
import app.ui.theme.AppTheme
import com.github.takahirom.roborazzi.captureRoboImage
import com.github.takahirom.roborazzi.captureScreenRoboImage
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * Snapshots of every shared component (core:ui) in each of its states. Baselines:
 * `src/test/snapshots/components/` (`./gradlew :core:ui:recordRoborazziDebug`).
 * Placeholder texts are test data, not copy.
 */
@RunWith(AndroidJUnit4::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(qualifiers = "w393dp-h852dp-xhdpi")
class ComponentSnapshotTest {
    @get:Rule val compose = createComposeRule()

    private fun shot(name: String, content: @Composable () -> Unit) =
        captureRoboImage("src/test/snapshots/components/$name.png") {
            AppTheme {
                CompositionLocalProvider(LocalReduceMotionOverride provides true) {
                    Column(Modifier.background(Tokens.Colors.globalBackgroundDeep).padding(Tokens.Sizes.globalScreenMargin)) { content() }
                }
            }
        }

    @Test fun primaryButton() = shot("primaryButton") {
        Column(verticalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalListGap)) {
            PrimaryButton("continue", {})
            PrimaryButton("continue", {}, enabled = false)
            PrimaryButton("continue", {}, size = PrimaryButtonSize.Sheet)
            PrimaryButton("continue", {}, loading = true)
        }
    }

    @Test fun lightPillAndTextLink() = shot("lightPill") {
        Column(verticalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalListGap)) {
            LightPill("invite more friends", {}, leadingIcon = Tokens.Icons.globalLink)
            LightPill("try again", {})
            LightPill("enable", {}, shape = LightPillShape.Capsule, height = Tokens.Sizes.onboardingPermissionContactsSizeCardButtonHeight, modifier = Modifier.width(Tokens.Sizes.onboardingPermissionContactsSizeCardButtonWidth))
            TextLink("send new code", {})
            TextLink("send new code", {}, enabled = false)
        }
    }

    @Test fun headerCircles() = shot("headerCircles") {
        Row(horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalHeaderGap)) {
            HeaderCircleButton(Tokens.Icons.globalBack, "back", {}, fill = HeaderCircleFill.Control)
            HeaderCircleButton(Tokens.Icons.globalClose, "close", {}, fill = HeaderCircleFill.OnDeep)
            HeaderCircleButton(Tokens.Icons.globalMore, "more", {}, fill = HeaderCircleFill.Raised)
            HeaderCircleButton(Tokens.Icons.globalAdd, "add", {})
        }
    }

    @Test fun avatars() = shot("avatars") {
        Row(horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalHeaderGap)) {
            Avatar(null, Tokens.Sizes.globalAvatarList)
            Avatar(null, Tokens.Sizes.globalAvatarList, fallbackIcon = Tokens.Icons.globalGroup)
            Avatar(ColorPainter(Tokens.Colors.globalAccentSecondary), Tokens.Sizes.globalAvatarList)
            Avatar(null, Tokens.Sizes.authProfileSizeAvatar)
        }
    }

    @Test fun formField() = shot("formField") {
        Column(verticalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalListGap)) {
            FormTextField(TextFieldValue(""), {}, placeholder = "phone number", accessibilityLabel = "phone number")
            FormTextField(TextFieldValue("+1 415 555 0100"), {}, placeholder = "phone number", accessibilityLabel = "phone number")
        }
    }

    @Test fun loadingHudAndToast() = shot("hudToast") {
        Column(verticalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalListGap)) {
            LoadingHud("Loading")
            LimeToast("you blocked Sam")
        }
    }

    @Test fun emptyStates() = shot("emptyState") {
        Column(verticalArrangement = Arrangement.spacedBy(Tokens.Sizes.groupsCreateSizeTitleToContent)) {
            EmptyState("you created group", "and added Ana, Rui", action = EmptyStateAction("invite more friends", {}, Tokens.Icons.globalLink))
            EmptyState("you’re offline", "your groups will be here when you’re back online")
        }
    }

    @Test fun permissionCard() = shot("permissionCard") {
        Column(verticalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalListGap)) {
            PermissionCard("can’t see your friends?", "enable contacts", "enable", {}, onDismiss = {}, dismissLabel = "dismiss")
            PermissionCard("can’t take pics?", "enable camera", "enable", {})
        }
    }

    @Test fun segmentedAndCheck() = shot("segmentedCheck") {
        Column(verticalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalListGap)) {
            SegmentedControl(listOf("friends", "family", "roommates", "custom"), 0, {})
            SegmentedControl(listOf("pics", "wall", "recaps"), 2, {})
            CheckRow("tell my groups when it’s my birthday", false, {}, "tell my groups", detail = "we’ll save your birthday for this")
            CheckRow("tell my groups when it’s my birthday", true, {}, "tell my groups", detail = "we’ll save your birthday for this")
        }
    }

    @Test fun titles() = shot("titles") {
        OnboardingTitle("sign up or log in")
        AccentTitle("create your", "first group")
    }

    @Test fun tabBar() = shot("tabBar") {
        val labels = TabLabels("camera", "groups", "walls", "me")
        Column(verticalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalListGap)) {
            FloatingTabBar(AppTab.Groups, {}, labels, meAvatar = null)
            FloatingTabBar(AppTab.Me, {}, labels, meAvatar = ColorPainter(Tokens.Colors.globalAccentSecondary))
        }
    }

    @Test fun systemList() = shot("systemList") {
        Column(Modifier.background(Tokens.Colors.globalSystemSurface)) {
            SystemSectionHeader("members")
            SystemRow("Ana Lima", supporting = "admin", leading = { Avatar(null, Tokens.Sizes.settingsRootSizeListItemAvatarAndroid) }, onClick = {})
            SystemSwitchRow("mute this group", checked = true, onCheckedChange = {})
            SystemSwitchRow("pause invitations", checked = false, onCheckedChange = {}, enabled = false)
            SystemSectionFooter("muted groups don’t send you notifications.")
            SystemSectionFooter("that didn’t work.", isError = true)
            SystemDivider()
            SystemRow("leave group", destructive = true, leading = { androidx.compose.material3.Icon(Tokens.Icons.globalLeave, null) }, onClick = {})
            SystemEmpty("No Blocked People", "When you block someone, you won’t see each other’s photos.")
        }
    }

    @Test fun alertDialog() {
        compose.setContent {
            AppTheme {
                SystemAlertDialog("Leave Sunday dinners?", "Your photos stay in the group.", "Leave", {}, "Cancel", {}, destructive = true)
            }
        }
        compose.waitForIdle()
        captureScreenRoboImage("src/test/snapshots/components/alertDialog.png")
    }
}
