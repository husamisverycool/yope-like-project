// Surface: birthday.request — view models (the request sheet and the group-screen entry).
// Spec: design/surfaces/birthday.request.md. The honoree never sees a request about them: RLS
// hides those rows, and these models drop them as well.
import AppData
import DesignSystem
import Foundation
import Observation

@MainActor
@Observable
final class BirthdayRequestModel {
    enum Phase: Equatable {
        case idle
        case loading
        /// Open: "Add Your Photo" or the member's own contribution, then Message Ideas.
        case open
        /// `tribute_closed` or `due_at` passed: hero + title stay, the rest is replaced.
        case closed
        /// `request_not_found` (honoree opted out, left, block) or the caller is the honoree.
        case notFound
        case error
        case offline
    }

    /// The member's own contribution (RLS returns only theirs).
    struct OwnContribution: Equatable {
        let postID: PostID
        let line: String
        let imageURL: URL?
        let aspectRatio: CGFloat?
    }

    /// A failed withdraw, said under the own block.
    enum Inline: Equatable {
        case offline
        case error
    }

    var phase: Phase = .idle
    var honoreeName = ""
    var heroURL: URL?
    var dueText = ""
    var contribution: OwnContribution?
    var inline: Inline?
    var isRemoving = false
    /// Presents `birthday.contribute` (full screen, its own navigation).
    var showsContribute = false
    private(set) var request: TributeRequest?

    let requestID: TributeRequestID
    private let dependencies: MemoryDependencies

    init(requestID: TributeRequestID, dependencies: MemoryDependencies) {
        self.requestID = requestID
        self.dependencies = dependencies
    }

    /// `birthday.request.title`.
    var title: String { Copy.birthdayRequestTitle(name: honoreeName) }

    /// `birthday.request.body` + " " + `.ease` + " " + `.thanks` as one paragraph.
    var message: String {
        [Copy.birthdayRequestBody(name: honoreeName), Copy.birthdayRequestEase, Copy.birthdayRequestThanks].joined(separator: " ")
    }

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
            guard let request = try await data.request(id: requestID) else {
                phase = .notFound
                return
            }
            let me = await data.currentUser()
            guard request.honoreeID != me else {
                phase = .notFound
                return
            }
            self.request = request
            let honoree = try await data.profiles(ids: [request.honoreeID]).first
            honoreeName = honoree?.firstName ?? ""
            if let avatar = honoree?.avatarPath {
                heroURL = try await data.signedURLs(paths: [avatar])[avatar]
            }
            dueText = Copy.birthdayRequestDue(date: MemoryFormat.dueDate(birthday: request.birthdayDate))
            guard request.isOpen(at: dependencies.now()) else {
                phase = .closed
                return
            }
            contribution = try await Self.ownContribution(requestID: requestID, data: data)
            phase = .open
        } catch {
            switch MemoryFailure(error) {
            case .offline: phase = .offline
            case .notFound: phase = .notFound
            case .closed: phase = .closed
            default: phase = .error
            }
        }
    }

    /// Re-reads the own contribution (after `birthday.contribute` closed).
    func reloadContribution() async {
        guard phase == .open, let data = dependencies.data else { return }
        do {
            contribution = try await Self.ownContribution(requestID: requestID, data: data)
            inline = nil
        } catch {
            if MemoryFailure(error) == .closed { phase = .closed }
        }
    }

    static func ownContribution(requestID: TributeRequestID, data: any MemoryDataSource) async throws -> OwnContribution? {
        guard let row = try await data.myContribution(requestID: requestID) else { return nil }
        let post = try await data.postsWithMedia(ids: [row.postID]).first
        var url: URL?
        if let path = post?.media?.imagePath(for: .display) {
            url = try await data.signedURLs(paths: [path])[path]
        }
        var aspect: CGFloat?
        if let width = post?.media?.width, let height = post?.media?.height, width > 0, height > 0 {
            aspect = CGFloat(width) / CGFloat(height)
        }
        return OwnContribution(postID: row.postID, line: row.line, imageURL: url, aspectRatio: aspect)
    }

    func addPhoto() {
        showsContribute = true
    }

    /// Withdraw (direct DELETE of the own row before `due_at`); no confirmation — re-adding is
    /// possible until the due time.
    func remove() async {
        guard contribution != nil, !isRemoving, let data = dependencies.data else { return }
        isRemoving = true
        defer { isRemoving = false }
        do {
            try await data.withdraw(requestID: requestID)
            contribution = nil
            inline = nil
            dependencies.haptics(Tokens.Haptics.globalSuccess)
        } catch {
            dependencies.haptics(Tokens.Haptics.globalError)
            switch MemoryFailure(error) {
            case .offline: inline = .offline
            case .closed: phase = .closed
            default: inline = .error
            }
        }
    }
}

/// Rows for the open birthday requests of one group (`groups.screen` entry).
@MainActor
@Observable
final class BirthdayRequestsEntryModel {
    struct Item: Identifiable, Equatable {
        let requestID: TributeRequestID
        let content: MemoryEntryContent
        var id: TributeRequestID { requestID }
    }

    var items: [Item] = []
    let groupID: GroupID
    private let dependencies: MemoryDependencies

    init(groupID: GroupID, dependencies: MemoryDependencies) {
        self.groupID = groupID
        self.dependencies = dependencies
    }

    func refresh() async {
        guard let data = dependencies.data else {
            items = []
            return
        }
        do {
            let me = await data.currentUser()
            let now = dependencies.now()
            let requests = try await data.openRequests().filter {
                $0.groupID == groupID && $0.honoreeID != me && $0.isOpen(at: now)
            }
            let profiles = try await data.profiles(ids: Array(Set(requests.map(\.honoreeID))))
            let names = Dictionary(profiles.map { ($0.id, $0.firstName ?? "") }, uniquingKeysWith: { first, _ in first })
            items = requests.map { request in
                Item(
                    requestID: request.id,
                    content: MemoryEntryContent(
                        title: Copy.birthdayRequestTitle(name: names[request.honoreeID] ?? ""),
                        subtitle: Copy.birthdayRequestDue(date: MemoryFormat.dueDate(birthday: request.birthdayDate))
                    )
                )
            }
        } catch {
            // The rows are invitations only: on failure they stay as they were.
        }
    }
}
