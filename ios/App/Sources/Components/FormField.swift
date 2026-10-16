// Shared component — C-12 text field and search field (design/components.md), replacing Yope's centred form field.
// Evidence: ED-W3 (52 high, corner fit 19.2; placeholder 17; magnifier ink 13.6), TC-1B (2023); RV §3.4, §3.5, §4 #9.
import DesignSystem
import SwiftUI
import UIKit

/// Single-line text field.
///
/// Fill `color.global.control` (#F1F1F1 / #262626), height `size.global.fieldHeight` (a minimum: grows with Dynamic
/// Type), corners `radius.global.field` (continuous); typed text and placeholder in text role `placeholder`, typed text
/// `color.global.textPrimary`, placeholder `color.global.textSecondary`; cursor and selection in the platform tint.
/// Text is leading-aligned (Retro's field). The field fills the proposed width; callers apply
/// `size.global.screenMargin` (or `size.global.buttonMarginH` in a form with a capsule). Inner side padding was not
/// measured (Gap) — platform padding. Focused: keyboard up, no focus ring (none captured).
///
/// `errorMessage`: an inline message below the field in text role `meta`, `color.global.destructive` (Retro's inline
/// errors are short labels — RP §4.2; their placement was not captured, Gap). Disabled: not captured (Gap).
///
/// With a `leading` accessory (auth.phone's country flag) the accessory sits at the leading edge and brings its own
/// insets; `trailingInset` keeps the text off the trailing edge.
///
/// Accessibility: the label comes from copy and stays after the placeholder disappears. Contrast: placeholder on the
/// fill 2.52:1 (light) FAIL — CONTRAST failure 1, reported, not changed.
struct FormField<Leading: View>: View {
    let placeholder: String
    @Binding var text: String
    let accessibilityLabel: String
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType?
    var submitLabel: SubmitLabel = .done
    var errorMessage: String?
    var onSubmit: () -> Void = {}
    private let leading: Leading?
    private let trailingInset: CGFloat?

    init(
        _ placeholder: String,
        text: Binding<String>,
        accessibilityLabel: String,
        keyboard: UIKeyboardType = .default,
        contentType: UITextContentType? = nil,
        submitLabel: SubmitLabel = .done,
        errorMessage: String? = nil,
        trailingInset: CGFloat,
        @ViewBuilder leading: () -> Leading
    ) {
        self.placeholder = placeholder
        _text = text
        self.accessibilityLabel = accessibilityLabel
        self.keyboard = keyboard
        self.contentType = contentType
        self.submitLabel = submitLabel
        self.errorMessage = errorMessage
        self.leading = leading()
        self.trailingInset = trailingInset
    }

    var body: some View {
        VStack(alignment: .leading) {
            Group {
                if let leading, let trailingInset {
                    HStack(spacing: 0) {
                        leading
                        field
                            .padding(.trailing, trailingInset)
                    }
                    // The accessory may fill the field's height (the flag's hit area); the row keeps the field's
                    // height instead of growing into the space it is offered.
                    .fixedSize(horizontal: false, vertical: true)
                } else {
                    field
                        .padding(.horizontal)
                }
            }
            .frame(maxWidth: .infinity, minHeight: Tokens.Sizes.globalFieldHeight)
            .background(Tokens.Colors.globalControl, in: DSShape.rounded(Tokens.Radii.globalField))
            if let errorMessage {
                Text(errorMessage)
                    .dsTextStyle(TextRole.meta)
                    .foregroundStyle(Tokens.Colors.globalDestructive)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var field: some View {
        TextField(text: $text, prompt: Text(placeholder).foregroundStyle(Tokens.Colors.globalTextSecondary)) {
            Text(accessibilityLabel)
        }
        .dsTextStyle(TextRole.placeholder)
        .foregroundStyle(Tokens.Colors.globalTextPrimary)
        .multilineTextAlignment(.leading)
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
        errorMessage: String? = nil,
        onSubmit: @escaping () -> Void = {}
    ) {
        self.placeholder = placeholder
        _text = text
        self.accessibilityLabel = accessibilityLabel
        self.keyboard = keyboard
        self.contentType = contentType
        self.submitLabel = submitLabel
        self.errorMessage = errorMessage
        self.onSubmit = onSubmit
        leading = nil
        trailingInset = nil
    }
}

/// C-12 search field: the text field with the leading `icon.global.search` in `color.global.textSecondary`, drawn at
/// the symbol size of the field's text (its ink then measures ≈ the 13.6 pt captured; no glyph-size token) so it scales
/// with Dynamic Type; glyph → text spacing is the platform's. Return key: search. Accessibility: search-field trait,
/// label from copy.
struct SearchField: View {
    let placeholder: String
    @Binding var text: String
    let accessibilityLabel: String
    var onSubmit: () -> Void = {}

    init(_ placeholder: String, text: Binding<String>, accessibilityLabel: String, onSubmit: @escaping () -> Void = {}) {
        self.placeholder = placeholder
        _text = text
        self.accessibilityLabel = accessibilityLabel
        self.onSubmit = onSubmit
    }

    var body: some View {
        HStack {
            Image(systemName: Tokens.Icons.globalSearch)
                .foregroundStyle(Tokens.Colors.globalTextSecondary)
                .accessibilityHidden(true)
            TextField(text: $text, prompt: Text(placeholder).foregroundStyle(Tokens.Colors.globalTextSecondary)) {
                Text(accessibilityLabel)
            }
            .foregroundStyle(Tokens.Colors.globalTextPrimary)
            .submitLabel(.search)
            .onSubmit(onSubmit)
            .accessibilityLabel(Text(accessibilityLabel))
            .accessibilityAddTraits(.isSearchField)
        }
        .dsTextStyle(TextRole.placeholder)
        .padding(.horizontal)
        .frame(maxWidth: .infinity, minHeight: Tokens.Sizes.globalFieldHeight)
        .background(Tokens.Colors.globalControl, in: DSShape.rounded(Tokens.Radii.globalField))
    }
}
