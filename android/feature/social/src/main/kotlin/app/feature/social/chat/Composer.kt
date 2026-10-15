// Surface: chat.composer — lime camera · text field "start typing..." · mic (→ lime send circle while typing).
// References: references/auto/yope/store/yope-store-05.png (primary; coordinates in
// references/auto/yope/frames/b-derot-store-05-rot-1.68.png), references/auto/yope/frames/b-play-04.png.
package app.feature.social.chat

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.waitForUpOrCancellation
import androidx.compose.foundation.layout.offset
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import kotlin.math.roundToInt
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.social.common.Glyph
import app.feature.social.common.InkGlyph
import app.feature.social.common.Line
import app.feature.social.common.Type
import app.feature.social.common.stringRes

/** A filled circle button with one glyph, drawn [size] wide (hit area ≥ `size.global.minTouchTarget.android`, SocialRoot). */
@Composable
fun CircleButton(
    size: Dp,
    fill: Color,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    tint: Color,
    /** The glyph's ink height (spec glyph sizes are ink measurements); null = platform icon size. */
    glyphInkHeight: Dp?,
    label: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Box(
        modifier
            .size(size)
            .clip(CircleShape)
            .background(fill)
            .clickable(role = Role.Button, onClick = onClick)
            .clearAndSetSemantics {
                contentDescription = label
                role = Role.Button
            },
        contentAlignment = Alignment.Center,
    ) { if (glyphInkHeight != null) InkGlyph(icon, tint, inkHeight = glyphInkHeight) else Glyph(icon, tint) }
}

/**
 * Yope's capsule text field (`chat.composer.dimension.fieldHeight`, `color.global.control`,
 * hairline rim `chat.composer.color.fieldRimTop` → `.fieldRimBottom`). It grows with multi-line
 * text. The send control is the lime circle of the row's trailing slot
 * (`chat.composer.layout.typingState`); the keyboard's send key sends too.
 */
@Composable
fun CapsuleField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    label: String,
    onSend: () -> Unit,
    modifier: Modifier = Modifier,
    trailing: (@Composable () -> Unit)? = null,
) {
    val sendLabel = stringRes(R.string.chat_composer_a11y_send)
    val rim = Brush.verticalGradient(listOf(Tokens.Colors.chatComposerColorFieldRimTop, Tokens.Colors.chatComposerColorFieldRimBottom))
    val shape = CircleShape
    Row(
        modifier
            .heightIn(min = Tokens.Sizes.chatComposerDimensionFieldHeight)
            .clip(shape)
            .background(Tokens.Colors.globalControl)
            .border(Tokens.Sizes.chatComposerDimensionFieldRim, rim, shape)
            .padding(start = Tokens.Sizes.chatComposerDimensionFieldPaddingLeading),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        BasicTextField(
            value = value,
            onValueChange = onValueChange,
            textStyle = Type.body().copy(color = Tokens.Colors.globalTextPrimary),
            cursorBrush = SolidColor(Tokens.Colors.globalTextPrimary),
            keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.None, imeAction = ImeAction.Send),
            keyboardActions = KeyboardActions(onSend = { onSend() }),
            modifier = Modifier
                .weight(1f)
                .semantics {
                    contentDescription = label
                    customActions = listOf(CustomAccessibilityAction(sendLabel) { onSend(); true })
                },
            decorationBox = { inner ->
                Box(contentAlignment = Alignment.CenterStart) {
                    if (value.isEmpty()) Line(placeholder, Type.placeholder(), Tokens.Colors.globalTextSecondary, Modifier.clearAndSetSemantics { })
                    inner()
                }
            },
        )
        if (trailing != null) trailing()
    }
}

/** The voice recording controls the composer row drives (state and callbacks live in the thread). */
class VoiceControls(
    val recording: Recording?,
    val elapsedMs: Long = 0L,
    val draftPlaying: Boolean = false,
    val draftProgress: Float = 0f,
    /** Finger down on the mic circle: starts recording; false when it could not start (e.g. the permission was asked). */
    val onHoldStart: () -> Boolean = { false },
    /** Lift while holding: send. */
    val onHoldEnd: () -> Unit = {},
    /** Slide left while holding, a tap shorter than a hold, or back: discard. */
    val onCancel: () -> Unit = {},
    /** Slide up onto the lock. */
    val onLock: () -> Unit = {},
    /** TalkBack's activation of the mic circle: hands-free recording at once (no hold gesture). */
    val onStartLocked: () -> Unit = {},
    val onPause: () -> Unit = {},
    val onPlayDraft: () -> Unit = {},
    /** The send circle while locked or paused. */
    val onSend: () -> Unit = {},
)

