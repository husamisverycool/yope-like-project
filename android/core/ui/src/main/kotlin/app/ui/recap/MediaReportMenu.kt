package app.ui.recap

import androidx.compose.foundation.layout.Box
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.ui.components.CircleButtonStyle
import app.ui.components.CircleIconButton
import app.ui.system.DsDropdownMenu
import app.ui.system.DsMenuItem

/**
 * Surface: safety.report — the report entry on the media surfaces that show group-made or shared content (birthday.tribute,
 * year.story, collage.view, week.recap): a C-11 "•••" circle on media (`size.global.circleButton`,
 * `color.global.controlOnDeep`, `icon.global.more`, label `safety.report.a11y.more`) opening the native menu (C-29) with one
 * destructive item, "Report {noun}" ([itemText]) (design/surfaces/safety.report.md "Entries"; MERGE FV-4). Retro Rewind's
 * "•••" and native menu (references/auto/retro/press/tc-2025-12-rewind-panels.png, TC-RWP). In the recap preview it sits
 * `size.global.headerIconPitch` before the close circle ([RecapPreviewScreen]'s `beforeClose`).
 */
@Composable
fun MediaReportMenu(itemText: String, onReport: () -> Unit, modifier: Modifier = Modifier) {
    var open by remember { mutableStateOf(false) }
    Box(modifier) {
        CircleIconButton(
            Tokens.Icons.globalMore,
            stringResource(R.string.safety_report_a11y_more),
            { open = true },
            Modifier.testTag("safety.report.more"),
            style = CircleButtonStyle.OnMedia,
        )
        DsDropdownMenu(expanded = open, onDismissRequest = { open = false }, items = listOf(DsMenuItem(itemText, onReport, destructive = true)))
    }
}
