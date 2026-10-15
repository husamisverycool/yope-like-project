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

/// One card of the tap-through, in the order of the spec's card table.
enum YearStoryCard: Equatable, Identifiable, Sendable {
    case intro
    case momentsSetup
    case moments(groupName: String, count: Int)
    case busiestMonth(month: Int, year: Int)
    case mostReactedSetup
    case mostReacted(YearStoryPhoto)
    case togetherSetup
    case togetherDay(YearStoryCollage)
    case teaser
    case outro
    case summary

    var id: String {
        switch self {
        case .intro: return "intro"
        case .momentsSetup: return "moments-setup"
        case .moments: return "moments"
        case .busiestMonth: return "busiest-month"
        case .mostReactedSetup: return "most-reacted-setup"
        case let .mostReacted(photo): return "most-reacted-" + photo.postID.rawValue
        case .togetherSetup: return "together-setup"
        case let .togetherDay(collage): return "together-" + collage.collageID.rawValue
        case .teaser: return "teaser"
        case .outro: return "outro"
        case .summary: return "summary"
        }
    }

    /// Cards that state a fact carry the share row and have a share image.
    var isShareable: Bool {
        switch self {
        case .moments, .busiestMonth, .mostReacted, .togetherDay: return true
        default: return false
        }
    }

    var headline: String {
        switch self {
        case .intro: return Copy.yearStoryIntroTitle
        case .momentsSetup: return Copy.yearStoryMomentsTitle
        case let .moments(groupName, count):
            return Copy.yearStoryMomentsCount(group: groupName, count: count.formatted())
        case let .busiestMonth(month, year):
            return Copy.yearStoryBusiestMonthTitle(month: MemoryFormat.storyMonth(month, year: year) ?? "")
        case .mostReactedSetup: return Copy.yearStoryMostReactedTitle
        case let .mostReacted(photo):
            return Copy.yearStoryMostReactedPhoto(name: photo.name, date: MemoryFormat.storyDate(photo.date))
        case .togetherSetup: return Copy.yearStoryTogetherTitle
        case let .togetherDay(collage): return MemoryFormat.storyDate(collage.date)
        case .teaser: return Copy.yearStoryOutroTeaser
        case .outro: return Copy.yearStoryOutroTitle
        case .summary: return ""
        }
    }

    var subline: String? {
        switch self {
        case .intro: return Copy.yearStoryIntroSubtitle
        case .moments: return Copy.yearStoryMomentsAside
        case .busiestMonth: return Copy.yearStoryBusiestMonthAside
        case .mostReactedSetup: return Copy.yearStoryMostReactedAside
        case .togetherSetup: return Copy.yearStoryTogetherAside
        case .outro: return Copy.yearStoryOutroSubtitle
        default: return nil
        }
    }

    /// Image of a photo / collage card.
    var imageURL: URL? {
        switch self {
        case let .mostReacted(photo): return photo.imageURL
        case let .togetherDay(collage): return collage.imageURL
        default: return nil
        }
    }

