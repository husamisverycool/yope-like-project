package app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import app.designsystem.generated.Tokens

/** The four tabs, in `groups.list.layout.tabBar` order: camera · groups · walls · me. */
enum class AppTab { Camera, Groups, Walls, Me }

/** Labels of the icon-only tabs (copy `groups.list.tab.*.accessibilityLabel`). */
data class TabLabels(val camera: String, val groups: String, val walls: String, val me: String)

/**
 * The app's own floating tab bar (`groups.list.layout.tabBar`; not a NavigationBar).
 *
 * Tokens: capsule (`radius.global.capsule`) in `color.global.control`, height
 * `size.global.tabBarHeight`, width `size.global.tabBarWidth` at most (narrower screens keep
 * `size.global.tabBarInset` on each side; the caller places it that far from the screen edges and
 * the bottom); icon-only items, no labels, no badges; glyphs `icon.global.camera`,
 * `icon.global.chats` (groups), `icon.global.wall` (walls) at `size.global.tabBarIcon`, and the
 * person's own avatar at `size.global.tabBarAvatar` (me). Selected item: pill
 * `size.global.tabBarSelectedWidth` × `.tabBarSelectedHeight` in `color.global.controlRaised`, glyph
 * `color.global.textPrimary`; unselected glyph `color.global.textSecondary`. Each item is a tab
 * (`Role.Tab`, selected state) labelled from copy.
 */
@Composable
fun FloatingTabBar(
    selected: AppTab?,
    onSelect: (AppTab) -> Unit,
    labels: TabLabels,
    meAvatar: Any?,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier
            .widthIn(max = Tokens.Sizes.globalTabBarWidth)
            .fillMaxWidth()
            .height(Tokens.Sizes.globalTabBarHeight)
            .background(Tokens.Colors.globalControl, CircleShape)
            .selectableGroup(),
        horizontalArrangement = Arrangement.SpaceEvenly,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        AppTab.entries.forEach { tab ->
            val isSelected = tab == selected
            val label = when (tab) {
                AppTab.Camera -> labels.camera
                AppTab.Groups -> labels.groups
                AppTab.Walls -> labels.walls
                AppTab.Me -> labels.me
            }
            Box(
                Modifier
                    .size(Tokens.Sizes.globalTabBarSelectedWidth, Tokens.Sizes.globalTabBarSelectedHeight)
                    .background(if (isSelected) Tokens.Colors.globalControlRaised else Tokens.Colors.globalControl, CircleShape)
                    .selectable(selected = isSelected, role = Role.Tab) { onSelect(tab) }
                    .semantics { contentDescription = label },
                contentAlignment = Alignment.Center,
            ) {
                val tint = if (isSelected) Tokens.Colors.globalTextPrimary else Tokens.Colors.globalTextSecondary
                when (tab) {
                    AppTab.Camera -> Icon(Tokens.Icons.globalCamera, null, tint = tint, modifier = Modifier.size(Tokens.Sizes.globalTabBarIcon))
                    AppTab.Groups -> Icon(Tokens.Icons.globalChats, null, tint = tint, modifier = Modifier.size(Tokens.Sizes.globalTabBarIcon))
                    AppTab.Walls -> Icon(Tokens.Icons.globalWall, null, tint = tint, modifier = Modifier.size(Tokens.Sizes.globalTabBarIcon))
                    AppTab.Me -> Avatar(meAvatar, Tokens.Sizes.globalTabBarAvatar)
                }
            }
        }
    }
}

/** [FloatingTabBar] placed per its tokens: `size.global.tabBarInset` from the sides and the bottom safe area. */
@Composable
fun FloatingTabBarSlot(content: @Composable () -> Unit, modifier: Modifier = Modifier) {
    Box(modifier.fillMaxWidth().padding(horizontal = Tokens.Sizes.globalTabBarInset), contentAlignment = Alignment.Center) { content() }
}
