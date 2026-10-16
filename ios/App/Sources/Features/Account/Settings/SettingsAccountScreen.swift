// Surface: settings.account — profile photo, name, phone, birthday, delete account. Visual reference: Retro Account
// section and Edit Profile page (strings references/auto/retro/apk/retro-android-2026.10.1150-strings.txt
// `edit_profile_*`, `edit_full_name_screen_title`, `delete_account_page_*`), Retro's grouped rows
// (references/auto/retro/video/ig-DJXvmqRv2_N-referrals-sheet-f042-059.png, VID-SET) and red row
// (references/auto/retro/press/tc-2024-04-retro-journals-5.png, TC-J5). Native action sheet, alerts and pickers
// (design/surfaces/settings.account.md).
import AppData
import AppModels
import AppServices
import AVFoundation
import DesignSystem
import Observation
import PhotosUI
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
    @State private var picking = false
    @State private var takingPhoto = false
    @State private var choosingPhoto = false
    @State private var cameraDenied = false
    @State private var confirmDelete = false
    @Environment(AccountDependencies.self) private var dependencies
    @Environment(\.settingsPush) private var settingsPush

    init(model: SettingsAccountModel) {
        _model = State(initialValue: model)
    }

    private var isOffline: Bool { dependencies.network.isOffline }

    var body: some View {
        SettingsList {
            SettingsGroup(rows: [
                photoRow,
                SettingsRow(Copy.settingsAccountName, value: model.profile?.displayName, kind: .navigation {
                    pushInSheet(.account(.settingsName))
                }, isEnabled: !isOffline)
                .accessibilityIdentifier("settings.account.name")
                .asSettingsRow(),
                SettingsRow(Copy.settingsAccountPhone, value: dependencies.currentPhone(), kind: .value)
                    .asSettingsRow(),
                SettingsRow(Copy.settingsAccountBirthday, value: model.birthday.flatMap(Self.birthdayText), kind: .navigation {
                    if let route = CrossGroupRoutes.birthdayAdd { pushInSheet(route) }
                })
                .accessibilityIdentifier("settings.account.birthday")
                .asSettingsRow(),
            ])
            SettingsGroup(footer: [Copy.settingsAccountDeleteFooter], rows: [
                SettingsRow(
                    Copy.settingsAccountDelete,
                    kind: model.isDeleting ? SettingsRow.Kind.busy : SettingsRow.Kind.destructive(action: { confirmDelete = true }),
                    isEnabled: !isOffline
                )
                .accessibilityIdentifier("settings.account.delete")
                .asSettingsRow(),
            ])
        }
        .settingsPage(title: Copy.settingsAccountTitle)
        .disabled(model.isDeleting)
        .interactiveDismissDisabled(model.isDeleting)
        .task { await model.load(premium: dependencies.purchases.isPremium) }
        .confirmationDialog(Text(Copy.settingsAccountPhotoSheetTitle), isPresented: $choosingPhoto, titleVisibility: .visible) {
            Button(Copy.settingsAccountPhotoLibrary) { picking = true }
            Button(Copy.settingsAccountPhotoCamera) { Task { await takePhoto() } }
            if model.hasPhoto {
                Button(Copy.settingsAccountPhotoRemove, role: .destructive) { Task { await model.removeAvatar() } }
            }
            Button(Copy.settingsAccountAlertCancel, role: .cancel) {}
        }
        .photosPicker(isPresented: $picking, selection: $pickerItem, matching: .images, preferredItemEncoding: .compatible)
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) { await model.setAvatar(imageData: data) }
                pickerItem = nil
            }
        }
        .fullScreenCover(isPresented: $takingPhoto) {
            CameraPhotoPicker { data in
                takingPhoto = false
                if let data { Task { await model.setAvatar(imageData: data) } }
            }
            .ignoresSafeArea()
        }
        .alert(Text(Copy.onboardingPermissionCameraDeniedTitle), isPresented: $cameraDenied) {
            Button(Copy.settingsAccountAlertCancel, role: .cancel) {}
            Button(Copy.onboardingPermissionCameraDeniedButton) {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
        } message: {
            Text(Copy.onboardingPermissionCameraDeniedDetail)
        }
        .alert(Text(Copy.settingsAccountDeleteTitle), isPresented: $confirmDelete) {
            Button(Copy.settingsAccountAlertCancel, role: .cancel) {}
            Button(Copy.settingsAccountDeleteConfirm, role: .destructive) {
                Task {
                    if await model.deleteAccount() { dependencies.session.accountDeleted() }
                }
            }
        } message: {
            Text(model.isPremium
                 ? Copy.settingsAccountDeleteMessage + "\n\n" + Copy.settingsAccountDeleteSubscriptionNote // provenance-ok: paragraph break between two copy strings
                 : Copy.settingsAccountDeleteMessage)
        }
        .formErrorAlert(model.profileError, trigger: model.errorCount)
        .dsHaptic(Tokens.Haptics.globalWarning, trigger: model.warningCount)
        .dsHaptic(Tokens.Haptics.globalSuccess, trigger: model.successCount)
        .dsHaptic(Tokens.Haptics.globalError, trigger: model.errorCount)
        .accessibilityIdentifier("settings.account")
    }

    /// The avatar row: `size.global.avatarProfile` circle leading (C-23; the platform indicator over it while saving), "Profile
    /// Photo" + chevron → the native action sheet (library, camera, remove).
    private var photoRow: AnyView {
        SettingsCustomRow(action: isOffline ? nil : { choosingPhoto = true }) {
            HStack {
                AvatarView(
                    path: model.profile?.avatarPath,
                    localImage: model.avatarImage.map { Image(uiImage: $0) },
                    diameter: Tokens.Sizes.globalAvatarProfile
                )
                .overlay { if model.isSavingPhoto { LoadingHUD() } }
                .dsAnimation(ComponentMotion.crossfade, value: model.avatarImage)
                Text(Copy.settingsAccountPhoto)
                    .dsTextStyle(TextRole.body)
                    .foregroundStyle(Tokens.Colors.globalTextPrimary)
                Spacer(minLength: 0)
                Glyph(Tokens.Icons.globalChevron, relativeTo: TextRole.body.relativeTo)
                    .foregroundStyle(Tokens.Colors.globalTextSecondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("settings.account.photo")
        .asSettingsRow()
    }

    /// The camera asks its permission (`onboarding.permission.camera`); denied or restricted → the denied copy in an alert.
    private func takePhoto() async {
        switch CameraService.authorization(for: .video) {
        case .granted, .limited:
            takingPhoto = true
        case .notDetermined:
            if await CameraService.requestAccess(for: .video).allowsAccess { takingPhoto = true } else { cameraDenied = true }
        case .denied, .restricted:
            cameraDenied = true
        }
    }

    /// Pushes inside the Settings sheet (its own stack): the hosting `NavigationStack` handles `AppRoute`s.
    private func pushInSheet(_ route: AppRoute) {
        settingsPush?(route)
    }

    /// The birthday as `layout.birthday.add.dateFormat` ("July 5").
    static func birthdayText(_ birthday: LocalDate) -> String? {
        var components = DateComponents()
        components.year = birthday.year
        components.month = birthday.month
        components.day = birthday.day
        guard let date = Calendar(identifier: .gregorian).date(from: components) else { return nil }
        return date.formatted(Date.FormatStyle().month(.wide).day())
    }
}

/// settings.account → Edit Full Name (pushed): native back + centred title; the C-12 field (prefilled)
/// `size.global.titleToContent` under the bar with the inline "Name too long"; C-05 "Save" pinned
/// `size.global.buttonMarginH` above the keyboard.
struct SettingsNameScreen: View {
    @Environment(AccountDependencies.self) private var dependencies

    var body: some View {
        SettingsNameView(model: SettingsAccountModel(data: dependencies.data))
    }
}

struct SettingsNameView: View {
    @State private var model: SettingsAccountModel
    @FocusState private var fieldFocused: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(AccountDependencies.self) private var dependencies

    init(model: SettingsAccountModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        VStack(spacing: 0) {
            FormField(
                Copy.settingsAccountName,
                text: $model.nameDraft,
                accessibilityLabel: Copy.settingsAccountName,
                contentType: .name,
                errorMessage: model.isNameTooLong ? Copy.settingsAccountNameTooLong : nil,
                onSubmit: { Task { await save() } }
            )
            .focused($fieldFocused)
            .disabled(model.isSavingProfile)
            .accessibilityIdentifier("settings.account.name.field")
            .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
            .padding(.top, Tokens.Sizes.globalTitleToContent)
            Spacer(minLength: Tokens.Sizes.globalButtonMarginH)
            PrimaryButton(Copy.settingsAccountNameSave, isEnabled: model.canSaveName, isBusy: model.isSavingProfile) {
                Task { await save() }
            }
            .accessibilityIdentifier("settings.account.name.save")
            .padding(.horizontal, Tokens.Sizes.globalButtonMarginH)
            .padding(.bottom, Tokens.Sizes.globalButtonMarginH)
        }
        .settingsPage(title: Copy.settingsAccountNameTitle)
        .task {
            await model.load(premium: dependencies.purchases.isPremium)
            fieldFocused = true
        }
        .dsHaptic(Tokens.Haptics.globalSuccess, trigger: model.successCount)
        .dsHaptic(Tokens.Haptics.globalError, trigger: model.errorCount)
        .formErrorAlert(model.profileError, trigger: model.errorCount)
        .accessibilityIdentifier("settings.account.nameEditor")
    }

    private func save() async {
        if await model.saveName() { dismiss() }
    }
}

/// The system camera for a profile photo (`UIImagePickerController(.camera)`): `onFinish` gets the JPEG, or nil when
/// cancelled.
struct CameraPhotoPicker: UIViewControllerRepresentable {
    let onFinish: (Data?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    @MainActor
    final class Coordinator: NSObject, @preconcurrency UIImagePickerControllerDelegate, @preconcurrency UINavigationControllerDelegate {
        let onFinish: (Data?) -> Void

        init(onFinish: @escaping (Data?) -> Void) {
            self.onFinish = onFinish
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = info[.originalImage] as? UIImage
            onFinish(image.flatMap { $0.jpegData(compressionQuality: 1) })
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onFinish(nil)
        }
    }
}

/// How a settings page pushes inside its sheet's own navigation stack (set by `SettingsRootScreen`).
private struct SettingsPushKey: EnvironmentKey {
    static let defaultValue: ((AppRoute) -> Void)? = nil
}

extension EnvironmentValues {
    var settingsPush: ((AppRoute) -> Void)? {
        get { self[SettingsPushKey.self] }
        set { self[SettingsPushKey.self] = newValue }
    }
}
