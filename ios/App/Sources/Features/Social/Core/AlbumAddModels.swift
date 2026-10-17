// Surfaces: albums.view (the add sheet, `albums.view.layout.add`) and photo.viewer (the album picker,
// `photo.viewer.layout.albumPicker`) — albums anyone in the group can add to (owner decision 34,
// docs/RESEARCH_FEATURES_2026-10-17.md #10; Apple Shared Albums, support.apple.com/108314). Specs:
// design/surfaces/albums.view.md "Add sheet", design/surfaces/photo.viewer.md "Album picker".
// View models only (Foundation + Observation + AppData).
import AppData
import AppModels
import Foundation
import Observation

/// `albums.view.layout.add` ("Add Photos"): the group's photos of the first page of weeks (`group_history_weeks`) the
/// album does not hold yet, newest week first; pick several, then `add_to_album` in the order picked.
@MainActor
@Observable
final class AlbumAddModel {
    let groupID: GroupID
    let albumID: AlbumID
    @ObservationIgnored private let data: any SocialDataSource
    @ObservationIgnored private let excluded: Set<PostID>

    private(set) var phase: SocialPhase = .loading
    private(set) var isOffline = false
    private(set) var posts: [PostWithMedia] = []
    private(set) var profiles: [UserID: Profile] = [:]
    private(set) var me: UserID?
    /// Picked photos in the order picked.
    private(set) var picked: [PostID] = []
    private(set) var isSaving = false
    /// The photos were added: the sheet closes.
    private(set) var isDone = false
    private(set) var signals = SocialSignals()

    init(groupID: GroupID, albumID: AlbumID, excluding: [PostID], data: any SocialDataSource) {
        self.groupID = groupID
        self.albumID = albumID
        excluded = Set(excluding)
        self.data = data
    }

    var canAdd: Bool { !picked.isEmpty && !isSaving }

    func isPicked(_ postID: PostID) -> Bool { picked.contains(postID) }

    func load() async {
        if me == nil { me = await data.currentUserID() }
        do {
            let weeks = try await data.historyWeeks(groupID: groupID, beforeWeek: nil)
            let found = try await data.posts(ids: Self.ids(of: weeks))
            apply(weeks, posts: found)
            isOffline = false
            profiles = await SocialPeople.profiles(of: posts, known: profiles, data: data)
        } catch {
            let failure = SocialFailure(error)
            if failure == .offline, let cached = await data.cachedHistoryWeeks(groupID: groupID) {
                let shown = await data.cachedPosts(ids: Self.ids(of: cached), groupID: groupID)
                if !shown.isEmpty {
                    isOffline = true
                    apply(cached, posts: shown)
                    return
                }
            }
            isOffline = failure == .offline
            phase = isOffline ? .offline : .failed
        }
    }

    func retry() async {
        phase = .loading
        await load()
    }

    /// Newest week first, newest photo first inside a week; each post once.
    private static func ids(of weeks: [HistoryWeek]) -> [PostID] {
        weeks.sorted { $0.weekStart > $1.weekStart }.flatMap { Array($0.postIDs.reversed()) }.socialUnique()
    }

    private func apply(_ weeks: [HistoryWeek], posts found: [PostWithMedia]) {
        var byID: [PostID: PostWithMedia] = [:]
        for post in found where byID[post.id] == nil { byID[post.id] = post }
        posts = Self.ids(of: weeks).filter { !excluded.contains($0) }.compactMap { byID[$0] }
        picked.removeAll { byID[$0] == nil }
        phase = posts.isEmpty ? .empty : .ready
    }

    /// A tap on a cell: picks or un-picks it (`haptic.global.select`).
    func toggle(_ postID: PostID) {
        if let index = picked.firstIndex(of: postID) {
            picked.remove(at: index)
        } else if posts.contains(where: { $0.id == postID }) {
            picked.append(postID)
        } else {
            return
        }
        signals.emit(.select)
    }

