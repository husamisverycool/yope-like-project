import Foundation

/// A photo, Live Photo or video ready to post, with its local files (docs/API.md recipe 9.4).
public struct PostDraft: Codable, Hashable, Sendable, Identifiable {
    /// A local file and its content type.
    public struct File: Codable, Hashable, Sendable {
        public var url: URL
        public var contentType: String

        public init(url: URL, contentType: String) {
            self.url = url
            self.contentType = contentType
        }

        var fileExtension: String {
            let ext = url.pathExtension.lowercased()
            if !ext.isEmpty { return ext }
            switch contentType {
            case ContentType.mp4: return "mp4"
            case ContentType.quickTime: return "mov"
            case ContentType.heic: return "heic"
            default: return "jpg"
            }
        }
    }

    /// Client-generated (UUID v4) so the files can be uploaded before the row exists.
    public var mediaID: MediaID
    public var kind: MediaKind
    /// The main image (back camera / only image), or the video file. Re-encode photos with
    /// `ImageEncoder.jpegForUpload` first (no location metadata leaves the device).
    public var original: File
    public var width: Int?
    public var height: Int?
    /// Front image of a dual capture.
    public var front: File?
    public var frontWidth: Int?
    public var frontHeight: Int?
    /// Live Photo video (required for `.livePhoto`).
    public var motion: File?
    /// Required for `.video`; the Live Photo motion length.
    public var durationMs: Int?
    /// Optional voice note (`.m4a`) and its length.
    public var voice: File?
    public var voiceDurationMs: Int?
    /// The voice note's waveform (100 levels of 0…31, docs/API.md §6.2 `p_voice_levels`).
    public var voiceLevels: [Int]?
    public var groupIDs: [GroupID]
    public var caption: String?
    /// The daily invitation being answered (the post is in-window only while it is open).
    public var invitationID: InvitationID?
    /// The chosen groups' open invitations this post answers (the camera's send-to while a window is open; migration
    /// 0035). Optional so drafts saved before it existed still decode.
    public var invitationIDs: [InvitationID]?
    /// Reply to a photo with a photo (exactly one group: the replied post's).
    public var replyToPostID: PostID?
    public var createdAt: Date
    /// Taken in the camera's 9 AM mode (camera.overnight): posted with `create_overnight_post` instead of
    /// `create_post`, so it develops at the groups' next 09:00 (docs/API.md §14.3). Photos only, without caption,
    /// voice note, invitation or reply. Optional so drafts saved before it existed still decode (nil = posted now).
    public var overnight: Bool?
    /// The weekly question this photo answers (question.weekly B, docs/API.md §14.4): once posted — at once or retried
    /// from the outbox — its post in `questionGroupID` is linked with `answer_question`. Optional so older drafts decode.
    public var questionID: GroupQuestionID?
    public var questionGroupID: GroupID?
    /// The day a library photo was taken (`media.taken_on`, migration 0050): the date only, in the device's zone; nil for
    /// camera photos. Optional so older drafts decode.
    public var takenOn: LocalDate?
    /// The selection this photo was posted with (`media.batch_id`, migration 0051): every photo of one selection shares it;
    /// nil for a single photo. Optional so older drafts decode.
    public var batchID: String?

    public var id: MediaID { mediaID }

    public init(
        mediaID: MediaID = .generate(),
        kind: MediaKind,
        original: File,
        width: Int? = nil,
        height: Int? = nil,
        front: File? = nil,
        frontWidth: Int? = nil,
        frontHeight: Int? = nil,
        motion: File? = nil,
        durationMs: Int? = nil,
        voice: File? = nil,
        voiceDurationMs: Int? = nil,
        voiceLevels: [Int]? = nil,
        groupIDs: [GroupID],
        caption: String? = nil,
        invitationID: InvitationID? = nil,
        invitationIDs: [InvitationID]? = nil,
        replyToPostID: PostID? = nil,
        createdAt: Date = Date(),
        overnight: Bool? = nil,
        questionID: GroupQuestionID? = nil,
        questionGroupID: GroupID? = nil,
        takenOn: LocalDate? = nil,
        batchID: String? = nil
    ) {
        self.mediaID = mediaID
        self.kind = kind
        self.original = original
        self.width = width
        self.height = height
        self.front = front
        self.frontWidth = frontWidth
        self.frontHeight = frontHeight
        self.motion = motion
        self.durationMs = durationMs
        self.voice = voice
        self.voiceDurationMs = voiceDurationMs
        self.voiceLevels = voiceLevels
        self.groupIDs = groupIDs
        self.caption = caption
        self.invitationID = invitationID
        self.invitationIDs = invitationIDs
        self.replyToPostID = replyToPostID
        self.createdAt = createdAt
        self.overnight = overnight
        self.questionID = questionID
        self.questionGroupID = questionGroupID
        self.takenOn = takenOn
        self.batchID = batchID
    }

