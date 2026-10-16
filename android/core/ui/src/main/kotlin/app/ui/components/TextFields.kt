package app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.autofill.ContentType
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.contentType
import androidx.compose.ui.semantics.error
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.isSpecified
import app.designsystem.generated.Tokens
import app.ui.foundation.PageRoles
import app.ui.text.TextRoles

/**
 * C-12 Text field (single line): fill `color.global.control`, minimum height `size.global.fieldHeight` (grows
 * with the font scale), corners `radius.global.field`, full width (the caller applies
 * `size.global.screenMargin`). Placeholder and typed text in text role `placeholder` (17) —
 * placeholder in secondary text (`color.global.textSecondary.android`), typed text `color.global.textPrimary`;
 * cursor and selection in the platform tint (`color.global.system.primary`, PLATFORM). Retro shows no focus
 * ring. The text's inner inset is not measured (Gap): it keeps `radius.global.field` from the ends so it never
 * enters the rounded corners.
 *
 * [accessibilityLabel] (copy) names the field for TalkBack — the placeholder is not the label.
 * [error]: the inline message below in `color.global.destructive`, text role `meta` (Retro's inline errors are
 * short labels, RP §4.2; their placement is not captured — Gap), announced politely and set as the field's
 * error. [autofill] sets the autofill content type. [leading] draws [leadingInset] in from the field's leading
 * edge (a country flag, the search glyph); the text then starts [leadingClearance] from the edge. [textAlign]
 * is Start (Retro's fields); sign-up screens are not captured (C-33 Gap).
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
    error: String? = null,
    textAlign: TextAlign = TextAlign.Start,
    leading: (@Composable () -> Unit)? = null,
    leadingInset: Dp = Dp.Unspecified,
    leadingClearance: Dp = Dp.Unspecified,
) {
    val inset = Tokens.Radii.globalField
    val textStart = if (leading != null && leadingClearance.isSpecified) leadingClearance else inset
    val shape = RoundedCornerShape(Tokens.Radii.globalField)
    val style = TextRoles.placeholder.copy(color = if (enabled) Tokens.Colors.globalTextPrimary else Tokens.Colors.globalTextTertiary, textAlign = textAlign)
    val placeholderColor = PageRoles.secondaryText()
    Column(modifier.fillMaxWidth()) {
        BasicTextField(
            value = value,
            onValueChange = onValueChange,
            enabled = enabled,
            singleLine = true,
            textStyle = style,
            cursorBrush = SolidColor(Tokens.Colors.globalSystemPrimary),
            keyboardOptions = keyboardOptions,
            keyboardActions = keyboardActions,
            modifier = Modifier
                .fillMaxWidth()
                .semantics {
                    contentDescription = accessibilityLabel
                    if (autofill != null) contentType = autofill
                    if (error != null) error(error)
                },
            decorationBox = { inner ->
                Box(
                    Modifier
                        .fillMaxWidth()
                        .heightIn(min = Tokens.Sizes.globalFieldHeight)
                        .clip(shape)
                        .background(Tokens.Colors.globalControl, shape),
                    contentAlignment = Alignment.CenterStart,
                ) {
                    if (leading != null) {
                        Box(Modifier.matchParentSize().padding(start = if (leadingInset.isSpecified) leadingInset else inset), contentAlignment = Alignment.CenterStart) { leading() }
                    }
                    Box(Modifier.fillMaxWidth().padding(start = textStart, end = inset), contentAlignment = Alignment.CenterStart) {
                        if (value.text.isEmpty()) {
                            Text(placeholder, style = style.copy(color = placeholderColor), modifier = Modifier.fillMaxWidth(), maxLines = 1)
                        }
                        inner()
                    }
                }
            },
        )
        if (error != null) {
            Text(
                error,
                style = TextRoles.meta,
                color = Tokens.Colors.globalDestructive,
                modifier = Modifier.padding(horizontal = inset).semantics { liveRegion = LiveRegionMode.Polite },
            )
        }
    }
}

/**
 * C-12 Search field: [FormTextField] with the leading `icon.global.search` glyph in secondary text, drawn in
 * the `size.global.icon` box at the field's text inset (`radius.global.field`); the text starts after it by
 * `size.global.pillIconGap` (glyph → label of the outline CTA, the nearest measured glyph-to-text gap — the
 * search field's own is not measured, Gap). TalkBack: the search-field label from copy.
 */
