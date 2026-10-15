// Surfaces: week.recap, week.edit, week.history — reference apps: Yope (recap, edit), Retro (history).
// Specs: design/surfaces/week.*.md ("States", "Data & actions"). View models only (Foundation + Observation + AppData).
import AppData
import AppModels
import Foundation
import Observation

/// Authors' profiles for photo labels.
enum SocialPeople {
    static func profiles(of posts: [PostWithMedia], known: [UserID: Profile], data: any SocialDataSource) async -> [UserID: Profile] {
        var result = known
        let wanted = posts.map(\.post.authorID).socialUnique().filter { result[$0] == nil }
        if !wanted.isEmpty, let found = try? await data.profiles(ids: wanted) {
            for profile in found { result[profile.id] = profile }
        }
        return result
    }
}

/// Loads the posts of one group-local week (`group_history_weeks`, chronological).
enum WeekPosts {
    static func ids(of weekStart: LocalDate, groupID: GroupID, data: any SocialDataSource) async throws -> [PostID] {
        // `p_before_week` is exclusive: the first week returned is `weekStart` when it has posts.
        let weeks = try await data.historyWeeks(groupID: groupID, beforeWeek: weekStart.adding(days: 1))
        return weeks.first { $0.weekStart == weekStart }?.postIDs ?? []
    }
}

/// `week.recap`: the recap card (recap items) and the week's pics grid.
@MainActor
@Observable
final class WeekRecapModel {
    enum Phase: Equatable {
        case loading
        case ready
        /// `status = pending` (`week.recap.pending`).
        case pending
        /// No ready recap yet.
        case empty
        case failed
        case offline
    }

    /// The floating "recap | pics" capsule.
    enum Segment: Hashable, Sendable {
        case recap
        case pics
    }

    let groupID: GroupID
    let recapID: RecapID
    @ObservationIgnored private let data: any SocialDataSource

    private(set) var phase: Phase = .loading
    private(set) var recap: WeeklyRecap?
    private(set) var group: PhotoGroup?
    /// Recap items in `weekly_recaps.items` order (hidden posts dropped by RLS).
    private(set) var cardPosts: [PostWithMedia] = []
    /// Every visible post of the week, chronological.
    private(set) var weekPosts: [PostWithMedia] = []
    private(set) var segment: Segment = .recap
    private(set) var signals = SocialSignals()
    /// Authors of the shown posts (tile labels) and the viewer.
    private(set) var profiles: [UserID: Profile] = [:]
    private(set) var me: UserID?

    init(groupID: GroupID, recapID: RecapID, data: any SocialDataSource) {
        self.groupID = groupID
        self.recapID = recapID
        self.data = data
    }

    var timeZone: TimeZone { group?.resolvedTimeZone ?? .current }

    /// The pencil opens `week.edit` only for a ready recap.
    var canEdit: Bool { recap?.status == .ready }

    func load() async {
        do {
            if group == nil { group = try await data.group(id: groupID) }
            guard let recap = try await data.recap(id: recapID) else {
                phase = .empty
                return
            }
            self.recap = recap
            guard recap.status == .ready else {
                phase = recap.status == .pending ? .pending : .empty
                return
            }
            cardPosts = try await data.posts(ids: recap.items)
            let weekIDs = try await WeekPosts.ids(of: recap.weekStart, groupID: groupID, data: data)
            weekPosts = try await data.posts(ids: weekIDs)
            me = await data.currentUserID()
            profiles = await SocialPeople.profiles(of: cardPosts + weekPosts, known: profiles, data: data)
            phase = .ready
        } catch {
            switch SocialFailure(error) {
            case .offline: phase = .offline
            case .notFound: phase = .empty
            default: phase = .failed
            }
        }
    }

    func retry() async {
        phase = .loading
        await load()
    }

    /// A segment was tapped (or scrolling crossed into the other part).
    func setSegment(_ segment: Segment, fromScroll: Bool = false) {
        guard segment != self.segment else { return }
        self.segment = segment
        if !fromScroll { signals.emit(.select) }
    }

