// Surface: chat.composer — lime camera · text field "start typing..." · mic.
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
import androidx.compose.ui.unit.Dp
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.social.common.Glyph
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
    glyph: Dp?,
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
    ) { Glyph(icon, tint, size = glyph) }
}

/**
 * Yope's capsule text field (`chat.composer.dimension.fieldHeight`, `color.global.control`,
 * hairline rim `chat.composer.color.fieldRimTop` → `.fieldRimBottom`). It grows with multi-line
 * text. The send control is BLOCKED (`chat.composer.layout.typingState`): the keyboard's return key
 * sends (the spec's approximation); TalkBack also gets a "send" action.
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

/**
 * The composer row: lime camera circle · field · mic circle on one centre line. The mic opens
 * voice recording, whose UI is BLOCKED (`chat.voice.layout.recording`): [onMic] is null in release
 * builds and the circle is left out. While [recordingLevels] is non-null (development builds) the
 * field shows the live waveform. The row's gap to the bottom safe area is BLOCKED
 * (`chat.composer.dimension.bottomInset`): none is added.
 */
@Composable
fun ComposerRow(
    draft: String,
    onDraft: (String) -> Unit,
    onSend: () -> Unit,
    onCamera: () -> Unit,
    onMic: (() -> Unit)?,
    recordingLevels: List<Float>?,
    modifier: Modifier = Modifier,
) {
    Row(modifier.fillMaxWidth(), verticalAlignment = Alignment.Bottom) {
        Spacer(Modifier.width(Tokens.Sizes.chatComposerDimensionInsetLeading))
        CircleButton(
            size = Tokens.Sizes.chatComposerDimensionCameraButton,
            fill = Tokens.Colors.globalAccent,
            icon = Tokens.Icons.globalCamera,
            tint = Tokens.Colors.globalOnAccent,
            glyph = Tokens.Sizes.chatComposerDimensionCameraGlyph,
            label = stringRes(R.string.chat_composer_a11y_camera),
            onClick = onCamera,
        )
        Spacer(Modifier.width(Tokens.Sizes.chatComposerDimensionGapCameraField))
        if (recordingLevels != null) {
            BoxWithConstraints(
                Modifier.weight(1f).heightIn(min = Tokens.Sizes.chatComposerDimensionFieldHeight).clip(CircleShape).background(Tokens.Colors.globalControl)
                    .padding(start = Tokens.Sizes.chatComposerDimensionFieldPaddingLeading),
                contentAlignment = Alignment.CenterStart,
            ) {
                val count = barCount(maxWidth)
                WaveformBars(app.voice.Waveform.bars(recordingLevels.ifEmpty { listOf(0f) }, count.coerceAtLeast(1)), count)
            }
        } else {
            CapsuleField(
                value = draft,
                onValueChange = onDraft,
                placeholder = stringRes(R.string.chat_composer_placeholder),
                label = stringRes(R.string.chat_composer_a11y_field),
                onSend = onSend,
                modifier = Modifier.weight(1f),
            )
        }
        if (onMic != null) {
            Spacer(Modifier.width(Tokens.Sizes.chatComposerDimensionGapFieldButton))
            CircleButton(
                size = Tokens.Sizes.chatComposerDimensionSideButton,
                fill = Tokens.Colors.globalControlRaised,
                icon = Tokens.Icons.globalMic,
                tint = Tokens.Colors.globalTextPrimary,
                glyph = Tokens.Sizes.chatComposerDimensionMicGlyph,
                label = stringRes(R.string.chat_composer_a11y_mic),
                onClick = onMic,
            )
        }
        Spacer(Modifier.width(Tokens.Sizes.chatComposerDimensionInsetTrailing))
    }
}

@Suppress("unused")
private val roleButton = Role.Button
