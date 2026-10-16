// Surface: onthisday — view models of the Rewind page and of the group-screen entry. Spec: design/surfaces/onthisday.md
// (Retro Rewind: one memory at a time, a dial with one slot per memory, play / pause, share, shuffle; MERGE RM-2…RM-7).
import AppData
import AppServices
import CoreTransferable
import DesignSystem
import Foundation
import Observation
import UniformTypeIdentifiers

/// The group-local day `on_this_day` is asked for: today in the group's zone, rolling over at
/// `layout.onthisday.dayBoundary.hour` (05:00) instead of midnight.
enum OnThisDayCalendar {
    static func localDate(now: Date, timeZone: TimeZone) -> LocalDate {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let hour = calendar.component(.hour, from: now)
        let today = LocalDate(now, in: timeZone)
        return hour < Int(Tokens.Layouts.OnthisdayDayBoundary.hour) ? today.adding(days: -1) : today
    }
}

@MainActor
@Observable
final class OnThisDayModel {
    /// One memory = one post.
    struct Memory: Identifiable, Equatable, Sendable {
        let id: PostID
        let authorID: UserID
        /// The poster's first name (`{name}` of the subtitle and the photo's label).
        let authorName: String
        /// `display_path` (the original until renditions are ready).
        let displayURL: URL?
        /// The original, for save and share.
        let originalURL: URL?
        let createdAt: Date
        let isMine: Bool
    }

    enum Phase: Equatable {
        case idle
        case loading
        case loaded
        /// Every memory was deleted while the page was open (the entry is hidden otherwise).
        case empty
        case error
        case offline
    }

    /// The day's memories, or random ones from the group's history after the dice (RM-5).
    enum Mode: Equatable {
        case day
        case shuffle
    }

    /// How the memory in view last changed: by the dial (`duration.global.crossfade`) or by playing
    /// (`duration.onthisday.memoryChange`).
    enum Change: Equatable {
        case dial
        case play
    }

    private(set) var phase: Phase = .idle
    /// The day's memories, newest first (the API's order is the dial's order: slot 0 = the newest).
    private(set) var memories: [Memory] = []
    /// Shuffle: the random picks shown so far, in order (previous = back through them).
    private(set) var picks: [Memory] = []
    private(set) var mode: Mode = .day
    private(set) var index = 0
    private(set) var lastChange: Change = .dial
    private(set) var isPlaying = false
    /// A random pick is being read (the dial waits for it).
    private(set) var isPicking = false
    /// The feature intro (C-29), once per account.
    var showsIntro = false
    /// The own memory waiting for the delete confirmation.
    var deleteCandidate: Memory?
    /// Add-only photo access was denied: the native alert that opens Settings.
    var showsSaveDenied = false
    private(set) var groupName = ""
    private(set) var timeZone: TimeZone = MemoryFormat.utc

    let groupID: GroupID
    private let dependencies: MemoryDependencies
    private let savePhoto: @Sendable (Data) async throws -> Void
    private let randomIndex: (Int) -> Int
    private var me: UserID?
    private var deletionTask: Task<Void, Never>?
    private var playTask: Task<Void, Never>?
    /// The shuffle's pool: every week of the group's history (`group_history_weeks`), read once per session.
    private var historyWeeks: [HistoryWeek]?

    /// - Parameters:
    ///   - savePhoto: saves image data with add-only access (`PhotoLibraryService.saveImage`).
    ///   - randomIndex: a random index below its argument (the dice); tests pass a fixed sequence.
    init(
        groupID: GroupID,
        dependencies: MemoryDependencies,
        savePhoto: @escaping @Sendable (Data) async throws -> Void = { try await PhotoLibraryService().saveImage($0) },
        randomIndex: @escaping (Int) -> Int = { Int.random(in: 0..<max(1, $0)) }
    ) {
        self.groupID = groupID
        self.dependencies = dependencies
        self.savePhoto = savePhoto
        self.randomIndex = randomIndex
    }

    // MARK: What the page shows

    /// The memories the dial steps through.
    var list: [Memory] { mode == .day ? memories : picks }

    var current: Memory? { list.indices.contains(index) ? list[index] : nil }

    /// The dial slot of the memory in view: memory index mod `layout.onthisday.dial.slots`.
    var dialSlot: Int {
        let slots = max(1, Int(Tokens.Layouts.OnthisdayDial.slots))
        return index % slots
    }

    /// The date title (`layout.onthisday.dateFormat`, "Jul 22, 2022", group time zone).
    var title: String {
        current.map { MemoryFormat.memoryDate($0.createdAt, timeZone: timeZone) } ?? ""
    }

