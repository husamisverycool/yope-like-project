// Account group — SettingsAccountModel: state and actions of the screen in SettingsAccountScreen.swift.
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
    var nameDraft = ""
    private(set) var avatarImage: UIImage?
    private(set) var isPremium = false
    private(set) var isDeleting = false
    private(set) var isSavingProfile = false
    /// Name / photo section footer after a failed save (`settings.account.name.error`).
    private(set) var profileError: String?
    private(set) var warningCount = 0
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
        if let server = try? await data.hasPremium() { isPremium = server || premium }
    }

    /// Saved on submit; trimmed, 1–80 characters (docs/API.md §5.1). Reverts on failure.
    func saveName() async {
        let trimmed = String(nameDraft.trimmingCharacters(in: .whitespacesAndNewlines).prefix(ProfileModel.maxNameLength))
        guard !trimmed.isEmpty, trimmed != profile?.displayName else {
            nameDraft = profile?.displayName ?? nameDraft
            return
        }
        profileError = nil
        isSavingProfile = true
        defer { isSavingProfile = false }
        do {
            profile = try await data.updateProfile(displayName: trimmed, avatarPath: nil)
            nameDraft = profile?.displayName ?? trimmed
        } catch {
            nameDraft = profile?.displayName ?? ""
            profileError = Copy.settingsAccountNameError
            errorCount += 1
        }
    }

    /// A new photo from the system picker: shown at once, uploaded, then `profiles.avatar_path` updated.
    func setAvatar(imageData: Data) async {
        guard let jpeg = try? UploadImage.jpeg(from: imageData), let image = UIImage(data: jpeg) else { return }
        let previous = avatarImage
        avatarImage = image
        profileError = nil
        do {
            let path = try await data.uploadAvatar(jpeg: jpeg)
            profile = try await data.updateProfile(displayName: nil, avatarPath: path)
        } catch {
            avatarImage = previous
            profileError = Copy.settingsAccountNameError
            errorCount += 1
        }
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
            errorCount += 1
            return false
        }
    }
}