    /// "Add" → `add_to_album`; a failure keeps the selection and says `week.edit.error.save`.
    func add() async {
        guard canAdd else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            _ = try await data.addToAlbum(id: albumID, groupID: groupID, postIDs: picked)
            isDone = true
        } catch {
            if SocialFailure(error) == .offline { isOffline = true }
            signals.emit(.failed)
            signals.post(.changesFailed)
        }
    }
}

/// `photo.viewer.layout.albumPicker` (Add to Album): "New Album" first, then the photo's group's albums, newest first.
/// A tap adds the photo (`add_to_album`); "New Album" saves a new album holding it (`save_album`).
@MainActor
@Observable
final class AlbumPickerModel {
    let groupID: GroupID
    let postID: PostID
    @ObservationIgnored private let data: any SocialDataSource

    private(set) var phase: SocialPhase = .loading
    private(set) var isOffline = false
    private(set) var albums: [AlbumWithItems] = []
    private(set) var covers: [PostID: PostWithMedia] = [:]
    private(set) var profiles: [UserID: Profile] = [:]
    private(set) var me: UserID?
    private(set) var isSaving = false
    /// The photo is in an album now: the sheet closes and the viewer confirms ("Added to Album!").
    private(set) var isDone = false
    private(set) var signals = SocialSignals()
    /// The "New Album" name sheet (`week.edit`'s).
    var isNaming = false
    var newName = ""
    /// `week.edit.error.albumName` under the field.
    private(set) var nameMissing = false

    init(groupID: GroupID, postID: PostID, data: any SocialDataSource) {
        self.groupID = groupID
        self.postID = postID
        self.data = data
    }

    func cover(of album: AlbumWithItems) -> PostWithMedia? {
        album.postIDs.first.flatMap { covers[$0] }
    }

    func savedByName(_ album: AlbumWithItems) -> String {
        album.album.createdBy.flatMap { profiles[$0]?.socialFirstName } ?? ""
    }

    /// `albums.list.row.subtitleMine`.
    func isMine(_ album: AlbumWithItems) -> Bool {
        me != nil && album.album.createdBy == me
    }

    func load() async {
        if me == nil { me = await data.currentUserID() }
        if albums.isEmpty, let cached = await data.cachedAlbums(groupID: groupID), !cached.isEmpty {
            albums = cached
            phase = .ready
        }
        do {
            albums = try await data.albums(groupID: groupID)
            isOffline = false
            phase = albums.isEmpty ? .empty : .ready
        } catch {
            if SocialFailure(error) == .offline { isOffline = true }
            if albums.isEmpty { phase = isOffline ? .offline : .failed }
        }
        let firstItems = albums.compactMap(\.postIDs.first).filter { covers[$0] == nil }
        if !firstItems.isEmpty, let found = try? await data.posts(ids: firstItems) {
            for post in found { covers[post.id] = post }
        }
        let people = albums.compactMap(\.album.createdBy).socialUnique().filter { profiles[$0] == nil }
        if !people.isEmpty, let found = try? await data.profiles(ids: people) {
            for profile in found { profiles[profile.id] = profile }
        }
    }

    func retry() async {
        phase = .loading
        await load()
    }

    /// A tap on an album row → `add_to_album` (a photo already there is skipped by the server).
    func add(to album: AlbumWithItems) async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            _ = try await data.addToAlbum(id: album.id, groupID: groupID, postIDs: [postID])
            isDone = true
        } catch {
            fail(error)
        }
    }

    func startNaming() {
        newName = ""
        nameMissing = false
        isNaming = true
    }

    /// "Create Album" in the name sheet → `save_album` with this photo.
    func createAlbum() async {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            nameMissing = true
            signals.emit(.failed)
            return
        }
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            _ = try await data.saveAlbum(groupID: groupID, name: name, postIDs: [postID])
            isNaming = false
            isDone = true
        } catch {
            if DataError.from(error).apiCode == .invalidName { nameMissing = true }
            fail(error)
        }
    }

    private func fail(_ error: Error) {
        if SocialFailure(error) == .offline { isOffline = true }
        signals.emit(.failed)
        signals.post(.changesFailed)
    }
}