/**
 * The composer row: lime camera circle · field · mic circle on one centre line, its bottom
 * `chat.composer.dimension.bottomInset` above the safe area / keyboard (caller). While the field
 * holds text the mic circle's slot shows the lime send circle (`chat.composer.layout.typingState`).
 * While recording, the camera and field give way to [RecordingRow] and the mic circle follows the
 * finger (`chat.voice.layout.recording`).
 */
@Composable
fun ComposerRow(
    draft: String,
    onDraft: (String) -> Unit,
    onSend: () -> Unit,
    onCamera: () -> Unit,
    voice: VoiceControls,
    modifier: Modifier = Modifier,
) {
    BoxWithConstraints(modifier.fillMaxWidth()) {
        // Sliding the circle onto the centred hint cancels (the distance is not measured: mic centre → hint centre).
        val recordArea = maxWidth - Tokens.Sizes.chatComposerDimensionInsetLeading - Tokens.Sizes.chatComposerDimensionGapFieldButton -
            Tokens.Sizes.chatComposerDimensionSideButton - Tokens.Sizes.chatComposerDimensionInsetTrailing
        val cancelDistance = recordArea / 2 + Tokens.Sizes.chatComposerDimensionGapFieldButton + Tokens.Sizes.chatComposerDimensionSideButton / 2
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.Bottom) {
            Spacer(Modifier.width(Tokens.Sizes.chatComposerDimensionInsetLeading))
            val recording = voice.recording
            if (recording != null) {
                RecordingRow(recording, voice.elapsedMs, voice.draftPlaying, voice.draftProgress, voice.onPause, voice.onPlayDraft, Modifier.weight(1f))
            } else {
                CircleButton(
                    size = Tokens.Sizes.chatComposerDimensionCameraButton,
                    fill = Tokens.Colors.globalAccent,
                    icon = Tokens.Icons.globalCamera,
                    tint = Tokens.Colors.globalOnAccent,
                    glyphInkHeight = Tokens.Sizes.chatComposerDimensionCameraGlyph,
                    label = stringRes(R.string.chat_composer_a11y_camera),
                    onClick = onCamera,
                )
                Spacer(Modifier.width(Tokens.Sizes.chatComposerDimensionGapCameraField))
                CapsuleField(
                    value = draft,
                    onValueChange = onDraft,
                    placeholder = stringRes(R.string.chat_composer_placeholder),
                    label = stringRes(R.string.chat_composer_a11y_field),
                    onSend = onSend,
                    modifier = Modifier.weight(1f),
                )
            }
            Spacer(Modifier.width(Tokens.Sizes.chatComposerDimensionGapFieldButton))
            MicSlot(
                send = if (recording != null) (recording !is Recording.Holding) else draft.isNotBlank(),
                holding = recording is Recording.Holding,
                onSendText = onSend,
                voice = voice,
                cancelDistance = cancelDistance,
            )
            Spacer(Modifier.width(Tokens.Sizes.chatComposerDimensionInsetTrailing))
        }
    }
}

/**
 * The lime send circle (`chat.composer.layout.typingState`: `chat.composer.dimension.sideButton`,
 * `color.global.accent`, `icon.global.send` in `color.global.onAccent`; glyph size not measured: the
 * mic glyph's, `chat.composer.dimension.micGlyph`).
 */
@Composable
fun SendCircle(onClick: () -> Unit, modifier: Modifier = Modifier) {
    CircleButton(
        size = Tokens.Sizes.chatComposerDimensionSideButton,
        fill = Tokens.Colors.globalAccent,
        icon = Tokens.Icons.globalSend,
        tint = Tokens.Colors.globalOnAccent,
        glyphInkHeight = Tokens.Sizes.chatComposerDimensionMicGlyph,
        label = stringRes(R.string.chat_composer_a11y_send),
        onClick = onClick,
        modifier = modifier,
    )
}

/**
 * The trailing slot: the mic circle (`color.global.controlRaised`, `icon.global.mic`) or, with [send],
 * the lime send circle in place (no transition, `chat.composer.layout.typingState`). One pointer
 * handler serves both, so a hold that starts a recording survives the row changing around it:
 * press and hold records; lift sends; slide left [cancelDistance] cancels; slide up onto the lock
 * locks. A press shorter than the platform long-press timeout is a tap, not a hold: it records nothing.
 */
