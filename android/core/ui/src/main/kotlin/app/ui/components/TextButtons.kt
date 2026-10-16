package app.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.style.TextAlign
import app.designsystem.generated.Tokens
import app.ui.foundation.PageRoles
import app.ui.foundation.tapClickable
import app.ui.text.TextRoles

/**
 * C-08 Text button in a header ("Invite", "Keys"): text role `textButton` (17 regular) in
 * `color.global.textPrimary`. Native sheet toolbars draw theirs in the system tint (see [SheetHeader]).
 * Touch bounds expand to `size.global.minTouchTarget.android`. Pressed: platform default + `haptic.global.tap`.
 */
@Composable
fun HeaderTextButton(text: String, onClick: () -> Unit, modifier: Modifier = Modifier, enabled: Boolean = true) {
    Text(
        text,
        style = TextRoles.textButton,
        color = if (enabled) Tokens.Colors.globalTextPrimary else Tokens.Colors.globalTextTertiary,
        modifier = modifier.tapClickable(enabled = enabled, onClick = onClick),
    )
}

/**
 * C-08 Secondary link under a capsule ("already have an account?", "send a new code"): text role `listTitle`
 * (15 semibold) in secondary text (`color.global.textSecondary.android` on the page; `color.global.textSecondary`
 * on media / the dark landing when [onMedia]), centred. Disabled is not captured (Gap): `color.global.textTertiary`
 * (the tertiary / disabled text role).
 */
@Composable
fun TextLink(text: String, onClick: () -> Unit, modifier: Modifier = Modifier, enabled: Boolean = true, onMedia: Boolean = false) {
    Text(
        text,
        style = TextRoles.listTitle,
        color = if (enabled) PageRoles.secondaryText(onMedia) else Tokens.Colors.globalTextTertiary,
        textAlign = TextAlign.Center,
        modifier = modifier.tapClickable(enabled = enabled, onClick = onClick),
    )
}

/**
 * C-10 Destructive action drawn by the app: red text (`color.global.destructive`), text role `body`, with an
 * optional glyph ([icon], e.g. `icon.global.trash`) in the same red — Retro never fills a button red. The
 * label states the action (copy, "Delete account"). Native alerts and menus draw their own destructive role
 * ([SystemAlertDialog] `destructive`, [DsMenuItem] `destructive`). Contrast of red text on the page 4.18:1 is a
 * recorded failure (CONTRAST failure 5).
 */
@Composable
fun DestructiveTextButton(text: String, onClick: () -> Unit, modifier: Modifier = Modifier, icon: ImageVector? = null, enabled: Boolean = true) {
    val color = if (enabled) Tokens.Colors.globalDestructive else Tokens.Colors.globalTextTertiary
    Row(
        modifier.tapClickable(enabled = enabled, onClick = onClick),
        horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalPillIconGap),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (icon != null) Icon(icon, contentDescription = null, tint = color, modifier = Modifier.size(Tokens.Sizes.globalIcon))
        Text(text, style = TextRoles.body, color = color)
    }
}