    func run() async {
        for await event in data.events(groupID: groupID) {
            handle(event)
        }
    }

    /// `post_deleted` → the item leaves the card and the grid.
    func handle(_ event: GroupEvent) {
        guard case let .postDeleted(postID, _) = event else { return }
        cardPosts.removeAll { $0.id == postID }
        weekPosts.removeAll { $0.id == postID }
    }
}

/// `week.edit`: check / uncheck the week's photos, edit the recap text, save; or save the checked
/// photos as a named album (also opened straight on the album sheet from `week.history`).
@MainActor
@Observable
final class WeekEditModel {
    enum Mode: Hashable, Sendable {
        /// Pencil on `week.recap`.
        case recap(RecapID)
        /// "Save as album" in a `week.history` week menu: that week's photos, all checked, album sheet open.
        case album(weekStart: LocalDate)
    }

    enum Phase: Equatable {
        case loading
        case ready
        /// `recap_not_ready` (`week.edit.error.notReady`).
        case notReady
        case failed
        case offline
    }

    let groupID: GroupID
    let mode: Mode
    @ObservationIgnored private let data: any SocialDataSource

    private(set) var phase: Phase = .loading
    private(set) var recap: WeeklyRecap?
    /// Grid order: the recap's items first in recap order, then the week's other posts in time order.
    private(set) var gridPosts: [PostWithMedia] = []
    private(set) var checked: Set<PostID> = []
    /// Recap text (`weekly_recaps.text`, ≤ 2000).
    var text = ""
    private(set) var isSaving = false
    /// Inline error above the buttons (`week.edit.error.save` / `.notReady`); the selection is kept.
    private(set) var saveError: SocialFailure?
    /// The editor is done (saved) and closes.
    private(set) var isFinished = false

    var isAlbumSheetPresented = false
    var albumName = ""
    /// `week.edit.error.albumName` after submitting an empty name.
    private(set) var albumNameMissing = false
    private(set) var isSavingAlbum = false
    private(set) var albumError: SocialFailure?
    private(set) var savedAlbum: Album?
    private(set) var signals = SocialSignals()
    private(set) var profiles: [UserID: Profile] = [:]
    private(set) var me: UserID?

    init(groupID: GroupID, mode: Mode, data: any SocialDataSource) {
        self.groupID = groupID
        self.mode = mode
        self.data = data
        if case .album = mode { isAlbumSheetPresented = true }
    }

    /// Checked photos in grid order (what `update_recap` / `save_album` receive).
    var checkedInOrder: [PostID] { gridPosts.map(\.id).filter(checked.contains) }

    /// Album save: at least one photo checked and a name typed.
    var canSaveAlbum: Bool {
        !checked.isEmpty && !albumName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSavingAlbum
    }

    func load() async {
        do {
            switch mode {
            case let .recap(recapID):
                guard let recap = try await data.recap(id: recapID) else {
                    phase = .failed
                    return
                }
                self.recap = recap
                guard recap.status == .ready else {
                    phase = .notReady
                    return
                }
                text = recap.text ?? ""
                let items = try await data.posts(ids: recap.items)
                let weekIDs = try await WeekPosts.ids(of: recap.weekStart, groupID: groupID, data: data)
                let inRecap = Set(items.map(\.id))
                let others = try await data.posts(ids: weekIDs.filter { !inRecap.contains($0) })
                gridPosts = items + others
                checked = inRecap
            case let .album(weekStart):
                let weekIDs = try await WeekPosts.ids(of: weekStart, groupID: groupID, data: data)
                gridPosts = try await data.posts(ids: weekIDs)
                checked = Set(gridPosts.map(\.id))
            }
            me = await data.currentUserID()
            profiles = await SocialPeople.profiles(of: gridPosts, known: profiles, data: data)
            phase = .ready
        } catch {
            switch SocialFailure(error) {
            case .offline: phase = .offline
            case .notReady: phase = .notReady
            default: phase = .failed
            }
        }
    }

    func isChecked(_ id: PostID) -> Bool { checked.contains(id) }

