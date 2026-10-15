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

    /// `layout.birthday.contribute.lineMax`: the line stops growing at this many characters, with no
    /// visible counter (the API's 280-character bound stays the server check).
    static var lineMax: Int { Int(Tokens.Layouts.BirthdayContributeLineMax.maxCharacters) }

    /// Applies the field rules to `line` after each edit: one line of meaning (a typed return ends the
    /// entry instead of adding a line, so it is removed) and at most `lineMax` characters (a longer
    /// paste is cut). Returns whether a return was removed, so the field can end editing.
    @discardableResult
    func normalizeLine() -> Bool {
        var value = line
        let hadReturn = value.contains("\n")
        if hadReturn { value = value.replacingOccurrences(of: "\n", with: "") }
        if value.count > Self.lineMax { value = String(value.prefix(Self.lineMax)) }
        if value != line { line = value }
        return hadReturn
    }

    func loadIfNeeded() async {
        guard phase == .idle else { return }
        await load()
    }

    func retry() async {
        await load()
    }

    private struct Cached {
        let groupID: GroupID
        let honoreeName: String
        let groupName: String
        let photos: [EligiblePhoto]
        let ownPostID: PostID?
        let ownLine: String?
    }

    private var cacheKey: String { "birthday.contribute." + requestID.rawValue } // provenance-ok: cache key

    /// Cache-first: the picker opened before shows its photos at once; the fresh read replaces them.
    private func load() async {
        guard let data = dependencies.data else {
            phase = .error
            return
        }
        let me = await data.currentUser()
        let showsContent = phase == .loaded || phase == .empty
        if !showsContent, let cached = dependencies.cache.value(Cached.self, key: cacheKey, user: me) {
            apply(cached, keepSelection: false)
        } else if !showsContent {
            phase = .loading
        }
        do {
            guard let request = try await data.request(id: requestID), request.honoreeID != me else {
                dependencies.cache.remove(key: cacheKey)
                phase = .error
                return
            }
            guard request.isOpen(at: dependencies.now()) else {
                phase = .closed
                return
            }
            let honoree = try await data.profiles(ids: [request.honoreeID]).first?.firstName ?? ""
            let group = try await data.group(id: request.groupID)?.name ?? ""
            let fresh = try await Self.eligiblePhotos(groupID: request.groupID, data: data)
            let own = try await data.myContribution(requestID: requestID)
            let value = Cached(
                groupID: request.groupID, honoreeName: honoree, groupName: group, photos: fresh,
                ownPostID: own?.postID, ownLine: own?.line
            )
            dependencies.cache.set(value, key: cacheKey, user: me, postIDs: Set(fresh.map(\.id)))
            apply(value, keepSelection: true)
            listenForDeletions(groupID: request.groupID, data: data)
        } catch {
            let failure = MemoryFailure(error)
            if failure == .closed {
                phase = .closed
            } else if phase != .loaded && phase != .empty {
                phase = failure == .offline ? .offline : .error
            }
        }
    }

    /// Shows `value`; a choice the person already made in this flow is kept.
    private func apply(_ value: Cached, keepSelection: Bool) {
        groupID = value.groupID
        honoreeName = value.honoreeName
        groupName = value.groupName
        photos = value.photos
        let current = keepSelection ? selectedID : nil
        if let current, photos.contains(where: { $0.id == current }) {
            selectedID = current
        } else if let own = value.ownPostID, photos.contains(where: { $0.id == own }) {
            // "Retake" from the request: the current photo starts selected, the line is kept.
            selectedID = own
        } else {
            selectedID = nil
        }
        if line.isEmpty, let ownLine = value.ownLine { line = ownLine }
        phase = photos.isEmpty ? .empty : .loaded
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

    /// Optimistic: step 3 shows at once (its Done button waits for the answer); on failure the flow
    /// goes back to where the problem is, with the spec's error line.
    func submit() async {
        guard canSubmit, let selectedID, let data = dependencies.data else { return }
        inline = nil
        isSending = true
        path = [.message, .done]
        defer { isSending = false }
        do {
            _ = try await data.contribute(requestID: requestID, postID: selectedID, line: trimmedLine)
            dependencies.haptics(Tokens.Haptics.globalSend)
            dependencies.cache.remove(key: "birthday.request." + requestID.rawValue) // provenance-ok: cache key of birthday.request
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
                path = [.message]
            case .notFound:
                if case .api(.postNotFound, _) = DataError.from(error) {
                    removePost(selectedID)
                    path = []
                } else {
                    inline = .error
                    path = [.message]
                }
            default:
                inline = .error
                path = [.message]
            }
        }
    }

    // MARK: Step 3 — Done / close

    func finish() {
        guard !isSending else { return }
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
        dependencies.cache.purge(postID: postID)
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
