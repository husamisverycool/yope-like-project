package app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import app.designsystem.generated.Tokens
import app.ui.text.TextRoles

/**
 * Yope's lime confirmation toast (reference T: "posted in the wall"), as specified by
 * `safety.block.layout.toast`: fill `color.global.accent`, `icon.global.checkmark` + label in
 * `color.global.onAccent` (text role `button`), shape `radius.global.capsule`, placed at the top under
 * the status bar, full width minus `size.global.screenMargin` (the caller applies the margin).
 * Height, glyph size, glyph inset and glyph-to-text gap are the measurements of the same Yope toast
 * in `camera.sendto.layout.toast` (49 / 17 / 19.5 / 11).
 *
 * **Dwell time is BLOCKED** (`safety.block.duration.toast`): [ToastDwell.millis] is null, so screens
 * never show a toast in any build (auth.phone, auth.code, groups.invite, safety.block Gaps). The
 * component exists so its layout can be reviewed in snapshot tests.
 */
@Composable
fun LimeToast(text: String, modifier: Modifier = Modifier) {
    val layout = Tokens.Layouts.CameraSendtoLayoutToast
    Row(
        modifier
            .fillMaxWidth()
            .heightIn(min = layout.height.dp)
            .background(Tokens.Colors.globalAccent, CircleShape)
            .padding(horizontal = layout.glyphInset.dp)
            .semantics { liveRegion = LiveRegionMode.Polite },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(layout.glyphToText.dp),
    ) {
        Icon(Tokens.Icons.globalCheckmark, contentDescription = null, tint = Tokens.Colors.globalOnAccent, modifier = Modifier.size(layout.glyph.dp))
        Text(text, style = TextRoles.button, color = Tokens.Colors.globalOnAccent)
    }
}

/** The toast's dwell time: `safety.block.duration.toast` is BLOCKED, so there is none. */
object ToastDwell {
    /** Null until the owner capture closes the gap; while null no toast is shown. */
    val millis: Long? = null
}