    /// Tap on a tile (`haptic.global.select`).
    func toggle(_ id: PostID) {
        guard gridPosts.contains(where: { $0.id == id }) else { return }
        if checked.contains(id) { checked.remove(id) } else { checked.insert(id) }
        signals.emit(.select)
    }

    /// Development-only reorder approximation (`week.edit.layout.reorder` is BLOCKED): moves a checked
    /// tile to another checked tile's place. Returns whether anything moved.
    @discardableResult
    func move(_ id: PostID, to target: PostID) -> Bool {
        guard id != target, checked.contains(id), checked.contains(target),
              let from = gridPosts.firstIndex(where: { $0.id == id }),
              let to = gridPosts.firstIndex(where: { $0.id == target }) else { return false }
        let post = gridPosts.remove(at: from)
        gridPosts.insert(post, at: to)
        return true
    }

    /// "save": `update_recap(p_items: checked in order, p_text)`.
    func save() async {
        guard case let .recap(recapID) = mode, !isSaving else { return }
        isSaving = true
        saveError = nil
        defer { isSaving = false }
        do {
            recap = try await data.updateRecap(id: recapID, items: checkedInOrder, text: text)
            signals.emit(.success)
            signals.post(.recapSaved)
            isFinished = true
        } catch {
            saveError = SocialFailure(error)
            signals.emit(.failed)
        }
    }

    /// The album sheet's lime button / return key.
    func saveAlbum() async {
        let name = albumName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            albumNameMissing = true
            return
        }
        guard !checked.isEmpty, !isSavingAlbum else { return }
        albumNameMissing = false
        albumError = nil
        isSavingAlbum = true
        defer { isSavingAlbum = false }
        do {
            savedAlbum = try await data.saveAlbum(groupID: groupID, name: name, postIDs: checkedInOrder)
            signals.emit(.success)
            signals.post(.albumSaved)
            isAlbumSheetPresented = false
            if case .album = mode { isFinished = true }
        } catch {
            albumError = SocialFailure(error)
            signals.emit(.failed)
        }
    }

    func albumNameChanged() {
        if albumNameMissing, !albumName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { albumNameMissing = false }
    }
}

/// `week.history`: the group's weeks, newest first, each a strip of its photos (Retro).
@MainActor
@Observable
final class WeekHistoryModel {
    struct Week: Identifiable, Equatable {
        var weekStart: LocalDate
        var postIDs: [PostID]
        /// The week containing today (group-local): it also shows the add tile and empty days.
        var isCurrent: Bool

        var id: LocalDate { weekStart }
    }

    enum Line: Equatable {
        /// `week.history.empty` (the group has no photos yet).
        case empty
        /// `week.history.error` (pull down to retry).
        case error
        /// `week.history.offline` at the top of the list.
        case offline
    }

    let groupID: GroupID
    @ObservationIgnored private let data: any SocialDataSource
    @ObservationIgnored private let now: @Sendable () -> Date

    private(set) var isLoading = true
    private(set) var group: PhotoGroup?
    private(set) var weeks: [Week] = []
    private(set) var posts: [PostID: PostWithMedia] = [:]
    private(set) var profiles: [UserID: Profile] = [:]
    /// Ready recaps by week (the week menu's "View recap").
    private(set) var readyRecaps: [LocalDate: RecapID] = [:]
    private(set) var line: Line?
    private(set) var isOffline = false
    private(set) var hasMore = false
    private(set) var isLoadingMore = false

    init(groupID: GroupID, data: any SocialDataSource, now: @escaping @Sendable () -> Date = { Date() }) {
        self.groupID = groupID
        self.data = data
        self.now = now
    }

    var timeZone: TimeZone { group?.resolvedTimeZone ?? .current }

    var currentWeekStart: LocalDate { SocialCalendar.weekStart(containing: now(), in: timeZone) }

