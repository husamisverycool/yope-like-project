// Surface: search.photos — find a photo by its caption or the chat about it, a member ("I'm in this") or a date
// (owner decision 34, research #6). Spec: design/surfaces/search.photos.md ("States", "Data & actions"). View model only
// (Foundation + Observation + AppData). No face or AI search; no result count anywhere (tenet 2).
import AppData
import AppModels
import Foundation
import Observation

@MainActor
@Observable
final class SearchPhotosModel {
    enum Phase: Equatable {
        /// Nothing typed, no chip on: `search.photos.idle.*`.
        case idle
        /// A search is out (placeholder cells).
        case loading
        /// At least one photo.
        case results
        /// `search.photos.empty.title`.
        case empty
        /// `search.photos.error` (tap searches again).
        case error
        /// `search.photos.offline` (tap searches again).
        case offline
    }

    /// One member chip: you first (`search.photos.member.you`), then the members by joining order.
    struct MemberChip: Identifiable, Equatable {
        let id: UserID
        /// The first name (empty for you: the chip shows `search.photos.member.you`).
        let name: String
        let isMe: Bool
    }

    /// The group searched (opened from `groups.screen`); nil: all your groups (opened from `groups.list`).
    let groupID: GroupID?
    @ObservationIgnored private let data: any SocialDataSource

    /// The field's text (searched on the keyboard's search key).
    var text = ""
    private(set) var memberID: UserID?
    private(set) var from: LocalDate?
    private(set) var to: LocalDate?
    private(set) var phase: Phase = .idle
    private(set) var hits: [PhotoSearchHit] = []
    private(set) var posts: [PostID: PostWithMedia] = [:]
    private(set) var profiles: [UserID: Profile] = [:]
    private(set) var members: [MemberChip] = []
    private(set) var me: UserID?
    private(set) var hasMore = false
    private(set) var isLoadingMore = false
    /// Each search gets the next number; an answer to an older one is dropped.
    @ObservationIgnored private var generation = 0
    /// The query the shown results answer (paging repeats it, whatever the field holds now).
    @ObservationIgnored private var asked: PhotoSearchQuery?

    init(groupID: GroupID?, data: any SocialDataSource) {
        self.groupID = groupID
        self.data = data
    }

    var query: PhotoSearchQuery {
        PhotoSearchQuery(text: text, groupID: groupID, memberID: memberID, from: from, to: to)
    }

    var hasDates: Bool { from != nil || to != nil }

    /// The photos found, in search order (newest first); a row whose post cannot be read is left out.
    var results: [PostWithMedia] { hits.compactMap { posts[$0.postID] } }

    /// `photo.viewer` over the results in this order; from all groups the header names each photo's group.
    func viewer(start: PostID) -> PhotoViewerContext {
        PhotoViewerContext(postIDs: results.map(\.id), start: start, groupID: groupID, showsGroupName: groupID == nil)
    }

    // MARK: Members

    /// The member chips: the group's members, or every member of every group you are in (each person once), you first,
    /// then by joining order.
    func loadMembers() async {
        me = await data.currentUserID()
        var people: [MemberProfile] = []
        if let groupID {
            people = await membersOf(groupID)
        } else {
            var groups: [PhotoGroup] = []
            if let fresh = try? await data.myGroups() {
                groups = fresh
            } else {
                groups = await data.cachedGroups() ?? []
            }
            for group in groups { people += await membersOf(group.id) }
        }
        var seen = Set<UserID>()
        var chips: [MemberChip] = []
        // Joining order; people who joined at the same moment keep the order they came in.
        let ordered = people.enumerated()
            .sorted { ($0.element.member.joinedAt, $0.offset) < ($1.element.member.joinedAt, $1.offset) }
            .map(\.element)
        for person in ordered {
            guard seen.insert(person.id).inserted else { continue }
            if let profile = person.profile { profiles[profile.id] = profile }
            chips.append(MemberChip(id: person.id, name: person.id == me ? "" : person.profile?.socialFirstName ?? "", isMe: person.id == me))
        }
        members = chips.filter(\.isMe) + chips.filter { !$0.isMe }
    }

    private func membersOf(_ id: GroupID) async -> [MemberProfile] {
        if let fresh = try? await data.members(groupID: id) { return fresh }
        return await data.cachedMembers(groupID: id) ?? []
    }

    // MARK: Criteria

    /// One member at a time: choosing another moves the selection; the chosen one again clears it.
    func toggle(member: UserID) async {
        memberID = memberID == member ? nil : member
        await search()
    }

    /// The date filter (inclusive, group-local days); a reversed range is put in order.
    func setDates(from start: LocalDate, to end: LocalDate) async {
        from = min(start, end)
        to = max(start, end)
        await search()
    }

    func clearDates() async {
        from = nil
        to = nil
        await search()
    }

    /// The field was edited: clearing the last criterion goes back to idle at once.
    func textChanged() {
        if query.isEmpty, phase != .idle { reset() }
    }

    // MARK: Search

    /// Searches with every criterion the screen holds; none → idle (nothing is asked).
    func search() async {
        let query = self.query
        generation += 1
        let mine = generation
        guard !query.isEmpty else {
            reset()
            return
        }
        phase = .loading
        hasMore = false
        do {
            let found = try await data.searchPhotos(query, before: nil)
            guard mine == generation else { return }
            try await loadDetails(found)
            guard mine == generation else { return }
            asked = query
            hits = found
            hasMore = found.count == SocialPaging.search
            phase = results.isEmpty ? .empty : .results
        } catch {
            guard mine == generation else { return }
            hits = []
            asked = nil
            phase = SocialFailure(error) == .offline ? .offline : .error
        }
    }

    /// The next page (`p_before` = the last row's `created_at`) when the grid reaches its end.
    func loadMore() async {
        guard hasMore, !isLoadingMore, phase == .results, let asked = asked, let last = hits.last else { return }
        let mine = generation
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let found = try await data.searchPhotos(asked, before: last.createdAt)
            guard mine == generation else { return }
            let known = Set(hits.map(\.postID))
            let fresh = found.filter { !known.contains($0.postID) }
            try await loadDetails(fresh)
            guard mine == generation else { return }
            hits += fresh
            hasMore = found.count == SocialPaging.search
        } catch {
            // The results shown stay; reaching the end again retries.
        }
    }

    private func reset() {
        generation += 1
        hits = []
        asked = nil
        hasMore = false
        phase = .idle
    }

    /// The rows' posts (with their media) and authors.
    private func loadDetails(_ batch: [PhotoSearchHit]) async throws {
        let wanted = batch.map(\.postID).filter { posts[$0] == nil }
        if !wanted.isEmpty {
            for post in try await data.posts(ids: wanted) { posts[post.id] = post }
        }
        let people = batch.map(\.authorID).socialUnique().filter { profiles[$0] == nil }
        if !people.isEmpty, let found = try? await data.profiles(ids: people) {
            for profile in found { profiles[profile.id] = profile }
        }
    }
}
