package app.ui.components

import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import app.ui.haptics.rememberHaptics

/**
 * C-30 Segmented control: the native M3 `SingleChoiceSegmentedButtonRow` (Retro uses the system control on
 * "Create Recap"; PLATFORM look and motion). The selected segment's container is the theme's
 * `color.global.system.secondaryContainer` (#F7F7F7 / #262626, Retro's scheme), its label and check
 * `onSecondaryContainer`; outlines `color.global.system.outline`; labels M3 `labelLarge`. Choosing a different
 * segment plays `haptic.global.select`. Each segment is a radio button for TalkBack (platform semantics).
 * Side margins come from the caller.
 */
@Composable
fun SegmentedControl(
    options: List<String>,
    selectedIndex: Int,
    onSelect: (Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    val haptics = rememberHaptics()
    SingleChoiceSegmentedButtonRow(modifier.fillMaxWidth()) {
        options.forEachIndexed { index, label ->
            SegmentedButton(
                selected = index == selectedIndex,
                onClick = {
                    if (index != selectedIndex) {
                        haptics.tick()
                        onSelect(index)
                    }
                },
                shape = SegmentedButtonDefaults.itemShape(index, options.size),
                label = { Text(label, maxLines = 1) },
            )
        }
    }
}
