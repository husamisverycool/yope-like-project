package app.ui.system

import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.MenuDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import app.ui.haptics.rememberHaptics

/**
 * One item of a native menu (C-29 context menu / action sheet): Sentence-case label from copy
 * (`retro.voice.menu-labels`), an optional outline glyph (`icon.global.*`), and [destructive] for delete /
 * remove / report / leave — drawn in the error role (`color.global.system.error`, Retro red #EA3337).
 */
@Immutable
data class DsMenuItem(
    val text: String,
    val onClick: () -> Unit,
    val icon: ImageVector? = null,
    val destructive: Boolean = false,
    val enabled: Boolean = true,
)

/**
 * C-29 menu: the native M3 `DropdownMenu` (PLATFORM look and motion — `easing.global.native.menu`) anchored to
 * its parent, colours from the theme's `color.global.system.*` scheme; destructive items in
 * `color.global.system.error`. Items play `haptic.global.tap` when chosen; the menu closes on choice.
 */
@Composable
fun DsDropdownMenu(expanded: Boolean, onDismissRequest: () -> Unit, items: List<DsMenuItem>, modifier: Modifier = Modifier) {
    val haptics = rememberHaptics()
    DropdownMenu(expanded = expanded, onDismissRequest = onDismissRequest, modifier = modifier) {
        items.forEach { item ->
            val color = if (item.destructive) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurface
            DropdownMenuItem(
                text = { Text(item.text) },
                onClick = {
                    haptics.tap()
                    onDismissRequest()
                    item.onClick()
                },
                enabled = item.enabled,
                trailingIcon = item.icon?.let { { Icon(it, contentDescription = null) } },
                colors = MenuDefaults.itemColors(textColor = color, trailingIconColor = color),
            )
        }
    }
}
