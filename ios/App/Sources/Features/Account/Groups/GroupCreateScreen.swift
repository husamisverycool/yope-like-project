// Surface: groups.create — create a group: type, cover, name (also edit mode from groups.settings). Visual reference:
// Retro "Ideas to Get Started" templates (references/auto/retro/press/jeddacp-2024-05-home-profile-journals.png phone 3,
// JED), the album-detail book cover and its shadow (references/auto/retro/press/tc-2024-04-journals-1.webp phone 3,
// TC-J1) and the Settings sheet header (references/auto/retro/video/ig-DJXvmqRv2_N-referrals-sheet-f042-059.png,
// VID-SET); the New Album form was not captured — composition of C-29, C-15, the cover, C-07, C-12, C-05 in Retro's New
// Album order (design/surfaces/groups.create.md).
import AppData
import AppModels
import DesignSystem
import Observation
import PhotosUI
import SwiftUI
import UIKit

/// groups.create sheet (large detent). `kind`: chosen on a groups.list template row (starts at step B).
struct GroupCreateScreen: View {
    let editingGroupID: String?
    var kind: GroupKind?
    @Environment(AccountDependencies.self) private var dependencies

    init(editingGroupID: String?, kind: GroupKind? = nil) {
        self.editingGroupID = editingGroupID
        self.kind = kind
    }

    var body: some View {
        GroupCreateView(model: GroupCreateModel(data: dependencies.data, editingGroupID: editingGroupID.map { GroupID($0) }, kind: kind))
    }
}

struct GroupCreateView: View {
    @State private var model: GroupCreateModel
    @State private var path: [GroupCreateModel.Step] = []
    /// Step A is the stack's root (opened from the header glyph or the empty state); otherwise step B is.
    @State private var startsWithType: Bool
    @Environment(AccountDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss

    init(model: GroupCreateModel) {
        _model = State(initialValue: model)
        _startsWithType = State(initialValue: model.step == .type)
    }

    /// True when this sheet is the router's modal; false when another surface hosts it (camera.sendto presents
    /// `AccountModalDestination(.groupCreate)` over send-to, which must keep the capture; groups.settings presents the
    /// edit form over its own sheet).
    private var isRouterModal: Bool {
        switch dependencies.router.modal {
        case .account(.groupCreate)?, .account(.groupEdit)?, .account(.groupCreateKind)?: return true
        default: return false
        }
    }

    private func close() {
        if isRouterModal {
            dependencies.router.modal = nil
        } else {
            dismiss()
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            root
                .navigationDestination(for: GroupCreateModel.Step.self) { _ in
                    GroupCreateDetails(model: model, showsBack: true, onClose: close, onSubmit: submit)
                }
        }
        .presentationDetents([.large])
        .dsSheetBackground()
        .dsHaptic(Tokens.Haptics.globalSelect, trigger: model.kindChoiceCount)
        .task { await model.loadForEdit() }
        .accessibilityIdentifier("groups.create")
    }

    @ViewBuilder
    private var root: some View {
        if startsWithType {
            GroupCreateTypeStep(onClose: close) { kind in
                model.choose(kind)
                path = [.details]
            }
        } else {
            GroupCreateDetails(model: model, showsBack: false, onClose: close, onSubmit: submit)
        }
    }

    /// After create: the sheet closes and the new group is pushed (groups.create Motion); hosted by another surface, the
    /// sheet only closes (that surface refreshes its groups).
    private func submit() async {
        AccessibilityNotification.Announcement(Copy.groupsCreateCreating).post()
        guard let group = await model.submit() else { return }
        guard isRouterModal else {
            dismiss()
            return
        }
        let router = dependencies.router
        router.modal = nil
        if !model.isEditing {
            router.path.append(.group(id: group.id.rawValue))
        }
    }
}

/// The sheet header of groups.create (C-29): the centred title (text role `sheetTitle`) with the close circle (C-11 on
/// the page); on step B after step A, the C-02 back chevron leads.
private struct GroupCreateHeader: View {
    let title: String
    var onBack: (() -> Void)?
    let onClose: () -> Void

