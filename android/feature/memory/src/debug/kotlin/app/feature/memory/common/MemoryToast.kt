package app.feature.memory.common

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import app.designsystem.generated.Tokens

/**
 * The Yope lime toast (DEBUG builds only). Its dwell time is BLOCKED
 * (`camera.sendto.duration.toastVisible`, `safety.block.duration.toast`), so release builds skip the
 * toast (same rule as `safety.block`) and debug builds keep it until it is tapped, for layout review.
 * Geometry: `camera.sendto.layout.toast` (the measured Yope toast); glyph `icon.global.checkmark`.
 */
@Composable
fun MemoryToast(message: String?, onDismiss: () -> Unit, modifier: Modifier = Modifier, success: Boolean = true) {
    if (message == null) return
    val toast = Tokens.Layouts.CameraSendtoLayoutToast
    Box(modifier.fillMaxWidth().padding(top = toast.top.dp, start = toast.marginHorizontal.dp, end = toast.marginHorizontal.dp)) {
        Row(
            Modifier
                .fillMaxWidth()
                .heightIn(min = toast.height.dp)
                .clip(RoundedCornerShape(toast.cornerRadius.dp))
                .background(Tokens.Colors.globalAccent)
                .clickable(onClick = onDismiss)
                .semantics { liveRegion = LiveRegionMode.Polite }
                .padding(start = toast.glyphInset.dp, end = toast.glyphInset.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            if (success) {
                Icon(Tokens.Icons.globalCheckmark, contentDescription = null, tint = Tokens.Colors.globalOnAccent, modifier = Modifier.size(toast.glyph.dp))
                Spacer(Modifier.size(toast.glyphToText.dp))
            }
            BasicText(message, style = roleStyle(Tokens.FontSizes.globalButton, Tokens.FontWeights.fontWeightGlobalButton).copy(color = Tokens.Colors.globalOnAccent))
        }
    }
}

/** Whether this build shows toasts (DEBUG: yes, for review; release: no while the dwell is BLOCKED). */
const val TOASTS_SHOWN: Boolean = true
