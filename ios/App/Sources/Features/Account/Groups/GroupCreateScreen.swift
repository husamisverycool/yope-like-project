// Surface: groups.create — create group: name, cover, type (also edit mode from groups.settings). Reference app: Yope
// ("new group" sheet 2026; cover step 2024–2025; design/surfaces/groups.create.md). Reference images:
// references/auto/yope/frames/a-itsmthuyope-7644974799302823175-t45.23-new-group-empty.png (NG1), …-t49.23-new-group-selected-create.png
// (NG2), a-yrrah-7452976839846382855-t3.73-create-new-group-empty-2024.png (C24), references/auto/yope/web/a-bi-2025-create-group-composite.jpg
// (BI), a-itsmthuyope-…-t51.73-group-profile-add-20-pics.png (GP), …-t50.60-loading-hud.png (HUD).
import AppData
import AppModels
import DesignSystem
import Observation
import PhotosUI
import SwiftUI
import UIKit

@MainActor
@Observable
final class GroupCreateModel {
    /// Nil: create; else the group being edited (admins).
    let editingGroupID: GroupID?
    private(set) var name = ""
    var kind: GroupKind = .friends
    /// The picked cover (fills the rectangle) and its upload-ready JPEG.
    private(set) var coverImage: UIImage?
    private var coverJPEG: Data?
    /// Edit mode: the group's current cover.
    private(set) var existingCoverPath: String?
    private(set) var isWorking = false
    /// Last failure copy (`groups.create.error.*`, `groups.create.offline`; presentation BLOCKED, announced).
    private(set) var failureMessage: String?
    private(set) var successCount = 0
    private(set) var errorCount = 0

    static let maxNameLength = 80
    /// The four types in `group_kind` order (friends is the default, the first segment).
    static let kinds: [GroupKind] = [.friends, .family, .roommates, .custom]

    private let data: AccountDataSource

    init(data: AccountDataSource, editingGroupID: GroupID? = nil) {
        self.data = data
        self.editingGroupID = editingGroupID
    }

    var isEditing: Bool { editingGroupID != nil }
    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    var canSubmit: Bool { !trimmedName.isEmpty && !isWorking }
    var hasCover: Bool { coverImage != nil || existingCoverPath != nil }

    func setName(_ value: String) {
        name = String(value.prefix(Self.maxNameLength))
    }

    /// Edit mode: prefill from the group.
    func loadForEdit() async {
        guard let editingGroupID, let group = try? await data.group(id: editingGroupID) else { return }
        name = group.name
        kind = Self.kinds.contains(group.kind) ? group.kind : .custom
        existingCoverPath = group.coverPath
    }

    func setCover(imageData: Data) {
        guard let jpeg = try? UploadImage.jpeg(from: imageData), let image = UIImage(data: jpeg) else {
            fail(Copy.groupsCreateErrorCover)
            return
        }
        coverJPEG = jpeg
        coverImage = image
    }

    /// Uploads the cover (if picked), then `create_group` / `update_group`. Returns the group when done.
    func submit() async -> PhotoGroup? {
        guard canSubmit else { return nil }
        failureMessage = nil
        isWorking = true
        defer { isWorking = false }
        var coverPath: String?
        if let coverJPEG {
            do {
                coverPath = try await data.uploadCover(jpeg: coverJPEG)
            } catch {
                // "cover upload failed": the cover returns to the placeholder.
                self.coverJPEG = nil
                coverImage = nil
                fail(DataError.from(error) == .offline ? Copy.groupsCreateOffline : Copy.groupsCreateErrorCover)
                return nil
            }
        }
        do {
            let group: PhotoGroup
            if let editingGroupID {
                group = try await data.updateGroup(
                    id: editingGroupID,
                    name: trimmedName,
                    kind: kind,
                    cover: coverPath.map(CoverChange.set) ?? .unchanged
                )
            } else {
                group = try await data.createGroup(name: trimmedName, kind: kind, coverPath: coverPath)
            }
            successCount += 1
            return group
        } catch {
            if DataError.from(error) == .offline {
                fail(Copy.groupsCreateOffline)
            } else {
                fail(isEditing ? Copy.groupsCreateErrorSaveFailed : Copy.groupsCreateErrorFailed)
            }
            return nil
        }
    }

    private func fail(_ message: String) {
        failureMessage = message
        errorCount += 1
        UIAccessibility.post(notification: .announcement, argument: message)
    }

    static func title(of kind: GroupKind) -> String {
        switch kind {
        case .family: return Copy.groupsCreateTypeFamily
        case .roommates: return Copy.groupsCreateTypeRoommates
        case .custom, .unknown: return Copy.groupsCreateTypeCustom
        case .friends: return Copy.groupsCreateTypeFriends
        }
    }
}

/// groups.create sheet (large detent).
struct GroupCreateScreen: View {
    let editingGroupID: String?
    @Environment(AccountDependencies.self) private var dependencies

    var body: some View {
        GroupCreateView(model: GroupCreateModel(data: dependencies.data, editingGroupID: editingGroupID.map(GroupID.init)))
    }
}

