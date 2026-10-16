// Surfaces: week.recap, week.edit, week.history — Retro recaps, "Add to Your Week" composer, profile week strips.
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

/// `week.recap` list (`week.recap.layout.list`): the group's recaps, newest first — ready ones as week cards (cover =
/// the first item), pending ones as placeholder cards.
@MainActor
@Observable
final class WeekRecapListModel {
    let groupID: GroupID
    @ObservationIgnored private let data: any SocialDataSource

    /// `.empty`: no recap yet.
    private(set) var phase: SocialPhase = .loading
    private(set) var isOffline = false
    private(set) var group: PhotoGroup?
    /// Ready and pending recaps, newest week first.
    private(set) var recaps: [WeeklyRecap] = []
    private(set) var covers: [PostID: PostWithMedia] = [:]
    private(set) var hasCheckedCache = false

    init(groupID: GroupID, data: any SocialDataSource) {
        self.groupID = groupID
        self.data = data
    }

    var showsLoading: Bool { phase == .loading && hasCheckedCache }

    var timeZone: TimeZone { group?.resolvedTimeZone ?? .current }

    func cover(of recap: WeeklyRecap) -> PostWithMedia? {
        recap.items.lazy.compactMap { self.covers[$0] }.first
    }

    func weekNumber(of recap: WeeklyRecap) -> Int {
        SocialCalendar.weekNumber(of: recap.weekStart, in: timeZone)
    }

    func load() async {
        if group == nil { group = await data.cachedGroup(id: groupID) }
        hasCheckedCache = true
        do {
            if let fresh = try? await data.group(id: groupID) { group = fresh }
            let all = try await data.recaps(groupID: groupID)
            recaps = all.filter { $0.status == .ready || $0.status == .pending }.sorted { $0.weekStart > $1.weekStart }
            isOffline = false
            let firstItems = recaps.compactMap(\.items.first).filter { covers[$0] == nil }
            if !firstItems.isEmpty, let found = try? await data.posts(ids: firstItems) {
                for post in found { covers[post.id] = post }
            }
            // A recap whose first item is hidden: its next visible item is the cover.
            let missing = recaps.filter { cover(of: $0) == nil }.flatMap { $0.items.dropFirst() }.filter { covers[$0] == nil }
            if !missing.isEmpty, let found = try? await data.posts(ids: Array(missing)) {
                for post in found { covers[post.id] = post }
            }
            phase = recaps.isEmpty ? .empty : .ready
        } catch {
            let failure = SocialFailure(error)
            isOffline = failure == .offline
            if recaps.isEmpty { phase = isOffline ? .offline : .failed }
        }
    }

    func retry() async {
        phase = .loading
        await load()
    }

    func run() async {
        for await event in data.events(groupID: groupID) {
            guard case let .postDeleted(postID, _) = event else { continue }
            covers[postID] = nil
            for index in recaps.indices { recaps[index].items.removeAll { $0 == postID } }
        }
    }
}

/// `week.recap` preview (`week.recap.layout.preview`): one recap's card (items in recap order), its note and cover.
@MainActor
@Observable
final class WeekRecapModel {
    enum Phase: Equatable {
        case loading
        case ready
        /// `status = pending` (`week.recap.pending`).
        case pending
        /// No such recap (deleted, or never made).
        case empty
        case failed
        case offline
    }

    let groupID: GroupID
    let recapID: RecapID
    @ObservationIgnored private let data: any SocialDataSource

    private(set) var phase: Phase = .loading
    private(set) var recap: WeeklyRecap?
    private(set) var group: PhotoGroup?
    /// Recap items in `weekly_recaps.items` order (hidden posts dropped by RLS).
    private(set) var cardPosts: [PostWithMedia] = []
    /// Every visible post of the week, chronological (the editor's grid).
    private(set) var weekPosts: [PostWithMedia] = []
    private(set) var signals = SocialSignals()
    /// Authors of the shown posts, and the recap's last editor (the note's attribution).
    private(set) var profiles: [UserID: Profile] = [:]
    private(set) var me: UserID?

    init(groupID: GroupID, recapID: RecapID, data: any SocialDataSource) {
        self.groupID = groupID
        self.recapID = recapID
        self.data = data
    }

    var timeZone: TimeZone { group?.resolvedTimeZone ?? .current }

    var weekNumber: Int? { recap.map { SocialCalendar.weekNumber(of: $0.weekStart, in: timeZone) } }

