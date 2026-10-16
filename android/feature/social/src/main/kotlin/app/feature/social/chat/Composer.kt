// Surface: chat.composer — design/surfaces/chat.composer.md (+ the recording row of chat.voice.md)
// References: references/auto/retro/press/tc-2023-07-retro-2b.jpg phone 2 (comment field: margins, own avatar,
// placeholder, trailing glyph), references/auto/whatsapp/store/whatsapp-store-04.png (camera + mic beside the idle field),
// references/auto/telegram/store/telegram-store-03.png (recording row with lock).
package app.feature.social.chat

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.waitForUpOrCancellation
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.layout
import androidx.compose.ui.unit.offset
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.max
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.social.common.Formats
import app.feature.social.common.PersonAvatar
import app.feature.social.common.stringRes
import app.ui.components.CircleButtonStyle
import app.ui.components.CircleIconButton
import app.ui.foundation.DsMotion
import app.ui.foundation.GlyphInk
import app.ui.foundation.PageRoles
import app.ui.foundation.tapClickable
import app.ui.text.TextRoles
import kotlin.math.roundToInt

/** Hit area of a field glyph: `size.global.headerButton`, at least `size.global.minTouchTarget.android`. */
internal val glyphHit: Dp get() = max(Tokens.Sizes.globalHeaderButton, Tokens.Sizes.globalMinTouchTargetAndroid)

/**
 * A glyph inside the field (`chat.composer.layout.typingState`): a bare [icon] in the `size.global.icon` box,
 * [tint], hit area [glyphHit]; [gesture] replaces the plain tap (the mic's press-and-hold); [anchor] draws
 * inside the glyph's box (a menu anchored to it).
 */
class FieldGlyph(
    val icon: ImageVector,
    val label: String,
    val tint: Color,
    val onClick: () -> Unit,
    val gesture: Modifier? = null,
    val dragOffset: () -> Offset = { Offset.Zero },
    val anchor: (@Composable BoxScope.() -> Unit)? = null,
)

/**
 * C-13 message field on a page (`chat.thread`) or on media (`photo.viewer`, [onMedia]), with the metrics
 * `chat.composer.dimension.*` measured on TC-2B (core:ui `ReplyBar` has one trailing glyph, one line and no
 * internal metrics — component gap, reported):
 *
 * - fill `color.global.surfaceSecondary.android` (page) / `color.global.controlOnDeep` (media), height
 *   `size.global.commentFieldHeight` growing with multi-line text, corners `radius.global.commentField`, inside
 *   `size.global.screenMargin`;
 * - own avatar `size.global.avatarComment` at `chat.composer.dimension.avatarInset`, the text
 *   `chat.composer.dimension.avatarToText` after it (text role `body`; placeholder in secondary text);
 * - trailing [glyphs] (the last one's ink `chat.composer.dimension.glyphInsetTrailing` from the trailing edge,
 *   centres `size.global.headerIconPitch` apart); while the field holds text they give way to `icon.global.send`
 *   in `color.global.textPrimary` at the last glyph's place (cross-fade `duration.global.crossfade`);
 * - [recording] replaces the avatar and text with the recording row (`chat.voice.layout.recording`).
 */
