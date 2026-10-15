// Account group — groups.list state: the person's groups with their newest post, newest activity first; cached rows
// offline; realtime inserts / deletions and foreground refetches update the subtitles and the cover (docs/API.md §5.8, §8).
import AppData
import AppModels
import Foundation
import Observation

/// One card of the home list.
struct GroupRow: Identifiable, Equatable {
    let group: PhotoGroup
    /// The group's newest post (nil: no pics yet).
    var newest: PostWithMedia?
    /// The newest post's author's first name (nil when unknown).
    var senderFirstName: String?
    /// The newest post is the viewer's own (`groups.list.row.newPic`).
    var isOwnPost: Bool

    var id: GroupID { group.id }
    /// Newest activity: the newest post, else the group's creation.
    var activity: Date { newest?.post.createdAt ?? group.createdAt }
}

@MainActor
@Observable
final class GroupsListModel {
    enum Phase: Equatable {
        case loading
        /// Rows shown (fresh or cached).
        case loaded
        /// No groups: "create your first group".
        case empty
        /// Fetch failed with nothing cached.
        case error
        /// No connection and nothing cached.
        case offline
    }

    private(set) var rows: [GroupRow] = []
    private(set) var phase: Phase = .loading
    /// The person's avatar (tab bar "me").
    private(set) var avatarPath: String?
    /// The person's first name (cover label when the newest photo is their own).
    private(set) var myFirstName: String?

    private let data: AccountDataSource
    private var realtimeTasks: [GroupID: Task<Void, Never>] = [:]

    init(data: AccountDataSource) {
        self.data = data
    }

    /// The cover header: the row whose newest post is the newest photo across the groups.
    var coverRow: GroupRow? {
        rows.filter { $0.newest?.media != nil }.max { $0.activity < $1.activity }
    }

    /// First load: cached groups at once, then the server's.
    func load() async {
        if rows.isEmpty, let cached = await data.cachedGroups(), !cached.isEmpty {
            rows = cached.map { GroupRow(group: $0, newest: nil, senderFirstName: nil, isOwnPost: false) }
            phase = .loaded
        }
        await refresh()
    }

    /// Pull-to-refresh, foreground, reconnect.
    func refresh() async {
        let groups: [PhotoGroup]
        do {
            groups = try await data.myGroups()
        } catch {
            if rows.isEmpty {
                phase = DataError.from(error) == .offline ? .offline : .error
            }
            return
        }
        if let profile = try? await data.myProfile() {
            avatarPath = profile.avatarPath
            myFirstName = profile.firstName
        }
        let me = data.currentUserID
        var newest: [GroupID: PostWithMedia] = [:]
        for group in groups {
            if let post = try? await data.newestPost(groupID: group.id) {
                newest[group.id] = post
            } else if let existing = rows.first(where: { $0.id == group.id })?.newest {
                newest[group.id] = existing
            }
        }
        let authorIDs = Set(newest.values.map(\.post.authorID)).filter { $0 != me }
        let profiles = (try? await data.profiles(ids: Array(authorIDs))) ?? []
        let names = Dictionary(profiles.map { ($0.id, $0.firstName) }, uniquingKeysWith: { first, _ in first })
        rows = groups.map { group -> GroupRow in
            let post = newest[group.id]
            let isOwn = post.map { $0.post.authorID == me } ?? false
            var sender: String?
            if let post, !isOwn, let name = names[post.post.authorID] {
                sender = name
            }
            return GroupRow(group: group, newest: post, senderFirstName: sender, isOwnPost: isOwn)
        }
        .sorted { $0.activity > $1.activity }
        phase = rows.isEmpty ? .empty : .loaded
        followRealtime()
    }

    /// Retry pill of the error state.
    func retry() async {
        phase = .loading
        await refresh()
    }

    // MARK: Realtime

    private func followRealtime() {
        let current = Set(rows.map(\.id))
        for (id, task) in realtimeTasks where !current.contains(id) {
            task.cancel()
            realtimeTasks[id] = nil
        }
        for id in current where realtimeTasks[id] == nil {
            let events = data.groupEvents(groupID: id)
            realtimeTasks[id] = Task { [weak self] in
                for await event in events {
                    await self?.handle(event, groupID: id)
                }
            }
        }
    }

    /// A post arrived or was deleted, or the connection came back: refresh that group's card.
    func handle(_ event: GroupEvent, groupID: GroupID) async {
        switch event {
        case .postInserted, .postDeleted, .resubscribed:
            await reloadRow(groupID)
        default:
            break
        }
    }

    private func reloadRow(_ groupID: GroupID) async {
        guard let index = rows.firstIndex(where: { $0.id == groupID }) else { return }
        guard let post = try? await data.newestPost(groupID: groupID) else {
            rows[index].newest = nil
            rows[index].senderFirstName = nil
            rows[index].isOwnPost = false
            return
        }
        let me = data.currentUserID
        let isOwn = post.post.authorID == me
        var name: String?
        if !isOwn {
            name = (try? await data.profiles(ids: [post.post.authorID]))?.first?.firstName
        }
        guard let current = rows.firstIndex(where: { $0.id == groupID }) else { return }
        rows[current].newest = post
        rows[current].isOwnPost = isOwn
        rows[current].senderFirstName = name
        rows.sort { $0.activity > $1.activity }
    }

    func stop() {
        realtimeTasks.values.forEach { $0.cancel() }
        realtimeTasks.removeAll()
    }

    // MARK: Previews and tests

    /// Seeds a state directly (snapshot tests).
    func seed(rows: [GroupRow], phase: Phase, avatarPath: String? = nil) {
        self.rows = rows
        self.phase = phase
        self.avatarPath = avatarPath
    }
}
