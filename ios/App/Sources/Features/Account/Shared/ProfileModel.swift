// Account group — ProfileModel: state and actions of auth.profile (step 1 name, step 2 photo; ProfileForm.swift and
// Auth/ProfileScreen.swift). Shared with the App Clip, which runs step 1 only.
import AppData
import AppModels
import DesignSystem
import Observation
import SwiftUI
import UIKit

@MainActor
@Observable
final class ProfileModel {
    enum Phase: Equatable {
        case form
        case offline
    }

    /// Retro's order: FULL_NAME, then PROFILE_PHOTO (MERGE RA-24).
    enum Step: Equatable {
        case name
        case photo
    }

    private(set) var step: Step
    /// Name as typed; 1–80 characters after trimming (docs/API.md §5.1) — past that the inline "Name too long" shows.
    private(set) var name = ""
    /// The picked photo (shown cropped to the circle) and its upload-ready JPEG.
    private(set) var avatarImage: UIImage?
    private var avatarJPEG: Data?
    private(set) var phase: Phase = .form
    private(set) var isSaving = false
    /// Last failure copy (`auth.profile.error.save` / `.upload`), shown as the message-only alert.
    private(set) var failureMessage: String?
    private(set) var successCount = 0
    private(set) var errorCount = 0

    static let maxNameLength = 80

    private let data: AccountDataSource
    /// Prepares a picked photo for upload (the app strips location metadata, `UploadImage.jpeg`; the App Clip has no
    /// photo step).
    private let prepareImage: (Data) throws -> Data

    init(data: AccountDataSource, step: Step = .name, prepareImage: @escaping (Data) throws -> Data = { $0 }) {
        self.data = data
        self.step = step
        self.prepareImage = prepareImage
    }

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    /// More than `maxNameLength` characters after trimming: `auth.profile.error.tooLong` under the field.
    var isNameTooLong: Bool { trimmedName.count > Self.maxNameLength }
    /// Step 1 "Next".
    var canContinue: Bool { !trimmedName.isEmpty && !isNameTooLong && !isSaving }

    func setName(_ value: String) {
        name = value
    }

    /// A photo chosen in the system picker (step 2).
    func setAvatar(imageData: Data) {
        guard let jpeg = try? prepareImage(imageData), let image = UIImage(data: jpeg) else {
            fail(Copy.authProfileErrorUpload)
            return
        }
        avatarJPEG = jpeg
        avatarImage = image
    }

    /// Step 1 "Next": `update profiles set display_name`. Returns true when saved (the app then shows the photo step).
    func saveName() async -> Bool {
        guard canContinue else { return false }
        failureMessage = nil
        isSaving = true
        defer { isSaving = false }
        do {
            _ = try await data.updateProfile(displayName: trimmedName, avatarPath: nil)
            successCount += 1
            return true
        } catch {
            if DataError.from(error) == .offline {
                phase = .offline
            } else {
                fail(Copy.authProfileErrorSave)
            }
            return false
        }
    }

    /// Step 2 "Next" with a chosen photo: upload `avatars/<uid>/<uuid>.jpg`, then `update profiles set avatar_path`.
    /// Returns true when saved. Upload failed: the circle returns to empty.
    func savePhoto() async -> Bool {
        guard let avatarJPEG, !isSaving else { return false }
        failureMessage = nil
        isSaving = true
        defer { isSaving = false }
        do {
            let path = try await data.uploadAvatar(jpeg: avatarJPEG)
            _ = try await data.updateProfile(displayName: nil, avatarPath: path)
            successCount += 1
            return true
        } catch {
            if DataError.from(error) == .offline {
                phase = .offline
                return false
            }
            self.avatarJPEG = nil
            avatarImage = nil
            fail(Copy.authProfileErrorUpload)
            return false
        }
    }

    func showPhotoStep() {
        step = .photo
    }

    func showNameStep() {
        step = .name
    }

    private func fail(_ message: String) {
        failureMessage = message
        errorCount += 1
    }

    /// Offline block's "Try again".
    func retry() {
        phase = .form
    }
}