@Composable
fun MessageField(
    value: TextFieldValue,
    onValueChange: (TextFieldValue) -> Unit,
    placeholder: String,
    accessibilityLabel: String,
    avatarPath: String?,
    glyphs: List<FieldGlyph>,
    onSend: () -> Unit,
    modifier: Modifier = Modifier,
    onMedia: Boolean = false,
    recording: (@Composable RowScope.() -> Unit)? = null,
) {
    val fill = if (onMedia) Tokens.Colors.globalControlOnDeep else PageRoles.secondarySurface
    val textColor = Tokens.Colors.globalTextPrimary
    val secondary = PageRoles.secondaryText(onMedia)
    val shape = RoundedCornerShape(Tokens.Radii.globalCommentField)
    val height = Tokens.Sizes.globalCommentFieldHeight
    val avatarTop = (height - Tokens.Sizes.globalAvatarComment) / 2
    val style = TextRoles.body.copy(color = textColor)
    val typing = value.text.isNotBlank() && recording == null
    val sendGlyph = FieldGlyph(Tokens.Icons.globalSend, stringRes(R.string.chat_composer_a11y_send), Tokens.Colors.globalTextPrimary, onSend)
    val shown = if (typing) listOf(sendGlyph) else glyphs
    Row(
        modifier
            .fillMaxWidth()
            .padding(horizontal = Tokens.Sizes.globalScreenMargin)
            .heightIn(min = height)
            .clip(shape)
            .background(fill, shape),
        verticalAlignment = Alignment.Top,
    ) {
        if (recording != null) {
            Row(Modifier.weight(1f).heightIn(min = height), verticalAlignment = Alignment.CenterVertically, content = recording)
        } else {
            Spacer(Modifier.width(Tokens.Sizes.chatComposerDimensionAvatarInset))
            PersonAvatar(avatarPath, Tokens.Sizes.globalAvatarComment, Modifier.padding(top = avatarTop))
            Spacer(Modifier.width(Tokens.Sizes.chatComposerDimensionAvatarToText))
            BasicTextField(
                value = value,
                onValueChange = onValueChange,
                textStyle = style,
                cursorBrush = SolidColor(Tokens.Colors.globalSystemPrimary),
                keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences),
                modifier = Modifier.weight(1f).semantics { contentDescription = accessibilityLabel },
                decorationBox = { field ->
                    Box(Modifier.heightIn(min = height).padding(vertical = avatarTop), contentAlignment = Alignment.CenterStart) {
                        if (value.text.isEmpty()) Text(placeholder, style = style.copy(color = secondary), maxLines = 1)
                        field()
                    }
                },
            )
        }
        AnimatedContent(shown, transitionSpec = { fadeIn(DsMotion.crossfade()) togetherWith fadeOut(DsMotion.crossfade()) }, label = "glyphs") { list ->
            FieldGlyphs(list, height)
        }
    }
}

/** The trailing glyphs, the last one's ink `chat.composer.dimension.glyphInsetTrailing` from the field's edge. */
@Composable
private fun FieldGlyphs(glyphs: List<FieldGlyph>, fieldHeight: Dp) {
    if (glyphs.isEmpty()) return
    val box = Tokens.Sizes.globalIcon
    val hit = glyphHit
    val last = glyphs.last().icon
    // Ink → field edge = glyphInsetTrailing: the hit box's trailing edge sits that much minus the glyph's own
    // trailing padding minus half the hit box's extra width in from the field's edge.
    val end = Tokens.Sizes.chatComposerDimensionGlyphInsetTrailing - GlyphInk.trailing(last, box) - (hit - box) / 2
    val gap = Tokens.Sizes.globalHeaderIconPitch - hit
    Row(Modifier.padding(top = (fieldHeight - hit) / 2).endInset(end)) {
        glyphs.forEachIndexed { i, g ->
            if (i > 0) Spacer(Modifier.width(gap))
            val drag = g.dragOffset()
            Box(
                Modifier
                    .size(hit)
                    .then(g.gesture ?: Modifier.tapClickable(onClick = g.onClick))
                    .semantics {
                        contentDescription = g.label
                        role = Role.Button
                        if (g.gesture != null) onClick { g.onClick(); true }
                    },
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    g.icon,
                    contentDescription = null,
                    tint = g.tint,
                    modifier = Modifier.offset { IntOffset(drag.x.roundToInt(), drag.y.roundToInt()) }.size(box),
                )
                g.anchor?.invoke(this)
            }
        }
    }
}

/**
 * The field's content while recording (`chat.voice.layout.recording`): `icon.global.mic` in
 * `color.global.destructive` (C-10 red glyph) at the avatar's place, the elapsed time (text role `body`, tabular
 * digits, `color.global.textPrimary`, a polite live region), then — centred in the remaining width while holding —
 * `icon.global.back` + `chat.voice.recording.slideToCancel` in secondary text.
 */
@Composable
fun RowScope.RecordingContent(recording: Recording, elapsedMs: Long, onMedia: Boolean = false) {
    val secondary = PageRoles.secondaryText(onMedia)
    Spacer(Modifier.width(Tokens.Sizes.chatComposerDimensionAvatarInset))
    Box(Modifier.size(Tokens.Sizes.globalAvatarComment), contentAlignment = Alignment.Center) {
        Icon(Tokens.Icons.globalMic, contentDescription = null, tint = Tokens.Colors.globalDestructive, modifier = Modifier.size(Tokens.Sizes.globalIcon))
    }
    Spacer(Modifier.width(Tokens.Sizes.chatComposerDimensionAvatarToText))
    Text(
        Formats.voiceDuration(elapsedMs),
        style = TextRoles.body.copy(fontFeatureSettings = TABULAR_DIGITS),
        color = Tokens.Colors.globalTextPrimary,
        maxLines = 1,
        modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
    )
    Box(Modifier.weight(1f), contentAlignment = Alignment.Center) {
        if (recording is Recording.Holding) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Tokens.Icons.globalBack, contentDescription = null, tint = secondary, modifier = Modifier.size(Tokens.Sizes.globalIconSmall))
                Spacer(Modifier.width(Tokens.Sizes.globalPillIconGap))
                Text(stringRes(R.string.chat_voice_recording_slidetocancel), style = TextRoles.body, color = secondary, maxLines = 1)
            }
        }
    }
}

