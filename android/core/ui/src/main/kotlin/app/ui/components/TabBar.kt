package app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import app.designsystem.generated.Tokens
import app.ui.foundation.PageRoles
import app.ui.foundation.tapSelectable

/**
 * One tab of [TabBar]: an outline glyph (`icon.global.home` / `.group` / `.rewind` / `.activity` / `.wall` …),
 * its TalkBack label (copy), and an unread marker. [unreadDescription] is the value TalkBack reads with the
 * marker ("new activity" — copy, never a count).
 */
@Immutable
data class TabBarItem(
    val icon: ImageVector,
    val contentDescription: String,
    val unread: Boolean = false,
    val unreadDescription: String? = null,
)

/**
 * C-04 Tab bar (replaces the Yope floating capsule bar).
 *
 * A standard bar across the full width (`size.global.tabBarInset` 0), height `size.global.tabBarHeight` above
 * the navigation bar inset, background = page (`color.global.background.android`; transparent [overMedia],
 * where the page's `layout.global.photoScrim` shows through), **no hairline, no labels**; up to five
 * icon-only items, evenly distributed (each takes an equal share, so centres sit at width ÷ 10, 3/10 …).
 * Glyph box `size.global.tabBarIcon`, centred; selected = glyph colour only (`color.global.textPrimary`,
 * over media `color.global.textOnMedia`), unselected `color.global.tabInactive` (over media
 * `color.global.tabInactiveOnMedia`); unread dot `size.global.tabBadgeDot` in `color.global.badge`, centred,
 * `size.global.tabBadgeOffset` below the glyph. Each item is a tab in a selectable group (selected state),
 * labelled from copy; choosing another tab plays `haptic.global.tap`. Tab-switch motion: not captured —
 * the platform's (no custom transition). Contrast of inactive glyphs is a recorded failure (CONTRAST failure 4).
 */
@Composable
fun TabBar(
    items: List<TabBarItem>,
    selectedIndex: Int?,
    onSelect: (Int) -> Unit,
    modifier: Modifier = Modifier,
    overMedia: Boolean = false,
) {
    val background = if (overMedia) Color.Transparent else PageRoles.page
    Box(modifier.fillMaxWidth().background(background).windowInsetsPadding(WindowInsets.navigationBars)) {
        Row(
            Modifier
                .fillMaxWidth()
                .padding(horizontal = Tokens.Sizes.globalTabBarInset)
                .height(Tokens.Sizes.globalTabBarHeight)
                .selectableGroup(),
        ) {
            items.forEachIndexed { index, item ->
                val selected = index == selectedIndex
                TabBarCell(item, selected, overMedia, Modifier.weight(1f)) { onSelect(index) }
            }
        }
    }
}

@Composable
private fun TabBarCell(item: TabBarItem, selected: Boolean, overMedia: Boolean, modifier: Modifier, onClick: () -> Unit) {
    val tint = when {
        selected && overMedia -> Tokens.Colors.globalTextOnMedia
        selected -> Tokens.Colors.globalTextPrimary
        overMedia -> Tokens.Colors.globalTabInactiveOnMedia
        else -> Tokens.Colors.globalTabInactive
    }
    Box(
        modifier
            .fillMaxHeight()
            .tapSelectable(selected = selected, onClick = onClick)
            .semantics {
                contentDescription = item.contentDescription
                if (item.unread && item.unreadDescription != null) stateDescription = item.unreadDescription
            },
        contentAlignment = Alignment.Center,
    ) {
        Icon(item.icon, contentDescription = null, tint = tint, modifier = Modifier.size(Tokens.Sizes.globalTabBarIcon))
        if (item.unread) {
            val glyphBottom = Tokens.Sizes.globalTabBarIcon / 2
            Box(
                Modifier
                    .offset(y = glyphBottom + Tokens.Sizes.globalTabBadgeOffset + Tokens.Sizes.globalTabBadgeDot / 2)
                    .size(Tokens.Sizes.globalTabBadgeDot)
                    .background(Tokens.Colors.globalBadge, CircleShape),
            )
        }
    }
}