    /// Storage objects of this draft, with the paths of docs/API.md §7.
    func uploads(owner: UserID) -> [UploadItem] {
        var items = [UploadItem(
            path: StoragePaths.original(owner: owner, media: mediaID, fileExtension: original.fileExtension),
            fileURL: original.url,
            contentType: original.contentType
        )]
        if let front {
            items.append(UploadItem(path: StoragePaths.front(owner: owner, media: mediaID), fileURL: front.url, contentType: front.contentType))
        }
        if let motion {
            items.append(UploadItem(path: StoragePaths.motion(owner: owner, media: mediaID), fileURL: motion.url, contentType: motion.contentType))
        }
        if let voice {
            items.append(UploadItem(path: StoragePaths.postVoice(owner: owner, media: mediaID), fileURL: voice.url, contentType: voice.contentType))
        }
        return items
    }

    func mediaRow(owner: UserID) -> NewMedia {
        NewMedia(
            id: mediaID,
            kind: kind,
            originalPath: StoragePaths.original(owner: owner, media: mediaID, fileExtension: original.fileExtension),
            frontOriginalPath: front.map { _ in StoragePaths.front(owner: owner, media: mediaID) },
            motionPath: motion.map { _ in StoragePaths.motion(owner: owner, media: mediaID) },
            width: width,
            height: height,
            frontWidth: frontWidth,
            frontHeight: frontHeight,
            durationMs: durationMs,
            takenOn: takenOn,
            batchID: batchID
        )
    }
}