    /// The cards for a story: a card (or a whole section) whose data is missing is skipped; lists
    /// keep at most `count.year.story.listLength` entries.
    static func build(data: YearStoryData, groupName: String, photos: [YearStoryPhoto], collages: [YearStoryCollage]) -> [YearStoryCard] {
        let listLength = Int(Tokens.Counts.yearStoryListLength)
        var cards: [YearStoryCard] = [.intro]
        if let count = data.momentsShared {
            cards += [.momentsSetup, .moments(groupName: groupName, count: count)]
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
        cards += [.teaser, .outro, .summary]
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
    /// The share card in view on the summary.
    var summaryPage = 0
    /// Rendered share images (1080 × 1920 PNG files and their previews), by card id.
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

    /// The fact cards, in story order (the summary's pager).
    var shareableCards: [YearStoryCard] { cards.filter(\.isShareable) }

    var images: any MemoryImageLoading { dependencies.images }

    func loadIfNeeded() async {
        guard phase == .idle else { return }
        await load()
    }

    func retry() async {
        await load()
    }

    /// Cache-first: the story shown last opens at once; the fresh read replaces it in place.
    private func load() async {
        guard let data = dependencies.data else {
            phase = .error
            return
        }
        let me = await data.currentUser()
        let cacheKey = "yearstory." + groupID.rawValue + "." + String(year) // provenance-ok: cache key
        if phase != .loaded, let cached = dependencies.cache.value([YearStoryCard].self, key: cacheKey, user: me) {
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
            let fresh = YearStoryCard.build(data: storyData, groupName: groupName, photos: photos, collages: collages)
            dependencies.cache.set(fresh, key: cacheKey, user: me, postIDs: Self.postIDs(of: fresh))
            apply(fresh)
            listenForDeletions(data: data)
        } catch {
            if phase != .loaded {
                phase = MemoryFailure(error) == .offline ? .offline : .error
            }
        }
    }

    /// Shows `fresh`, staying on the card in view when it is still there.
    private func apply(_ fresh: [YearStoryCard]) {
        let currentID = currentCard?.id
        if fresh != cards {
            shareFiles = shareFiles.filter { id, _ in fresh.contains { $0.id == id } }
            shareImages = shareImages.filter { id, _ in fresh.contains { $0.id == id } }
        }
        cards = fresh
        index = currentID.flatMap { id in fresh.firstIndex { $0.id == id } } ?? 0
        phase = .loaded
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
        let upcoming = cards.dropFirst(index).prefix(Self.preloadCount + 1).compactMap(\.imageURL)
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

    /// "Replay from beginning".
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

    // MARK: Auto-advance (`MemoryBlocked.yearStoryCardDuration`; tap-only while BLOCKED)

    /// Paused with the pause circle (shown only when the story advances on its own).
    private(set) var isPaused = false
    /// Time already spent on the current card before the last pause.
    private(set) var elapsedBeforePause: TimeInterval = 0
    /// When the current card's timer last (re)started.
    private(set) var timerStartedAt: Date?
    private var advanceTask: Task<Void, Never>?

    /// The card duration once it is sourced; nil = tap-only.
    var cardDuration: TimeInterval? { MemoryBlocked.yearStoryCardDuration }

    /// Filled fraction of the current progress segment at `date` (1 while tap-only).
    func currentFraction(at date: Date) -> Double {
        guard let duration = cardDuration, duration > 0, currentCard != .summary else { return 1 }
        var elapsed = elapsedBeforePause
        if !isPaused, let start = timerStartedAt { elapsed += date.timeIntervalSince(start) }
        return min(max(elapsed / duration, 0), 1)
    }

    func restartCardTimer() {
        advanceTask?.cancel()
        elapsedBeforePause = 0
        timerStartedAt = dependencies.now()
        scheduleAdvance()
    }

    func togglePause() {
        if isPaused {
            isPaused = false
            timerStartedAt = dependencies.now()
            scheduleAdvance()
        } else {
            advanceTask?.cancel()
            if let start = timerStartedAt { elapsedBeforePause += dependencies.now().timeIntervalSince(start) }
            timerStartedAt = nil
            isPaused = true
        }
    }

    private func scheduleAdvance() {
        guard let duration = cardDuration, !isPaused, phase == .loaded, let card = currentCard, card != .summary else { return }
        let remaining = max(0, duration - elapsedBeforePause)
        let cardID = card.id
        advanceTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(remaining))
            guard !Task.isCancelled, let self, self.currentCard?.id == cardID, !self.isPaused else { return }
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
        }
        summaryPage = min(summaryPage, max(shareableCards.count - 1, 0))
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

/// The group-screen entry (A in design/surfaces/year.story.md): shown while this year's story is ready.
@MainActor
@Observable
final class YearStoryEntryModel {
    var content: MemoryEntryContent?
    var year: Int?
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
                  story.data != nil else {
                content = nil
                dependencies.cache.remove(key: cacheKey)
                return
            }
            let fresh = MemoryEntryContent(
                title: Copy.yearStoryEntryTitle(year: String(currentYear)),
                subtitle: Copy.yearStoryEntrySubtitle,
                buttonTitle: Copy.yearStoryEntryButton
            )
            year = currentYear
            content = fresh
            dependencies.cache.set(Cached(content: fresh, year: currentYear), key: cacheKey, user: me)
        } catch {
            // An invitation only: on failure it stays as it was.
        }
    }
}
