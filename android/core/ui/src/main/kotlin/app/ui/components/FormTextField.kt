package app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.autofill.ContentType
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.contentType
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.isSpecified
import app.designsystem.dsTextStyle
import app.designsystem.generated.Tokens

/**
 * The Yope single-line form field ("name group", phone number, code, birthday, your name).
 *
 * Tokens: fill `groups.create.color.field`, minimum height `size.global.fieldHeight` (grows with the
 * font scale), corners `radius.global.field`, text `groups.create.fontSize.fieldText` +
 * `groups.create.fontWeight.fieldText` in `color.global.textPrimary`, centred; the placeholder in the
 * same size in `color.global.textSecondary`; cursor `color.global.textPrimary`. Inner side inset =
 * `radius.global.field` (text never enters the rounded corners; Yope's inner inset is not measured —
 * text is centred, so only long values reach it). [accessibilityLabel] (copy
 * `*.field.accessibilityLabel`) names the field for TalkBack because the placeholder disappears once
 * typing starts. [autofill] sets the autofill content type (`ContentType.PhoneNumber`,
 * `ContentType.SmsOtpCode`, `ContentType.PersonFirstName`).
 *
 * [leading] draws at the field's leading edge, [leadingInset] in from it (auth.phone's country flag,
 * `auth.phone.layout.countryCode`); the text stays centred on the whole field and keeps
 * [leadingClearance] free on both sides so it never runs under the leading element.
 */
@Composable
fun FormTextField(
    value: TextFieldValue,
    onValueChange: (TextFieldValue) -> Unit,
    placeholder: String,
    accessibilityLabel: String,
    modifier: Modifier = Modifier,
    keyboardOptions: KeyboardOptions = KeyboardOptions.Default,
    keyboardActions: KeyboardActions = KeyboardActions.Default,
    autofill: ContentType? = null,
    enabled: Boolean = true,
    leading: (@Composable () -> Unit)? = null,
    leadingInset: Dp = Dp.Unspecified,
    leadingClearance: Dp = Dp.Unspecified,
) {
    val sideInset = if (leading != null && leadingClearance.isSpecified) maxOf(leadingClearance, Tokens.Radii.globalField) else Tokens.Radii.globalField
    val shape = RoundedCornerShape(Tokens.Radii.globalField)
    val style: TextStyle = dsTextStyle(Tokens.FontSizes.groupsCreateFontSizeFieldText, Tokens.FontWeights.groupsCreateFontWeightFieldText, Tokens.Fonts.globalFamily)
        .copy(color = Tokens.Colors.globalTextPrimary, textAlign = TextAlign.Center)
    BasicTextField(
        value = value,
        onValueChange = onValueChange,
        enabled = enabled,
        singleLine = true,
        textStyle = style,
        cursorBrush = SolidColor(Tokens.Colors.globalTextPrimary),
        keyboardOptions = keyboardOptions,
        keyboardActions = keyboardActions,
        modifier = modifier
            .fillMaxWidth()
            .semantics {
                contentDescription = accessibilityLabel
                if (autofill != null) contentType = autofill
            },
        decorationBox = { inner ->
            Box(
                Modifier
                    .fillMaxWidth()
                    .heightIn(min = Tokens.Sizes.globalFieldHeight)
                    .clip(shape)
                    .background(Tokens.Colors.groupsCreateColorField, shape),
                contentAlignment = Alignment.Center,
            ) {
                if (leading != null) {
                    // matchParentSize: the leading element never changes the field's height.
                    Box(
                        Modifier.matchParentSize().padding(start = if (leadingInset.isSpecified) leadingInset else Tokens.Radii.globalField),
                        contentAlignment = Alignment.CenterStart,
                    ) { leading() }
                }
                Box(Modifier.fillMaxWidth().padding(horizontal = sideInset), contentAlignment = Alignment.Center) {
                    if (value.text.isEmpty()) {
                        Text(placeholder, style = style.copy(color = Tokens.Colors.globalTextSecondary), modifier = Modifier.fillMaxWidth(), maxLines = 1)
                    }
                    inner()
                }
            }
        },
    )
}
