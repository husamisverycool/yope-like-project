// Shared component — C-29 sheets, menus, alerts and other native components (design/components.md). Native components
// stay native (PLATFORM): `.sheet` / `.confirmationDialog` / `Menu` / `.alert` / `ShareLink` / `Toggle` / pickers, with
// destructive items as `Button(role: .destructive)`. This file holds the app-drawn parts: the sheet header, the native
// toolbar header, the sheet background and the feature-intro content. Evidence: VID-SET, VID-COMP (sheet motion VM §A,
// §C), TC-R3 phone 1 (feature-intro sheet), TC-RWP (menu); RV §4 #14, #16, #20; RP §5.1.
import DesignSystem
import SwiftUI

/// A sheet / modal header: the title centred (text role `sheetTitle`, `color.global.textPrimary`, header trait) with an
/// optional trailing close circle (C-11 `.page`: #F1F1F1 on light sheets, #262626 on dark; `icon.global.close`). Inset
/// `size.global.screenMargin`; at least `size.global.minTouchTarget.ios` tall. Vertical placement in the sheet was not
/// measured (Gap) — the caller stacks it at the top of the sheet's content.
struct SheetHeader: View {
    let title: String
    var closeAccessibilityLabel: String?
    var onClose: (() -> Void)?

    init(title: String, closeAccessibilityLabel: String? = nil, onClose: (() -> Void)? = nil) {
        self.title = title
        self.closeAccessibilityLabel = closeAccessibilityLabel
        self.onClose = onClose
    }

    var body: some View {
        ZStack {
            Text(title)
                .dsTextStyle(TextRole.sheetTitle)
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
                // Keeps the centred title clear of the close circle on both sides.
                .padding(.horizontal, Tokens.Sizes.globalCircleButton)
            if let onClose, let closeAccessibilityLabel {
                HStack {
                    Spacer(minLength: 0)
                    CircleButton(icon: Tokens.Icons.globalClose, accessibilityLabel: closeAccessibilityLabel, style: .page, action: onClose)
                }
            }
        }
        .frame(minHeight: Tokens.Sizes.globalMinTouchTargetIos)
        .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
    }
}

extension View {
    /// The native sheet toolbar 'Cancel / Title / Update' (VID-COMP): an inline navigation title and system text buttons
    /// in the tint `color.global.selection` (PLATFORM). Use inside a `NavigationStack` in the sheet.
    func sheetToolbar(
        title: String,
        cancelTitle: String,
        onCancel: @escaping () -> Void,
        confirmTitle: String? = nil,
        isConfirmEnabled: Bool = true,
        onConfirm: (() -> Void)? = nil
    ) -> some View {
        navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(cancelTitle, action: onCancel)
                }
                if let confirmTitle, let onConfirm {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(confirmTitle, action: onConfirm)
                            .disabled(!isConfirmEnabled)
                    }
                }
            }
            .tint(Tokens.Colors.globalSelection)
    }

    /// The content background of a native sheet: `color.global.background` (follows the appearance; corners
    /// `radius.global.sheet` are the system's).
    func dsSheetBackground() -> some View {
        presentationBackground(Tokens.Colors.globalBackground)
    }
}

/// One row of the feature-intro sheet: a leading outline glyph and a line of text (text role `body`,
/// `color.global.textSecondary`).
struct FeatureIntroRow {
    let icon: String
    let text: String

    init(icon: String, text: String) {
        self.icon = icon
        self.text = text
    }
}

/// The feature-intro sheet's content (2023, TC-R3 phone 1): an icon tile slot (`art`, owner art ≈64 pt — Gap), the title
/// (text role `sheetTitle`), rows of grey text each with a leading outline glyph (measured 20 pt; no token — the
/// `size.global.icon` box), and the full-width primary capsule (C-05). Present it in a native sheet
/// (`.dsSheetBackground()`); Retro's sheet floats `size.global.featureSheetInset` in from the screen edges, which the
/// system sheet draws only where the platform floats sheets (its corners are the system's). Spacing between the parts
/// was not measured (Gap) — platform stack spacing; content inset `size.global.buttonMarginH`.
struct FeatureIntroSheet<Art: View>: View {
    @ViewBuilder let art: () -> Art
    let title: String
    let rows: [FeatureIntroRow]
    let buttonTitle: String
    let onButton: () -> Void

    init(
        title: String,
        rows: [FeatureIntroRow],
        buttonTitle: String,
        onButton: @escaping () -> Void,
        @ViewBuilder art: @escaping () -> Art
    ) {
        self.title = title
        self.rows = rows
        self.buttonTitle = buttonTitle
        self.onButton = onButton
        self.art = art
    }

    var body: some View {
        VStack {
            art()
            Text(title)
                .dsTextStyle(TextRole.sheetTitle)
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading) {
                ForEach(rows.indices, id: \.self) { index in
                    HStack(alignment: .top) {
                        Glyph(rows[index].icon, relativeTo: TextRole.body.relativeTo)
                            .foregroundStyle(Tokens.Colors.globalTextPrimary)
                        Text(rows[index].text)
                            .dsTextStyle(TextRole.body)
                            .foregroundStyle(Tokens.Colors.globalTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            PrimaryButton(buttonTitle, height: .sheet, action: onButton)
        }
        .padding(.horizontal, Tokens.Sizes.globalButtonMarginHSheet)
        .frame(maxWidth: .infinity)
        .background(Tokens.Colors.globalBackground)
    }
}

extension FeatureIntroSheet where Art == EmptyView {
    init(title: String, rows: [FeatureIntroRow], buttonTitle: String, onButton: @escaping () -> Void) {
        self.init(title: title, rows: rows, buttonTitle: buttonTitle, onButton: onButton) { EmptyView() }
    }
}
