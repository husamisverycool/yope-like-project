// Surface: birthday.tribute — view model. Spec: design/surfaces/birthday.tribute.md.
// The honoree can read the tribute only once it is delivered (`delivered_at` set and past; RLS
// enforces it and this model checks it too); other members can read it at any time.
import AppData
import AppServices
import AVFoundation
import DesignSystem
import Foundation
import Observation

@MainActor
@Observable
final class TributeModel {
    enum Phase: Equatable {
        case idle
        case loading
        /// `status = 'pending'` (first render or re-render after a photo was deleted): same as loading.
        case rendering
        case ready
        /// The tribute was deleted, or it is not delivered to the honoree yet.
        case notFound
        case error
        case offline
    }

    private(set) var phase: Phase = .idle
    private(set) var groupName = ""
    /// The honoree's first name (`birthday.tribute.title.member`); empty for the honoree.
    private(set) var honoreeName = ""
    /// The caller is the honoree (`birthday.tribute.title`).
    private(set) var isHonoree = false
    private(set) var videoURL: URL?
    private(set) var posterURL: URL?
    /// The MP4 on the device, for save and Share; nil until downloaded.
    private(set) var localFile: URL?
    private(set) var isSaving = false
    /// Add-only photo access was denied: the native alert that opens Settings (`birthday.tribute.saveDenied.*`).
    var showsSaveDenied = false
    /// Prepared as soon as the video URL is known, so playback starts fast when the screen shows it.
    private(set) var player: AVPlayer?

    let tributeID: TributeID
    private let dependencies: MemoryDependencies
    private let saveVideo: @Sendable (URL) async throws -> Void

    /// - Parameter saveVideo: saves the file to the photo library with add-only access
    ///   (`PhotoLibraryService.saveVideo`).
    init(
        tributeID: TributeID,
        dependencies: MemoryDependencies,
        saveVideo: @escaping @Sendable (URL) async throws -> Void = { try await PhotoLibraryService().saveVideo(at: $0) }
    ) {
        self.tributeID = tributeID
        self.dependencies = dependencies
        self.saveVideo = saveVideo
    }

    /// Whether `user` may see `tribute` at `now`: everyone but the honoree at any time; the honoree
    /// only once it was delivered.
    static func isVisible(_ tribute: Tribute, to user: UserID?, now: Date) -> Bool {
        guard tribute.honoreeID == user else { return true }
        guard let deliveredAt = tribute.deliveredAt else { return false }
        return deliveredAt <= now
    }

    /// Save and Share are the honoree's: the video was made for them, and it carries other members' photos, which leave the
    /// app only through the person they were given to (owner decision 12). Members watch it in the app.
    var offersExport: Bool { isHonoree }

    /// Save and Share work once the file is on the device (the honoree only).
    var canUseFile: Bool { offersExport && phase == .ready && localFile != nil && !isSaving }

    /// "Your birthday video" for the honoree, "{name}'s birthday video" for anyone else.
    var title: String {
        isHonoree ? Copy.birthdayTributeTitle : Copy.birthdayTributeTitleMember(name: honoreeName)
    }

    func loadIfNeeded() async {
        guard phase == .idle else { return }
        await load()
    }

    func retry() async {
        await load()
    }

    /// Back in the foreground while (re)rendering: read the row again.
    func refreshIfRendering() async {
        guard phase == .rendering else { return }
        await load()
    }

    private func load() async {
        if phase != .rendering { phase = .loading }
        guard let data = dependencies.data else {
            phase = .error
            return
        }
        do {
            let me = await data.currentUser()
            guard let tribute = try await data.tribute(id: tributeID),
                  Self.isVisible(tribute, to: me, now: dependencies.now()) else {
                phase = .notFound
                return
            }
            groupName = try await data.group(id: tribute.groupID)?.name ?? ""
            isHonoree = tribute.honoreeID == me
            if !isHonoree {
                honoreeName = try await data.profiles(ids: [tribute.honoreeID]).first?.firstName ?? ""
            }
            switch tribute.status {
            case .failed:
                phase = .error
                return
            case .pending, .unknown:
                phase = .rendering
                return
            case .ready:
                break
            }
            guard let videoPath = tribute.videoPath else {
                phase = .rendering
                return
            }
            let urls = try await data.signedURLs(paths: [videoPath] + [tribute.posterPath].compactMap { $0 })
            guard let video = urls[videoPath] else {
                phase = .notFound
                return
            }
            if videoURL != video || player == nil {
                videoURL = video
                player = AVPlayer(url: video)
            }
            posterURL = tribute.posterPath.flatMap { urls[$0] }
            phase = .ready
            // The file for Download / Share (the honoree's) comes after the player was prepared.
            guard offersExport else { return }
            localFile = try? await data.downloadFile(from: video, name: tribute.id.rawValue + ".mp4") // provenance-ok: file extension of the MP4
        } catch {
            switch MemoryFailure(error) {
            case .offline: phase = .offline
            case .notFound: phase = .notFound
            default: phase = .error
            }
        }
    }

    /// "Save to Camera Roll": the MP4 to the photo library (add-only access). `haptic.global.success` +
    /// `birthday.tribute.saved`; denied → the native alert; failed → `haptic.global.error` + `birthday.tribute.saveFailed`.
    func download() async {
        guard canUseFile, let localFile else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await saveVideo(localFile)
            dependencies.haptics(Tokens.Haptics.globalSuccess)
            dependencies.toasts.show(Copy.birthdayTributeSaved)
        } catch {
            dependencies.haptics(Tokens.Haptics.globalError)
            if OnThisDayModel.isAccessDenied(error) {
                showsSaveDenied = true
            } else {
                dependencies.toasts.show(Copy.birthdayTributeSaveFailed)
            }
        }
    }
}
