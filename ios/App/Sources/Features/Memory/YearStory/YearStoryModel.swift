// Surface: year.story — data, cards and navigation. Spec: design/surfaces/year.story.md.
// One fact per card; most-reacted photos are shown in order with no number, rank or reaction glyph
// (docs/SPEC_FLAGS.md T2); the only number is the group-level "moments shared" (T3).
import AppData
import DesignSystem
import Foundation
import Observation
import UIKit

/// `YearStoryData` v1, written by the worker (`backend/worker/src/jobs/year.ts`).
struct YearStoryData: Equatable, Sendable {
    struct EveryoneDay: Equatable, Sendable {
        let localDate: LocalDate
        let collageID: CollageID
        let postIDs: [PostID]
    }

    let year: Int
    let timeZone: TimeZone
    let momentsShared: Int?
    /// 1–12.
    let busiestMonth: Int?
    /// Most-reacted first; ids only.
    let mostReacted: [PostID]
    /// Chronological (worker order).
    let everyoneDays: [EveryoneDay]

    init?(json: JSONValue?, fallbackYear: Int) {
        guard let json, case .object(_) = json else { return nil }
        year = json["year"]?.intValue ?? fallbackYear
        timeZone = json["time_zone"]?.stringValue.flatMap { TimeZone(identifier: $0) } ?? MemoryFormat.utc
        momentsShared = json["moments_shared"]?.intValue
        busiestMonth = json["busiest_month"]?["month"]?.intValue.flatMap { (1...12).contains($0) ? $0 : nil }
        if case let .array(ids)? = json["most_reacted"] {
            mostReacted = ids.compactMap { $0.stringValue.map { PostID($0) } }
        } else {
            mostReacted = []
        }
        if case let .array(days)? = json["everyone_days"] {
            everyoneDays = days.compactMap { day in
                guard let date = day["local_date"]?.stringValue.flatMap({ LocalDate($0) }),
                      let collage = day["collage_id"]?.stringValue else { return nil }
                var posts: [PostID] = []
                if case let .array(ids)? = day["post_ids"] { posts = ids.compactMap { $0.stringValue.map { PostID($0) } } }
                return EveryoneDay(localDate: date, collageID: CollageID(collage), postIDs: posts)
            }
        } else {
            everyoneDays = []
        }
    }
}

/// A most-reacted photo card.
struct YearStoryPhoto: Equatable, Sendable {
    let postID: PostID
    /// The poster's first name.
    let name: String
    /// Group-local day the photo was posted.
    let date: LocalDate
    /// `display_path`.
    let imageURL: URL?
}

/// A day when everyone answered the daily invitation, with its collage.
struct YearStoryCollage: Equatable, Sendable {
    let collageID: CollageID
    let date: LocalDate
    let postIDs: [PostID]
    let imageURL: URL?
}

/// One cell of the summary's recap card.
struct YearStoryGridPhoto: Equatable, Sendable, Identifiable {
    let postID: PostID
    /// `thumb_path`.
    let imageURL: URL?
    /// The poster's first name (the cell's VoiceOver label).
    let name: String
    let date: LocalDate
    var id: PostID { postID }
}

/// What the summary's two share styles show (C in year.story.md).
struct YearStorySummary: Equatable, Sendable {
    enum Style: String, Equatable, Sendable, CaseIterable {
        /// `layout.year.story.recapCard` on the blurred cover.
        case recapCard
        /// The cover photo full bleed with the year and the group name.
        case cover
    }

    let year: Int
    let groupName: String
    /// The recap card's photos: full rows only (`layout.year.story.recapCard.columns`, up to `maxRows`).
    let grid: [YearStoryGridPhoto]

    /// The recap card is offered only with at least one full row.
    var styles: [Style] { grid.isEmpty ? [.cover] : [.recapCard, .cover] }
}

/// One card of the tap-through, in the order of the spec's card table.
enum YearStoryCard: Equatable, Identifiable, Sendable {
    case intro(groupName: String, year: Int)
    case lookBack
    case moments(groupName: String, count: Int)
    case busiestMonth(month: Int, year: Int)
    case mostReactedSetup
    case mostReacted(YearStoryPhoto)
    case togetherSetup
    case togetherDay(YearStoryCollage)
    case outro
    case summary

