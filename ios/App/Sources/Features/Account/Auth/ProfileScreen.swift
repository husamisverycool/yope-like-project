// Surface: auth.profile — step 1 name (Shared/ProfileNameForm.swift) and step 2 profile photo. Visual reference: Retro's
// FULL_NAME and PROFILE_PHOTO sign-up steps (references/auto/retro/apk/retro-android-2026.10.1150-strings.txt
// `onboarding_v3_page_title_profile_photo`, `onboarding_v3_profile_photo_cta_*`), the 112-pt avatar of Retro's web
// invite page (references/auto/retro/web/retro.app-5bff8a0be69f7ec7.css) and the landing's capsule and link
// (references/auto/retro/lazyweb/retro-lazyweb-20251119-social.png); composition of C-02, C-12, C-23, C-05, C-08
// (design/surfaces/auth.profile.md; MERGE RA-24).
import AppData
import AppModels
import AppServices
import DesignSystem
import Observation
import PhotosUI
import SwiftUI
import UIKit

/// Prepares a picked photo for upload: a JPEG with no location metadata (the app never collects location). JPEGs keep
/// their pixels (`ImageEncoder.removingLocation`); other formats are re-encoded at their own size and the encoder's
/// highest quality (no upload size is defined by the API contract, so nothing is scaled).
enum UploadImage {
    enum Failure: Error {
        case unreadable
    }

    static func jpeg(from data: Data) throws -> Data {
        let isJPEG = data.starts(with: [0xFF, 0xD8, 0xFF])
        if isJPEG, let stripped = ImageEncoder.removingLocation(from: data) {
            return stripped
        }
        guard let size = ImageEncoder.pixelSize(data) else { throw Failure.unreadable }
        return try ImageEncoder.jpegForUpload(data, options: .init(maxPixelSize: max(size.width, size.height), compressionQuality: 1))
    }
}

/// auth.profile: the name step, then the photo step (onboarding page transition between them,
/// `duration.global.pageTransition`); after the photo step (or "Maybe Later") the session continues to the
/// notifications ask.
struct ProfileScreen: View {
    @State private var model: ProfileModel
    @Environment(AccountDependencies.self) private var dependencies

    init(model: ProfileModel) {
        _model = State(initialValue: model)
    }

    private static let pageTransition = DSAnimation.timing(duration: Tokens.Durations.globalPageTransition, easing: Tokens.Easings.globalStandard)

    var body: some View {
        ZStack {
            switch model.step {
            case .name:
                ProfileNameForm(model: model, network: dependencies.network) {
                    withDSAnimation(Self.pageTransition) { model.showPhotoStep() }
                }
                .transition(.opacity)
            case .photo:
                ProfilePhotoStep(model: model, network: dependencies.network) {
                    withDSAnimation(Self.pageTransition) { model.showNameStep() }
                } onDone: {
                    Task { await dependencies.session.profileSaved() }
                }
                .transition(.opacity)
            }
        }
    }
}

/// auth.profile step 2: back → step 1 · "Add a profile photo" · explanation · the avatar circle
/// (`auth.profile.size.avatar`, C-23; empty = `auth.profile.layout.avatarPicker.empty`) centred between the explanation
/// and the capsule · C-05 "Choose photo" (empty) / "Next" (chosen) · C-08 "Maybe Later" (empty) / "Edit photo" (chosen)
/// `auth.phone.size.capsuleToLink` under it. Picking uses the system picker (no permission).
struct ProfilePhotoStep: View {
    @Bindable var model: ProfileModel
    let network: NetworkMonitor
    let onBack: () -> Void
    let onDone: () -> Void

    @State private var pickerItem: PhotosPickerItem?
    @State private var picking = false

    private static let photoFade = DSAnimation.timing(duration: Tokens.Durations.globalFade, easing: Tokens.Easings.globalStandard)

    private var hasPhoto: Bool { model.avatarImage != nil }

    var body: some View {
        SignUpLayout(
            back: FormBackButton(accessibilityLabel: Copy.authCodeBackAccessibilityLabel, identifier: "auth.profile.back", action: onBack),
            title: Copy.authProfilePhotoTitle,
            explanation: Copy.authProfilePhotoSubtitle,
            replacement: network.isOffline || model.phase == .offline ? .signUpOffline { model.retry() } : nil,
            centersContent: true
        ) {
            Button {
                picking = true
            } label: {
                AvatarView(
                    localImage: model.avatarImage.map { Image(uiImage: $0) },
                    diameter: Tokens.Sizes.authProfileSizeAvatar
                )
                .dsAnimation(Self.photoFade, value: hasPhoto)
            }
            .buttonStyle(.plain)
            .disabled(model.isSaving)
            .accessibilityLabel(Text(hasPhoto ? Copy.authProfileAvatarChangeAccessibilityLabel : Copy.authProfileAvatarAccessibilityLabel))
            .accessibilityAddTraits(.isImage)
            .accessibilityIdentifier("auth.profile.avatar")
            .frame(maxWidth: .infinity)
        } bottom: {
            MetricStack(alignment: .center) {
                PrimaryButton(hasPhoto ? Copy.authProfileContinue : Copy.authProfileAvatarAdd, isBusy: model.isSaving) {
                    if hasPhoto {
                        Task { if await model.savePhoto() { onDone() } }
                    } else {
                        picking = true
                    }
                }
                .accessibilityIdentifier("auth.profile.photo.primary")
                TextButton(hasPhoto ? Copy.authProfileAvatarEdit : Copy.authProfilePhotoSkip, style: .link) {
                    if hasPhoto { picking = true } else { onDone() }
                }
                .capHeight(of: TextRole.listTitle)
                .disabled(model.isSaving)
                .accessibilityIdentifier("auth.profile.photo.secondary")
                .metricGap(Tokens.Sizes.authPhoneSizeCapsuleToLink, from: .bottom, to: .capTop)
            }
        }
        .photosPicker(isPresented: $picking, selection: $pickerItem, matching: .images, preferredItemEncoding: .compatible)
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    model.setAvatar(imageData: data)
                }
                pickerItem = nil
            }
        }
        .dsHaptic(Tokens.Haptics.globalSuccess, trigger: model.successCount)
        .dsHaptic(Tokens.Haptics.globalError, trigger: model.errorCount)
        .formErrorAlert(model.failureMessage, trigger: model.errorCount)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("auth.profile.photo")
    }
}
