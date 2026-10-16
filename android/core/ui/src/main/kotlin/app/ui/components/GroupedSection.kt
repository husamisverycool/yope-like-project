package app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.paddingFrom
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.layout.LastBaseline
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Dp
import app.designsystem.generated.Tokens
import app.ui.foundation.PageRoles
import app.ui.foundation.tapClickable
import app.ui.foundation.tickToggleable
import app.ui.text.TextRoles

/** Where a row sits in its group: which corners round (`radius.global.groupedRow`). */
enum class GroupedPosition {
    Single, First, Middle, Last;

    /** First row: top corners; last: bottom corners; a single row: all four; middle rows square. */
    fun shape(radius: Dp = Tokens.Radii.globalGroupedRow): Shape = when (this) {
        Single -> RoundedCornerShape(radius)
        First -> RoundedCornerShape(topStart = radius, topEnd = radius)
        Middle -> RectangleShape
        Last -> RoundedCornerShape(bottomStart = radius, bottomEnd = radius)
    }

    /** Whether a hairline follows the row (between rows only). */
    val dividerBelow: Boolean get() = this == First || this == Middle

    companion object {
        fun of(index: Int, count: Int): GroupedPosition = when {
            count <= 1 -> Single
            index == 0 -> First
            index == count - 1 -> Last
            else -> Middle
        }
    }
}

/** What a grouped row shows at its trailing end. */
sealed interface GroupedTrailing {
    /** `icon.global.chevron` in secondary text — the row opens something. */
    data object Chevron : GroupedTrailing

    data object None : GroupedTrailing

    /** A value in secondary text (text role `body`). */
    data class Value(val text: String) : GroupedTrailing

    /** A value in secondary text followed by the chevron: the row opens something and shows its current value ("Full Name  Ana ›"). */
    data class ValueChevron(val text: String) : GroupedTrailing

    /** A native switch (PLATFORM, tint `color.global.system.primary`); the whole row toggles. */
    data class Toggle(val checked: Boolean, val onCheckedChange: (Boolean) -> Unit) : GroupedTrailing
}

/** One row of a [GroupedSection]. [onClick] null and no toggle = not interactive. Labels are copy (Title Case, `retro.voice.settings`). */
@Immutable
data class GroupedRowSpec(
    val title: String,
    val subtitle: String? = null,
    val trailing: GroupedTrailing = GroupedTrailing.Chevron,
    val destructive: Boolean = false,
    val enabled: Boolean = true,
    val leading: (@Composable () -> Unit)? = null,
    val onClick: (() -> Unit)? = null,
)

/**
 * C-14 Grouped section (settings): an optional section header, then [rows] in one rounded group inset
 * `size.global.screenMargin`; the group fill is `color.global.surfaceSecondary.android` (iOS
 * `color.global.control`), corners `radius.global.groupedRow` by [GroupedPosition], a hairline
 * (`color.global.separator`, 1 device px) between rows. Row metrics, header size and spacing are not
 * measured (components.md C-14 Gap, VID-SET only): see [GroupedRow] and [GroupedSectionHeader].
 */
@Composable
fun GroupedSection(
    rows: List<GroupedRowSpec>,
    modifier: Modifier = Modifier,
    header: String? = null,
    minRowHeight: Dp = Tokens.Sizes.globalMinTouchTargetAndroid,
) {
    Column(modifier.fillMaxWidth()) {
        if (header != null) GroupedSectionHeader(header)
        Column(Modifier.padding(horizontal = Tokens.Sizes.globalScreenMargin)) {
            rows.forEachIndexed { i, row -> GroupedRow(row, GroupedPosition.of(i, rows.size), minHeight = minRowHeight) }
        }
    }
}

/**
 * C-14 section header: a single Title Case word ("Account") in text role `meta`, secondary text, header
 * trait; aligned with the rows' text (group inset + row padding); the rows start
 * `size.global.sectionHeaderToContent` below its baseline (the C-20 header → content distance; C-14's own is
 * not measured — Gap).
 */