    var id: String {
        switch self {
        case .intro: return "intro"
        case .lookBack: return "look-back"
        case .moments: return "moments"
        case .busiestMonth: return "busiest-month"
        case .mostReactedSetup: return "most-reacted-setup"
        case let .mostReacted(photo): return "most-reacted-" + photo.postID.rawValue
        case .togetherSetup: return "together-setup"
        case let .togetherDay(collage): return "together-" + collage.collageID.rawValue
        case .outro: return "outro"
        case .summary: return "summary"
        }
    }

    /// The cards with the Share pill (the card table's last column): the facts, the outro and the summary.
    var isShareable: Bool {
        switch self {
        case .moments, .busiestMonth, .mostReacted, .togetherDay, .outro, .summary: return true
        case .intro, .lookBack, .mostReactedSetup, .togetherSetup: return false
        }
    }

    /// The headline of a text card (empty for photo, collage and summary cards).
    var headline: String {
        switch self {
        case .intro: return Copy.yearStoryIntroTitle
        case .lookBack: return Copy.yearStoryLookBackTitle
        case let .moments(groupName, count):
            return Copy.yearStoryMomentsCount(group: groupName, count: MemoryFormat.number(count))
        case let .busiestMonth(month, year):
            return Copy.yearStoryBusiestMonthTitle(month: MemoryFormat.storyMonth(month, year: year) ?? "")
        case .mostReactedSetup: return Copy.yearStoryMostReactedTitle
        case .togetherSetup: return Copy.yearStoryTogetherTitle
        case .outro: return Copy.yearStoryOutroTitle
        case .mostReacted, .togetherDay, .summary: return ""
        }
    }

    /// The subline of a text card (revealed after the headline).
    var subline: String? {
        switch self {
        case let .intro(groupName, year): return Copy.yearStoryIntroSubtitle(group: groupName, year: String(year))
        case .togetherSetup: return Copy.yearStoryTogetherAside
        default: return nil
        }
    }

    /// The image of a photo / collage card.
    var imageURL: URL? {
        switch self {
        case let .mostReacted(photo): return photo.imageURL
        case let .togetherDay(collage): return collage.imageURL
        default: return nil
        }
    }

    /// The cards for a story: a card whose data is missing is skipped (a list's setup card with its list); lists keep at
    /// most `count.year.story.listLength` entries.
    static func build(data: YearStoryData, groupName: String, photos: [YearStoryPhoto], collages: [YearStoryCollage]) -> [YearStoryCard] {
        let listLength = Int(Tokens.Counts.yearStoryListLength)
        var cards: [YearStoryCard] = [.intro(groupName: groupName, year: data.year), .lookBack]
        if let count = data.momentsShared {
            cards.append(.moments(groupName: groupName, count: count))
        }
        if let month = data.busiestMonth {
            cards.append(.busiestMonth(month: month, year: data.year))
        }
        let shownPhotos = Array(photos.prefix(listLength))
        if !shownPhotos.isEmpty {
            cards.append(.mostReactedSetup)
            cards += shownPhotos.map { .mostReacted($0) }
        }
        let shownCollages = Array(collages.prefix(listLength))
        if !shownCollages.isEmpty {
            cards.append(.togetherSetup)
            cards += shownCollages.map { .togetherDay($0) }
        }
        cards += [.outro, .summary]
        return cards
    }
}