struct GroupCreateView: View {
    @State private var model: GroupCreateModel
    @State private var pickerItem: PhotosPickerItem?
    @Environment(AccountDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss

    init(model: GroupCreateModel) {
        _model = State(initialValue: model)
    }

    /// True when this sheet is the router's modal; false when another surface hosts it (camera.sendto presents
    /// `AccountModalDestination(.groupCreate)` over send-to, which must keep the capture).
    private var isRouterModal: Bool {
        switch dependencies.router.modal {
        case .account(.groupCreate)?, .account(.groupEdit)?: return true
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

    private static let titleStyle = DSTextStyle(
        family: Tokens.Fonts.globalFamily,
        size: Tokens.FontSizes.groupsCreateFontSizeTitle,
        weight: Tokens.FontWeights.groupsCreateFontWeightTitle,
        relativeTo: .subheadline
    )

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 0) {
                    cover
                        .padding(.top, Tokens.Sizes.groupsCreateSizeTitleToContent)
                    FormField(
                        Copy.groupsCreateNamePlaceholder,
                        text: Binding(get: { model.name }, set: { model.setName($0) }),
                        accessibilityLabel: Copy.groupsCreateNameAccessibilityLabel
                    )
                    .accessibilityIdentifier("groups.create.name")
                    .padding(.top, Tokens.Sizes.groupsCreateSizeMediaToField)
                    Text(Copy.groupsCreateTypeLabel)
                        .dsTextStyle(TextRole.sectionLabel)
                        .foregroundStyle(Tokens.Colors.globalTextSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, Tokens.Sizes.groupsCreateSizeMediaToField)
                    SegmentedPills(
                        options: GroupCreateModel.kinds.map { SegmentOption($0, title: GroupCreateModel.title(of: $0)) },
                        selection: $model.kind
                    )
                    .accessibilityIdentifier("groups.create.type")
                }
                .padding(.horizontal, Tokens.Sizes.globalButtonMarginH)
            }
            .scrollBounceBehavior(.basedOnSize)
            PrimaryButton(model.isEditing ? Copy.groupsCreateSave : Copy.groupsCreateCta, isEnabled: model.canSubmit) {
                Task { await submit() }
            }
            .accessibilityIdentifier("groups.create.submit")
            .padding(.horizontal, Tokens.Sizes.globalButtonMarginH)
            .padding(.vertical, Tokens.Sizes.groupsCreateSizeFieldToButton)
        }
        .background(Tokens.Colors.globalBackgroundDeep.ignoresSafeArea())
        .loadingHUD(model.isWorking)
        .dsHaptic(Tokens.Haptics.globalSuccess, trigger: model.successCount)
        .dsHaptic(Tokens.Haptics.globalError, trigger: model.errorCount)
        .presentationDetents([.large])
        .task { await model.loadForEdit() }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    model.setCover(imageData: data)
                }
                pickerItem = nil
            }
        }
        .accessibilityIdentifier("groups.create")
    }

    /// ✕ circle leading; title centred on the circle's row.
    private var header: some View {
        ZStack {
            Text(model.isEditing ? Copy.groupsCreateTitleEdit : Copy.groupsCreateTitle)
                .dsTextStyle(Self.titleStyle)
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
                .accessibilityAddTraits(.isHeader)
            HStack {
                HeaderCircleButton(icon: Tokens.Icons.globalClose, accessibilityLabel: Copy.groupsCreateCloseAccessibilityLabel, fill: .onDeep) {
                    close()
                }
                .accessibilityIdentifier("groups.create.close")
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, Tokens.Sizes.globalHeaderInset)
        .padding(.top, Tokens.Sizes.globalHeaderInset)
    }

    /// Cover placeholder `groups.create.size.cover.width` × `.height`, corners `groups.create.radius.cover`, fill
    /// `groups.create.color.cover`, camera glyph `groups.create.size.coverGlyph` tall; the picked photo fills it.
    private var cover: some View {
        PhotosPicker(selection: $pickerItem, matching: .images, preferredItemEncoding: .compatible) {
            Tokens.Colors.groupsCreateColorCover
                .aspectRatio(Tokens.Sizes.groupsCreateSizeCoverWidth / Tokens.Sizes.groupsCreateSizeCoverHeight, contentMode: .fit)
                .frame(maxWidth: Tokens.Sizes.groupsCreateSizeCoverWidth)
                .overlay {
                    if let image = model.coverImage {
                        Image(uiImage: image).resizable().scaledToFill()
                    } else if let path = model.existingCoverPath {
                        StorageImage(path: path) { Tokens.Colors.groupsCreateColorCover }
                    } else {
                        Image(systemName: Tokens.Icons.globalCamera)
                            .resizable()
                            .scaledToFit()
                            .frame(height: Tokens.Sizes.groupsCreateSizeCoverGlyph)
                            .foregroundStyle(Tokens.Colors.globalTextPrimary)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: Tokens.Radii.groupsCreateRadiusCover))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(model.hasCover ? Copy.groupsCreateCoverChangeAccessibilityLabel : Copy.groupsCreateCoverAccessibilityLabel))
        .accessibilityIdentifier("groups.create.cover")
    }

    /// After create: the sheet closes and the new group is pushed (groups.create Motion); hosted by another surface,
    /// the sheet only closes (that surface refreshes its groups).
    private func submit() async {
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
