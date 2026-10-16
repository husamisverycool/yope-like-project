// Surface: camera.overnight, part A — the mode control, the destination pill and the destination sheet on
// camera.capture. Visual reference Retro, by composition only: C-30 native segmented control on a black page
// (references/auto/retro/press/tc-2023-12-recaps.png, TC-REC), C-09 pill on media (references/auto/retro/store/
// retro-store-03.png, ST-03), C-29 native sheet with camera.sendto's group rows. Mechanics: Dispo's 9AM · NOW switch
// and roll drawer (references/auto/dispo/store/dispo-store-X-1.png, references/auto/dispo/help/
// help-4410178185492_userguide-nov21.png). Spec: design/surfaces/camera.overnight.md (A); MERGE_DECISIONS ON-1 … ON-7.
import DesignSystem
import SwiftUI

/// `camera.overnight.layout.modeControl`: the C-30 native segmented control "9 AM" · "Now" (`SegmentedPills`), full
/// width inside `size.global.screenMargin`, drawn by the system in the camera's dark appearance; a change plays
/// `haptic.global.select`. Label `camera.overnight.a11y.mode`, hint `camera.overnight.a11y.modeHint`; the platform
/// announces the selection. The caller places it `size.global.titleToContent` below the header title's baseline (the
/// header's bottom) and the viewfinder `size.global.sectionHeaderToContent` below it.
struct OvernightModeControl: View {
    let model: OvernightCaptureModel

    var body: some View {
        SegmentedPills(
            options: OvernightCaptureModel.Mode.allCases.map { SegmentOption($0, title: model.title(of: $0)) },
            selection: Binding(get: { model.mode }, set: { model.setMode($0) }),
            accessibilityLabel: Copy.cameraOvernightA11yMode
        )
        .accessibilityHint(Text(Copy.cameraOvernightA11yModeHint(time: OvernightReveal.timeText())))
        .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
        .accessibilityIdentifier("camera.overnight.mode") // provenance-ok: accessibility identifier for UI tests
    }
}

/// `camera.overnight.layout.destinationPill`: C-09 on media (`color.global.controlOnDeep`, `icon.global.group` at
/// `size.global.iconSmall`, label text role `pill` in `color.global.textOnMedia`, `size.global.pillHeight`, the pill
/// paddings and icon gap — `LightPill`'s dark style), hugging its label up to the viewfinder width less
/// `size.global.screenMargin` on each side (one line, truncated at the end), centred, its bottom
/// `camera.sendto.layout.messageField` bottomInset (20.5) above the viewfinder bottom (the coach pill's slot). Tap →
/// the destination sheet.
struct OvernightDestinationPill: View {
    let model: OvernightCaptureModel
    let viewfinderWidth: CGFloat

    var body: some View {
        LightPill(model.pillLabel, icon: Tokens.Icons.globalGroup, style: .dark) {
            model.isDestinationOpen = true
        }
        .lineLimit(1)
        .frame(maxWidth: max(0, viewfinderWidth - 2 * Tokens.Sizes.globalScreenMargin))
        .fixedSize(horizontal: false, vertical: true)
        .padding(.bottom, Tokens.Layouts.CameraSendtoLayoutMessageField.bottomInset)
        .accessibilityHint(Text(Copy.cameraOvernightA11yDestinationHint))
        .accessibilityIdentifier("camera.overnight.destination") // provenance-ok: accessibility identifier for UI tests
    }
}

/// `camera.overnight.layout.destinationSheet`: a native sheet (C-29) that follows the appearance — Dispo's roll drawer
/// drawn with camera.sendto's rows: toolbar title `camera.overnight.destination.title` (text role `sheetTitle`) and the
/// C-08 "Done"; the explanation `camera.overnight.destination.detail` ({reveal}; text role `body`,
/// `color.global.textSecondary`, at most two lines, `size.global.screenMargin` margins); one
/// `camera.sendto.layout.recipientRow` per group (cover circle, name, check circle; C-32 between rows) in the sheet's
/// colours, every group selected by default. No groups: camera.sendto's empty state (C-27). Done (or a swipe down)
/// keeps the choice for the session; with nothing selected the camera goes back to Now.
struct OvernightDestinationSheet: View {
    let model: OvernightCaptureModel
    var canCreateGroup = true

    @State private var isCreatingGroup = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(model.detailText)
                        .dsTextStyle(TextRole.body)
                        .foregroundStyle(Tokens.Colors.globalTextSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(Tokens.Sizes.globalScreenMargin)
                        .accessibilityIdentifier("camera.overnight.destination.detail") // provenance-ok: accessibility identifier for UI tests
                    groups
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Tokens.Colors.globalBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(Copy.cameraOvernightDestinationTitle)
                        .dsTextStyle(TextRole.sheetTitle)
                        .foregroundStyle(Tokens.Colors.globalTextPrimary)
                        .accessibilityAddTraits(.isHeader)
                }
                ToolbarItem(placement: .confirmationAction) {
                    TextButton(Copy.cameraOvernightDestinationDone) { model.destinationClosed() }
                        .accessibilityIdentifier("camera.overnight.destination.done") // provenance-ok: accessibility identifier for UI tests
                }
            }
        }
        .dsHaptic(Tokens.Haptics.globalSelect, trigger: model.selectionChanges)
        .dsSheetBackground()
        .presentationDragIndicator(.visible)
        // groups.create (account group) over the sheet; the list reloads after.
        .sheet(isPresented: $isCreatingGroup, onDismiss: { Task { await model.loadGroups() } }) {
            AccountModalDestination(modal: .groupCreate)
        }
        .accessibilityIdentifier("camera.overnight.destinationSheet") // provenance-ok: accessibility identifier for UI tests
    }

    @ViewBuilder
    private var groups: some View {
        let row = Tokens.Layouts.CameraSendtoLayoutRecipientRow.padding
        switch model.listState {
        case .idle:
            Color.clear.frame(height: 0)
        case .loading:
            LoadingHUD()
                .frame(maxWidth: .infinity)
                .padding(.vertical, row)
        case .empty:
            EmptyStateView(
                icon: Tokens.Icons.globalGroup,
                title: Copy.cameraSendtoEmptyTitle,
                detail: Copy.cameraSendtoEmptyDetail,
                action: canCreateGroup ? EmptyStateView.Action(Copy.cameraSendtoEmptyButton) { isCreatingGroup = true } : nil
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, row)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("camera.overnight.destination.empty") // provenance-ok: accessibility identifier for UI tests
        case .offline, .failed:
            EmptyStateView(
                title: nil,
                detail: model.listState == .offline ? Copy.cameraSendtoErrorOffline : Copy.cameraSendtoErrorGeneric,
                action: EmptyStateView.Action(Copy.cameraSendtoErrorRetry) { Task { await model.loadGroups() } }
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, row)
        case .loaded:
            VStack(spacing: 0) {
                ForEach(Array(model.groups.enumerated()), id: \.element.id) { index, group in
                    if index > 0 {
                        HairlineDivider()
                            .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
                    }
                    SendToGroupRow(
                        group: group,
                        cover: model.covers[group.id],
                        isSelected: model.isSelected(group.id),
                        onToggle: { model.toggle(group.id) },
                        onMedia: false,
                        identifierPrefix: "camera.overnight.row." // provenance-ok: accessibility identifier for UI tests
                    )
                }
            }
        }
    }
}
