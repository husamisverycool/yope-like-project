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
///
/// With a `leading` accessory (auth.phone's country flag) the accessory sits at the leading edge and the text is
/// leading-aligned right after it; the accessory brings its own insets, and `trailingInset` keeps the text off the
/// trailing edge.
struct FormField<Leading: View>: View {
    let placeholder: String
    @Binding var text: String
    let accessibilityLabel: String
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType?
    var submitLabel: SubmitLabel = .done
    var onSubmit: () -> Void = {}
    private let leading: Leading?
    private let trailingInset: CGFloat

    init(
        _ placeholder: String,
        text: Binding<String>,
        accessibilityLabel: String,
        keyboard: UIKeyboardType = .default,
        contentType: UITextContentType? = nil,
        submitLabel: SubmitLabel = .done,
        trailingInset: CGFloat,
        @ViewBuilder leading: () -> Leading
    ) {
        self.placeholder = placeholder
        _text = text
        self.accessibilityLabel = accessibilityLabel
        self.keyboard = keyboard
        self.contentType = contentType
        self.submitLabel = submitLabel
        self.leading = leading()
        self.trailingInset = trailingInset
    }

    var body: some View {
        Group {
            if let leading {
                HStack(spacing: 0) {
                    leading
                    field
                        .multilineTextAlignment(.leading)
                        .padding(.trailing, trailingInset)
                }
            } else {
                field
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, minHeight: Tokens.Sizes.globalFieldHeight)
        .background(Tokens.Colors.groupsCreateColorField, in: RoundedRectangle(cornerRadius: Tokens.Radii.globalField))
    }

    private var field: some View {
        TextField(text: $text, prompt: Text(placeholder).foregroundStyle(Tokens.Colors.globalTextSecondary)) {
            Text(accessibilityLabel)
        }
        .dsTextStyle(TextRole.fieldText)
        .foregroundStyle(Tokens.Colors.globalTextPrimary)
        .keyboardType(keyboard)
        .textContentType(contentType)
        .submitLabel(submitLabel)
        .onSubmit(onSubmit)
        .frame(maxWidth: .infinity, minHeight: Tokens.Sizes.globalFieldHeight)
        .accessibilityLabel(Text(accessibilityLabel))
    }
}

extension FormField where Leading == EmptyView {
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
        leading = nil
        trailingInset = 0
    }
}