@Composable
private fun MicSlot(send: Boolean, holding: Boolean, onSendText: () -> Unit, voice: VoiceControls, cancelDistance: Dp) {
    val size = Tokens.Sizes.chatComposerDimensionSideButton
    val current = rememberUpdatedState(MicSlotState(send, voice, onSendText))
    var drag by remember { mutableStateOf(Offset.Zero) }
    val density = LocalDensity.current
    val cancelPx = with(density) { cancelDistance.toPx() }
    // The lock capsule's centre: one circle plus the field gap above the mic circle's top.
    val lockPx = with(density) { (size / 2 + Tokens.Sizes.chatComposerDimensionGapFieldButton + size).toPx() }
    val micLabel = stringRes(R.string.chat_composer_a11y_mic)
    val sendLabel = stringRes(R.string.chat_composer_a11y_send)
    Box(
        Modifier
            .size(size)
            .pointerInput(cancelPx, lockPx) {
                awaitEachGesture {
                    val down = awaitFirstDown()
                    val start = current.value
                    if (start.send) {
                        val up = waitForUpOrCancellation()
                        if (up != null) {
                            up.consume()
                            if (start.voice.recording != null) start.voice.onSend() else start.onSendText()
                        }
                        return@awaitEachGesture
                    }
                    down.consume()
                    if (!start.voice.onHoldStart()) {
                        waitForUpOrCancellation()
                        return@awaitEachGesture
                    }
                    var outcome = Outcome.Lift
                    var last = down.uptimeMillis
                    while (true) {
                        val event = awaitPointerEvent()
                        val change = event.changes.firstOrNull { it.id == down.id }
                        if (change == null) {
                            outcome = Outcome.Cancel
                            break
                        }
                        last = change.uptimeMillis
                        change.consume()
                        if (!change.pressed) break
                        val d = change.position - down.position
                        drag = Offset(minOf(0f, d.x), minOf(0f, d.y))
                        if (d.x <= -cancelPx) {
                            outcome = Outcome.Cancel
                            break
                        }
                        if (d.y <= -lockPx) {
                            outcome = Outcome.Lock
                            break
                        }
                    }
                    drag = Offset.Zero
                    val v = current.value.voice
                    when {
                        outcome == Outcome.Lock -> v.onLock()
                        outcome == Outcome.Cancel -> v.onCancel()
                        last - down.uptimeMillis < viewConfiguration.longPressTimeoutMillis -> v.onCancel()
                        else -> v.onHoldEnd()
                    }
                    // A cancel or lock ends the gesture early: swallow the rest of it.
                    if (outcome != Outcome.Lift) {
                        do {
                            val rest = awaitPointerEvent()
                            rest.changes.forEach { it.consume() }
                        } while (rest.changes.any { it.pressed })
                    }
                }
            }
            .semantics {
                contentDescription = if (send) sendLabel else micLabel
                role = Role.Button
                onClick {
                    val s = current.value
                    when {
                        s.send && s.voice.recording != null -> s.voice.onSend()
                        s.send -> s.onSendText()
                        else -> s.voice.onStartLocked()
                    }
                    true
                }
            },
    ) {
        if (holding) LockIndicator(Modifier.align(Alignment.BottomCenter).offset(y = -(size + Tokens.Sizes.chatComposerDimensionGapFieldButton)))
        Box(
            Modifier
                .offset { IntOffset(drag.x.roundToInt(), drag.y.roundToInt()) }
                .size(size)
                .clip(CircleShape)
                .background(if (send) Tokens.Colors.globalAccent else Tokens.Colors.globalControlRaised)
                .clearAndSetSemantics { },
            contentAlignment = Alignment.Center,
        ) {
            if (send) InkGlyph(Tokens.Icons.globalSend, Tokens.Colors.globalOnAccent, inkHeight = Tokens.Sizes.chatComposerDimensionMicGlyph)
            else InkGlyph(Tokens.Icons.globalMic, Tokens.Colors.globalTextPrimary, inkHeight = Tokens.Sizes.chatComposerDimensionMicGlyph)
        }
    }
}

private class MicSlotState(val send: Boolean, val voice: VoiceControls, val onSendText: () -> Unit)

private enum class Outcome { Lift, Cancel, Lock }
