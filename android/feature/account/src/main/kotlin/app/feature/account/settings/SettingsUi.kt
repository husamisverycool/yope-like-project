package app.feature.account.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.ui.components.ActivityIndicator
import app.ui.components.GroupedPosition
import app.ui.components.GroupedRow
import app.ui.components.GroupedRowSpec
import app.ui.components.GroupedSectionHeader
import app.ui.foundation.PageRoles
import app.ui.text.CapTop
import app.ui.text.TextRoles
import app.ui.text.capTopAt

/*
 * The settings list (`settings.root.layout.list`): C-14 sections on the page — a section header (text role `meta`, secondary,
 * aligned with the rows' text), the rows in one rounded group inset `size.global.screenMargin` (rows at least
 * `settings.root.size.rowHeight`, TC-J5), footers under a group (text role `meta`, secondary), and `size.global.sectionGap`
 * between a group's bottom and the next section header. Used by groups.settings and settings.*.
 */

/** Row padding of C-14 (APK `pik` 16 dp = `size.global.screenMargin`): headers and footers align with the rows' text. */
private val rowTextInset get() = Tokens.Sizes.globalScreenMargin + Tokens.Sizes.globalScreenMargin

/** A section header; [first] = the first section of the page (no section gap above it). */
@Composable
fun SettingsHeader(text: String, first: Boolean = false) {
    GroupedSectionHeader(text, if (first) Modifier else Modifier.capTopAt(Tokens.Sizes.globalSectionGap, CapTop.height(TextRoles.meta)))
}

/** The gap before a group that has no header (the last "Sign Out" / "Report · Leave" group). */
@Composable
fun SettingsGap() {
    Box(Modifier.padding(top = Tokens.Sizes.globalSectionGap))
}

/** One rounded group of C-14 rows, at least `settings.root.size.rowHeight` each. */
@Composable
fun SettingsGroup(rows: List<GroupedRowSpec>, modifier: Modifier = Modifier) {
    Column(modifier.fillMaxWidth().padding(horizontal = Tokens.Sizes.globalScreenMargin)) {
        rows.forEachIndexed { i, row -> GroupedRow(row, GroupedPosition.of(i, rows.size), minHeight = Tokens.Sizes.settingsRootSizeRowHeight) }
    }
}

/** A footer under a group: text role `meta`, secondary text, its cap top `size.global.sectionHeaderToContent` under the group; [error] = `color.global.destructive`. */
@Composable
fun SettingsFooter(text: String, error: Boolean = false) {
    Text(
        text,
        style = TextRoles.meta,
        color = if (error) Tokens.Colors.globalDestructive else PageRoles.secondaryText(),
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = rowTextInset, end = rowTextInset)
            .capTopAt(Tokens.Sizes.globalSectionHeaderToContent, CapTop.height(TextRoles.meta)),
    )
}

/** Loading (C-28): one C-14 row holding the platform activity indicator. */
@Composable
fun LoadingGroup() {
    val shape = GroupedPosition.Single.shape()
    Box(
        Modifier
            .padding(horizontal = Tokens.Sizes.globalScreenMargin)
            .fillMaxWidth()
            .heightIn(min = Tokens.Sizes.settingsRootSizeRowHeight)
            .clip(shape)
            .background(PageRoles.secondarySurface, shape),
        contentAlignment = Alignment.Center,
    ) { ActivityIndicator(stringResource(R.string.global_a11y_loading)) }
}

/** A row spec shortcut for a navigation row (chevron). */
fun navRow(title: String, subtitle: String? = null, enabled: Boolean = true, onClick: () -> Unit) =
    GroupedRowSpec(title = title, subtitle = subtitle, enabled = enabled, onClick = onClick)