    /// The editor opens only for a ready recap.
    var canEdit: Bool { recap?.status == .ready }

    /// The recap's first item: the cover of page 2, the blurred backdrop and the select-photos thumbnail.
    var cover: PostWithMedia? { cardPosts.first }

    /// The note (`week.recap.layout.note`): the recap text, attributed to `edited_by`.
    var note: (text: String, editor: Profile?)? {
        guard let text = recap?.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        return (text, recap?.editedBy.flatMap { profiles[$0] })
    }

    /// The editor starts from what this screen shows.
    var editSeed: WeekEditModel.Seed? {
        guard phase == .ready, let recap else { return nil }
        return WeekEditModel.Seed(recap: recap, cardPosts: cardPosts, weekPosts: weekPosts, profiles: profiles, me: me)
    }

    /// The on-device copy was looked at: only then may the loading state show (none over cached content).
    private(set) var hasCheckedCache = false
    /// Showing the on-device copy because the server could not be reached.
    private(set) var isOffline = false

    var showsLoading: Bool { phase == .loading && hasCheckedCache }

    /// The recap as fetched earlier this session, with its photos from the device, first; then the server's,
    /// replaced in place.
    func load() async {
        if phase == .loading { await showCached() }
        hasCheckedCache = true
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
            let card = try await data.posts(ids: recap.items)
            let weekIDs = try await WeekPosts.ids(of: recap.weekStart, groupID: groupID, data: data)
            let week = try await data.posts(ids: weekIDs)
            me = await data.currentUserID()
            var people = await SocialPeople.profiles(of: card + week, known: profiles, data: data)
            if let editor = recap.editedBy, people[editor] == nil, let found = try? await data.profiles(ids: [editor]) {
                for profile in found { people[profile.id] = profile }
            }
            profiles = people
            cardPosts = card
            weekPosts = week
            isOffline = false
            phase = .ready
        } catch {
            let failure = SocialFailure(error)
            if phase == .ready, failure != .notFound {
                isOffline = failure == .offline
                return
            }
            switch failure {
            case .offline: phase = .offline
            case .notFound: phase = .empty
            default: phase = .failed
            }
        }
    }

    private func showCached() async {
        guard let cached = await data.cachedRecap(id: recapID), cached.status == .ready else { return }
        let card = await data.cachedPosts(ids: cached.items, groupID: groupID)
        guard !card.isEmpty else { return }
        let weekIDs = await data.cachedHistoryWeeks(groupID: groupID)?.first { $0.weekStart == cached.weekStart }?.postIDs
        var weekPosts: [PostWithMedia] = []
        if let weekIDs { weekPosts = await data.cachedPosts(ids: weekIDs, groupID: groupID) }
        if weekPosts.isEmpty { weekPosts = card.sorted { $0.post.createdAt < $1.post.createdAt } }
        if group == nil { group = await data.cachedGroup(id: groupID) }
        recap = cached
        cardPosts = card
        self.weekPosts = weekPosts
        me = await data.currentUserID()
        phase = .ready
    }

    func retry() async {
        phase = .loading
        await load()
    }

    func run() async {
        for await event in data.events(groupID: groupID) {
            handle(event)
        }
    }

    /// `post_deleted` → the item leaves the card and the week.
    func handle(_ event: GroupEvent) {
        guard case let .postDeleted(postID, _) = event else { return }
        cardPosts.removeAll { $0.id == postID }
        weekPosts.removeAll { $0.id == postID }
    }
}

/// `week.edit`: the recap's chosen photos as a strip (reorder by drag), the week's photos as a grid (tap toggles in /
/// out), the recap text, "Update"; or — opened from `week.recap` / `week.history` — the album sheet alone with the
/// recap's items or the week's photos selected.
@MainActor
@Observable
final class WeekEditModel {
    enum Mode: Hashable, Sendable {
        /// The select-photos thumbnail of `week.recap`: the editor.
        case recap(RecapID)
        /// "Save as Album" in a `week.history` week menu: the album sheet with that week's photos.
        case album(weekStart: LocalDate)
        /// "Save as Album" on `week.recap`: the album sheet with the recap's items in recap order.
        case recapAlbum(RecapID)
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
    private(set) var group: PhotoGroup?
    /// The grid: every visible post of the recap's week in time order.
    private(set) var gridPosts: [PostWithMedia] = []
    /// The strip: the chosen photos in recap order (`p_items`); a checked photo joins its end.
    private(set) var chosen: [PostID] = []
    private var postsByID: [PostID: PostWithMedia] = [:]
    /// Recap text (`weekly_recaps.text`); the view limits it (`week.edit.layout.message.limit`).
    var text = ""
    private var initialChosen: [PostID] = []
    private var initialText = ""
    private(set) var isSaving = false
    /// The save failed (`week.edit.error.save` / `.notReady`); the selection is kept.
    private(set) var saveError: SocialFailure?
    /// The editor is done (saved, or the album saved in an album mode) and closes.
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

