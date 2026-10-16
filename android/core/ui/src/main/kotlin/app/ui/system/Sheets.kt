package app.ui.system

import android.content.Context
import android.content.Intent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.SheetState
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import app.designsystem.generated.Tokens
import app.ui.components.CircleButtonStyle
import app.ui.components.CircleIconButton
import app.ui.components.HeaderAction
import app.ui.components.PrimaryButton
import app.ui.components.PrimaryButtonSize
import app.ui.foundation.PageRoles
import app.ui.foundation.tapClickable
import app.ui.text.TextRoles

/** Top corners of native sheets on Android (`radius.global.sheet` android: the ModalBottomSheet default, 28). */
private val sheetCorner get() = Tokens.Layouts.GlobalSheet.android.dp

/**
 * C-29 page sheet: the native `ModalBottomSheet` (PLATFORM motion — Retro's sheet measured as
 * `spring.global.sheetPresent`, critically damped, which the platform sheet's own settle matches; content
 * appears at rest). Top corners `radius.global.sheet`; content on the page colour
 * (`color.global.background.android`, sheets follow the appearance even over media); drag handle and scrim
 * are the platform's. Opens fully expanded (a page sheet).
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DsBottomSheet(
    onDismissRequest: () -> Unit,
    modifier: Modifier = Modifier,
    sheetState: SheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
    content: @Composable ColumnScope.() -> Unit,
) {
    ModalBottomSheet(
        onDismissRequest = onDismissRequest,
        modifier = modifier,
        sheetState = sheetState,
        shape = RoundedCornerShape(topStart = sheetCorner, topEnd = sheetCorner),
        containerColor = PageRoles.page,
        contentColor = Tokens.Colors.globalTextPrimary,
        content = content,
    )
}

/** A text action in a native sheet toolbar ("Cancel" / "Update"). */
@Immutable
data class SheetTextAction(val text: String, val onClick: () -> Unit, val enabled: Boolean = true)

/**
 * C-29 sheet header: the centred title in text role `sheetTitle` (17 semibold, `color.global.textPrimary`,
 * header trait), with either a trailing [close] circle (C-11 on-page: `color.global.control` — #262626 on dark,
 * #F1F1F1 on light sheets) or the toolbar pattern [leading] / [trailing] text actions ("Cancel / Title /
 * Update") in the system tint (`color.global.system.primary`, text role `textButton`, PLATFORM). Sides at
 * `size.global.screenMargin`; at least `size.global.minTouchTarget.android` high.
 */
@Composable
fun SheetHeader(
    title: String,
    modifier: Modifier = Modifier,
    close: HeaderAction? = null,
    leading: SheetTextAction? = null,
    trailing: SheetTextAction? = null,
) {
    Box(
        modifier.fillMaxWidth().heightIn(min = Tokens.Sizes.globalMinTouchTargetAndroid).padding(horizontal = Tokens.Sizes.globalScreenMargin),
        contentAlignment = Alignment.Center,
    ) {
        Text(title, style = TextRoles.sheetTitle, color = Tokens.Colors.globalTextPrimary, textAlign = TextAlign.Center, modifier = Modifier.semantics { heading() })
        if (leading != null) ToolbarText(leading, Modifier.align(Alignment.CenterStart))
        if (trailing != null) ToolbarText(trailing, Modifier.align(Alignment.CenterEnd))
        if (close != null) {
            CircleIconButton(close.icon, close.contentDescription, close.onClick, Modifier.align(Alignment.CenterEnd), style = CircleButtonStyle.OnPage)
        }
    }
}

@Composable
private fun ToolbarText(action: SheetTextAction, modifier: Modifier) {
    val tint = MaterialTheme.colorScheme.primary
    Text(
        action.text,
        style = TextRoles.textButton,
        color = if (action.enabled) tint else Tokens.Colors.globalTextTertiary,
        modifier = modifier.tapClickable(enabled = action.enabled, onClick = action.onClick),
    )
}

/** One line of a [FeatureIntroSheet]: an outline glyph and a sentence (copy). */
@Immutable
data class FeatureIntroRow(val icon: ImageVector, val text: String)

/**
 * C-29 feature-intro sheet (2023, TC-R3 phone 1): a light rounded sheet floating `size.global.featureSheetInset`
 * in from the screen edges over the dimmed screen; an optional [icon] tile (the owner's asset, ≈64 — not a
 * token), the title in text role `sheetTitle`, [rows] of text role `body` in secondary text each with a leading
 * outline glyph (`size.global.icon` box; Retro's 20 pt glyph has no token — Gap), and a full-width C-05
 * [PrimaryButton]. Its inner spacing is not measured (Gap): items sit `size.global.screenMargin` apart and from
 * the sheet edges.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FeatureIntroSheet(
    title: String,
    rows: List<FeatureIntroRow>,
    actionText: String,
    onAction: () -> Unit,
    onDismissRequest: () -> Unit,
    modifier: Modifier = Modifier,
    icon: (@Composable () -> Unit)? = null,
) {
    val inset = Tokens.Sizes.globalFeatureSheetInset
    val margin = Tokens.Sizes.globalScreenMargin
    ModalBottomSheet(
        onDismissRequest = onDismissRequest,
        modifier = modifier.padding(start = inset, end = inset, bottom = inset),
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        shape = RoundedCornerShape(sheetCorner),
        containerColor = PageRoles.page,
        contentColor = Tokens.Colors.globalTextPrimary,
        dragHandle = null,
    ) {
        Column(Modifier.fillMaxWidth().padding(margin), verticalArrangement = Arrangement.spacedBy(margin), horizontalAlignment = Alignment.CenterHorizontally) {
            icon?.invoke()
            Text(title, style = TextRoles.sheetTitle, color = Tokens.Colors.globalTextPrimary, textAlign = TextAlign.Center, modifier = Modifier.semantics { heading() })
            rows.forEach { row ->
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalPillIconGap), verticalAlignment = Alignment.CenterVertically) {
                    Icon(row.icon, contentDescription = null, tint = PageRoles.secondaryText(), modifier = Modifier.size(Tokens.Sizes.globalIcon))
                    Text(row.text, style = TextRoles.body, color = PageRoles.secondaryText())
                }
            }
            PrimaryButton(actionText, onAction, size = PrimaryButtonSize.Sheet)
        }
    }
}

/**
 * C-29 share sheet: the platform chooser (`Intent.createChooser(ACTION_SEND text/plain)`, the Android
 * Sharesheet — PLATFORM). [title] is the chooser's title from copy, if any.
 */
object ShareSheet {
    fun share(context: Context, text: String, title: String? = null) {
        val send = Intent(Intent.ACTION_SEND).setType(MIME_TEXT).putExtra(Intent.EXTRA_TEXT, text)
        val chooser = Intent.createChooser(send, title).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        runCatching { context.startActivity(chooser) }
    }

    private const val MIME_TEXT = "text/plain"
}
