// Surfaces: camera.capture → camera.sendto, daily.capture (design/surfaces/<id>.md; reference images listed there).
// The captured media handed from the camera to the send step, and its conversion into an AppData `PostDraft` (docs/API.md recipe 9.4:
// original.jpg, front.jpg, motion.mov, voice.m4a).
import AppData
import AppModels
import AppServices
@preconcurrency import AVFoundation
import Foundation
import UIKit

/// What the camera (or the library picker) produced; nothing is uploaded until send.
struct CapturedMedia: Identifiable, Sendable, Equatable {
    enum Kind: Sendable, Equatable {
        case photo
        case livePhoto
        case video
    }

    let id: UUID
    var kind: Kind
    /// Photo / Live Photo still.
    var still: CaptureStill?
    var video: CaptureVideo?
    /// When the photo was taken.
    var capturedAt: Date

    static func photo(_ still: CaptureStill, capturedAt: Date) -> CapturedMedia {
        CapturedMedia(
            id: UUID(),
            kind: still.livePhotoMovieURL == nil ? .photo : .livePhoto,
            still: still,
            video: nil,
            capturedAt: capturedAt
        )
    }

    static func video(_ video: CaptureVideo, capturedAt: Date) -> CapturedMedia {
        CapturedMedia(id: UUID(), kind: .video, still: nil, video: video, capturedAt: capturedAt)
    }

    /// Video needs premium at `create_post` (`premium_required`).
    var needsPremium: Bool { kind == .video }

    /// Removes the temporary files the camera wrote (after discard or once the outbox holds copies).
    func removeTemporaryFiles() {
        let files = [still?.livePhotoMovieURL, video?.fileURL].compactMap { $0 }
        for file in files where file.path.hasPrefix(FileManager.default.temporaryDirectory.path) {
            try? FileManager.default.removeItem(at: file)
        }
    }
}

/// A daily same-moment answer: the main photo and, when both cameras worked, the inset.
struct DailyAnswer: Sendable, Equatable {
    var main: CaptureStill
    var inset: CaptureStill?
    var capturedAt: Date
}

/// Everything one send needs, prepared on the main actor and encoded off it.
struct CaptureSendRequest: Sendable, Identifiable {
    enum Payload: Sendable {
        case media(CapturedMedia)
        case daily(DailyAnswer)
    }

    let id = UUID()
    var payload: Payload
    var groupIDs: [String]
    var caption: String?
    var voice: VoiceNote?
    var invitationID: String?
    /// The confirmation announced once posted (`camera.sendto.toast.postedOne` / `.postedMany`; C-26).
    var confirmation: String?
    /// A photo replying to this post (`create_post p_reply_to_post_id`; exactly one group, the post's).
    var replyToPostID: String?

    /// Removes the camera's and the recorder's temporary files once the outbox holds copies.
    func removeTemporaryFiles() {
        if case let .media(media) = payload { media.removeTemporaryFiles() }
        if let voice, voice.fileURL.path.hasPrefix(FileManager.default.temporaryDirectory.path) {
            try? FileManager.default.removeItem(at: voice.fileURL)
        }
    }
}

enum CaptureDraftError: Error, Equatable {
    case missingMedia
    case unreadableImage
}

/// Builds the outbox draft: photos are re-encoded as JPEG without metadata (no location leaves
/// the device; the worker's renderer reads JPEG), movies and voice notes are passed as files.
enum CaptureDraftBuilder {
    /// JPEG quality of uploaded originals: the same encoder setting the worker uses for every
    /// image it writes (backend/worker/src/media/renditions.ts `JPEG_OPTIONS.quality` 85). The
    /// API contract (docs/API.md §7) sets no upload quality; photos are never downscaled.
    static let jpegQuality = 0.85

