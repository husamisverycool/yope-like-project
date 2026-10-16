package app.ui.foundation

import androidx.compose.foundation.clickable
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.toggleable
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.semantics.Role
import app.ui.haptics.rememberHaptics

/*
 * Pressing, as every component in design/components.md does it ("Rules every component follows" →
 * Pressed): the visual press state is the platform default (`Modifier.clickable`'s indication — the
 * Material ripple from `AppTheme`; Retro's own press state was not recorded, RP §5.3), and on Android the
 * tap haptic `haptic.global.tap` (VIRTUAL_KEY) plays just before the action, as Retro's click wrapper does.
 * Touch targets: Compose expands the touch bounds of anything smaller than the view configuration's
 * minimum touch target, which `AppTheme` sets to `size.global.minTouchTarget.android` (48 dp), so drawn
 * sizes stay the measured ones.
 */

/** [clickable] that plays `haptic.global.tap` before [onClick]. [onClickLabel] is the TalkBack action label (copy). */
fun Modifier.tapClickable(
    enabled: Boolean = true,
    role: Role? = Role.Button,
    onClickLabel: String? = null,
    onClick: () -> Unit,
): Modifier = composed {
    val haptics = rememberHaptics()
    clickable(enabled = enabled, role = role, onClickLabel = onClickLabel) {
        haptics.tap()
        onClick()
    }
}

/** [selectable] for a tab / segment: plays `haptic.global.tap` when a different item is chosen. */
fun Modifier.tapSelectable(selected: Boolean, enabled: Boolean = true, role: Role? = Role.Tab, onClick: () -> Unit): Modifier = composed {
    val haptics = rememberHaptics()
    selectable(selected = selected, enabled = enabled, role = role) {
        if (!selected) haptics.tap()
        onClick()
    }
}

/** [toggleable] that plays `haptic.global.select` (the tick: "a toggled selection") on change. */
fun Modifier.tickToggleable(value: Boolean, enabled: Boolean = true, role: Role? = Role.Switch, onValueChange: (Boolean) -> Unit): Modifier = composed {
    val haptics = rememberHaptics()
    toggleable(value = value, enabled = enabled, role = role) {
        haptics.tick()
        onValueChange(it)
    }
}