/**
 * The lock circle over the mic while holding (`chat.voice.layout.recording` lockCircle): C-11 on the page
 * (`size.global.circleButton`, `color.global.control`, `icon.global.lock`), `size.global.pillGap` above the field.
 */
@Composable
fun LockCircle(onLock: () -> Unit, modifier: Modifier = Modifier) {
    CircleIconButton(Tokens.Icons.globalLock, stringRes(R.string.chat_voice_a11y_lock), onLock, modifier, style = CircleButtonStyle.OnPage)
}

/** Callbacks of the mic's press-and-hold. */
class MicGesture(
    /** Finger down: starts recording; false when it could not start (the permission was asked). */
    val onHoldStart: () -> Boolean,
    /** Lift after a hold: send. */
    val onRelease: () -> Unit,
    /** Slide left past the hint, a press shorter than a hold, or back: discard. */
    val onCancel: () -> Unit,
    /** Slide up onto the lock circle. */
    val onLock: () -> Unit,
)

/** The mic glyph's drag (it stays under the finger) and its press-and-hold handler. */
class MicDrag {
    var offset by mutableStateOf(Offset.Zero)
}

/**
 * The mic's pointer handler (`chat.voice.layout.recording`, WhatsApp): press and hold records, lift sends,
 * sliding left [cancelDistance] discards, sliding up [lockDistance] locks; a press shorter than the platform
 * long-press timeout records nothing. No haptics (the microphone is in use).
 */
@Composable
fun Modifier.micGesture(gesture: MicGesture, drag: MicDrag, cancelDistance: Dp, lockDistance: Dp): Modifier {
    val current by rememberUpdatedState(gesture)
    val density = LocalDensity.current
    val cancelPx = with(density) { cancelDistance.toPx() }
    val lockPx = with(density) { lockDistance.toPx() }
    return pointerInput(cancelPx, lockPx) {
        awaitEachGesture {
            val down = awaitFirstDown()
            down.consume()
            if (!current.onHoldStart()) {
                waitForUpOrCancellation()
                return@awaitEachGesture
            }
            var outcome = MicOutcome.Lift
            var last = down.uptimeMillis
            while (true) {
                val event = awaitPointerEvent()
                val change = event.changes.firstOrNull { it.id == down.id }
                if (change == null) {
                    outcome = MicOutcome.Cancel
                    break
                }
                last = change.uptimeMillis
                change.consume()
                if (!change.pressed) break
                val d = change.position - down.position
                drag.offset = Offset(minOf(0f, d.x), minOf(0f, d.y))
                if (d.x <= -cancelPx) {
                    outcome = MicOutcome.Cancel
                    break
                }
                if (d.y <= -lockPx) {
                    outcome = MicOutcome.Lock
                    break
                }
            }
            drag.offset = Offset.Zero
            when {
                outcome == MicOutcome.Lock -> current.onLock()
                outcome == MicOutcome.Cancel -> current.onCancel()
                last - down.uptimeMillis < viewConfiguration.longPressTimeoutMillis -> current.onCancel()
                else -> current.onRelease()
            }
            if (outcome != MicOutcome.Lift) {
                do {
                    val rest = awaitPointerEvent()
                    rest.changes.forEach { it.consume() }
                } while (rest.changes.any { it.pressed })
            }
        }
    }
}

private enum class MicOutcome { Lift, Cancel, Lock }

/** Keeps [end] free after the content (a negative [end] lets the content's hit area run past the edge). */
internal fun Modifier.endInset(end: Dp): Modifier = layout { measurable, constraints ->
    val e = end.roundToPx()
    val placeable = measurable.measure(constraints.offset(horizontal = -e.coerceAtLeast(0)))
    layout((placeable.width + e).coerceAtLeast(0), placeable.height) { placeable.place(0, 0) }
}

/** The reply bar's close glyph, labelled `chat.thread.a11y.cancelReply` (decorative glyph, labelled hit area). */
@Composable
internal fun BareGlyph(icon: ImageVector, label: String, tint: Color, onClick: () -> Unit, modifier: Modifier = Modifier) {
    Box(
        modifier.size(glyphHit).tapClickable(onClick = onClick).clearAndSetSemantics {
            contentDescription = label
            role = Role.Button
        },
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(Tokens.Sizes.globalIcon))
    }
}
