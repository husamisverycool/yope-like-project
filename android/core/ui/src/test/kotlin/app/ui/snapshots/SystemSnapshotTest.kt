package app.ui.snapshots

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.TextFieldValue
import app.designsystem.generated.Tokens
import app.ui.components.GroupedRowSpec
import app.ui.components.GroupedSection
import app.ui.components.HeaderAction
import app.ui.components.ScreenHeader
import app.ui.components.SearchField
import app.ui.system.DsBottomSheet
import app.ui.system.DsDropdownMenu
import app.ui.system.DsMenuItem
import app.ui.system.ErrorAlert
import app.ui.system.FeatureIntroRow
import app.ui.system.FeatureIntroSheet
import app.ui.system.SheetHeader
import app.ui.system.SheetTextAction
import app.ui.system.SystemAlertDialog
import org.junit.Test

/** C-29 sheets, menus, alerts (native components in the Retro M3 scheme, light and dark). */
@OptIn(ExperimentalMaterial3Api::class)
class SystemSnapshotTest(appearance: Appearance) : SnapshotTest(appearance) {
    @Test fun c29SheetHeaderClose() = snap("c29-native", "sheet-header-close") {
        SheetHeader("Postcard", close = HeaderAction(Tokens.Icons.globalClose, "Close", {}))
    }

    @Test fun c29SheetHeaderToolbar() = snap("c29-native", "sheet-header-toolbar") {
        SheetHeader("Add to Your Week", leading = SheetTextAction("Cancel", {}), trailing = SheetTextAction("Update", {}))
    }

    @Test fun c29PageSheet() = snapScreen("c29-native", "page-sheet") {
        ScreenHeader("Week 43")
        DsBottomSheet(onDismissRequest = {}) {
            SheetHeader("Settings", close = HeaderAction(Tokens.Icons.globalClose, "Close", {}))
            Column(Modifier.padding(vertical = Tokens.Sizes.globalScreenMargin)) {
                GroupedSection(listOf(GroupedRowSpec("Notifications", onClick = {}), GroupedRowSpec("Widgets", onClick = {})), header = "Account")
            }
        }
    }

    @Test fun c29FeatureIntro() = snapScreen("c29-native", "feature-intro-sheet") {
        ScreenHeader("Week 43")
        FeatureIntroSheet(
            title = "New! Recaps",
            rows = listOf(FeatureIntroRow(Tokens.Icons.globalRecap, "Turn a month of photos into a recap."), FeatureIntroRow(Tokens.Icons.globalShare, "Share it with your group.")),
            actionText = "Try it",
            onAction = {},
            onDismissRequest = {},
        )
    }

    @Test fun c29Menu() = snapScreen("c29-native", "menu-destructive") {
        ScreenHeader("Week 43")
        Box(Modifier.padding(start = Tokens.Sizes.globalScreenMargin, top = Tokens.Sizes.globalTitleTop)) {
            DsDropdownMenu(
                expanded = true,
                onDismissRequest = {},
                items = listOf(
                    DsMenuItem("Save", {}, Tokens.Icons.globalDownload),
                    DsMenuItem("Hide", {}, Tokens.Icons.globalHide),
                    DsMenuItem("Report", {}, Tokens.Icons.globalReport),
                    DsMenuItem("Delete from Photos", {}, Tokens.Icons.globalTrash, destructive = true),
                ),
            )
        }
    }

    @Test fun c29AlertDestructive() = snapScreen("c29-native", "alert-destructive") {
        SystemAlertDialog("Delete this photo?", "It will be removed from the group for everyone.", "Yes, delete", {}, "Cancel", {}, destructive = true)
    }

    @Test fun c29AlertBusy() = snapScreen("c29-native", "alert-busy") {
        SystemAlertDialog("Leave Sunday dinners?", "Your photos stay in the group.", "Leave", {}, "Cancel", {}, confirmBusy = true)
    }

    @Test fun c29ErrorAlert() = snapScreen("c29-native", "error-alert") {
        SearchField(TextFieldValue("+1 415"), {}, "Phone number", "Phone number")
        ErrorAlert("Check your number and try again.", "OK", {})
    }
}
