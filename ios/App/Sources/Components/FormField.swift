// Shared component — the Yope single-line form field ("name group", phone number, code, birthday, name).
import DesignSystem
import SwiftUI
import UIKit

/// Single-line text field with centred text, on black.
///
/// Tokens: fill `groups.create.color.field`, height `size.global.fieldHeight` (minimum; grows with Dynamic Type),
/// corners `radius.global.field`, typed text `groups.create.fontSize.fieldText` / `.fontWeight.fieldText` in
/// `color.global.textPrimary`, placeholder the same size in `color.global.textSecondary`. The field fills the
/// proposed width; callers apply `size.global.buttonMarginH`. `accessibilityLabel` (from copy) stays after the
/// placeholder disappears.
struct FormField: View {
    let placeholder: String
    @Binding var text: String
    let accessibilityLabel: String
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType?
    var submitLabel: SubmitLabel = .done
    var onSubmit: () -> Void = {}

    init(
        _ placeholder: String,
        text: Binding<String>,
        accessibilityLabel: String,
        keyboard: UIKeyboardType = .default,
        contentType: UITextContentType? = nil,
        submitLabel: SubmitLabel = .done,
        onSubmit: @escaping () -> Void = {}
    ) {
        self.placeholder = placeholder
        _text = text
        self.accessibilityLabel = accessibilityLabel
        self.keyboard = keyboard
        self.contentType = contentType
        self.submitLabel = submitLabel
        self.onSubmit = onSubmit
    }

    var body: some View {
        TextField(text: $text, prompt: Text(placeholder).foregroundStyle(Tokens.Colors.globalTextSecondary)) {
            Text(accessibilityLabel)
        }
        .dsTextStyle(TextRole.fieldText)
        .foregroundStyle(Tokens.Colors.globalTextPrimary)
        .multilineTextAlignment(.center)
        .keyboardType(keyboard)
        .textContentType(contentType)
        .submitLabel(submitLabel)
        .onSubmit(onSubmit)
        .frame(maxWidth: .infinity, minHeight: Tokens.Sizes.globalFieldHeight)
        .background(Tokens.Colors.groupsCreateColorField, in: RoundedRectangle(cornerRadius: Tokens.Radii.globalField))
        .accessibilityLabel(Text(accessibilityLabel))
    }
}
