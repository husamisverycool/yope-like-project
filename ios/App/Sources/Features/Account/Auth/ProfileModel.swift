// Account group — ProfileModel: state and actions of the screen in ProfileScreen.swift.
import AppData
import AppModels
import AppServices
import DesignSystem
import Observation
import PhotosUI
import SwiftUI
import UIKit

@MainActor
@Observable
final class ProfileModel {
    enum Phase: Equatable {
        case form
        case offline
    }

    /// Name as typed (≤ 80 characters, docs/API.md §5.1).
    private(set) var name = ""
    /// The picked photo (shown cropped to the circle) and its upload-ready JPEG.
    private(set) var avatarImage: UIImage?
    private var avatarJPEG: Data?
    private(set) var phase: Phase = .form
    private(set) var isSaving = false
    /// Last failure copy (`auth.profile.error.upload` / `.save`), shown as the form error alert.
    private(set) var failureMessage: String?
    private(set) var successCount = 0
    private(set) var errorCount = 0

    static let maxNameLength = 80

    private let data: AccountDataSource

    init(data: AccountDataSource) {
        self.data = data
    }

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    var canContinue: Bool { !trimmedName.isEmpty && !isSaving }

    func setName(_ value: String) {
        name = String(value.prefix(Self.maxNameLength))
    }

    /// A photo chosen in the system picker.
    func setAvatar(imageData: Data) {
        guard let jpeg = try? UploadImage.jpeg(from: imageData), let image = UIImage(data: jpeg) else {
            fail(Copy.authProfileErrorUpload)
            return
        }
        avatarJPEG = jpeg
        avatarImage = image
    }

    /// Uploads the avatar (if any), then updates `profiles`. Returns true when saved.
    func save() async -> Bool {
        guard canContinue else { return false }
        failureMessage = nil
        isSaving = true
        defer { isSaving = false }
        var avatarPath: String?
        if let avatarJPEG {
            do {
                avatarPath = try await data.uploadAvatar(jpeg: avatarJPEG)
            } catch {
                if DataError.from(error) == .offline {
                    phase = .offline
                    return false
                }
                // "upload failed": the avatar returns to empty; continue stays enabled.
                self.avatarJPEG = nil
                avatarImage = nil
                fail(Copy.authProfileErrorUpload)
                return false
            }
        }
        do {
            _ = try await data.updateProfile(displayName: trimmedName, avatarPath: avatarPath)
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

    private func fail(_ message: String) {
        failureMessage = message
        errorCount += 1
    }

    func retry() {
        phase = .form
    }
}
