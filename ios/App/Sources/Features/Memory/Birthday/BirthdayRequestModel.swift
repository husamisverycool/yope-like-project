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
    /// A refresh failed offline while content is shown: `birthday.request.offline` under the hero.
    var isOffline = false
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

    private struct Cached {
        let request: TributeRequest
        let honoreeName: String
        let heroURL: URL?
        let dueText: String
        let contribution: OwnContribution?
    }

    private var cacheKey: String { "birthday.request." + requestID.rawValue } // provenance-ok: cache key

    /// Cache-first: the request opened before shows at once; the fresh read replaces it in place.
    private func load() async {
        guard let data = dependencies.data else {
            phase = .error
            return
        }
        let me = await data.currentUser()
        if phase != .open && phase != .closed, let cached = dependencies.cache.value(Cached.self, key: cacheKey, user: me),
           cached.request.honoreeID != me {
            apply(cached)
        } else if phase != .open && phase != .closed {
            phase = .loading
        }
        do {
            guard let request = try await data.request(id: requestID), request.honoreeID != me else {
                // The honoree never sees a request about them.
                dependencies.cache.remove(key: cacheKey)
                phase = .notFound
                return
            }
            let honoree = try await data.profiles(ids: [request.honoreeID]).first
            var hero: URL?
            if let avatar = honoree?.avatarPath {
                hero = try await data.signedURLs(paths: [avatar])[avatar]
            }
            var own: OwnContribution?
            if request.isOpen(at: dependencies.now()) {
                own = try await Self.ownContribution(requestID: requestID, data: data)
            }
            let fresh = Cached(
                request: request,
                honoreeName: honoree?.firstName ?? "",
                heroURL: hero,
                dueText: Copy.birthdayRequestDue(date: MemoryFormat.dueDate(birthday: request.birthdayDate)),
                contribution: own
            )
            dependencies.cache.set(fresh, key: cacheKey, user: me, postIDs: Set([own?.postID].compactMap { $0 }))
            isOffline = false
            apply(fresh)
        } catch {
            let failure = MemoryFailure(error)
            if phase == .open || phase == .closed {
                // Cached content stays; offline is said under the hero.
                isOffline = failure == .offline
                return
            }
            switch failure {
            case .offline: phase = .offline
            case .notFound: phase = .notFound
            case .closed: phase = .closed
            default: phase = .error
            }
        }
    }

    private func apply(_ value: Cached) {
        request = value.request
        honoreeName = value.honoreeName
        heroURL = value.heroURL
        dueText = value.dueText
        contribution = value.contribution
        phase = value.request.isOpen(at: dependencies.now()) ? .open : .closed
    }

    private func storeContribution() async {
        guard let request, let data = dependencies.data else { return }
        let me = await data.currentUser()
        let value = Cached(request: request, honoreeName: honoreeName, heroURL: heroURL, dueText: dueText, contribution: contribution)
        dependencies.cache.set(value, key: cacheKey, user: me, postIDs: Set([contribution?.postID].compactMap { $0 }))
    }

    /// Re-reads the own contribution (after `birthday.contribute` closed).
    func reloadContribution() async {
        guard phase == .open, let data = dependencies.data else { return }
        do {
            contribution = try await Self.ownContribution(requestID: requestID, data: data)
            inline = nil
            await storeContribution()
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
    /// possible until the due time. Optimistic: the block goes at once and comes back on failure.
    func remove() async {
        guard let removed = contribution, !isRemoving, let data = dependencies.data else { return }
        isRemoving = true
        defer { isRemoving = false }
        contribution = nil
        inline = nil
        do {
            try await data.withdraw(requestID: requestID)
            dependencies.haptics(Tokens.Haptics.globalSuccess)
            await storeContribution()
        } catch {
            contribution = removed
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
        let me = await data.currentUser()
        let cacheKey = "birthday.requests.entry." + groupID.rawValue // provenance-ok: cache key
        if items.isEmpty, let cached = dependencies.cache.value([Item].self, key: cacheKey, user: me) {
            items = cached
        }
        do {
            let now = dependencies.now()
            let requests = try await data.openRequests().filter {
                $0.groupID == groupID && $0.honoreeID != me && $0.isOpen(at: now)
            }
            let profiles = try await data.profiles(ids: Array(Set(requests.map(\.honoreeID))))
            let names = Dictionary(profiles.map { ($0.id, $0.firstName ?? "") }, uniquingKeysWith: { first, _ in first })
            let fresh = requests.map { request in
                Item(
                    requestID: request.id,
                    content: MemoryEntryContent(
                        title: Copy.birthdayRequestTitle(name: names[request.honoreeID] ?? ""),
                        subtitle: Copy.birthdayRequestDue(date: MemoryFormat.dueDate(birthday: request.birthdayDate))
                    )
                )
            }
            items = fresh
            dependencies.cache.set(fresh, key: cacheKey, user: me)
        } catch {
            // The rows are invitations only: on failure they stay as they were.
        }
    }
}
