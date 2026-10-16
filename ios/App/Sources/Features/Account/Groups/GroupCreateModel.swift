// Account group — GroupCreateModel: state and actions of the screen in GroupCreateScreen.swift.
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
    /// Step A (type: the template rows) and step B (cover and name).
    enum Step: Hashable {
        case type
        case details
    }

    /// Nil: create; else the group being edited (admins).
    let editingGroupID: GroupID?
    /// Step A is skipped when the kind was chosen on a template row (groups.list) and in edit mode.
    private(set) var step: Step
    /// Name as typed; 1–80 characters after trimming (`groups.create.error.tooLong` past that).
    private(set) var name = ""
    var kind: GroupKind = .friends
    /// Bumped when a kind is chosen on step A (`haptic.global.select`).
    private(set) var kindChoiceCount = 0
    /// The picked cover (fills the rectangle) and its upload-ready JPEG.
    private(set) var coverImage: UIImage?
    private var coverJPEG: Data?
    /// Edit mode: the group's current cover.
    private(set) var existingCoverPath: String?
    private(set) var isWorking = false
    /// Last failure copy (`groups.create.error.*`, `groups.create.offline`), shown as the form error alert.
    private(set) var failureMessage: String?
    private(set) var successCount = 0
    private(set) var errorCount = 0

    static let maxNameLength = 80
    /// The four types in `group_kind` order.
    static var kinds: [GroupKind] { GroupKindCopy.kinds }

    private let data: AccountDataSource

    /// - Parameter kind: a kind chosen on a template row (starts at step B).
    init(data: AccountDataSource, editingGroupID: GroupID? = nil, kind: GroupKind? = nil) {
        self.data = data
        self.editingGroupID = editingGroupID
        step = editingGroupID != nil || kind != nil ? .details : .type
        if let kind { self.kind = kind }
    }

    var isEditing: Bool { editingGroupID != nil }
    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    /// More than `maxNameLength` characters after trimming.
    var isNameTooLong: Bool { trimmedName.count > Self.maxNameLength }
    var canSubmit: Bool { !trimmedName.isEmpty && !isNameTooLong && !isWorking }
    var hasCover: Bool { coverImage != nil || existingCoverPath != nil }

    func setName(_ value: String) {
        name = value
    }

    /// Step A: a template row (or its "Create" capsule) chose the kind → step B.
    func choose(_ kind: GroupKind) {
        self.kind = kind
        kindChoiceCount += 1
        step = .details
    }

    /// Step B's back chevron (only when step A was shown).
    func backToType() {
        step = .type
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
    }

    static func title(of kind: GroupKind) -> String {
        GroupKindCopy.title(kind)
    }
}
