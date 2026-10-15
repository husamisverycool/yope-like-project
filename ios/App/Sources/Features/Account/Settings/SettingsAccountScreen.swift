// Surface: settings.account — account, delete account. Reference: Apple HIG / Apple's account-deletion guidance (system
// surface; design/surfaces/settings.account.md). Reference: https://developer.apple.com/support/offering-account-deletion-in-your-app/,
// HIG managing accounts, HIG alerts.
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

struct SettingsAccountScreen: View {
    @Environment(AccountDependencies.self) private var dependencies

    var body: some View {
        SettingsAccountView(model: SettingsAccountModel(data: dependencies.data))
    }
}

struct SettingsAccountView: View {
    @State private var model: SettingsAccountModel
    @State private var pickerItem: PhotosPickerItem?
    @State private var confirmDelete = false
    @State private var deleteFailed = false
    @State private var showsManageSubscriptions = false
    @Environment(AccountDependencies.self) private var dependencies

    init(model: SettingsAccountModel) {
        _model = State(initialValue: model)
    }

    private var isOffline: Bool { dependencies.network.isOffline }

    var body: some View {
        List {
            Section {
                LabeledContent(Copy.settingsAccountName) {
                    TextField(Copy.settingsAccountName, text: $model.nameDraft)
                        .multilineTextAlignment(.trailing)
                        .textContentType(.givenName)
                        .submitLabel(.done)
                        .onSubmit { Task { await model.saveName() } }
                        .disabled(isOffline || model.isSavingProfile)
                        .accessibilityIdentifier("settings.account.name")
                }
                PhotosPicker(selection: $pickerItem, matching: .images, preferredItemEncoding: .compatible) {
                    LabeledContent(Copy.settingsAccountPhoto) {
                        AvatarView(
                            path: model.profile?.avatarPath,
                            localImage: model.avatarImage.map { Image(uiImage: $0) },
                            diameter: Tokens.Sizes.globalAvatarPicker
                        )
                    }
                    .foregroundStyle(.primary) // provenance-ok: system label colour (color.global.system.ios)
                }
                .disabled(isOffline)
                LabeledContent(Copy.settingsAccountPhone, value: dependencies.currentPhone() ?? "")
                Button {
                    if let route = CrossGroupRoutes.birthdayAdd { dependencies.router.path.append(route) }
                } label: {
                    LabeledContent(Copy.settingsAccountBirthday) {
                        Image(systemName: Tokens.Icons.globalChevron)
                            .foregroundStyle(.tertiary) // provenance-ok: system disclosure indicator colour
                            .accessibilityHidden(true)
                    }
                    .foregroundStyle(.primary) // provenance-ok: system label colour (color.global.system.ios)
                }
            } footer: {
                if let error = model.profileError { Text(error) }
            }
            if model.isPremium {
                Section {
                    Button(Copy.settingsRootManageSubscription) { showsManageSubscriptions = true }
                }
            }
            Section {
                Button(role: .destructive) {
                    confirmDelete = true
                } label: {
                    HStack {
                        Spacer(minLength: 0)
                        if model.isDeleting {
                            ProgressView()
                        } else {
                            Text(Copy.settingsAccountDelete)
                        }
                        Spacer(minLength: 0)
                    }
                }
                .disabled(isOffline || model.isDeleting)
                .accessibilityIdentifier("settings.account.delete")
            } footer: {
                Text(Copy.settingsAccountDeleteFooter)
            }
        }
        .listStyle(.insetGrouped)
        .disabled(model.isDeleting)
        .navigationTitle(Text(Copy.settingsAccountTitle))
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load(premium: dependencies.purchases.isPremium) }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) { await model.setAvatar(imageData: data) }
                pickerItem = nil
            }
        }
        .alert(Text(Copy.settingsAccountDeleteTitle), isPresented: $confirmDelete) {
            Button(Copy.settingsAccountAlertCancel, role: .cancel) {}
            if model.isPremium {
                Button(Copy.settingsRootManageSubscription) { showsManageSubscriptions = true }
            }
            Button(Copy.settingsAccountDeleteConfirm, role: .destructive) {
                Task {
                    if await model.deleteAccount() {
                        dependencies.session.accountDeleted()
                    } else {
                        deleteFailed = true
                    }
                }
            }
        } message: {
            Text(model.isPremium
                 ? Copy.settingsAccountDeleteMessage + "\n\n" + Copy.settingsAccountDeleteSubscriptionNote // provenance-ok: paragraph break between two copy strings
                 : Copy.settingsAccountDeleteMessage)
        }
        .alert(Text(Copy.settingsAccountDeleteError), isPresented: $deleteFailed) {
            Button(Copy.settingsAccountAlertCancel, role: .cancel) {}
        }
        .manageSubscriptionsSheet(isPresented: $showsManageSubscriptions)
        .dsHaptic(Tokens.Haptics.globalWarning, trigger: model.warningCount)
        .dsHaptic(Tokens.Haptics.globalError, trigger: model.errorCount)
        .accessibilityIdentifier("settings.account")
    }
}