@MainActor
@Observable
final class YearStoryModel {
    enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case error
        case offline
    }

    var phase: Phase = .idle
    var cards: [YearStoryCard] = []
    var index = 0
    /// Set when the player should close.
    var isFinished = false
    /// The summary's share style in view (its pager).
    var summaryPage = 0
    /// The summary's styles and photos; nil until loaded.
    private(set) var summary: YearStorySummary?
    /// The cover (`data.most_reacted` first, else the first of `post_ids`): the text cards' blurred backdrop and the
    /// summary's full-bleed style.
    private(set) var coverURL: URL?
    /// Rendered share images (1080 × 1920 PNG files and their previews), by `shareKey`.
    var shareFiles: [String: URL] = [:]
    var shareImages: [String: UIImage] = [:]

    let groupID: GroupID
    let year: Int
    private let dependencies: MemoryDependencies
    private var deletionTask: Task<Void, Never>?

    init(groupID: GroupID, year: Int, dependencies: MemoryDependencies) {
        self.groupID = groupID
        self.year = year
        self.dependencies = dependencies
    }

    var currentCard: YearStoryCard? { cards.indices.contains(index) ? cards[index] : nil }

    var images: any MemoryImageLoading { dependencies.images }

    /// The summary's styles (one page each).
    var summaryStyles: [YearStorySummary.Style] { summary?.styles ?? [.cover] }

    /// The summary style in view.
    var summaryStyle: YearStorySummary.Style {
        let styles = summaryStyles
        return styles[min(max(summaryPage, 0), styles.count - 1)]
    }

    /// The share image's key of the card in view (the summary: per style).
    func shareKey(_ card: YearStoryCard) -> String {
        card == .summary ? card.id + "-" + summaryStyle.rawValue : card.id // provenance-ok: dictionary key, not UI text
    }

    /// `year.story.position` ("3 of 12"): the card among the cards before the summary; nil on the summary (the page dots
    /// take over).
    var position: String? {
        guard let card = currentCard, card != .summary else { return nil }
        let total = cards.filter { $0 != .summary }.count
        return Copy.yearStoryPosition(position: MemoryFormat.number(index + 1), total: MemoryFormat.number(total))
    }

    func loadIfNeeded() async {
        guard phase == .idle else { return }
        await load()
    }

    func retry() async {
        await load()
    }

    private struct Cached {
        let cards: [YearStoryCard]
        let summary: YearStorySummary
        let coverURL: URL?
    }

    /// Cache-first: the story shown last opens at once; the fresh read replaces it in place.
    private func load() async {
        guard let data = dependencies.data else {
            phase = .error
            return
        }
        let me = await data.currentUser()
        let cacheKey = "yearstory." + groupID.rawValue + "." + String(year) // provenance-ok: cache key
        if phase != .loaded, let cached = dependencies.cache.value(Cached.self, key: cacheKey, user: me) {
            apply(cached)
        } else if phase != .loaded {
            phase = .loading
        }
        do {
            guard let story = try await data.yearStory(groupID: groupID, year: year), story.status == .ready,
                  let storyData = YearStoryData(json: story.data, fallbackYear: year) else {
                // `status = 'pending'` has no screen (the entry is hidden); opened by a link, it reads as an error.
                if phase != .loaded { phase = .error }
                return
            }
            let groupName = try await data.group(id: groupID)?.name ?? ""
            let photos = try await Self.photos(storyData, data: data)
            let collages = try await Self.collages(storyData, data: data)
            let grid = try await Self.grid(storyData, postIDs: story.postIDs, data: data)
            let cover = try await Self.coverURL(storyData, postIDs: story.postIDs, data: data)
            let fresh = Cached(
                cards: YearStoryCard.build(data: storyData, groupName: groupName, photos: photos, collages: collages),
                summary: YearStorySummary(year: storyData.year, groupName: groupName, grid: grid),
                coverURL: cover
            )
            dependencies.cache.set(fresh, key: cacheKey, user: me, postIDs: Self.postIDs(of: fresh.cards).union(grid.map(\.postID)))
            apply(fresh)
            listenForDeletions(data: data)
        } catch {
            if phase != .loaded {
                phase = MemoryFailure(error) == .offline ? .offline : .error
            }
        }
    }

    /// Shows `fresh`, staying on the card in view when it is still there. The first time, the story starts playing —
    /// paused instead while VoiceOver runs (auto-advance would cut speech; WCAG 2.2.2).
    private func apply(_ fresh: Cached) {
        let currentID = currentCard?.id
        let isFirst = phase != .loaded
        if fresh.cards != cards || fresh.summary != summary {
            shareFiles = [:]
            shareImages = [:]
        }
        cards = fresh.cards
        summary = fresh.summary
        coverURL = fresh.coverURL
        summaryPage = min(summaryPage, summaryStyles.count - 1)
        index = currentID.flatMap { id in fresh.cards.firstIndex { $0.id == id } } ?? 0
        phase = .loaded
        if isFirst, dependencies.isVoiceOverRunning() { isPaused = true }
        preloadUpcoming()
        if currentID == nil || currentCard?.id != currentID { restartCardTimer() }
    }

    static func postIDs(of cards: [YearStoryCard]) -> Set<PostID> {
        var ids = Set<PostID>()
        for card in cards {
            switch card {
            case let .mostReacted(photo): ids.insert(photo.postID)
            case let .togetherDay(collage): ids.formUnion(collage.postIDs)
            default: break
            }
        }
        return ids
    }

    /// Pixel size the photo box is shown and shared at (set by the screen from the canvas).
    var imagePixelSize: CGFloat?

    /// Loads the images of the card in view and the next cards before they are tapped to.
    func preloadUpcoming() {
        var upcoming = cards.dropFirst(index).prefix(Self.preloadCount + 1).compactMap(\.imageURL)
        if let coverURL { upcoming.insert(coverURL, at: 0) }
        if cards.dropFirst(index).prefix(Self.preloadCount + 1).contains(.summary) {
            upcoming += summary?.grid.compactMap(\.imageURL) ?? []
        }
        guard !upcoming.isEmpty else { return }
        let images = dependencies.images
        let size = imagePixelSize
        Task {
            for url in upcoming {
                _ = await images.image(for: url, maxPixelSize: size)
            }
        }
    }

    /// How many cards ahead are preloaded: the photo / collage cards of one list
    /// (`count.year.story.listLength`).
    static var preloadCount: Int { Int(Tokens.Counts.yearStoryListLength) }

    /// Most-reacted posts in the worker's order; posts hidden by a block (RLS) are skipped.
    static func photos(_ story: YearStoryData, data: any MemoryDataSource) async throws -> [YearStoryPhoto] {
        let listLength = Int(Tokens.Counts.yearStoryListLength)
        guard !story.mostReacted.isEmpty else { return [] }
        let posts = try await data.postsWithMedia(ids: story.mostReacted)
        let visible = Array(posts.prefix(listLength))
        let profiles = try await data.profiles(ids: Array(Set(visible.map(\.post.authorID))))
        let names = Dictionary(profiles.map { ($0.id, $0.firstName ?? "") }, uniquingKeysWith: { first, _ in first })
        let paths = visible.compactMap { $0.media?.imagePath(for: .display) }
        let urls = try await data.signedURLs(paths: paths)
        return visible.map { post in
            YearStoryPhoto(
                postID: post.post.id,
                name: names[post.post.authorID] ?? "",
                date: LocalDate(post.post.createdAt, in: story.timeZone),
                imageURL: post.media?.imagePath(for: .display).flatMap { urls[$0] }
            )
        }
    }

    /// Collages of the everyone-answered days that are ready (`status = 'ready'`), worker order.
    static func collages(_ story: YearStoryData, data: any MemoryDataSource) async throws -> [YearStoryCollage] {
        guard !story.everyoneDays.isEmpty else { return [] }
        let rows = try await data.collages(ids: story.everyoneDays.map(\.collageID))
        let ready = Dictionary(rows.filter(\.isReady).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let days = story.everyoneDays.filter { ready[$0.collageID] != nil }
        let urls = try await data.signedURLs(paths: days.compactMap { ready[$0.collageID]?.imagePath })
        return days.map { day in
            YearStoryCollage(
                collageID: day.collageID,
                date: day.localDate,
                postIDs: day.postIDs,
                imageURL: ready[day.collageID]?.imagePath.flatMap { urls[$0] }
            )
        }
    }

    /// The recap card's photos: `data.most_reacted` first, then `year_stories.post_ids` in order, deduplicated; posts
    /// hidden by a block are skipped; full rows only (`layout.year.story.recapCard`), at most `maxRows` rows.
    static func grid(_ story: YearStoryData, postIDs: [PostID], data: any MemoryDataSource) async throws -> [YearStoryGridPhoto] {
        var seen = Set<PostID>()
        let ordered = (story.mostReacted + postIDs).filter { seen.insert($0).inserted }
        let limit = Int(Tokens.Layouts.YearStoryRecapCard.columns * Tokens.Layouts.YearStoryRecapCard.maxRows)
        guard !ordered.isEmpty else { return [] }
        // Read a few more than a full card so photos hidden by a block (RLS) leave no hole.
        let posts = try await data.postsWithMedia(ids: Array(ordered.prefix(limit * 2)))
        let shown = RecapCard.fullRows(Array(posts.prefix(limit)))
        guard !shown.isEmpty else { return [] }
        let profiles = try await data.profiles(ids: Array(Set(shown.map(\.post.authorID))))
        let names = Dictionary(profiles.map { ($0.id, $0.firstName ?? "") }, uniquingKeysWith: { first, _ in first })
        let urls = try await data.signedURLs(paths: shown.compactMap { $0.media?.imagePath(for: .thumb) })
        return shown.map { post in
            YearStoryGridPhoto(
                postID: post.post.id,
                imageURL: post.media?.imagePath(for: .thumb).flatMap { urls[$0] },
                name: names[post.post.authorID] ?? "",
                date: LocalDate(post.post.createdAt, in: story.timeZone)
            )
        }
    }

    /// The cover's display rendition: the first visible post of `data.most_reacted`, else of `year_stories.post_ids`.
    static func coverURL(_ story: YearStoryData, postIDs: [PostID], data: any MemoryDataSource) async throws -> URL? {
        for candidates in [story.mostReacted, postIDs] where !candidates.isEmpty {
            guard let post = try await data.postsWithMedia(ids: Array(candidates.prefix(Int(Tokens.Counts.yearStoryListLength)))).first,
                  let path = post.media?.imagePath(for: .display) else { continue }
            return try await data.signedURLs(paths: [path])[path]
        }
        return nil
    }

    // MARK: Navigation (`layout.year.story.navigation`)

    /// Right half: the next card (nothing on the last card).
    func next() {
        if index + 1 < cards.count {
            index += 1
            preloadUpcoming()
            restartCardTimer()
        }
    }

    /// Left half: the previous card (nothing on the first card).
    func previous() {
        if index > 0 {
            index -= 1
            restartCardTimer()
        }
    }

    /// The summary's replay circle (`year.story.summary.replay`): back to card 1.
    func replay() {
        index = 0
        summaryPage = 0
        preloadUpcoming()
        restartCardTimer()
    }

    func close() {
        deletionTask?.cancel()
        advanceTask?.cancel()
        isFinished = true
    }

    // MARK: Auto-advance (`duration.year.story.card`)

    /// Paused with the pause circle (or by sharing); stays paused across taps until play is tapped
    /// (WCAG 2.2.2 Pause, Stop, Hide).
    private(set) var isPaused = false
    /// The app is not in the foreground: the clock stops and resumes by itself on return.
    private(set) var isSuspended = false
    /// Time already spent on the current card while its clock last ran.
    private(set) var elapsedBeforePause: TimeInterval = 0
    /// When the current card's clock last started; nil while it is stopped.
    private(set) var timerStartedAt: Date?
    private var advanceTask: Task<Void, Never>?

    /// Each card's time before the story advances on its own (`duration.year.story.card`).
    var cardDuration: TimeInterval { Tokens.Durations.yearStoryCard }

    /// Whether the current card advances on its own: every loaded card but the summary.
    var advancesOnItsOwn: Bool {
        phase == .loaded && currentCard != nil && currentCard != .summary
    }

    /// Whether the progress bar should be redrawn over time.
    var clockRuns: Bool { advancesOnItsOwn && !isPaused && !isSuspended }

    /// Elapsed share of the current card's time at `date`, 0…1 (linear; the progress bar maps it
    /// through `easing.year.story.progress.fill`). The summary, which does not advance, reads 1.
    func currentFraction(at date: Date) -> Double {
        guard advancesOnItsOwn, cardDuration > 0 else { return 1 }
        return min(max(elapsed(at: date) / cardDuration, 0), 1)
    }

    private func elapsed(at date: Date) -> TimeInterval {
        elapsedBeforePause + (timerStartedAt.map { date.timeIntervalSince($0) } ?? 0)
    }

    /// Moves to the next card when the current one's time is up at `date` (clock running, not the
    /// summary). Returns whether it moved.
    @discardableResult
    func advanceIfDue(at date: Date) -> Bool {
        guard clockRuns, elapsed(at: date) >= cardDuration else { return false }
        next()
        return true
    }

    /// A new card: its clock starts from zero (stopped while paused or suspended).
    func restartCardTimer() {
        advanceTask?.cancel()
        elapsedBeforePause = 0
        timerStartedAt = clockRuns ? dependencies.now() : nil
        scheduleAdvance()
    }

    func togglePause() {
        if isPaused {
            isPaused = false
            startClock()
        } else {
            stopClock()
            isPaused = true
        }
    }

    /// Pauses (no-op when already paused): sharing a card keeps it in view while the share sheet is up.
    func pause() {
        if !isPaused { togglePause() }
    }

    /// The app left (true) or returned to (false) the foreground.
    func setSuspended(_ suspended: Bool) {
        guard suspended != isSuspended else { return }
        if suspended {
            stopClock()
            isSuspended = true
        } else {
            isSuspended = false
            startClock()
        }
    }

    private func stopClock() {
        advanceTask?.cancel()
        if let start = timerStartedAt { elapsedBeforePause += dependencies.now().timeIntervalSince(start) }
        timerStartedAt = nil
    }

    private func startClock() {
        guard clockRuns, timerStartedAt == nil else { return }
        timerStartedAt = dependencies.now()
        scheduleAdvance()
    }

    /// Sleeps for the rest of the current card's time, then advances (unless the card changed, the
    /// clock stopped or the story closed meanwhile).
    private func scheduleAdvance() {
        advanceTask?.cancel()
        guard clockRuns, let cardID = currentCard?.id else { return }
        let remaining = max(0, cardDuration - elapsedBeforePause)
        let sleep = dependencies.sleep
        advanceTask = Task { [weak self] in
            do {
                try await sleep(remaining)
            } catch {
                return
            }
            guard !Task.isCancelled, let self, self.currentCard?.id == cardID, self.clockRuns, !self.isFinished else { return }
            self.next()
        }
    }

    // MARK: Deletions

    /// Drops the card(s) showing a deleted photo, and a section's setup card when its list is empty.
    func removePost(_ postID: PostID) {
        dependencies.cache.purge(postID: postID)
        let currentID = currentCard?.id
        cards.removeAll { card in
            switch card {
            case let .mostReacted(photo): return photo.postID == postID
            case let .togetherDay(collage): return collage.postIDs.contains(postID)
            default: return false
            }
        }
        if let current = summary, current.grid.contains(where: { $0.postID == postID }) {
            summary = YearStorySummary(
                year: current.year, groupName: current.groupName,
                grid: RecapCard.fullRows(current.grid.filter { $0.postID != postID })
            )
            summaryPage = min(summaryPage, summaryStyles.count - 1)
            shareFiles = shareFiles.filter { !$0.key.hasPrefix(YearStoryCard.summary.id) }
            shareImages = shareImages.filter { !$0.key.hasPrefix(YearStoryCard.summary.id) }
        }
        if !cards.contains(where: { if case .mostReacted = $0 { return true } else { return false } }) {
            cards.removeAll { $0 == .mostReactedSetup }
        }
        if !cards.contains(where: { if case .togetherDay = $0 { return true } else { return false } }) {
            cards.removeAll { $0 == .togetherSetup }
        }
        if let currentID, let kept = cards.firstIndex(where: { $0.id == currentID }) {
            index = kept
        } else {
            index = min(index, max(cards.count - 1, 0))
            // The card in view was dropped: the one now shown gets its full time.
            restartCardTimer()
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
        advanceTask?.cancel()
    }
}

/// The group-screen entry (A in design/surfaces/year.story.md): shown while this year's story is ready ("Year in Photos" /
/// "2025 Recap" / "View memories", `icon.global.recap`, the story's cover).
@MainActor
@Observable
final class YearStoryEntryModel {
    private(set) var content: MemoryEntryContent?
    private(set) var year: Int?
    let groupID: GroupID
    private let dependencies: MemoryDependencies

    init(groupID: GroupID, dependencies: MemoryDependencies) {
        self.groupID = groupID
        self.dependencies = dependencies
    }

    private struct Cached {
        let content: MemoryEntryContent
        let year: Int
    }

    func refresh() async {
        guard let data = dependencies.data else {
            content = nil
            return
        }
        let me = await data.currentUser()
        let cacheKey = "yearstory.entry." + groupID.rawValue // provenance-ok: cache key
        if content == nil, let cached = dependencies.cache.value(Cached.self, key: cacheKey, user: me) {
            year = cached.year
            content = cached.content
        }
        do {
            let zone = try await data.group(id: groupID)?.resolvedTimeZone ?? MemoryFormat.utc
            let currentYear = LocalDate(dependencies.now(), in: zone).year
            guard let story = try await data.yearStory(groupID: groupID, year: currentYear), story.status == .ready,
                  let storyData = YearStoryData(json: story.data, fallbackYear: currentYear) else {
                content = nil
                dependencies.cache.remove(key: cacheKey)
                return
            }
            // The card's photo: the story's cover (the first visible most-reacted post, else the first post).
            var photo: String?
            for candidates in [storyData.mostReacted, story.postIDs] where photo == nil && !candidates.isEmpty {
                photo = try await data.postsWithMedia(ids: Array(candidates.prefix(Int(Tokens.Counts.yearStoryListLength))))
                    .first?.media?.imagePath(for: .display)
            }
            let fresh = MemoryEntryContent(
                title: Copy.yearStoryEntryTitle,
                subtitle: Copy.yearStoryEntrySubtitle(year: String(currentYear)),
                buttonTitle: Copy.yearStoryEntryButton,
                icon: Tokens.Icons.globalRecap,
                photoPath: photo
            )
            year = currentYear
            content = fresh
            dependencies.cache.set(Cached(content: fresh, year: currentYear), key: cacheKey, user: me)
        } catch {
            // An invitation only: on failure it stays as it was.
        }
    }
}
