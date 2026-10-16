package app.ui.snapshots

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.TextFieldValue
import app.designsystem.generated.Tokens
import app.ui.components.Avatar
import app.ui.components.CheckRow
import app.ui.components.FormTextField
import app.ui.components.GroupedRow
import app.ui.components.GroupedRowSpec
import app.ui.components.GroupedPosition
import app.ui.components.GroupedSection
import app.ui.components.GroupedTrailing
import app.ui.components.HeaderAction
import app.ui.components.ReplyBar
import app.ui.components.SearchField
import org.junit.Test

/** C-12 text / search field, C-13 reply bar, C-14 grouped sections, the selection row. */
class FieldSnapshotTest(appearance: Appearance) : SnapshotTest(appearance) {
    @Composable
    private fun Margins(content: @Composable () -> Unit) = Box(Modifier.padding(horizontal = Tokens.Sizes.globalScreenMargin)) { content() }

    @Test fun c12Placeholder() = snap("c12-text-field", "placeholder") { Margins { FormTextField(TextFieldValue(""), {}, "Your name", "Name") } }

    @Test fun c12Filled() = snap("c12-text-field", "filled") { Margins { FormTextField(TextFieldValue("Isabel Reyes"), {}, "Your name", "Name") } }

    @Test fun c12Error() = snap("c12-text-field", "error") { Margins { FormTextField(TextFieldValue("Isabel Reyes Montenegro de la Cruz"), {}, "Your name", "Name", error = "Name too long") } }

    @Test fun c12Disabled() = snap("c12-text-field", "disabled") { Margins { FormTextField(TextFieldValue("+1 415 555 0100"), {}, "Phone number", "Phone number", enabled = false) } }

    @Test fun c12SearchEmpty() = snap("c12-text-field", "search-empty") { Margins { SearchField(TextFieldValue(""), {}, "Search", "Search friends") } }

    @Test fun c12SearchFilled() = snap("c12-text-field", "search-filled") { Margins { SearchField(TextFieldValue("daniel"), {}, "Search", "Search friends") } }

    @Test fun c12FontScale200() = snap("c12-text-field", "font-scale-200", fontScale = 2f) { Margins { SearchField(TextFieldValue(""), {}, "Search", "Search friends") } }

    @Test fun c13OnMediaEmpty() = snap("c13-reply-bar", "on-media-empty", surface = Surface.Media) {
        ReplyBar(TextFieldValue(""), {}, "Add a comment…", "Comment", avatar(0), trailing = HeaderAction(Tokens.Icons.globalMore, "More", {}))
    }

    @Test fun c13OnMediaTyped() = snap("c13-reply-bar", "on-media-typed", surface = Surface.Media) {
        ReplyBar(TextFieldValue("so good"), {}, "Add a comment…", "Comment", avatar(0), trailing = HeaderAction(Tokens.Icons.globalSend, "Send", {}))
    }

    @Test fun c13OnPage() = snap("c13-reply-bar", "on-page") {
        ReplyBar(TextFieldValue(""), {}, "Message", "Message", avatar(1), onMedia = false, trailing = HeaderAction(Tokens.Icons.globalSend, "Send", {}))
    }

    private val rows = listOf(
        GroupedRowSpec("Notifications", subtitle = "Posts, comments, birthdays", onClick = {}),
        GroupedRowSpec("Widgets", onClick = {}),
        GroupedRowSpec("Daily reminder", trailing = GroupedTrailing.Toggle(true) {}),
        GroupedRowSpec("Time Zone", trailing = GroupedTrailing.Value("Mexico City"), onClick = {}),
    )

    @Test fun c14Section() = snap("c14-grouped-section", "header-rows") { GroupedSection(rows, header = "Account") }

    @Test fun c14SingleDestructive() = snap("c14-grouped-section", "single-destructive") {
        GroupedSection(listOf(GroupedRowSpec("Delete Account", trailing = GroupedTrailing.None, destructive = true, onClick = {})))
    }

    @Test fun c14ToggleOffDisabled() = snap("c14-grouped-section", "toggle-off-disabled") {
        GroupedSection(
            listOf(
                GroupedRowSpec("Daily reminder", trailing = GroupedTrailing.Toggle(false) {}),
                GroupedRowSpec("Quiet hours", subtitle = "Turn on notifications first", trailing = GroupedTrailing.Toggle(false) {}, enabled = false),
            ),
        )
    }

    @Test fun c14LeadingAvatar() = snap("c14-grouped-section", "leading-avatar") {
        Box(Modifier.padding(horizontal = Tokens.Sizes.globalScreenMargin)) {
            GroupedRow(GroupedRowSpec("Isabel Reyes", subtitle = "@isareyes", leading = { Avatar(avatar(3), Tokens.Sizes.globalAvatarPicker) }, onClick = {}), GroupedPosition.Single)
        }
    }

    @Test fun c14FontScale200() = snap("c14-grouped-section", "font-scale-200", fontScale = 2f) { GroupedSection(rows.take(2), header = "Account") }

    @Test fun selectionRow() = snap("selection", "check-row") {
        Margins {
            Stack {
                CheckRow("Tell my groups on my birthday", false, {}, "Tell my groups on my birthday", detail = "We'll save your birthday for this")
                CheckRow("Tell my groups on my birthday", true, {}, "Tell my groups on my birthday", detail = "We'll save your birthday for this")
            }
        }
    }
}
