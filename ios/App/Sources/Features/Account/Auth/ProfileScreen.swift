// Surface: auth.profile — name and avatar. Reference app: Yope onboarding (Yope's in-app step was not found; built from
// documented Yope parts, design/surfaces/auth.profile.md). Reference images: as auth.phone, plus
// references/auto/yope/frames/a-itsmthuyope-7644974799302823175-t51.73-group-profile-add-20-pics.png (GP, avatar size) and
// a-yrrah-7434441926000037121-t43.23-members-list-2024.png (ML, default avatar).
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

/// auth.profile screen: title, subtitle, avatar circle + caption, name field + note, lime "continue".
struct ProfileScreen: View {
    @State private var model: ProfileModel
    @State private var pickerItem: PhotosPickerItem?
    @Environment(AccountDependencies.self) private var dependencies

    init(model: ProfileModel) {
        _model = State(initialValue: model)
    }

    private static let noteStyle = TextRole.caption

    var body: some View {
        Group {
            if dependencies.network.isOffline || model.phase == .offline {
                SignUpStateView(
                    title: Copy.authPhoneOfflineTitle,
                    detail: Copy.authProfileOfflineDetail,
                    retry: EmptyStateView.Action(Copy.authPhoneOfflineRetry) { model.retry() }
                )
            } else {
                form
            }
        }
        .loadingHUD(model.isSaving)
        .dsHaptic(Tokens.Haptics.globalSuccess, trigger: model.successCount)
        .dsHaptic(Tokens.Haptics.globalError, trigger: model.errorCount)
        .navigationBarBackButtonHidden(true)
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    model.setAvatar(imageData: data)
                }
                pickerItem = nil
            }
        }
        .accessibilityIdentifier("auth.profile")
    }

    private var form: some View {
        SignUpLayout {
            VStack(spacing: 0) {
                OnboardingTitleBlock(title: Copy.authProfileTitle, subtitle: Copy.authProfileSubtitle)
                    .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
                avatarPicker
                    .padding(.top, Tokens.Sizes.groupsCreateSizeTitleToContent)
                if model.avatarImage == nil {
                    PhotosPicker(selection: $pickerItem, matching: .images, preferredItemEncoding: .compatible) {
                        Text(Copy.authProfileAvatarAdd)
                            .dsTextStyle(TextRole.listSubtitle)
                            .foregroundStyle(Tokens.Colors.globalTextSecondary)
                    }
                    .accessibilityHidden(true)
                    .padding(.top, Tokens.Sizes.groupsCreateSizeFieldToButton)
                }
                FormField(
                    Copy.authProfileFieldPlaceholder,
                    text: Binding(get: { model.name }, set: { model.setName($0) }),
                    accessibilityLabel: Copy.authProfileFieldAccessibilityLabel,
                    contentType: .givenName
                )
                .accessibilityIdentifier("auth.profile.field")
                .padding(.top, Tokens.Sizes.groupsCreateSizeMediaToField)
                Text(Copy.authProfileFieldNote)
                    .dsTextStyle(Self.noteStyle)
                    .foregroundStyle(Tokens.Colors.globalTextSecondary)
                    .multilineTextAlignment(.center)
                PrimaryButton(Copy.authProfileContinue, isEnabled: model.canContinue) {
                    Task {
                        if await model.save() { await dependencies.session.profileSaved() }
                    }
                }
                .accessibilityIdentifier("auth.profile.continue")
                .padding(.top, Tokens.Sizes.groupsCreateSizeFieldToButton)
            }
            .padding(.horizontal, Tokens.Sizes.globalButtonMarginH)
        }
    }

    /// Avatar circle `auth.profile.size.avatar`; empty look `auth.profile.layout.avatarPicker`; tap → system picker.
    private var avatarPicker: some View {
        PhotosPicker(selection: $pickerItem, matching: .images, preferredItemEncoding: .compatible) {
            AvatarView(
                localImage: model.avatarImage.map { Image(uiImage: $0) },
                diameter: Tokens.Sizes.authProfileSizeAvatar
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(model.avatarImage == nil ? Copy.authProfileAvatarAccessibilityLabel : Copy.authProfileAvatarChangeAccessibilityLabel))
        .accessibilityIdentifier("auth.profile.avatar")
    }
}
