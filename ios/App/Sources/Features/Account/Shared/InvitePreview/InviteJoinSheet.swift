// Surface: invite.appclip — the join sheet (Partiful's RSVP sheet P4 without its Going / Maybe / Can't Go choices):
// name, phone, helper line, Cancel / Continue; then the SMS code step (auth.code) and `join_group`.
// Reference images: references/auto/partiful/web/pf-web-public-light-rsvp-sheet.png, pf-web-public-dark-rsvp-sheet.png (P4).
import DesignSystem
import SwiftUI

struct InviteJoinSheet: View {
    let theme: InviteTheme
    @Binding var name: String
    @Binding var phone: String
    let isSending: Bool
    let onCancel: () -> Void
    let onContinue: () -> Void

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name
        case phone
    }

    /// `invite.appclip.fontSize.sheetInput` (title2) / `.sheetHelper` (subheadline).
    private static let inputStyle = DSTextStyle(family: Tokens.Fonts.inviteWebFont, size: Tokens.FontSizes.inviteAppclipFontSizeSheetInput, weight: Tokens.FontWeights.inviteWebFontWeightBody, relativeTo: .title2)
    private static let helperStyle = DSTextStyle(family: Tokens.Fonts.inviteWebFont, size: Tokens.FontSizes.inviteAppclipFontSizeSheetHelper, weight: Tokens.FontWeights.inviteWebFontWeightBody, relativeTo: .subheadline)

    var canContinue: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && PhoneNumberInput.hasSubscriberDigits(phone) && !isSending
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Sizes.inviteWebDimensionSectionGap) {
            field(Copy.inviteAppclipSheetName, text: $name, field: .name)
                .textContentType(.name)
                .submitLabel(.next)
                .onSubmit { focusedField = .phone }
            field(Copy.inviteAppclipSheetPhone, text: $phone, field: .phone)
                .textContentType(.telephoneNumber)
                .keyboardType(.phonePad)
            Text(Copy.inviteAppclipSheetHelper)
                .dsTextStyle(Self.helperStyle)
                .foregroundStyle(theme.text.opacity(theme.helperOpacity))
            HStack(spacing: Tokens.Sizes.inviteWebDimensionButtonGap) {
                Button(action: onCancel) {
                    Text(Copy.inviteAppclipSheetCancel)
                        .dsTextStyle(InviteStyle.bodyButton)
                        .foregroundStyle(theme.text)
                        .padding(.horizontal, Tokens.Sizes.inviteWebDimensionButtonLargePaddingH)
                        .frame(minHeight: Tokens.Sizes.inviteWebDimensionButtonLargeHeight)
                }
                .buttonStyle(InvitePressStyle())
                if isSending {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: Tokens.Sizes.inviteWebDimensionButtonLargeHeight)
                } else {
                    InviteFilledButton(title: Copy.inviteAppclipSheetContinue, theme: theme, action: onContinue)
                        .disabled(!canContinue)
                        .accessibilityIdentifier("invite.sheet.continue")
                }
            }
        }
        .padding(Tokens.Sizes.inviteWebDimensionMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(theme.background.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear { focusedField = .name }
        .accessibilityIdentifier("invite.sheet")
    }

    /// Visible placeholder; the accessibility label equals it (invite.appclip Accessibility).
    private func field(_ placeholder: String, text: Binding<String>, field: Field) -> some View {
        TextField(text: text, prompt: Text(placeholder).foregroundStyle(theme.text.opacity(theme.placeholderOpacity))) {
            Text(placeholder)
        }
        .dsTextStyle(Self.inputStyle)
        .foregroundStyle(theme.text)
        .focused($focusedField, equals: field)
    }
}