    func load() async {
        if group == nil { group = await data.cachedGroup(id: groupID) }
        // Cached weeks first (no indicator when there are some), refreshed in place.
        if weeks.isEmpty, let cached = await data.cachedHistoryWeeks(groupID: groupID), !cached.isEmpty {
            apply(cached, replacing: true)
            isLoading = false
            await loadDetails()
        }
        if let fresh = try? await data.group(id: groupID) { group = fresh }
        do {
            let fetched = try await data.historyWeeks(groupID: groupID, beforeWeek: nil)
            isOffline = false
            apply(fetched, replacing: true)
            hasMore = fetched.count == SocialPaging.historyWeeks
            line = fetched.isEmpty ? .empty : nil
            await loadDetails()
        } catch {
            let failure = SocialFailure(error)
            if failure == .offline, let cached = await data.cachedHistoryWeeks(groupID: groupID) {
                isOffline = true
                apply(cached, replacing: true)
                line = .offline
                await loadDetails()
            } else {
                apply([], replacing: true)
                isOffline = failure == .offline
                line = isOffline ? .offline : .error
            }
        }
        isLoading = false
    }

    /// Next 8 weeks when the list reaches its end.
    func loadMore() async {
        guard hasMore, !isLoadingMore, let last = weeks.last?.weekStart else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let fetched = try await data.historyWeeks(groupID: groupID, beforeWeek: last)
            apply(fetched, replacing: false)
            hasMore = fetched.count == SocialPaging.historyWeeks
            await loadDetails()
        } catch {
            if SocialFailure(error) == .offline { isOffline = true }
        }
    }

    private func apply(_ fetched: [HistoryWeek], replacing: Bool) {
        let current = currentWeekStart
        var result = replacing ? [] : weeks
        let known = Set(result.map(\.weekStart))
        for week in fetched where !known.contains(week.weekStart) {
            result.append(Week(weekStart: week.weekStart, postIDs: week.postIDs, isCurrent: week.weekStart == current))
        }
        // The current week is synthesised when it has no posts (docs/API.md §6.4 note in the spec).
        if !result.contains(where: { $0.weekStart == current }) {
            result.append(Week(weekStart: current, postIDs: [], isCurrent: true))
        }
        weeks = result.sorted { $0.weekStart > $1.weekStart }
    }

    private func loadDetails() async {
        let wanted = weeks.flatMap(\.postIDs).filter { posts[$0] == nil }
        if !wanted.isEmpty, let found = try? await data.posts(ids: wanted) {
            for post in found { posts[post.id] = post }
        }
        let people = posts.values.map(\.post.authorID).socialUnique().filter { profiles[$0] == nil }
        if !people.isEmpty, let found = try? await data.profiles(ids: people) {
            for profile in found { profiles[profile.id] = profile }
        }
        if let recaps = try? await data.recaps(groupID: groupID) {
            for recap in recaps where recap.status == .ready { readyRecaps[recap.weekStart] = recap.id }
        }
        // Posts hidden from the caller (blocks) leave the strips.
        let hidden = weeks.flatMap(\.postIDs).filter { posts[$0] == nil }
        if !hidden.isEmpty, !isOffline {
            let gone = Set(hidden)
            for index in weeks.indices { weeks[index].postIDs.removeAll { gone.contains($0) } }
        }
    }

    func run() async {
        for await event in data.events(groupID: groupID) {
            await handle(event)
        }
    }

    /// `post_deleted` drops tiles; a new post joins the current week.
    func handle(_ event: GroupEvent) async {
        switch event {
        case let .postDeleted(postID, _):
            for index in weeks.indices { weeks[index].postIDs.removeAll { $0 == postID } }
            weeks.removeAll { $0.postIDs.isEmpty && !$0.isCurrent }
            posts[postID] = nil
            if weeks.allSatisfy({ $0.postIDs.isEmpty }) { line = .empty }
        case let .postInserted(post):
            guard post.groupID == groupID,
                  let index = weeks.firstIndex(where: { $0.weekStart == SocialCalendar.weekStart(containing: post.createdAt, in: timeZone) }),
                  !weeks[index].postIDs.contains(post.id) else { return }
            weeks[index].postIDs.append(post.id)
            if let found = try? await data.posts(ids: [post.id]) {
                for item in found { posts[item.id] = item }
            }
            if line == .empty { line = nil }
        default:
            break
        }
    }
}