@Composable
fun GroupedSectionHeader(text: String, modifier: Modifier = Modifier) {
    Text(
        text,
        style = TextRoles.meta,
        color = PageRoles.secondaryText(),
        modifier = modifier
            .padding(start = Tokens.Sizes.globalScreenMargin + rowPadding)
            .paddingFrom(LastBaseline, after = Tokens.Sizes.globalSectionHeaderToContent)
            .semantics { heading() },
    )
}

/**
 * Row padding: APK grouped list `pik` padding 16 dp (RV §4 #17) — the same Retro constant
 * `size.global.screenMargin` records (APK horizontal padding 16 dp, the most common); no own token.
 */
private val rowPadding: Dp get() = Tokens.Sizes.globalScreenMargin

/**
 * C-14 row, usable on its own in a lazy list with its [position]. Title text role `body` in
 * `color.global.textPrimary` (C-10 destructive: `color.global.destructive`), subtitle text role `meta` in secondary
 * text; trailing per [GroupedTrailing]; padding [rowPadding] on every side, at least
 * [minHeight] high (default `size.global.minTouchTarget.android`; C-14's row height is not measured — a surface passes its
 * own measured value, e.g. `settings.root.size.rowHeight`, content centred). A [GroupedRowSpec.leading] element (an avatar) sits before the
 * text, `size.global.cardNameGap` (avatar → name, C-18) apart. Rows are buttons (or switches); a toggle row
 * plays `haptic.global.select`, a button row `haptic.global.tap`.
 */
@Composable
fun GroupedRow(
    spec: GroupedRowSpec,
    position: GroupedPosition,
    modifier: Modifier = Modifier,
    minHeight: Dp = Tokens.Sizes.globalMinTouchTargetAndroid,
) {
    val shape = position.shape()
    val trailing = spec.trailing
    val interaction = when {
        trailing is GroupedTrailing.Toggle -> Modifier.tickToggleable(trailing.checked, spec.enabled, Role.Switch, trailing.onCheckedChange)
        spec.onClick != null -> Modifier.tapClickable(enabled = spec.enabled, onClick = spec.onClick)
        else -> Modifier
    }
    val titleColor = when {
        !spec.enabled -> Tokens.Colors.globalTextTertiary
        spec.destructive -> Tokens.Colors.globalDestructive
        else -> Tokens.Colors.globalTextPrimary
    }
    val secondary = PageRoles.secondaryText()
    Column(
        modifier
            .fillMaxWidth()
            .clip(shape)
            .background(PageRoles.secondarySurface, shape)
            .then(interaction)
            .semantics(mergeDescendants = true) {},
    ) {
        Row(
            Modifier.fillMaxWidth().heightIn(min = maxOf(minHeight, Tokens.Sizes.globalMinTouchTargetAndroid)).padding(rowPadding),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalCardNameGap),
        ) {
            spec.leading?.invoke()
            Column(Modifier.weight(1f)) {
                Text(spec.title, style = TextRoles.body, color = titleColor)
                if (spec.subtitle != null) Text(spec.subtitle, style = TextRoles.meta, color = secondary)
            }
            when (trailing) {
                GroupedTrailing.Chevron -> Icon(Tokens.Icons.globalChevron, contentDescription = null, tint = secondary, modifier = Modifier.size(Tokens.Sizes.globalIcon))
                is GroupedTrailing.Value -> Text(trailing.text, style = TextRoles.body, color = secondary)
                is GroupedTrailing.ValueChevron -> Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(trailing.text, style = TextRoles.body, color = secondary)
                    Icon(Tokens.Icons.globalChevron, contentDescription = null, tint = secondary, modifier = Modifier.size(Tokens.Sizes.globalIcon))
                }
                is GroupedTrailing.Toggle -> Switch(checked = trailing.checked, onCheckedChange = null, enabled = spec.enabled)
                GroupedTrailing.None -> Unit
            }
        }
        if (position.dividerBelow) Hairline()
    }
}
