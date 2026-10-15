// Account group — groups.screen state: the group's photos newest first (paged), members, "{first_name} joined" pills,
// realtime inserts / deletions, cached content offline (docs/API.md §5.3–5.4, §5.8, §8, §9.6).
import AppData
import AppModels
import Foundation
import Observation
import UIKit

/// One element of the feed: a photo card or a "joined" system pill.
enum FeedItem: Identifiable, Equatable {
    case post(PostWithMedia)
    case joined(MemberProfile)

    var id: String {
        switch self {
        case let .post(post): return "post-" + post.id.rawValue
        case let .joined(member): return "joined-" + member.id.rawValue
        }
    }

    var date: Date {
        switch self {
        case let .post(post): return post.post.createdAt
        case let .joined(member): return member.member.joinedAt
        }
    }
}

@MainActor
@Observable
final class GroupFeedModel {
    enum Phase: Equatable {
        case loading
        case loaded
        /// The viewer created the group and nothing is posted yet.
        case created
        /// Joined group without posts.
        case empty
        case error
        /// No connection and nothing cached.
        case offline
        /// `not_group_member`.
        case removed
    }

    let groupID: GroupID
    private(set) var group: PhotoGroup?
    private(set) var members: [MemberProfile] = []
    private(set) var posts: [PostWithMedia] = []
    private(set) var phase: Phase = .loading
    private(set) var isLoadingMore = false
    private(set) var latestRecapID: RecapID?
    /// Bumped when a realtime insert added cards (VoiceOver layout-changed announcement).
    private(set) var insertedCount = 0

    private(set) var nextCursor: Date?
    private let data: AccountDataSource
    private var realtimeTask: Task<Void, Never>?

    init(groupID: GroupID, data: AccountDataSource) {
        self.groupID = groupID
        self.data = data
    }

    var me: UserID? { data.currentUserID }
    var isCreator: Bool { group?.createdBy != nil && group?.createdBy == me }
    var isAdmin: Bool { members.contains { $0.member.userID == me && $0.member.role == .admin } }

    func profile(of userID: UserID) -> Profile? {
        members.first { $0.member.userID == userID }?.profile
    }

    /// Members who joined after the group was created (everyone but its creator), for the pills and "and added …".
    var joinedMembers: [MemberProfile] {
        members.filter { $0.member.userID != group?.createdBy }
    }

    /// `groups.screen.created.detail` {names}: joined members' first names, comma-separated (copy note).
    var joinedNames: String? {
        let names = joinedMembers.filter { $0.member.userID != me }.compactMap { $0.profile?.firstName }
        return names.isEmpty ? nil : names.joined(separator: ", ")
    }

    /// Cards and joined pills, newest first. Pills older than the oldest loaded card wait until the last page.
    var items: [FeedItem] {
        let oldest = nextCursor == nil ? Date.distantPast : (posts.last?.post.createdAt ?? Date.distantPast)
        let pills = joinedMembers.filter { $0.member.joinedAt >= oldest }.map(FeedItem.joined)
        return (posts.map(FeedItem.post) + pills).sorted { $0.date > $1.date }
    }

    // MARK: Loading

    /// Cached group, members and first page at once; then the server's.
    func load() async {
        if posts.isEmpty {
            if group == nil { group = await data.cachedGroups()?.first { $0.id == groupID } }
            if let cachedMembers = await data.cachedMembers(groupID: groupID) { members = cachedMembers }
            if let cached = await data.cachedFeed(groupID: groupID), !cached.isEmpty {
                posts = cached
                phase = .loaded
            }
        }
        await refresh()
        followRealtime()
    }

    func refresh() async {
        do {
            guard let fresh = try await data.group(id: groupID) else {
                phase = .removed
                return
            }
            group = fresh
            members = (try? await data.members(groupID: groupID)) ?? members
            let page = try await data.feed(groupID: groupID, before: nil)
            mergeFirstPage(page)
            latestRecapID = (try? await data.latestRecap(groupID: groupID))?.id
            updatePhase()
        } catch {
            let failure = DataError.from(error)
            if failure.apiCode == .notGroupMember {
                phase = .removed
            } else if posts.isEmpty {
                phase = failure == .offline ? .offline : .error
            }
        }
    }

