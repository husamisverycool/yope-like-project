// Surface: onthisday — view models (the day and the group-screen entry). Spec: design/surfaces/onthisday.md.
import AppData
import DesignSystem
import Foundation
import Observation

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

    /// Rows grouped by `years_ago` ascending (1 year ago first), API order kept inside a year.
    static func years(_ rows: [OnThisDayItem]) -> [(yearsAgo: Int, rows: [OnThisDayItem])] {
        var order: [Int] = []
        var grouped: [Int: [OnThisDayItem]] = [:]
        for row in rows {
            if grouped[row.yearsAgo] == nil { order.append(row.yearsAgo) }
            grouped[row.yearsAgo, default: []].append(row)
        }
        return order.sorted().map { ($0, grouped[$0] ?? []) }
    }
}

@MainActor
@Observable
final class OnThisDayModel {
    struct Photo: Identifiable, Equatable {
        let id: PostID
        let authorName: String
        let avatarURL: URL?
        /// `display_path` (original until renditions are ready): the single-photo layout.
        let displayURL: URL?
        /// `thumb_path`: the grid.
        let thumbURL: URL?
        /// width / height of the media; nil when unknown.
        let aspectRatio: CGFloat?
        let createdAt: Date
    }

    struct Year: Identifiable, Equatable {
        let yearsAgo: Int
        var photos: [Photo]
        var id: Int { yearsAgo }
    }

    enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case error
        case offline
    }

    var phase: Phase = .idle
    var years: [Year] = []
    var index = 0
    /// Set when the day should close (✕, past the oldest year, or no photo left).
    var isFinished = false
    var timeZone: TimeZone = MemoryFormat.utc

    let groupID: GroupID
    private let dependencies: MemoryDependencies
    private var deletionTask: Task<Void, Never>?

    init(groupID: GroupID, dependencies: MemoryDependencies) {
        self.groupID = groupID
        self.dependencies = dependencies
    }

    var currentYear: Year? { years.indices.contains(index) ? years[index] : nil }

    /// Reached fraction of the progress bar: (index + 1) / number of years (`layout.onthisday.progress`).
    var progress: CGFloat {
        guard !years.isEmpty else { return 0 }
        return CGFloat(index + 1) / CGFloat(years.count)
    }

    func loadIfNeeded() async {
        guard phase == .idle else { return }
        await load()
    }

    func retry() async {
        await load()
    }

    private struct Cached {
        let years: [Year]
        let timeZone: TimeZone
    }

    /// Cache-first: the last content of this day shows at once and is replaced in place.
    private func load() async {
        guard let data = dependencies.data else {
            phase = .error
            return
        }
        let me = await data.currentUser()
        let cacheKey = "onthisday." + groupID.rawValue // provenance-ok: cache key
        let cached = dependencies.cache.value(Cached.self, key: cacheKey, user: me)
        if let cached, phase != .loaded {
            apply(cached.years, timeZone: cached.timeZone)
        } else if phase != .loaded {
            phase = .loading
        }
        do {
            let group = try await data.group(id: groupID)
            let zone = group?.resolvedTimeZone ?? MemoryFormat.utc
            let day = OnThisDayCalendar.localDate(now: dependencies.now(), timeZone: zone)
            let rows = try await data.onThisDay(groupID: groupID, localDate: day)
            let fresh = try await Self.resolve(rows: rows, data: data)
            dependencies.cache.set(Cached(years: fresh, timeZone: zone), key: cacheKey, user: me,
                                   postIDs: Set(fresh.flatMap { $0.photos.map(\.id) }))
            apply(fresh, timeZone: zone)
            if years.isEmpty { isFinished = true }
            listenForDeletions(data: data)
        } catch {
            // Cached content stays on screen; without it, the error / offline state.
            if phase != .loaded {
                phase = MemoryFailure(error) == .offline ? .offline : .error
            }
        }
    }

    /// Shows `fresh`, keeping the year in view when it is still there.
    private func apply(_ fresh: [Year], timeZone zone: TimeZone) {
        let currentID = currentYear?.id
        timeZone = zone
        years = fresh
        if let currentID, let kept = fresh.firstIndex(where: { $0.id == currentID }) {
            index = kept
        } else {
            index = 0
        }
        phase = .loaded
        preloadUpcoming()
    }

    /// Pixel size of the content area's longest side (set by the screen); photos are decoded at it.
    /// Nothing is preloaded until it is known.
    var imagePixelSize: CGFloat?

    /// Decodes the next (older) year's photos before it is tapped to, so the year cross-fade
    /// (`duration.onthisday.memoryChange`) never fades into an empty frame.
    func preloadUpcoming() {
        guard let size = imagePixelSize, years.indices.contains(index + 1) else { return }
        let photos = years[index + 1].photos
        let urls = photos.count == 1
            ? photos.compactMap(\.displayURL) + photos.compactMap(\.avatarURL)
            : photos.compactMap(\.thumbURL)
        guard !urls.isEmpty else { return }
        let images = dependencies.images
        Task {
            for url in urls {
                _ = await images.image(for: url, maxPixelSize: size)
            }
        }
    }

    static func resolve(rows: [OnThisDayItem], data: any MemoryDataSource) async throws -> [Year] {
        let posts = try await data.postsWithMedia(ids: rows.map(\.postID))
        let byPost = Dictionary(posts.map { ($0.post.id, $0) }, uniquingKeysWith: { first, _ in first })
        let profiles = try await data.profiles(ids: Array(Set(rows.map(\.authorID))))
        let byUser = Dictionary(profiles.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var paths: [String] = []
        for post in posts {
            if let path = post.media?.imagePath(for: .display) { paths.append(path) }
            if let path = post.media?.imagePath(for: .thumb) { paths.append(path) }
        }
        paths += profiles.compactMap(\.avatarPath)
        let urls = try await data.signedURLs(paths: paths)
        return OnThisDayCalendar.years(rows).compactMap { group -> Year? in
            let photos = group.rows.compactMap { row -> Photo? in
                guard let post = byPost[row.postID] else { return nil }
                let media = post.media
                let profile = byUser[row.authorID]
                var aspect: CGFloat?
                if let width = media?.width, let height = media?.height, width > 0, height > 0 {
                    aspect = CGFloat(width) / CGFloat(height)
                }
                return Photo(
                    id: row.postID,
                    authorName: profile?.firstName ?? "",
                    avatarURL: profile?.avatarPath.flatMap { urls[$0] },
                    displayURL: media?.imagePath(for: .display).flatMap { urls[$0] },
                    thumbURL: media?.imagePath(for: .thumb).flatMap { urls[$0] },
                    aspectRatio: aspect,
                    createdAt: row.createdAt
                )
            }
            return photos.isEmpty ? nil : Year(yearsAgo: group.yearsAgo, photos: photos)
        }
    }

    // MARK: Navigation (`layout.onthisday.navigation`)

    /// Right half: the next (older) year; on the oldest year it closes the day.
    func next() {
        if index + 1 < years.count {
            index += 1
            preloadUpcoming()
        } else {
            isFinished = true
        }
    }

    /// Left half: the previous (newer) year; nothing on the newest year.
    func previous() {
        if index > 0 { index -= 1 }
    }

    func close() {
        isFinished = true
    }

    // MARK: Deletions (docs/API.md §8.2)

    /// Drops a deleted photo, its year when it was the last one, and closes the day when none remain.
    func removePost(_ postID: PostID) {
        dependencies.cache.purge(postID: postID)
        let currentID = currentYear?.id
        for position in years.indices {
            years[position].photos.removeAll { $0.id == postID }
        }
        years.removeAll { $0.photos.isEmpty }
        if years.isEmpty {
            isFinished = true
            index = 0
            return
        }
        if let currentID, let kept = years.firstIndex(where: { $0.id == currentID }) {
            index = kept
        } else {
            index = min(index, years.count - 1)
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
    }

    // MARK: Text

    func bannerLabel(for year: Year) -> String {
        MemoryFormat.yearsAgo(year.yearsAgo)
    }

    func meta(for photo: Photo) -> String {
        Copy.onthisdayMemoryMeta(
            weekday: MemoryFormat.metaWeekday(photo.createdAt, timeZone: timeZone),
            time: MemoryFormat.metaTime(photo.createdAt, timeZone: timeZone)
        )
    }

    func accessibilityLabel(for photo: Photo) -> String {
        Copy.onthisdayA11yPhoto(
            name: photo.authorName,
            weekday: MemoryFormat.spokenWeekday(photo.createdAt, timeZone: timeZone),
            time: MemoryFormat.metaTime(photo.createdAt, timeZone: timeZone)
        )
    }
}

/// The group-screen entry: visible only while `on_this_day` returns rows.
@MainActor
@Observable
final class OnThisDayEntryModel {
    /// Title (`onthisday.entry.title`) and second line (the newest memory's banner label).
    struct Content: Equatable {
        let title: String
        let subtitle: String
    }

    var content: Content?
    let groupID: GroupID
    private let dependencies: MemoryDependencies

    init(groupID: GroupID, dependencies: MemoryDependencies) {
        self.groupID = groupID
        self.dependencies = dependencies
    }

    func refresh() async {
        guard let data = dependencies.data else {
            content = nil
            return
        }
        let me = await data.currentUser()
        let cacheKey = "onthisday.entry." + groupID.rawValue // provenance-ok: cache key
        if content == nil, let cached = dependencies.cache.value(Content.self, key: cacheKey, user: me) {
            content = cached
        }
        do {
            let group = try await data.group(id: groupID)
            guard let group else {
                content = nil
                dependencies.cache.remove(key: cacheKey)
                return
            }
            let day = OnThisDayCalendar.localDate(now: dependencies.now(), timeZone: group.resolvedTimeZone)
            let rows = try await data.onThisDay(groupID: groupID, localDate: day)
            guard let newest = rows.map(\.yearsAgo).min() else {
                content = nil
                dependencies.cache.remove(key: cacheKey)
                return
            }
            let fresh = Content(title: Copy.onthisdayEntryTitle(group: group.name), subtitle: MemoryFormat.yearsAgo(newest))
            content = fresh
            dependencies.cache.set(fresh, key: cacheKey, user: me, postIDs: Set(rows.map(\.postID)))
        } catch {
            // The entry is only an invitation: on failure it stays as it was.
        }
    }
}
