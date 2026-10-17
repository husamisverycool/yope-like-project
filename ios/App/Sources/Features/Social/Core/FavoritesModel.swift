// Surface: favorites — your private favorites (Apple Photos Favorites; owner decision 34,
// docs/RESEARCH_FEATURES_2026-10-17.md #19). Spec: design/surfaces/favorites.md ("States", "Data & actions").
// View model only (Foundation + Observation + AppData); the view is FavoritesScreen. Never a count.
import AppData
import AppModels
import Foundation
import Observation

@MainActor
@Observable
final class FavoritesModel {
    @ObservationIgnored private let data: any SocialDataSource

    private(set) var phase: SocialPhase = .loading
    private(set) var isOffline = false
    /// Newest favorite first (`favorited_at`).
    private(set) var items: [FavoritePhoto] = []
    private(set) var profiles: [UserID: Profile] = [:]
    /// Media of the shown photos (the video pill).
    private(set) var media: [PostID: Media] = [:]
    private(set) var me: UserID?
    private(set) var isLoadingMore = false
    @ObservationIgnored private var nextCursor: Date?
    private(set) var hasCheckedCache = false

    var showsLoading: Bool { phase == .loading && hasCheckedCache }

    init(data: any SocialDataSource) {
        self.data = data
    }

    /// The viewer's context: the favorites shown, in this order (the header names each photo's group).
    func viewerContext(start: PostID) -> PhotoViewerContext {
        PhotoViewerContext(postIDs: items.map(\.postID), start: start, showsGroupName: true)
    }

    func load() async {
        if me == nil { me = await data.currentUserID() }
        if items.isEmpty, let cached = await data.cachedFavorites(), !cached.isEmpty {
            items = cached
            phase = .ready
        }
        hasCheckedCache = true
        do {
            let rows = try await data.favorites(before: nil, limit: SocialPaging.favorites)
            items = rows
            nextCursor = rows.count == SocialPaging.favorites ? rows.last?.favoritedAt : nil
            isOffline = false
            phase = rows.isEmpty ? .empty : .ready
        } catch {
            if SocialFailure(error) == .offline { isOffline = true }
            if items.isEmpty { phase = isOffline ? .offline : .failed }
        }
        await loadDetails()
    }

    func retry() async {
        phase = .loading
        await load()
    }

    /// The last row shows: the next page (`p_before` = the last `favorited_at`).
    func loadMore() async {
        guard let cursor = nextCursor, !isLoadingMore, phase == .ready else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let rows = try await data.favorites(before: cursor, limit: SocialPaging.favorites)
            let known = Set(items.map(\.mediaID))
            items += rows.filter { !known.contains($0.mediaID) }
            nextCursor = rows.count == SocialPaging.favorites ? rows.last?.favoritedAt : nil
            await loadDetails()
        } catch {
            if SocialFailure(error) == .offline { isOffline = true }
        }
    }

    private func loadDetails() async {
        let people = items.map(\.authorID).socialUnique().filter { profiles[$0] == nil }
        if !people.isEmpty, let found = try? await data.profiles(ids: people) {
            for profile in found { profiles[profile.id] = profile }
        }
        let videos = items.filter { $0.kind == .video && media[$0.postID] == nil }.map(\.postID)
        if !videos.isEmpty, let found = try? await data.posts(ids: videos) {
            for post in found { if let item = post.media { media[post.id] = item } }
        }
    }

    func run() async {
        for await status in data.network() {
            switch status {
            case .offline: isOffline = true
            case .online:
                let wasOffline = isOffline
                isOffline = false
                if wasOffline { await load() }
            case .unknown: break
            }
        }
    }
}