    static var draftsDirectory: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("CaptureDrafts", isDirectory: true)
    }

    static func build(_ request: CaptureSendRequest) async throws -> PostDraft {
        let folder = draftsDirectory.appendingPathComponent(request.id.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let groupIDs = request.groupIDs.map { GroupID($0) }
        let caption = request.caption.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
        let voice = request.voice.map { PostDraft.File(url: $0.fileURL, contentType: ContentType.m4a) }
        let invitationID = request.invitationID.map { InvitationID($0) }
        let replyTo = request.replyToPostID.map { PostID($0) }

        switch request.payload {
        case let .media(media):
            switch media.kind {
            case .photo, .livePhoto:
                guard let still = media.still else { throw CaptureDraftError.missingMedia }
                let original = try writeJPEG(still.imageData, to: folder, name: "original")
                var motion: PostDraft.File?
                var motionMs: Int?
                if media.kind == .livePhoto, let movie = still.livePhotoMovieURL {
                    motion = PostDraft.File(url: movie, contentType: ContentType.quickTime)
                    motionMs = await durationMs(of: movie)
                }
                return PostDraft(
                    kind: motion == nil ? .photo : .livePhoto,
                    original: original.file,
                    width: original.width,
                    height: original.height,
                    motion: motion,
                    durationMs: motionMs,
                    voice: voice,
                    voiceDurationMs: request.voice?.durationMs,
                    groupIDs: groupIDs,
                    caption: caption,
                    invitationID: invitationID,
                    replyToPostID: replyTo
                )
            case .video:
                guard let video = media.video else { throw CaptureDraftError.missingMedia }
                let ext = video.fileURL.pathExtension.lowercased()
                let type = ContentType.forExtension(ext) ?? ContentType.quickTime
                let size = await pixelSize(ofVideo: video.fileURL)
                let measured = await durationMs(of: video.fileURL)
                return PostDraft(
                    kind: .video,
                    original: PostDraft.File(url: video.fileURL, contentType: type),
                    width: size?.width,
                    height: size?.height,
                    durationMs: video.durationMs > 0 ? video.durationMs : measured,
                    voice: voice,
                    voiceDurationMs: request.voice?.durationMs,
                    groupIDs: groupIDs,
                    caption: caption,
                    invitationID: invitationID,
                    replyToPostID: replyTo
                )
            }
        case let .daily(answer):
            let original = try writeJPEG(answer.main.imageData, to: folder, name: "original")
            let front = try answer.inset.map { try writeJPEG($0.imageData, to: folder, name: "front") }
            return PostDraft(
                kind: .photo,
                original: original.file,
                width: original.width,
                height: original.height,
                front: front?.file,
                frontWidth: front?.width,
                frontHeight: front?.height,
                groupIDs: groupIDs,
                caption: caption,
                invitationID: invitationID
            )
        }
    }

    /// Removes the temporary folder of a request once the outbox has copied its files.
    static func cleanUp(_ request: CaptureSendRequest) {
        try? FileManager.default.removeItem(at: draftsDirectory.appendingPathComponent(request.id.uuidString, isDirectory: true))
    }

    private struct EncodedImage {
        let file: PostDraft.File
        let width: Int?
        let height: Int?
    }

    private static func writeJPEG(_ data: Data, to folder: URL, name: String) throws -> EncodedImage {
        guard let size = ImageEncoder.pixelSize(data) else { throw CaptureDraftError.unreadableImage }
        let jpeg = try ImageEncoder.jpegForUpload(
            data,
            options: ImageEncoder.Options(maxPixelSize: max(size.width, size.height), compressionQuality: jpegQuality)
        )
        let url = folder.appendingPathComponent(name).appendingPathExtension("jpg")
        try jpeg.write(to: url, options: [.atomic])
        let encoded = ImageEncoder.pixelSize(jpeg)
        return EncodedImage(file: PostDraft.File(url: url, contentType: ContentType.jpeg), width: encoded?.width, height: encoded?.height)
    }

    static func durationMs(of url: URL) async -> Int? {
        let asset = AVURLAsset(url: url)
        guard let duration = try? await asset.load(.duration) else { return nil }
        let seconds = CMTimeGetSeconds(duration)
        guard seconds.isFinite, seconds > 0 else { return nil }
        return Int((seconds * 1000).rounded())
    }

    static func pixelSize(ofVideo url: URL) async -> (width: Int, height: Int)? {
        let asset = AVURLAsset(url: url)
        guard let track = try? await asset.loadTracks(withMediaType: .video).first,
              let loaded = try? await track.load(.naturalSize, .preferredTransform) else { return nil }
        let rect = CGRect(origin: .zero, size: loaded.0).applying(loaded.1)
        let width = Int(abs(rect.width).rounded())
        let height = Int(abs(rect.height).rounded())
        guard width > 0, height > 0 else { return nil }
        return (width, height)
    }
}

extension CaptureStill {
    /// Decoded for display (preview card, dual image).
    var image: UIImage? { UIImage(data: imageData) }
}