    /// `onthisday.subtitle.day` / `.subtitle.shuffle` with the poster's first name.
    var subtitle: String? {
        guard let current else { return nil }
        return mode == .day ? Copy.onthisdaySubtitleDay(name: current.authorName) : Copy.onthisdaySubtitleShuffle(name: current.authorName)
    }

    /// `onthisday.a11y.photo` ("Photo by Maya, Jul 22, 2022").
    var photoLabel: String {
        guard let current else { return "" }
        return Copy.onthisdayA11yPhoto(name: current.authorName, date: title)
    }

    /// `onthisday.a11y.dialValue` ("2 of 5").
    var dialValue: String {
        Copy.onthisdayA11yDialValue(position: MemoryFormat.number(index + 1), total: MemoryFormat.number(list.count))
    }

    var canGoPrevious: Bool { index > 0 && !isPicking }

    var canGoNext: Bool {
        switch mode {
        case .day: return index + 1 < memories.count
        case .shuffle: return !isPicking && (index + 1 < picks.count || hasUnshownHistory)
        }
    }

    /// Today's date for the share sheet's title (`layout.year.story.dateFormat`, "Tuesday, December 2").
    var shareTitle: String {
        MemoryFormat.weekdayMonthDay(LocalDate(dependencies.now(), in: timeZone))
    }

    // MARK: Loading

    func loadIfNeeded() async {
        guard phase == .idle else { return }
        await load()
    }

    func retry() async {
        await load()
    }

    private struct Cached {
        let memories: [Memory]
        let groupName: String
        let timeZone: TimeZone
    }

    private var cacheKey: String { "onthisday." + groupID.rawValue } // provenance-ok: cache key

    /// Cache-first: the day shown last opens at once; the fresh read replaces it in place.
    private func load() async {
        guard let data = dependencies.data else {
            phase = .error
            return
        }
        me = await data.currentUser()
        if phase != .loaded, let cached = dependencies.cache.value(Cached.self, key: cacheKey, user: me) {
            apply(cached)
        } else if phase != .loaded {
            phase = .loading
        }
        do {
            let group = try await data.group(id: groupID)
            let zone = group?.resolvedTimeZone ?? MemoryFormat.utc
            let day = OnThisDayCalendar.localDate(now: dependencies.now(), timeZone: zone)
            let rows = try await data.onThisDay(groupID: groupID, localDate: day)
            let fresh = try await resolve(rows.map(\.postID), data: data)
            let value = Cached(memories: fresh, groupName: group?.name ?? "", timeZone: zone)
            dependencies.cache.set(value, key: cacheKey, user: me, postIDs: Set(fresh.map(\.id)))
            apply(value)
            listenForDeletions(data: data)
            showIntroIfFirstTime()
        } catch {
            // Cached content stays on screen; without it, the error / offline state.
            if phase != .loaded {
                phase = MemoryFailure(error) == .offline ? .offline : .error
            }
        }
    }

    /// Shows `value`, keeping the memory in view when it is still there.
    private func apply(_ value: Cached) {
        let currentID = current?.id
        groupName = value.groupName
        timeZone = value.timeZone
        memories = value.memories
        if mode == .day {
            index = currentID.flatMap { id in memories.firstIndex { $0.id == id } } ?? 0
        }
        phase = list.isEmpty ? .empty : .loaded
        preloadNeighbours()
    }

    /// Posts → memories in the order of `ids` (RLS drops posts hidden by a block).
    private func resolve(_ ids: [PostID], data: any MemoryDataSource) async throws -> [Memory] {
        let posts = try await data.postsWithMedia(ids: ids)
        let profiles = try await data.profiles(ids: Array(Set(posts.map(\.post.authorID))))
        let names = Dictionary(profiles.map { ($0.id, $0.firstName ?? "") }, uniquingKeysWith: { first, _ in first })
        var paths: [String] = []
        for post in posts {
            if let path = post.media?.imagePath(for: .display) { paths.append(path) }
            if let path = post.media?.originalPath { paths.append(path) }
        }
        let urls = try await data.signedURLs(paths: paths)
        return posts.map { post in
            Memory(
                id: post.post.id,
                authorID: post.post.authorID,
                authorName: names[post.post.authorID] ?? "",
                displayURL: post.media?.imagePath(for: .display).flatMap { urls[$0] },
                originalURL: post.media.flatMap { urls[$0.originalPath] },
                createdAt: post.post.createdAt,
                isMine: post.post.authorID == me
            )
        }
    }

    // MARK: Feature intro (C-29, once per account)

