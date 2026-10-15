// Surface: tagging — "i'm in this" self-tag, placed in photo.viewer's top-right chip slot (S-19).
// The memory pass owns the surface's content, states and copy (design/surfaces/tagging.md); it exposes
// no reusable composable, so the toggle is built here from that spec with its `tagging.*` copy.
// References: references/auto/yope/frames/a-chuongxetank-7694968408424582452-t7.73-posted-toast-contacts-card.png (white pill),
// references/auto/yope/frames/a-jacob-7691153057177931039-t3.73-camera-hold-to-record.png (coach tooltip).
package app.feature.social.viewer

import android.content.Context
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.selection.toggleable
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.core.content.edit
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.social.common.Glyph
import app.feature.social.common.InkGlyph
import app.feature.social.common.Line
import app.feature.social.common.Type
import app.feature.social.common.stringRes

/**
 * The toggle: Yope's white secondary pill as a capsule (`color.global.surfaceLight`,
 * `radius.global.capsule`), state glyph (`size.global.checkCircle`: `icon.global.uncheck` in
 * `color.global.onSurfaceLight` / `icon.global.check` in `color.global.selection`), gap
 * `size.global.headerGap`, label `tagging.toggle` (text role `button`, `color.global.onSurfaceLight`).
 * Its inner padding is not measured: `size.global.headerGap` (approximation). TalkBack reads it as a
 * switch with the same label. Taps are ignored while a call is in flight.
 */
@Composable
fun TagToggle(on: Boolean, pending: Boolean, onToggle: () -> Unit, modifier: Modifier = Modifier) {
    val label = stringRes(R.string.tagging_toggle)
    Row(
        modifier
            .clip(CircleShape)
            .background(Tokens.Colors.globalSurfaceLight)
            .toggleable(value = on, enabled = !pending, role = Role.Switch, onValueChange = { onToggle() })
            .semantics { contentDescription = label }
            .padding(Tokens.Sizes.globalHeaderGap),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalHeaderGap),
    ) {
        if (on) Glyph(Tokens.Icons.globalCheck, Tokens.Colors.globalSelection, size = Tokens.Sizes.globalCheckCircle)
        else Glyph(Tokens.Icons.globalUncheck, Tokens.Colors.globalOnSurfaceLight, size = Tokens.Sizes.globalCheckCircle)
        Line(label, Type.button(), Tokens.Colors.globalOnSurfaceLight, Modifier.clearAndSetSemantics { })
    }
}

/**
 * The first-use coach under the toggle: the foundations coach tooltip as measured on Yope's camera
 * (`camera.capture.layout.coach`, `.fontSize.coach`, `.fontWeight.coach`): lime body, text
 * `tagging.coach`, ✕; its pointer points up at the toggle (the toggle sits at the photo's top, so the
 * tooltip goes below it). ✕ dismisses it for good.
 */
@Composable
fun TagCoach(targetWidth: androidx.compose.ui.unit.Dp, onDismiss: () -> Unit, modifier: Modifier = Modifier) {
    val coach = Tokens.Layouts.CameraCaptureLayoutCoach
    val close = stringRes(R.string.photo_viewer_a11y_close)
    Column(modifier, horizontalAlignment = Alignment.End) {
        Spacer(Modifier.height(coach.pointerToTarget.dp))
        // Apex under the toggle's centre ([targetWidth] = the toggle's width; tooltip right-aligned with it).
        val pointerEnd = (targetWidth / 2 - coach.pointerWidth.dp / 2).coerceAtLeast(0.dp)
        Canvas(Modifier.padding(end = pointerEnd).size(width = coach.pointerWidth.dp, height = coach.pointerHeight.dp)) {
            val path = Path().apply {
                moveTo(size.width / 2, 0f)
                lineTo(size.width, size.height)
                lineTo(0f, size.height)
                close()
            }
            drawPath(path, Tokens.Colors.globalAccent)
        }
        Row(
            Modifier
                .heightIn(min = coach.height.dp)
                .clip(RoundedCornerShape(coach.cornerRadius.dp))
                .background(Tokens.Colors.globalAccent)
                .padding(horizontal = coach.paddingHorizontal.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Line(
                stringRes(R.string.tagging_coach),
                Type.style(Tokens.FontSizes.cameraCaptureFontSizeCoach, Tokens.FontWeights.cameraCaptureFontWeightCoach),
                Tokens.Colors.globalOnAccent,
            )
            Spacer(Modifier.width(coach.textToCloseGap.dp))
            InkGlyph(
                Tokens.Icons.globalClose,
                Tokens.Colors.globalOnAccent,
                Modifier.clickable(role = Role.Button, onClick = onDismiss).clearAndSetSemantics { contentDescription = close; role = Role.Button },
                inkHeight = coach.closeGlyph.dp,
            )
        }
    }
}

/** "Once per account" (tagging.md): remembered on this device per signed-in user. */
object TagCoachMemory {
    private const val PREFS = "social_tagging"

    fun seen(context: Context, userId: String?): Boolean =
        userId == null || context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(userId, false)

    fun markSeen(context: Context, userId: String?) {
        if (userId == null) return
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit { putBoolean(userId, true) }
    }
}
