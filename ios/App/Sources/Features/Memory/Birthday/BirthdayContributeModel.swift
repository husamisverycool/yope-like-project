// Surface: birthday.contribute — view model. Spec: design/surfaces/birthday.contribute.md.
// Rule from the product spec: a contributor can only pick a photo of the request's group that they
// posted or are self-tagged in (`tagging`). One contribution per person; sending again replaces it.
import AppData
import DesignSystem
import Foundation
import Observation

@MainActor
@Observable
final class BirthdayContributeModel {
    /// Steps pushed after step 1 (Photo), which is the flow's root.
    enum Step: Hashable {
        case message
        case done
    }

    enum Phase: Equatable {
        case idle
        case loading
        case loaded
        /// No eligible photo: the Yope empty state under the thanks line.
        case empty
        /// `tribute_closed` / past `due_at`: replaces the step content.
        case closed
        case error
        case offline
    }

    /// Lines said in place (`birthday.contribute.notEligible` / `.offline` / `.error.*`).
    enum Inline: Equatable {
        case notEligible
        case offline
        case error
    }

    struct EligiblePhoto: Identifiable, Equatable {
        let id: PostID
        let thumbURL: URL?
        let displayURL: URL?
        let aspectRatio: CGFloat?
        let createdAt: Date
    }

    var phase: Phase = .idle
    var photos: [EligiblePhoto] = []
    var selectedID: PostID?
    var line = ""
    var path: [Step] = []
    var isSending = false
    var inline: Inline?
    var honoreeName = ""
    var groupName = ""
    /// Set when the flow should close (Done or ✕).
    var isFinished = false
    /// Set when the empty state's "open group" was tapped.
    var openGroupRequested = false
    private(set) var groupID: GroupID?

    let requestID: TributeRequestID
    private let dependencies: MemoryDependencies
    private var deletionTask: Task<Void, Never>?

    init(requestID: TributeRequestID, dependencies: MemoryDependencies) {
        self.requestID = requestID
        self.dependencies = dependencies
    }

    var step: Int {
        switch path.last {
        case nil: return 1
        case .message?: return 2
        case .done?: return 3
        }
    }

    var selectedPhoto: EligiblePhoto? {
        photos.first { $0.id == selectedID }
    }

    var trimmedLine: String {
        line.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// "Use Photo" is enabled once a photo is selected.
    var canUsePhoto: Bool { selectedPhoto != nil }

    /// "Submit" is disabled until the line has a non-space character.
    var canSubmit: Bool { !trimmedLine.isEmpty && !isSending && selectedPhoto != nil }

    func loadIfNeeded() async {
        guard phase == .idle else { return }
        await load()
    }

    func retry() async {
        await load()
    }

    private func load() async {
        phase = .loading
        guard let data = dependencies.data else {
            phase = .error
            return
        }
        do {
            let me = await data.currentUser()
            guard let request = try await data.request(id: requestID), request.honoreeID != me else {
                phase = .error
                return
            }
            groupID = request.groupID
            honoreeName = try await data.profiles(ids: [request.honoreeID]).first?.firstName ?? ""
            groupName = try await data.group(id: request.groupID)?.name ?? ""
            guard request.isOpen(at: dependencies.now()) else {
                phase = .closed
                return
            }
            photos = try await Self.eligiblePhotos(groupID: request.groupID, data: data)
            if let own = try await data.myContribution(requestID: requestID) {
                // "Retake" from the request: the current photo starts selected, the line is kept.
                if photos.contains(where: { $0.id == own.postID }) { selectedID = own.postID }
                line = own.line
            }
            phase = photos.isEmpty ? .empty : .loaded
            listenForDeletions(groupID: request.groupID, data: data)
        } catch {
            switch MemoryFailure(error) {
            case .offline: phase = .offline
            case .closed: phase = .closed
            default: phase = .error
            }
        }
    }

    /// The group's posts the caller posted or is self-tagged in, newest first, deduplicated.
    static func eligiblePhotos(groupID: GroupID, data: any MemoryDataSource) async throws -> [EligiblePhoto] {
        let ids = try await data.eligiblePostIDs(groupID: groupID)
        var seen = Set<PostID>()
        let unique = ids.filter { seen.insert($0).inserted }
        let posts = try await data.postsWithMedia(ids: unique)
            .filter { $0.post.groupID == groupID }
            .sorted { $0.post.createdAt > $1.post.createdAt }
        var paths: [String] = []
        for post in posts {
            if let path = post.media?.imagePath(for: .thumb) { paths.append(path) }
            if let path = post.media?.imagePath(for: .display) { paths.append(path) }
        }
        let urls = try await data.signedURLs(paths: paths)
        return posts.map { post in
            var aspect: CGFloat?
            if let width = post.media?.width, let height = post.media?.height, width > 0, height > 0 {
                aspect = CGFloat(width) / CGFloat(height)
            }
            return EligiblePhoto(
                id: post.post.id,
                thumbURL: post.media?.imagePath(for: .thumb).flatMap { urls[$0] },
                displayURL: post.media?.imagePath(for: .display).flatMap { urls[$0] },
                aspectRatio: aspect,
                createdAt: post.post.createdAt
            )
        }
    }

    // MARK: Step 1 — Photo

    /// Single choice: tapping another photo moves the check.
    func select(_ id: PostID) {
        guard selectedID != id else { return }
        selectedID = id
        inline = nil
        dependencies.haptics(Tokens.Haptics.globalSelect)
    }

    /// "Use Photo" → step 2.
    func usePhoto() {
        guard canUsePhoto else { return }
        inline = nil
        path = [.message]
    }

    // MARK: Step 2 — Message

    /// "Retake" → back to step 1, selection kept.
    func retake() {
        path = []
    }

    func submit() async {
        guard canSubmit, let selectedID, let data = dependencies.data else { return }
        inline = nil
        isSending = true
        defer { isSending = false }
        do {
            _ = try await data.contribute(requestID: requestID, postID: selectedID, line: trimmedLine)
            dependencies.haptics(Tokens.Haptics.globalSend)
            path = [.message, .done]
        } catch {
            dependencies.haptics(Tokens.Haptics.globalError)
            switch MemoryFailure(error) {
            case .notEligible:
                inline = .notEligible
                path = []
            case .closed:
                phase = .closed
                path = []
            case .offline:
                inline = .offline
            case .notFound:
                if case .api(.postNotFound, _) = DataError.from(error) {
                    removePost(selectedID)
                } else {
                    inline = .error
                }
            default:
                inline = .error
            }
        }
    }

    // MARK: Step 3 — Done / close

    func finish() {
        deletionTask?.cancel()
        isFinished = true
    }

    func openGroup() {
        openGroupRequested = true
        finish()
    }

    // MARK: Deletions (`post_deleted`)

    /// Drops the cell; if it was the chosen photo, back to step 1.
    func removePost(_ postID: PostID) {
        photos.removeAll { $0.id == postID }
        if selectedID == postID {
            selectedID = nil
            if step != 3 { path = [] }
        }
        if photos.isEmpty, phase == .loaded { phase = .empty }
    }

    private func listenForDeletions(groupID: GroupID, data: any MemoryDataSource) {
        deletionTask?.cancel()
        let stream = data.deletedPosts(groupID: groupID)
        deletionTask = Task { [weak self] in
            for await postID in stream {
                self?.removePost(postID)
            }
        }
    }

    func stopListening() {
        deletionTask?.cancel()
        deletionTask = nil
    }
}