    static func introKey(_ user: UserID) -> String {
        "memory.onthisday.introSeen." + user.rawValue // provenance-ok: defaults key, not UI text
    }

    private func showIntroIfFirstTime() {
        guard phase == .loaded, let me, !dependencies.defaults.bool(forKey: Self.introKey(me)) else { return }
        showsIntro = true
    }

    /// "Try it out" (or the sheet dismissed): never shown again on this account.
    func dismissIntro() {
        showsIntro = false
        if let me { dependencies.defaults.set(true, forKey: Self.introKey(me)) }
    }

    // MARK: The dial (`layout.onthisday.dial`)

    /// One slot clockwise: the next (older) memory; in shuffle mode a new random pick once the picks run out.
    /// Plays `haptic.global.select` when the memory changes. Returns whether it moved (or started a pick).
    @discardableResult
    func next(change: Change = .dial) -> Bool {
        guard phase == .loaded else { return false }
        switch mode {
        case .day:
            guard index + 1 < memories.count else { return false }
            move(to: index + 1, change: change)
            return true
        case .shuffle:
            guard !isPicking else { return false }
            if index + 1 < picks.count {
                move(to: index + 1, change: change)
                return true
            }
            guard hasUnshownHistory else { return false }
            Task { await self.pickRandom(change: change) }
            return true
        }
    }

    /// One slot counter-clockwise: the previous memory (or the previous pick). Stops at the first.
    @discardableResult
    func previous() -> Bool {
        guard phase == .loaded, canGoPrevious else { return false }
        move(to: index - 1, change: .dial)
        return true
    }

    private func move(to newIndex: Int, change: Change) {
        lastChange = change
        index = newIndex
        dependencies.haptics(Tokens.Haptics.globalSelect)
        preloadNeighbours()
    }

    // MARK: Play / pause (`duration.onthisday.playHold`)

    /// The dial centre. Playing advances one memory every `duration.onthisday.playHold` and stops after the last;
    /// from the last memory, play starts again at the first.
    func togglePlay() {
        if isPlaying {
            stopPlaying()
            return
        }
        guard phase == .loaded, !list.isEmpty else { return }
        if mode == .day, index + 1 >= memories.count, memories.count > 1 {
            move(to: 0, change: .play)
        }
        isPlaying = true
        let sleep = dependencies.sleep
        let hold = Tokens.Durations.onthisdayPlayHold
        playTask?.cancel()
        playTask = Task { [weak self] in
            while true {
                do {
                    try await sleep(hold)
                } catch {
                    return
                }
                guard let self, !Task.isCancelled, self.isPlaying else { return }
                if self.mode == .shuffle, self.index + 1 >= self.picks.count {
                    guard self.hasUnshownHistory else {
                        self.stopPlaying()
                        return
                    }
                    await self.pickRandom(change: .play)
                } else if !self.next(change: .play) {
                    self.stopPlaying()
                    return
                }
                if self.mode == .day, self.index + 1 >= self.memories.count {
                    // The last memory stays in view for its time, then play stops (play glyph again).
                    try? await sleep(hold)
                    self.stopPlaying()
                    return
                }
            }
        }
    }

    func stopPlaying() {
        playTask?.cancel()
        playTask = nil
        isPlaying = false
    }

    // MARK: Shuffle (the dice, RM-5)

    private var shownIDs: Set<PostID> { Set(picks.map(\.id)) }

    private var hasUnshownHistory: Bool {
        guard let historyWeeks else { return true }
        let shown = shownIDs
        return historyWeeks.contains { week in week.postIDs.contains { !shown.contains($0) } }
    }

    /// The dice: a random memory from the group's whole history; the subtitle switches to `onthisday.subtitle.shuffle`
    /// and the dial steps through further random picks.
    func shuffle() async {
        guard phase == .loaded, !isPicking else { return }
        stopPlaying()
        picks = []
        await pickRandom(change: .dial, startsShuffle: true)
    }

