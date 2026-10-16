package app.ui.components

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.paddingFrom
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.LastBaseline
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import app.designsystem.generated.Tokens
import app.ui.foundation.PageRoles
import app.ui.text.CapTop
import app.ui.text.TextRoles
import app.ui.text.capTopAt

/**
 * The single action of an [EmptyState]: with [icon] it is the C-07 outline CTA (`icon.global.add`,
 * `icon.global.camera`, `icon.global.link` …); without, a C-06 outline capsule ("Try again").
 */
@Immutable
data class EmptyStateAction(val text: String, val onClick: () -> Unit, val icon: ImageVector? = null)

/**
 * C-27 Empty state — also the error, offline and permission-denied states (same block, their own copy and
 * action: `retro.voice.empty-state` / `.error` / `.permission`).
 *
 * Centred: [icon] (outline, `size.global.emptyIcon`, `color.global.textPrimary`, decorative) →
 * `size.global.emptyIconToTitle` to the title's cap top → [title] (text role `emptyTitle`, 20 semibold,
 * `color.global.textPrimary`, Sentence case, header trait) → optional [detail] (text role `emptyDetail`,
 * secondary text, ≤ 2 lines, directly under the title — its gap is not measured) → `size.global.emptyTitleToAction`
 * from the last baseline to the capsule top → [action]. Side margins `size.global.screenMargin`. Place it with
 * [EmptyStateFill] (centred in the free space between the content above and the tab bar, H43). [alignment] Start draws the
 * same block left-aligned inside a section (the permission block of a list section, e.g. the invite sheet's Contacts).
 */
@Composable
fun EmptyState(
    title: String?,
    detail: String?,
    modifier: Modifier = Modifier,
    action: EmptyStateAction? = null,
    icon: ImageVector? = null,
    alignment: Alignment.Horizontal = Alignment.CenterHorizontally,
) {
    val titleStyle = TextRoles.emptyTitle
    val textAlign = if (alignment == Alignment.Start) TextAlign.Start else TextAlign.Center
    Column(modifier.padding(horizontal = Tokens.Sizes.globalScreenMargin), horizontalAlignment = alignment) {
        if (icon != null) Icon(icon, contentDescription = null, tint = Tokens.Colors.globalTextPrimary, modifier = Modifier.size(Tokens.Sizes.globalEmptyIcon))
        val afterLast = if (action != null) Tokens.Sizes.globalEmptyTitleToAction else Dp.Unspecified
        if (title != null) {
            Text(
                title,
                style = titleStyle,
                color = Tokens.Colors.globalTextPrimary,
                textAlign = textAlign,
                modifier = Modifier
                    .capTopAt(if (icon != null) Tokens.Sizes.globalEmptyIconToTitle else Dp.Unspecified, CapTop.height(titleStyle))
                    .then(if (detail == null && afterLast != Dp.Unspecified) Modifier.paddingFrom(LastBaseline, after = afterLast) else Modifier)
                    .semantics { heading() },
            )
        }
        if (detail != null) {
            Text(
                detail,
                style = TextRoles.emptyDetail,
                color = PageRoles.secondaryText(),
                textAlign = textAlign,
                maxLines = DETAIL_MAX_LINES,
                modifier = if (afterLast != Dp.Unspecified) Modifier.paddingFrom(LastBaseline, after = afterLast) else Modifier,
            )
        }
        if (action != null) {
            if (action.icon != null) OutlineCta(action.text, action.onClick, icon = action.icon) else Capsule(action.text, action.onClick, style = CapsuleStyle.Outline)
        }
    }
}

/** C-27: the explanation runs at most two lines (TC-2B). */
private const val DETAIL_MAX_LINES = 2

/** Centres an [EmptyState] (or any block) in the free space it is given — C-27 placement. */
@Composable
fun EmptyStateFill(modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    Box(modifier.fillMaxSize(), contentAlignment = Alignment.Center) { content() }
}
