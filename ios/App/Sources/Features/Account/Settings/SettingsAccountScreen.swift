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