    private func pickRandom(change: Change, startsShuffle: Bool = false) async {
        guard let data = dependencies.data, !isPicking else { return }
        isPicking = true
        defer { isPicking = false }
        do {
            let weeks = try await loadHistory(data: data)
            let shown = shownIDs
            let candidates = weeks.compactMap { week -> [PostID]? in
                let unshown = week.postIDs.filter { !shown.contains($0) }
                return unshown.isEmpty ? nil : unshown
            }
            guard !candidates.isEmpty else { return }
            let week = candidates[min(candidates.count - 1, max(0, randomIndex(candidates.count)))]
            let postID = week[min(week.count - 1, max(0, randomIndex(week.count)))]
            guard let memory = try await resolve([postID], data: data).first else {
                // Hidden by a block or gone meanwhile: leave it out of the pool and try another.
                historyWeeks = historyWeeks?.map { HistoryWeek(weekStart: $0.weekStart, postIDs: $0.postIDs.filter { $0 != postID }) }
                return
            }
            picks.append(memory)
            if startsShuffle { mode = .shuffle }
            move(to: picks.count - 1, change: change)
        } catch {
            dependencies.haptics(Tokens.Haptics.globalError)
            dependencies.toasts.show(MemoryFailure(error) == .offline ? Copy.onthisdayOfflineDetail : Copy.onthisdayErrorDetail)
        }
    }

    /// `group_history_weeks` in pages of `p_limit` (the API's clamp, 52) until a page comes back short; cached per session.
    private func loadHistory(data: any MemoryDataSource) async throws -> [HistoryWeek] {
        if let historyWeeks { return historyWeeks }
        let key = "onthisday.history." + groupID.rawValue // provenance-ok: cache key
        if let cached = dependencies.cache.value([HistoryWeek].self, key: key, user: me) {
            historyWeeks = cached
            return cached
        }
        let pageSize = Self.historyPageSize
        var weeks: [HistoryWeek] = []
        var before: LocalDate?
        while true {
            let page = try await data.historyWeeks(groupID: groupID, before: before, limit: pageSize)
            weeks += page
            guard page.count == pageSize, let last = page.last else { break }
            before = last.weekStart
        }
        historyWeeks = weeks
        dependencies.cache.set(weeks, key: key, user: me, postIDs: Set(weeks.flatMap(\.postIDs)))
        return weeks
    }

    /// `p_limit` of the shuffle's history pages: the API's upper clamp (docs/API.md `group_history_weeks`: 1–52).
    static let historyPageSize = 52 // provenance-ok: API page-size bound (docs/API.md group_history_weeks), not a design value

    // MARK: Save, share, report, delete (the '•••' menu, D)

    /// Save and share take a photo out of the app, so they exist only for your own memory (owner decision 12: sharing
    /// outside the app is for your own photos; other members' memories have no share action).
    var canExport: Bool { current?.isMine == true }

    /// "Save to Camera Roll" (your own memory only): the original, add-only photo access. `haptic.global.success` +
    /// `onthisday.toast.saved`; denied → the native alert (`onthisday.saveDenied.*`); failed → `haptic.global.error` +
    /// `onthisday.saveFailed`.
    func save() async {
        guard let current, current.isMine, let data = dependencies.data, let url = current.originalURL ?? current.displayURL else { return }
        do {
            let bytes = try await data.downloadData(from: url)
            try await savePhoto(bytes)
            dependencies.haptics(Tokens.Haptics.globalSuccess)
            dependencies.toasts.show(Copy.onthisdayToastSaved)
        } catch {
            dependencies.haptics(Tokens.Haptics.globalError)
            if Self.isAccessDenied(error) {
                showsSaveDenied = true
            } else {
                dependencies.toasts.show(Copy.onthisdaySaveFailed)
            }
        }
    }

    static func isAccessDenied(_ error: Error) -> Bool {
        if case .notAuthorized? = error as? PhotoLibraryService.LibraryError { return true }
        return false
    }

    /// The memory's original for the share sheet (downloaded when a destination is picked); nil for someone else's memory.
    var shareItem: MemoryShareImage? {
        guard let current, current.isMine, let data = dependencies.data, let url = current.originalURL ?? current.displayURL else { return nil }
        return MemoryShareImage(url: url, name: current.id.rawValue, data: data)
    }

    /// "Report Post" (someone else's memory) → `safety.report` (target kind post).
    func report() {
        guard let current, !current.isMine else { return }
        stopPlaying()
        dependencies.openReport(ReportTarget(
            kind: .post, id: current.id.rawValue,
            person: BlockTarget(userID: current.authorID.rawValue, firstName: current.authorName)
        ))
    }

    /// "Delete Post" (your own memory): asks first.
    func requestDelete() {
        guard let current, current.isMine else { return }
        stopPlaying()
        deleteCandidate = current
    }