    /// The first page replaces the newest cards and keeps older pages already loaded.
    private func mergeFirstPage(_ page: Page<PostWithMedia>) {
        guard let oldestFresh = page.items.last?.post.createdAt, page.nextCursor != nil else {
            posts = page.items
            nextCursor = nil
            return
        }
        let older = posts.filter { $0.post.createdAt < oldestFresh }
        posts = page.items + older
        if older.isEmpty { nextCursor = page.nextCursor }
    }

    private func updatePhase() {
        if !posts.isEmpty {
            phase = .loaded
        } else {
            phase = isCreator ? .created : .empty
        }
    }

    /// The next (older) page, when the last card appears.
    func loadMore() async {
        guard let cursor = nextCursor, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        guard let page = try? await data.feed(groupID: groupID, before: cursor) else { return }
        let known = Set(posts.map(\.id))
        posts += page.items.filter { !known.contains($0.id) }
        nextCursor = page.nextCursor
    }

    /// Error state's retry.
    func retry() async {
        phase = .loading
        await refresh()
    }

    // MARK: Realtime

    private func followRealtime() {
        guard realtimeTask == nil else { return }
        let events = data.groupEvents(groupID: groupID)
        realtimeTask = Task { [weak self] in
            for await event in events {
                await self?.handle(event)
            }
        }
    }

    func stop() {
        realtimeTask?.cancel()
        realtimeTask = nil
    }

    func handle(_ event: GroupEvent) async {
        switch event {
        case let .postInserted(post) where post.groupID == groupID:
            guard !posts.contains(where: { $0.id == post.id }) else { return }
            await insertNewest()
        case let .postDeleted(postID, _):
            posts.removeAll { $0.id == postID }
            updatePhase()
        case .resubscribed:
            await refresh()
        default:
            break
        }
    }

    /// A new post: the first page is read again and new cards slide in at the top.
    private func insertNewest() async {
        guard let page = try? await data.feed(groupID: groupID, before: nil) else { return }
        let known = Set(posts.map(\.id))
        let fresh = page.items.filter { !known.contains($0.id) }
        guard !fresh.isEmpty else { return }
        posts = (fresh + posts).sorted { $0.post.createdAt > $1.post.createdAt }
        if !members.contains(where: { member in fresh.contains { $0.post.authorID == member.member.userID } }) {
            members = (try? await data.members(groupID: groupID)) ?? members
        }
        insertedCount += 1
        updatePhase()
    }

    /// The person was blocked: their content disappears (RLS); read again.
    func blocked(_ userID: UserID) async {
        posts.removeAll { $0.post.authorID == userID }
        await refresh()
    }

    // MARK: Prefetch

    /// Warms the image cache for the newest page beyond what is on screen (`pixels` = card pixel size).
    func prefetchImages(after index: Int, pixels: Int) async {
        let upcoming = posts.dropFirst(index + 1).prefix(PostRepositoryPrefetch.count)
        var items: [(path: String, url: URL)] = []
        for post in upcoming {
            guard let path = post.media?.imagePath(for: .display), let url = try? await data.signedURL(path: path) else { continue }
            items.append((path, url))
        }
        ImagePipeline.shared.prefetch(items, pixels: pixels)
    }

    // MARK: Previews and tests

    func seed(group: PhotoGroup?, members: [MemberProfile], posts: [PostWithMedia], phase: Phase) {
        self.group = group
        self.members = members
        self.posts = posts
        self.phase = phase
    }
}

/// How far ahead the feed warms images: one feed page (`PostRepository.pageSize`).
enum PostRepositoryPrefetch {
    static var count: Int { PostRepository.pageSize }
}
