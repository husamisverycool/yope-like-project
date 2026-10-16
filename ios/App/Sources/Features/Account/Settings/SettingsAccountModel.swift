// Account group — SettingsAccountModel: state and actions of settings.account (SettingsAccountScreen.swift) and its Edit
// Full Name page.
import AppData
import AppModels
import DesignSystem
import Observation
import PhotosUI
import StoreKit
import SwiftUI
import UIKit

@MainActor
@Observable
final class SettingsAccountModel {
    private(set) var profile: Profile?
    /// The Edit Full Name field (prefilled with the name).
    var nameDraft = ""
    private(set) var avatarImage: UIImage?
    /// The person's birthday when they shared it (`profile_private.birthday`), for the Birthday row's value.
    private(set) var birthday: LocalDate?
    private(set) var isPremium = false
    private(set) var isDeleting = false
    private(set) var isSavingProfile = false
    private(set) var isSavingPhoto = false
    /// The last failure (`settings.account.name.error` / `.delete.error`), shown as the message-only alert.
    private(set) var profileError: String?
    private(set) var warningCount = 0
    private(set) var successCount = 0
    private(set) var errorCount = 0

    private let data: AccountDataSource

    init(data: AccountDataSource) {
        self.data = data
    }

    func load(premium: Bool) async {
        isPremium = premium
        if let profile = try? await data.myProfile() {
            self.profile = profile
            nameDraft = profile.displayName
        }
        if let privateProfile = try? await data.myPrivateProfile() {
            birthday = privateProfile.birthday
        }
        if let server = try? await data.hasPremium() { isPremium = server || premium }
    }

    /// More than `ProfileModel.maxNameLength` characters after trimming: "Name too long" under the field.
    var isNameTooLong: Bool {
        nameDraft.trimmingCharacters(in: .whitespacesAndNewlines).count > ProfileModel.maxNameLength
    }

    var canSaveName: Bool {
        let trimmed = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && !isNameTooLong && !isSavingProfile
    }

    /// Edit Full Name "Save": trimmed, 1–80 characters (docs/API.md §5.1). An empty or unchanged name is not sent; a
    /// failure reverts the field. Returns true when the page can close.
    @discardableResult
    func saveName() async -> Bool {
        let trimmed = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isNameTooLong, trimmed != profile?.displayName else {
            nameDraft = profile?.displayName ?? nameDraft
            return trimmed == profile?.displayName
        }
        profileError = nil
        isSavingProfile = true
        defer { isSavingProfile = false }
        do {
            profile = try await data.updateProfile(displayName: trimmed, avatarPath: nil)
            nameDraft = profile?.displayName ?? trimmed
            successCount += 1
            return true
        } catch {
            nameDraft = profile?.displayName ?? ""
            fail()
            return false
        }
    }

    /// A new photo (library or camera): shown at once, uploaded, then `profiles.avatar_path` updated; reverts on failure.
    func setAvatar(imageData: Data) async {
        guard let jpeg = try? UploadImage.jpeg(from: imageData), let image = UIImage(data: jpeg) else { return }
        let previous = avatarImage
        avatarImage = image
        profileError = nil
        isSavingPhoto = true
        defer { isSavingPhoto = false }
        do {
            let path = try await data.uploadAvatar(jpeg: jpeg)
            profile = try await data.updateProfile(displayName: nil, avatarPath: path)
            successCount += 1
        } catch {
            avatarImage = previous
            fail()
        }
    }

    /// "Remove Profile Photo": clears `avatar_path`.
    func removeAvatar() async {
        profileError = nil
        isSavingPhoto = true
        defer { isSavingPhoto = false }
        do {
            profile = try await data.removeAvatar()
            avatarImage = nil
            successCount += 1
        } catch {
            fail()
        }
    }

    var hasPhoto: Bool { avatarImage != nil || profile?.avatarPath != nil }

    private func fail() {
        profileError = Copy.settingsAccountNameError
        errorCount += 1
    }

    /// `delete_account` → sign-out → local data cleared. Returns true when the account is gone.
    func deleteAccount() async -> Bool {
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await data.deleteAccount()
            warningCount += 1
            return true
        } catch {
            profileError = Copy.settingsAccountDeleteError
            errorCount += 1
            return false
        }
    }
}