    /// What `week.recap` already shows: the editor opens on it at once (no loading state).
    struct Seed {
        let recap: WeeklyRecap
        let cardPosts: [PostWithMedia]
        let weekPosts: [PostWithMedia]
        let profiles: [UserID: Profile]
        let me: UserID?
    }

    init(groupID: GroupID, mode: Mode, data: any SocialDataSource, seed: Seed? = nil) {
        self.groupID = groupID
        self.mode = mode
        self.data = data
        if isAlbumOnly { isAlbumSheetPresented = true }
        if let seed, seed.recap.status == .ready {
            switch mode {
            case let .recap(recapID) where seed.recap.id == recapID:
                apply(recap: seed.recap, items: seed.cardPosts, week: seed.weekPosts)
                profiles = seed.profiles
                me = seed.me
                phase = .ready
            case let .recapAlbum(recapID) where seed.recap.id == recapID:
                apply(recap: seed.recap, items: seed.cardPosts, week: seed.cardPosts)
                profiles = seed.profiles
                me = seed.me
                phase = .ready
            default:
                break
            }
        }
    }

    /// Album modes show only the album sheet's content.
    var isAlbumOnly: Bool {
        if case .recap = mode { return false }
        return true
    }

    /// The strip's photos in order.
    var chosenPosts: [PostWithMedia] { chosen.compactMap { postsByID[$0] } }

    /// What `update_recap(p_items)` / `save_album(p_post_ids)` receive.
    var checkedInOrder: [PostID] { chosen }

    func isChecked(_ id: PostID) -> Bool { chosen.contains(id) }

    /// Cancel asks first (`week.edit.lostChanges.*`) when something changed.
    var hasChanges: Bool { chosen != initialChosen || text != initialText }

    /// The week number of the recap's week (`week.edit.header`).
    var weekNumber: Int? {
        guard let recap else { return nil }
        return SocialCalendar.weekNumber(of: recap.weekStart, in: group?.resolvedTimeZone ?? .current)
    }

    /// Album save: at least one photo and a name typed.
    var canSaveAlbum: Bool {
        !chosen.isEmpty && !albumName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSavingAlbum
    }

    private func apply(recap: WeeklyRecap, items: [PostWithMedia], week: [PostWithMedia]) {
        self.recap = recap
        text = recap.text ?? ""
        for post in items + week { postsByID[post.id] = post }
        gridPosts = week.sorted { $0.post.createdAt < $1.post.createdAt }
        chosen = recap.items.filter { postsByID[$0] != nil }
        initialChosen = chosen
        initialText = text
    }

