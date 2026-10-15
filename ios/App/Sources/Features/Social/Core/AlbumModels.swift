// Surfaces: albums.list, albums.view — reference app: Yope (composition from documented Yope components, S-14).
// Specs: design/surfaces/albums.*.md ("States", "Data & actions"). View models only (Foundation + Observation + AppData).
import AppData
import AppModels
import Foundation
import Observation

/// `albums.list`: the group's saved albums, newest first, each with its first photo as cover.
@MainActor
@Observable
final class AlbumsListModel {
    let groupID: GroupID
    @ObservationIgnored private let data: any SocialDataSource

    private(set) var phase: SocialPhase = .loading
    private(set) var isOffline = false
    private(set) var albums: [AlbumWithItems] = []
    private(set) var covers: [PostID: PostWithMedia] = [:]
    private(set) var profiles: [UserID: Profile] = [:]
    /// The latest ready recap (empty-state "view recap").
    private(set) var latestRecapID: RecapID?
    private(set) var hasCheckedCache = false

    var showsLoading: Bool { phase == .loading && hasCheckedCache }

    init(groupID: GroupID, data: any SocialDataSource) {
        self.groupID = groupID
        self.data = data
    }

    func cover(of album: AlbumWithItems) -> PostWithMedia? {
        album.postIDs.first.flatMap { covers[$0] }
    }

    func savedByName(_ album: AlbumWithItems) -> String? {
        album.album.createdBy.flatMap { profiles[$0]?.socialFirstName }
    }

    func load() async {
        if albums.isEmpty, let cached = await data.cachedAlbums(groupID: groupID), !cached.isEmpty {
            albums = cached
            phase = .ready
            await loadDetails()
        }
        hasCheckedCache = true
        do {
            albums = try await data.albums(groupID: groupID)
            isOffline = false
            phase = albums.isEmpty ? .empty : .ready
        } catch {
            if SocialFailure(error) == .offline { isOffline = true }
            if albums.isEmpty { phase = isOffline ? .offline : .failed }
        }
        await loadDetails()
        if phase == .empty, let recaps = try? await data.recaps(groupID: groupID) {
            latestRecapID = recaps.first { $0.status == .ready }?.id
        }
    }

    func retry() async {
        phase = .loading
        await load()
    }

    private func loadDetails() async {
        let firstItems = albums.compactMap(\.postIDs.first).filter { covers[$0] == nil }
        if !firstItems.isEmpty, let found = try? await data.posts(ids: firstItems) {
            for post in found { covers[post.id] = post }
        }
        let people = albums.compactMap(\.album.createdBy).socialUnique().filter { profiles[$0] == nil }
        if !people.isEmpty, let found = try? await data.profiles(ids: people) {
            for profile in found { profiles[profile.id] = profile }
        }
    }
}

/// `albums.view`: one album's photos in `position` order; rename and delete from the ••• menu.
@MainActor
@Observable
final class AlbumModel {
    enum Phase: Equatable {
        case loading
        case ready
        /// Every item deleted or hidden.
        case empty
        /// `album_not_found` (deleted meanwhile).
        case notFound
        case failed
        case offline
    }

    let groupID: GroupID
    let albumID: AlbumID
    @ObservationIgnored private let data: any SocialDataSource

    private(set) var phase: Phase = .loading
    private(set) var isOffline = false
    private(set) var album: Album?
    private(set) var posts: [PostWithMedia] = []
    /// "delete album" is offered to the album's creator and group admins.
    private(set) var canDelete = false
    var isRenaming = false
    var renameText = ""
    /// `week.edit.error.albumName` under the field.
    private(set) var renameMissing = false
    private(set) var isWorking = false
    /// The album was deleted here: the screen pops.
    private(set) var isDeleted = false
    private(set) var signals = SocialSignals()
    private(set) var profiles: [UserID: Profile] = [:]
    private(set) var me: UserID?

    init(groupID: GroupID, albumID: AlbumID, data: any SocialDataSource) {
        self.groupID = groupID
        self.albumID = albumID
        self.data = data
    }

    var postIDs: [PostID] { posts.map(\.id) }

    private(set) var hasCheckedCache = false

    var showsLoading: Bool { phase == .loading && hasCheckedCache }

    func load() async {
        let me = await data.currentUserID()
        if album == nil, let cached = await data.cachedAlbums(groupID: groupID),
           let found = cached.first(where: { $0.album.id == albumID }) {
            album = found.album
            if let shown = try? await data.posts(ids: found.postIDs), !shown.isEmpty {
                posts = shown
                phase = .ready
            }
        }
        hasCheckedCache = true
        do {
            let albums = try await data.albums(groupID: groupID)
            isOffline = false
            try await apply(albums)
            if let membership = try? await data.myMembership(groupID: groupID) {
                canDelete = album?.createdBy == me || membership.role == .admin
            } else {
                canDelete = album?.createdBy == me
            }
        } catch {
            let failure = SocialFailure(error)
            if failure == .offline, let cached = await data.cachedAlbums(groupID: groupID) {
                isOffline = true
                try? await apply(cached)
            } else if failure == .notFound {
                phase = .notFound
            } else {
                isOffline = failure == .offline
                phase = isOffline ? .offline : .failed
            }
        }
    }

    private func apply(_ albums: [AlbumWithItems]) async throws {
        guard let found = albums.first(where: { $0.album.id == albumID }) else {
            phase = .notFound
            return
        }
        album = found.album
        posts = try await data.posts(ids: found.postIDs)
        if me == nil { me = await data.currentUserID() }
        profiles = await SocialPeople.profiles(of: posts, known: profiles, data: data)
        phase = posts.isEmpty ? .empty : .ready
    }

    func retry() async {
        phase = .loading
        await load()
    }

    func startRename() {
        renameText = album?.name ?? ""
        renameMissing = false
        isRenaming = true
    }

    /// `rename_album` → toast `albums.view.toast.renamed`.
    func rename() async {
        let name = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            renameMissing = true
            return
        }
        guard !isWorking, let previous = album else { return }
        isWorking = true
        defer { isWorking = false }
        // Shown at once; put back if the call fails.
        album?.name = name
        isRenaming = false
        renameMissing = false
        do {
            album = try await data.renameAlbum(id: albumID, name: name)
            signals.emit(.success)
            signals.post(.albumRenamed)
        } catch {
            album = previous
            if SocialFailure(error) == .notFound { phase = .notFound }
            signals.emit(.failed)
            signals.post(.changesFailed)
        }
    }

    /// `delete_album` after the confirmation → pop + toast `albums.view.toast.deleted`. Posts stay.
    func delete() async {
        guard canDelete, !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        signals.emit(.warning)
        do {
            try await data.deleteAlbum(id: albumID, groupID: groupID)
            signals.post(.albumDeleted)
            isDeleted = true
        } catch {
            if SocialFailure(error) == .notFound {
                isDeleted = true
            } else {
                signals.emit(.failed)
                signals.post(.changesFailed)
            }
        }
    }

    func run() async {
        for await event in data.events(groupID: groupID) {
            handle(event)
        }
    }

    /// `post_deleted` → drop the tile.
    func handle(_ event: GroupEvent) {
        guard case let .postDeleted(postID, _) = event else { return }
        posts.removeAll { $0.id == postID }
        if phase == .ready, posts.isEmpty { phase = .empty }
    }
}
