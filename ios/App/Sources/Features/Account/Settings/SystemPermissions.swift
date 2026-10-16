// Account group — the system permissions settings.root lists (System Permissions section; system.permissions) and their
// live status (AppServices: camera, photo library add-only, microphone, contacts; notifications through
// `NotificationAuthorizing`).
import AppModels
import AppServices
import AVFoundation
import DesignSystem
import Foundation

/// A permission row of settings.root.
enum SystemPermission: String, CaseIterable, Identifiable {
    case camera
    case photos
    case microphone
    case contacts
    case notifications

    var id: String { rawValue }

    /// `settings.root.permissions.*`
    var title: String {
        switch self {
        case .camera: return Copy.settingsRootPermissionsCamera
        case .photos: return Copy.settingsRootPermissionsPhotos
        case .microphone: return Copy.settingsRootPermissionsMicrophone
        case .contacts: return Copy.settingsRootPermissionsContacts
        case .notifications: return Copy.settingsRootPermissionsNotifications
        }
    }

    /// The live status (`AVCaptureDevice.authorizationStatus`, `PHPhotoLibrary.authorizationStatus(for: .addOnly)`,
    /// `AVAudioApplication.recordPermission`, `CNContactStore.authorizationStatus`, the notification settings).
    @MainActor
    static func liveStatus(_ permission: SystemPermission, notifications: NotificationAuthorizing) async -> PermissionStatus {
        switch permission {
        case .camera: return CameraService.authorization(for: .video)
        case .photos: return PhotoLibraryService.addAuthorization()
        case .microphone: return VoiceRecorder.permission()
        case .contacts: return ContactsService.authorization()
        case .notifications: return await notifications.authorizationStatus()
        }
    }
}