@Composable
fun SearchField(
    value: TextFieldValue,
    onValueChange: (TextFieldValue) -> Unit,
    placeholder: String,
    accessibilityLabel: String,
    modifier: Modifier = Modifier,
    keyboardOptions: KeyboardOptions = KeyboardOptions.Default,
    keyboardActions: KeyboardActions = KeyboardActions.Default,
    enabled: Boolean = true,
) {
    val inset = Tokens.Radii.globalField
    val glyphColor = PageRoles.secondaryText()
    FormTextField(
        value = value,
        onValueChange = onValueChange,
        placeholder = placeholder,
        accessibilityLabel = accessibilityLabel,
        modifier = modifier,
        keyboardOptions = keyboardOptions,
        keyboardActions = keyboardActions,
        enabled = enabled,
        leading = { Icon(Tokens.Icons.globalSearch, contentDescription = null, tint = glyphColor, modifier = Modifier.size(Tokens.Sizes.globalIcon)) },
        leadingInset = inset,
        leadingClearance = inset + Tokens.Sizes.globalIcon + Tokens.Sizes.globalPillIconGap,
    )
}

/**
 * C-13 Reply / comment bar: fill `color.global.controlOnDeep` on media ([onMedia], the viewer) or
 * `color.global.surfaceSecondary.android` on a page (a thread); height `size.global.commentFieldHeight`,
 * corners `radius.global.commentField` (a rounded rectangle, not a capsule); `size.global.screenMargin` from
 * the screen sides (applied here). Leading own [avatar] at `size.global.avatarComment`, centred with equal top
 * and side insets (the field's inner insets are not measured — Gap: the avatar sits (height − avatar) ÷ 2 from
 * the edge and the text the same distance after it); placeholder text role `body` in secondary text
 * (`color.global.textSecondary` on media). [trailing] is the trailing glyph button (`icon.global.more`, or
 * `icon.global.send` once text is present — mechanics) in secondary text.
 */
@Composable
fun ReplyBar(
    value: TextFieldValue,
    onValueChange: (TextFieldValue) -> Unit,
    placeholder: String,
    accessibilityLabel: String,
    avatar: Any?,
    modifier: Modifier = Modifier,
    onMedia: Boolean = true,
    trailing: HeaderAction? = null,
    keyboardOptions: KeyboardOptions = KeyboardOptions.Default,
    keyboardActions: KeyboardActions = KeyboardActions.Default,
) {
    val fill = if (onMedia) Tokens.Colors.globalControlOnDeep else PageRoles.secondarySurface
    val text = if (onMedia) Tokens.Colors.globalTextOnMedia else Tokens.Colors.globalTextPrimary
    val secondary = PageRoles.secondaryText(onMedia)
    val shape = RoundedCornerShape(Tokens.Radii.globalCommentField)
    val inner = (Tokens.Sizes.globalCommentFieldHeight - Tokens.Sizes.globalAvatarComment) / 2
    val style = TextRoles.body.copy(color = text)
    BasicTextField(
        value = value,
        onValueChange = onValueChange,
        singleLine = true,
        textStyle = style,
        cursorBrush = SolidColor(Tokens.Colors.globalSystemPrimary),
        keyboardOptions = keyboardOptions,
        keyboardActions = keyboardActions,
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = Tokens.Sizes.globalScreenMargin)
            .semantics { contentDescription = accessibilityLabel },
        decorationBox = { field ->
            Row(
                Modifier
                    .fillMaxWidth()
                    .heightIn(min = Tokens.Sizes.globalCommentFieldHeight)
                    .clip(shape)
                    .background(fill, shape)
                    .padding(start = inner),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Avatar(avatar, Tokens.Sizes.globalAvatarComment)
                Box(Modifier.weight(1f).padding(horizontal = inner), contentAlignment = Alignment.CenterStart) {
                    if (value.text.isEmpty()) Text(placeholder, style = style.copy(color = secondary), maxLines = 1)
                    field()
                }
                if (trailing != null) HeaderIconButton(trailing.icon, trailing.contentDescription, trailing.onClick, tint = secondary)
            }
        },
    )
}