/// Posts drafts with the recipe of docs/API.md 9.4 — upload the files, insert the `media` row,
/// call `create_post` — through an on-disk outbox, so a post survives going offline, a failed
/// request or the app being terminated mid-upload. Every step is idempotent (an object that
/// already exists, a media row already inserted, `already_posted`), so `resumePending()` can
/// replay a draft from the start.
public actor PostPublisher {
    public let posts: PostRepository
    public let uploader: MediaUploader
    public let directory: URL

    /// - Parameter directory: the outbox (default `Application Support/AppDataOutbox`); drafts
    ///   and copies of their files live here until posted or discarded.
    public init(posts: PostRepository, uploader: MediaUploader, directory: URL = PostPublisher.defaultDirectory()) {
        self.posts = posts
        self.uploader = uploader
        self.directory = directory
    }

    public static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("AppDataOutbox", isDirectory: true)
    }

    /// Saves the draft (copying its files into the outbox) and posts it. When it throws a transient
    /// error (`DataError.isTransient`) the draft stays in the outbox for `resumePending()`. An `overnight`
    /// draft returns no posts: it develops at its groups' reveal (docs/API.md §14.3).
    @discardableResult
    public func publish(_ draft: PostDraft) async throws -> [Post] {
        let saved = try enqueue(draft)
        return try await run(saved)
    }

    /// Saves the draft in the outbox without posting it.
    @discardableResult
    public func enqueue(_ draft: PostDraft) throws -> PostDraft {
        let folder = folder(draft.mediaID)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            var saved = draft
            saved.original = try copy(draft.original, to: folder, name: "original")
            saved.front = try draft.front.map { try copy($0, to: folder, name: "front") }
            saved.motion = try draft.motion.map { try copy($0, to: folder, name: "motion") }
            saved.voice = try draft.voice.map { try copy($0, to: folder, name: "voice") }
            let data = try DataCoding.makeEncoder().encode(saved)
            try data.write(to: folder.appendingPathComponent("draft.json"), options: [.atomic])
            return saved
        } catch let error as DataError {
            throw error
        } catch {
            throw DataError.localFile(draft.mediaID.rawValue)
        }
    }

    /// Drafts waiting in the outbox, oldest first.
    public func pending() -> [PostDraft] {
        let folders = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return folders.compactMap { folder in
            guard let data = try? Data(contentsOf: folder.appendingPathComponent("draft.json")) else { return nil }
            return try? DataCoding.makeDecoder().decode(PostDraft.self, from: data)
        }.sorted { $0.createdAt < $1.createdAt }
    }

    /// Retries every pending draft (on launch, after sign-in, when the network returns).
    /// Drafts that fail with a permanent error stay until `discard`ed; the result says why.
    @discardableResult
    public func resumePending() async -> [MediaID: Result<[Post], DataError>] {
        var results: [MediaID: Result<[Post], DataError>] = [:]
        for draft in pending() {
            do {
                results[draft.mediaID] = .success(try await run(draft))
            } catch {
                results[draft.mediaID] = .failure(DataError.from(error))
            }
        }
        return results
    }

    /// Removes a draft and its local files. Objects already uploaded stay private to the owner
    /// (docs/API.md 9.4 step 4).
    public func discard(_ mediaID: MediaID) {
        try? FileManager.default.removeItem(at: folder(mediaID))
    }

    /// Removes every draft (sign-out, account deletion).
    public func removeAll() {
        try? FileManager.default.removeItem(at: directory)
    }

    // MARK: Steps

    private func run(_ draft: PostDraft) async throws -> [Post] {
        let owner = try await posts.client.requireUserID()
        let items = draft.uploads(owner: owner)
        for item in items {
            try await uploader.upload(item)
        }
        try await posts.insertMedia(draft.mediaRow(owner: owner))
        if draft.overnight == true {
            do {
                try await posts.createOvernight(mediaID: draft.mediaID, groupIDs: draft.groupIDs)
            } catch DataError.api(.alreadyPosted, _) {
                // A replay after the photo was set to develop (the response was lost).
            }
            uploader.ledger?.forget(items.map(\.path))
            discard(draft.mediaID)
            // Nothing is readable before the reveal: no posts yet.
            return []
        }
        let created: [Post]
        do {
            created = try await posts.create(
                mediaID: draft.mediaID,
                groupIDs: draft.groupIDs,
                caption: draft.caption,
                voicePath: draft.voice.map { _ in StoragePaths.postVoice(owner: owner, media: draft.mediaID) },
                voiceDurationMs: draft.voice == nil ? nil : draft.voiceDurationMs,
                voiceLevels: draft.voice == nil ? nil : draft.voiceLevels,
                invitationID: draft.invitationID,
                invitationIDs: draft.invitationIDs,
                replyToPostID: draft.replyToPostID
            )
        } catch DataError.api(.alreadyPosted, _) {
            // A replay after the posts were created (the response was lost).
            let groups = Set(draft.groupIDs)
            created = try await posts.posts(mediaID: draft.mediaID).filter { groups.contains($0.groupID) }
        }
        await answerQuestion(draft, posts: created)
        uploader.ledger?.forget(items.map(\.path))
        discard(draft.mediaID)
        return created
    }

    /// Links the post in the question's group to the weekly question (question.weekly B). Best effort: the photo is
    /// posted either way, and a question that closed meanwhile is not a failed post.
    private func answerQuestion(_ draft: PostDraft, posts created: [Post]) async {
        guard draft.overnight != true, let questionID = draft.questionID,
              let post = created.first(where: { $0.groupID == draft.questionGroupID }) else { return }
        _ = try? await QuestionRepository(client: posts.client).answer(postID: post.id, questionID: questionID)
    }

    private func folder(_ mediaID: MediaID) -> URL {
        directory.appendingPathComponent(mediaID.rawValue, isDirectory: true)
    }

    private func copy(_ file: PostDraft.File, to folder: URL, name: String) throws -> PostDraft.File {
        let ext = file.fileExtension
        let destination = folder.appendingPathComponent("\(name).\(ext)")
        if file.url.standardizedFileURL == destination.standardizedFileURL { return file }
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        do {
            try FileManager.default.copyItem(at: file.url, to: destination)
        } catch {
            throw DataError.localFile(file.url.lastPathComponent)
        }
        return PostDraft.File(url: destination, contentType: file.contentType)
    }
}