    func load() async {
        if group == nil { group = await data.cachedGroup(id: groupID) }
        if let fresh = try? await data.group(id: groupID) { group = fresh }
        do {
            switch mode {
            case let .recap(recapID), let .recapAlbum(recapID):
                guard let recap = try await data.recap(id: recapID) else {
                    phase = .failed
                    return
                }
                guard recap.status == .ready else {
                    self.recap = recap
                    phase = .notReady
                    return
                }
                let items = try await data.posts(ids: recap.items)
                if case .recapAlbum = mode {
                    apply(recap: recap, items: items, week: items)
                } else {
                    let weekIDs = try await WeekPosts.ids(of: recap.weekStart, groupID: groupID, data: data)
                    let inRecap = Set(items.map(\.id))
                    let others = try await data.posts(ids: weekIDs.filter { !inRecap.contains($0) })
                    apply(recap: recap, items: items, week: items + others)
                }
            case let .album(weekStart):
                let weekIDs = try await WeekPosts.ids(of: weekStart, groupID: groupID, data: data)
                let week = try await data.posts(ids: weekIDs)
                for post in week { postsByID[post.id] = post }
                gridPosts = week.sorted { $0.post.createdAt < $1.post.createdAt }
                chosen = gridPosts.map(\.id)
                initialChosen = chosen
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

    /// Tap on a grid cell (`haptic.global.select`): a checked photo joins the strip's end; unchecking removes it.
    func toggle(_ id: PostID) {
        guard postsByID[id] != nil else { return }
        if let index = chosen.firstIndex(of: id) {
            chosen.remove(at: index)
        } else {
            chosen.append(id)
        }
        signals.emit(.select)
    }

    /// `week.edit.layout.reorder`: the dragged strip tile takes `target`'s place; the others shift. Returns whether
    /// anything moved.
    @discardableResult
    func move(_ id: PostID, to target: PostID) -> Bool {
        guard id != target, let from = chosen.firstIndex(of: id), let to = chosen.firstIndex(of: target) else { return false }
        chosen.remove(at: from)
        chosen.insert(id, at: to)
        return true
    }

    /// Accessibility "move earlier / later" on a strip tile.
    @discardableResult
    func move(_ id: PostID, by offset: Int) -> Bool {
        guard let from = chosen.firstIndex(of: id) else { return false }
        let to = from + offset
        guard chosen.indices.contains(to) else { return false }
        return move(id, to: chosen[to])
    }

    /// "Update": `update_recap(p_items: the strip, p_text)`.
    func save() async {
        guard case let .recap(recapID) = mode, !isSaving else { return }
        isSaving = true
        saveError = nil
        defer { isSaving = false }
        do {
            recap = try await data.updateRecap(id: recapID, items: chosen, text: text)
            initialChosen = chosen
            initialText = text
            signals.emit(.success)
            signals.post(.recapSaved)
            isFinished = true
        } catch {
            saveError = SocialFailure(error)
            signals.emit(.failed)
        }
    }

    /// "Create Album" (or the return key).
    func saveAlbum() async {
        let name = albumName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            albumNameMissing = true
            return
        }
        guard !chosen.isEmpty, !isSavingAlbum else { return }
        albumNameMissing = false
        albumError = nil
        isSavingAlbum = true
        defer { isSavingAlbum = false }
        do {
            savedAlbum = try await data.saveAlbum(groupID: groupID, name: name, postIDs: chosen)
            signals.emit(.success)
            signals.post(.albumSaved)
            isAlbumSheetPresented = false
            albumName = ""
            if isAlbumOnly { isFinished = true }
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
        /// The group has no photos yet: the empty-state block under the current week (`week.history.empty.*`).
        case empty
        /// `week.history.error` (tap to retry).
        case error
        /// `week.history.offline` at the top of the list.
        case offline
    }

    let groupID: GroupID
    @ObservationIgnored private let data: any SocialDataSource
    @ObservationIgnored private let now: @Sendable () -> Date

    private(set) var isLoading = true
    /// The cached weeks were looked at: only then may the indicator show (none before cached content).
    private(set) var hasCheckedCache = false

    var showsLoading: Bool { isLoading && hasCheckedCache }
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

    var currentWeekNumber: Int { SocialCalendar.weekNumber(of: currentWeekStart, in: timeZone) }

    func weekNumber(of week: Week) -> Int { SocialCalendar.weekNumber(of: week.weekStart, in: timeZone) }

    /// The current week's days without a photo (`week.history`: one empty-day tile each, after the add tile), Monday
    /// first; nil until every photo of the week is loaded (no tile appears and then disappears).
    func emptyDays(of week: Week) -> [LocalDate]? {
        guard week.isCurrent else { return [] }
        let loaded = week.postIDs.compactMap { posts[$0] }
        guard loaded.count == week.postIDs.count else { return nil }
        let photoDays = Set(loaded.map { LocalDate($0.post.createdAt, in: timeZone) })
        return SocialCalendar.days(of: week.weekStart).filter { !photoDays.contains($0) }
    }

    func load() async {
        if group == nil { group = await data.cachedGroup(id: groupID) }
        // Cached weeks first (no indicator when there are some), refreshed in place.
        var showsCached = !weeks.isEmpty
        if weeks.isEmpty, let cached = await data.cachedHistoryWeeks(groupID: groupID), !cached.isEmpty {
            apply(cached, replacing: true)
            isLoading = false
            showsCached = true
            await loadDetails()
        }
        hasCheckedCache = true
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
                // Weeks already on screen stay; the line explains.
                if !showsCached { apply([], replacing: true) }
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