    /// "Yes, delete": `haptic.global.warning`, `delete_post`, then `onthisday.toast.deleted` and the memory leaves the dial.
    /// - Parameter memory: the memory the confirmation was shown for (default: `deleteCandidate`).
    func confirmDelete(_ memory: Memory? = nil) async {
        guard let memory = memory ?? deleteCandidate, memory.isMine, let data = dependencies.data else { return }
        deleteCandidate = nil
        dependencies.haptics(Tokens.Haptics.globalWarning)
        do {
            try await data.deletePost(id: memory.id)
            removePost(memory.id)
            dependencies.toasts.show(Copy.onthisdayToastDeleted)
        } catch {
            dependencies.haptics(Tokens.Haptics.globalError)
            dependencies.toasts.show(MemoryFailure(error) == .offline ? Copy.onthisdayOfflineDetail : Copy.onthisdayErrorDetail)
        }
    }

    // MARK: Deletions (docs/API.md §8.2)

    /// Drops a deleted memory from the dial; when it was in view, the next one (or the previous) shows. With none left,
    /// the C-27 empty block.
    func removePost(_ postID: PostID) {
        dependencies.cache.purge(postID: postID)
        historyWeeks = historyWeeks?.map { HistoryWeek(weekStart: $0.weekStart, postIDs: $0.postIDs.filter { $0 != postID }) }
        let currentID = current?.id
        memories.removeAll { $0.id == postID }
        picks.removeAll { $0.id == postID }
        if mode == .shuffle, picks.isEmpty {
            mode = .day
            index = 0
        }
        if let currentID, let kept = list.firstIndex(where: { $0.id == currentID }) {
            index = kept
        } else {
            index = min(index, max(list.count - 1, 0))
        }
        if list.isEmpty {
            stopPlaying()
            phase = .empty
        }
    }

    private func listenForDeletions(data: any MemoryDataSource) {
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
        stopPlaying()
    }

    // MARK: Images

    /// Pixel size of the page's longest side (set by the screen); photos are decoded at it.
    var imagePixelSize: CGFloat?

    /// Decodes the memories on both sides of the one in view, so a dial step cross-fades into a photo, not an empty page.
    func preloadNeighbours() {
        guard let size = imagePixelSize else { return }
        let urls = [index - 1, index + 1].compactMap { list.indices.contains($0) ? list[$0].displayURL : nil }
        guard !urls.isEmpty else { return }
        let images = dependencies.images
        Task {
            for url in urls {
                _ = await images.image(for: url, maxPixelSize: size)
            }
        }
    }
}

/// The memory's original for the native share sheet, downloaded when the member picks a destination.
struct MemoryShareImage: Transferable {
    let url: URL
    let name: String
    let data: any MemoryDataSource

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .jpeg) { item in
            SentTransferredFile(try await item.data.downloadFile(from: item.url, name: item.name + ".jpg")) // provenance-ok: file extension of the JPEG
        }
    }
}

/// The group-screen entry: visible only while `on_this_day` returns rows (A in onthisday.md).
@MainActor
@Observable
final class OnThisDayEntryModel {
    private(set) var content: MemoryEntryContent?
    let groupID: GroupID
    private let dependencies: MemoryDependencies

    init(groupID: GroupID, dependencies: MemoryDependencies) {
        self.groupID = groupID
        self.dependencies = dependencies
    }

    func open() {
        dependencies.openOnThisDay(groupID.rawValue)
    }

    func refresh() async {
        guard let data = dependencies.data else {
            content = nil
            return
        }
        let me = await data.currentUser()
        let cacheKey = "onthisday.entry." + groupID.rawValue // provenance-ok: cache key
        if content == nil, let cached = dependencies.cache.value(MemoryEntryContent.self, key: cacheKey, user: me) {
            content = cached
        }
        do {
            guard let group = try await data.group(id: groupID) else {
                content = nil
                dependencies.cache.remove(key: cacheKey)
                return
            }
            let day = OnThisDayCalendar.localDate(now: dependencies.now(), timeZone: group.resolvedTimeZone)
            let rows = try await data.onThisDay(groupID: groupID, localDate: day)
            guard let newest = rows.first else {
                content = nil
                dependencies.cache.remove(key: cacheKey)
                return
            }
            let photo = try await data.postsWithMedia(ids: [newest.postID]).first?.media?.imagePath(for: .display)
            let fresh = MemoryEntryContent(
                title: Copy.onthisdayEntryTitle,
                subtitle: Copy.onthisdayEntrySubtitle(date: MemoryFormat.dayMonth(day)),
                buttonTitle: Copy.onthisdayEntryButton,
                icon: Tokens.Icons.globalRewind,
                photoPath: photo
            )
            content = fresh
            dependencies.cache.set(fresh, key: cacheKey, user: me, postIDs: Set(rows.map(\.postID)))
        } catch {
            // The entry is only an invitation: on failure it stays as it was.
        }
    }
}
