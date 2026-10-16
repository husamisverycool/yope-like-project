// Social group — sheet parts shared by week.recap, week.edit and albums.view: the sheet header with the C-11 close
// circle at the leading margin (Retro's "Create Recap" / "New Album" sheets), and the name sheet (week.edit's "New
// Album", albums.view's "Rename Album"). Specs: design/surfaces/week.recap.md "Structure A", week.edit.md "Album sheet",
// albums.view.md "Rename sheet". References: references/auto/retro/press/tc-2023-12-recaps.png phone 1 (close circle,
// centred title), references/auto/retro/apk/retro-android-2026.10.1150-strings.txt ("New Album", "Name your album",
// "Create Album", "Name missing").
import DesignSystem
import SwiftUI

/// A sheet header: the C-11 close circle (`size.global.circleButton`, `color.global.control`, `icon.global.close`) at the
/// leading margin and the title centred (text role `sheetTitle`, header trait). (The shared `SheetHeader` puts its
/// close circle at the trailing edge; Retro's recap and album sheets lead with it.)
struct LeadingCloseSheetHeader: View {
    let title: String
    let closeAccessibilityLabel: String
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Text(title)
                .dsTextStyle(TextRole.sheetTitle)
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, Tokens.Sizes.globalCircleButton + Tokens.Sizes.globalPillGap)
            HStack {
                CircleButton(icon: Tokens.Icons.globalClose, accessibilityLabel: closeAccessibilityLabel, style: .page, action: onClose)
                Spacer(minLength: 0)
            }
        }
        .frame(minHeight: Tokens.Sizes.globalMinTouchTargetIos)
        .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
    }
}

/// The name sheet (C-29): the leading close circle and the centred title; `size.global.titleToContent` below, the C-12
/// field (placeholder, prefilled when renaming) with the inline error (`week.edit.error.albumName`, text role `meta`,
/// `color.global.destructive`) when submitted empty; the C-05 primary capsule (`size.global.buttonHeightSheet`,
/// `size.global.buttonMarginHSheet`) at the bottom above the keyboard, disabled (`color.global.controlRaised`) while it
/// cannot save; busy while saving.
struct SocialNameSheet: View {
    let title: String
    let placeholder: String
    let buttonTitle: String
    @Binding var name: String
    let isEnabled: Bool
    let isBusy: Bool
    let showsMissingName: Bool
    let closeAccessibilityLabel: String
    let onNameChange: () -> Void
    let onSave: () -> Void
    let onClose: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            LeadingCloseSheetHeader(title: title, closeAccessibilityLabel: closeAccessibilityLabel, onClose: onClose)
                .padding(.top, Tokens.Sizes.globalScreenMargin)
            FormField(
                placeholder,
                text: $name,
                accessibilityLabel: placeholder,
                submitLabel: .done,
                errorMessage: showsMissingName ? Copy.weekEditErrorAlbumName : nil,
                onSubmit: onSave
            )
            .focused($focused)
            .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
            .padding(.top, Tokens.Sizes.globalTitleToContent)
            .onChange(of: name) { _, _ in onNameChange() }
            Spacer(minLength: 0)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PrimaryButton(buttonTitle, height: .sheet, isEnabled: isEnabled, isBusy: isBusy, action: onSave)
                .padding(.horizontal, Tokens.Sizes.globalButtonMarginHSheet)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Tokens.Colors.globalBackground.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .dsSheetBackground()
        .onAppear { focused = true }
    }
}