    var body: some View {
        SheetHeader(title: title, closeAccessibilityLabel: Copy.groupsCreateCloseAccessibilityLabel, onClose: onClose)
            .overlay(alignment: .leading) {
                if let onBack {
                    FormBackButton(accessibilityLabel: Copy.groupsCreateBackAccessibilityLabel, identifier: "groups.create.back", action: onBack)
                }
            }
            .accessibilityIdentifier("groups.create.header")
    }
}

/// Step A — type: the question in the display serif (text role `displayMedium`) `size.global.titleToContent` under the
/// header, then the four template rows (`GroupTemplateRow`, `size.global.listGap` apart) `size.global.titleToContent`
/// below. Choosing a row (or its "Create") → step B with that kind.
private struct GroupCreateTypeStep: View {
    let onClose: () -> Void
    let onChoose: (GroupKind) -> Void

    var body: some View {
        VStack(spacing: 0) {
            GroupCreateHeader(title: Copy.groupsCreateTitle, onClose: onClose)
            ScrollView {
                MetricStack {
                    Text(Copy.groupsCreateTypeLabel)
                        .dsTextRole(TextRole.displayMedium)
                        .foregroundStyle(Tokens.Colors.globalTextPrimary)
                        .accessibilityAddTraits(.isHeader)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
                        .metricGap(Tokens.Sizes.globalTitleToContent, from: .top, to: .capTop)
                    ThumbnailRowList {
                        ForEach(GroupKindCopy.kinds, id: \.self) { kind in
                            GroupTemplateRow(kind: kind) { onChoose(kind) }
                        }
                    }
                    .metricGap(Tokens.Sizes.globalTitleToContent, from: .lastBaseline, to: .top)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(Tokens.Colors.globalBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityIdentifier("groups.create.type")
    }
}

/// Step B — cover and name: the book cover (`groups.screen.size.coverWidth` × `.coverHeight`, `radius.global.thumbnail`,
/// shadow `groups.screen.shadow.cover`; empty = `color.global.control`) `size.global.titleToContent` under the header;
/// `groups.screen.size.coverToTitle` below it the cover CTA (C-07 "+ Add cover image" while empty, C-06 outline "Edit cover
/// image" once chosen); `size.global.titleToContent` below the name field (C-12, inline "Name too long"); C-05 "Create
/// Group" / "Save" pinned `size.global.buttonMarginH` above the keyboard. Creating: the capsule is busy and the fields
/// are disabled; failures show the message-only alert.
private struct GroupCreateDetails: View {
    @Bindable var model: GroupCreateModel
    let showsBack: Bool
    let onClose: () -> Void
    let onSubmit: () async -> Void

    @State private var pickerItem: PhotosPickerItem?
    @State private var picking = false
    @Environment(\.dismiss) private var dismiss

    private static let coverFade = DSAnimation.timing(duration: Tokens.Durations.globalFade, easing: Tokens.Easings.globalStandard)

    var body: some View {
        VStack(spacing: 0) {
            GroupCreateHeader(
                title: model.isEditing ? Copy.groupsCreateTitleEdit : Copy.groupsCreateTitle,
                onBack: showsBack ? back : nil,
                onClose: onClose
            )
            ScrollView {
                MetricStack(alignment: .center) {
                    cover
                        .metricGap(Tokens.Sizes.globalTitleToContent, from: .top, to: .top)
                    coverAction
                        .metricGap(Tokens.Sizes.groupsScreenSizeCoverToTitle, from: .bottom, to: .top)
                    FormField(
                        Copy.groupsCreateNamePlaceholder,
                        text: Binding(get: { model.name }, set: { model.setName($0) }),
                        accessibilityLabel: Copy.groupsCreateNameAccessibilityLabel,
                        errorMessage: model.isNameTooLong ? Copy.groupsCreateErrorTooLong : nil
                    )
                    .disabled(model.isWorking)
                    .accessibilityIdentifier("groups.create.name")
                    .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
                    .metricGap(Tokens.Sizes.globalTitleToContent, from: .bottom, to: .top)
                }
                .padding(.bottom, Tokens.Sizes.globalButtonMarginH)
            }
            .scrollBounceBehavior(.basedOnSize)
            PrimaryButton(
                model.isEditing ? Copy.groupsCreateSave : Copy.groupsCreateCta,
                height: .sheet,
                isEnabled: !model.trimmedName.isEmpty && !model.isNameTooLong,
                isBusy: model.isWorking
            ) {
                Task { await onSubmit() }
            }
            .accessibilityIdentifier("groups.create.submit")
            .padding(.horizontal, Tokens.Sizes.globalButtonMarginHSheet)
            .padding(.bottom, Tokens.Sizes.globalButtonMarginHSheet)
        }
        .background(Tokens.Colors.globalBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .photosPicker(isPresented: $picking, selection: $pickerItem, matching: .images, preferredItemEncoding: .compatible)
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    model.setCover(imageData: data)
                }
                pickerItem = nil
            }
        }
        .dsHaptic(Tokens.Haptics.globalSuccess, trigger: model.successCount)
        .dsHaptic(Tokens.Haptics.globalError, trigger: model.errorCount)
        .formErrorAlert(model.failureMessage, trigger: model.errorCount)
        .accessibilityIdentifier("groups.create.details")
    }

    /// Back to step A (a native pop inside the sheet).
    private func back() {
        model.backToType()
        dismiss()
    }

    private var cover: some View {
        Button {
            picking = true
        } label: {
            GroupCover(
                source: model.coverImage.map { PhotoSource.image($0) } ?? model.existingCoverPath.map { PhotoSource.storage($0) },
                width: Tokens.Sizes.groupsScreenSizeCoverWidth,
                height: Tokens.Sizes.groupsScreenSizeCoverHeight,
                showsGroupGlyph: false
            )
            .dsAnimation(Self.coverFade, value: model.hasCover)
        }
        .buttonStyle(.plain)
        .disabled(model.isWorking)
        .accessibilityLabel(Text(model.hasCover ? Copy.groupsCreateCoverChangeAccessibilityLabel : Copy.groupsCreateCoverAccessibilityLabel))
        .accessibilityAddTraits(.isImage)
        .accessibilityIdentifier("groups.create.cover")
    }

    @ViewBuilder
    private var coverAction: some View {
        if model.hasCover {
            CapsuleButton(Copy.groupsCreateCoverEdit, style: .outline) { picking = true }
                .fixedSize()
                .disabled(model.isWorking)
        } else {
            OutlineCTA(Copy.groupsCreateCoverAdd) { picking = true }
                .fixedSize()
                .disabled(model.isWorking)
        }
    }
}

/// The group's book cover (TC-J1): `width` × `height`, corners `radius.global.thumbnail` (continuous), drop shadow
/// `groups.screen.shadow.cover` (measured in light; invisible on black — groups.screen Gaps), the photo aspect-fill;
/// without a photo `color.global.control`, with `icon.global.group` in `color.global.textSecondary` when
/// `showsGroupGlyph` (groups.screen). Decorative: the caller labels it.
struct GroupCover: View {
    let source: PhotoSource?
    let width: CGFloat
    let height: CGFloat
    var showsGroupGlyph = true

    var body: some View {
        ZStack {
            Tokens.Colors.globalControl
            if source != nil {
                PhotoView(source: source)
            } else if showsGroupGlyph {
                Glyph(Tokens.Icons.globalGroup)
                    .foregroundStyle(Tokens.Colors.globalTextSecondary)
            }
        }
        .frame(width: width, height: height)
        .clipShape(DSShape.rounded(Tokens.Radii.globalThumbnail))
        .dsShadow(Tokens.Shadows.groupsScreenShadowCover)
    }
}
