import Foundation
import Supabase

/// Browsing and remembering (docs/API.md §5.13–5.15, §5.19, §6.4): walls, week history,
/// on this day, weekly recaps, albums, collages and year stories.
public struct MemoriesRepository: Sendable {
    public let client: DataClient
    private let cache: OfflineCache?

    public init(client: DataClient, cache: OfflineCache? = nil) {
        self.client = client
        self.cache = cache
    }

    // MARK: Walls

    /// `wall`: a person's photos as seen by the caller (shared groups only; one item per photo,
    /// plus collages containing one of their photos), newest first. The first page is cached.
    public func wall(userID: UserID, before: Date? = nil, limit: Int = 50) async throws -> Page<WallItem> {
        let items: [WallItem] = try await client.rpc("wall", [
            "p_user_id": .id(userID),
            "p_before": .timestamp(before),
            "p_limit": .integer(limit),
        ])
        if before == nil { await cache?.write(items, for: .wall(userID)) }
        return Page(items: items, nextCursor: items.count == limit ? items.last?.createdAt : nil)
    }

    public func cachedWall(userID: UserID) async -> CachedValue<[WallItem]>? {
        await cache?.read([WallItem].self, for: .wall(userID))
    }

    // MARK: Weeks

    /// `group_history_weeks`: weeks with posts, newest first; page with the last `weekStart`.
    public func historyWeeks(groupID: GroupID, beforeWeek: LocalDate? = nil, limit: Int = 8) async throws -> [HistoryWeek] {
        let weeks: [HistoryWeek] = try await client.rpc("group_history_weeks", [
            "p_group_id": .id(groupID),
            "p_before_week": .date(beforeWeek),
            "p_limit": .integer(limit),
        ])
        if beforeWeek == nil { await cache?.write(weeks, for: .history(groupID)) }
        return weeks
    }

    public func cachedHistoryWeeks(groupID: GroupID) async -> CachedValue<[HistoryWeek]>? {
        await cache?.read([HistoryWeek].self, for: .history(groupID))
    }

    /// `group_history_months` (migration 0045): the months of the group's history with the days that have something and
    /// the week each one jumps to (`historyWeeks(beforeWeek: newestWeek + 7)` starts with it), newest month first.
    public func historyMonths(groupID: GroupID) async throws -> [HistoryMonth] {
        try await client.rpc("group_history_months", ["p_group_id": .id(groupID)])
    }

    // MARK: Search

    /// `search_photos` (migration 0040): the photos you can see — in `groupID` or all your groups — matching every
    /// criterion given: `text` (caption or chat about the photo; each word a prefix), `memberID` (posted it or tagged
    /// themselves), the day taken in `from…to` (group-local, inclusive). Newest first; page with `before` = the last
    /// `createdAt`. At least one criterion (`invalid_argument` otherwise). No face or AI search.
    public func searchPhotos(
        text: String?, groupID: GroupID? = nil, memberID: UserID? = nil, from: LocalDate? = nil, to: LocalDate? = nil,
        before: Date? = nil, limit: Int = 60
    ) async throws -> [PhotoSearchHit] {
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        return try await client.rpc("search_photos", [
            "p_text": .text(trimmed?.isEmpty == false ? trimmed : nil),
            "p_group_id": .id(groupID),
            "p_member_id": .id(memberID),
            "p_from": .date(from),
            "p_to": .date(to),
            "p_before": .timestamp(before),
            "p_limit": .integer(limit),
        ])
    }

    /// `group_collages`: the group's ready same-moment collages whose day (group-local) is in `from…to`, newest first.
    public func groupCollages(groupID: GroupID, from: LocalDate? = nil, to: LocalDate? = nil) async throws -> [GroupCollage] {
        try await client.rpc("group_collages", [
            "p_group_id": .id(groupID),
            "p_from": .date(from),
            "p_to": .date(to),
        ])
    }

    /// `on_this_day`: posts from the same month and day in earlier years (group-local).
    /// `localDate` defaults to today in the group's zone.
    public func onThisDay(groupID: GroupID, localDate: LocalDate) async throws -> [OnThisDayItem] {
        try await client.rpc("on_this_day", ["p_group_id": .id(groupID), "p_local_date": .date(localDate)])
    }

    // MARK: Recaps

    /// The group's recaps, newest week first.
    public func recaps(groupID: GroupID, limit: Int = 12) async throws -> [WeeklyRecap] {
        try await client.rows(WeeklyRecap.self) {
            client.supabase.from("weekly_recaps").select()
                .eq("group_id", value: groupID.rawValue)
                .order("week_start", ascending: false)
                .limit(limit)
        }
    }

    public func recap(id: RecapID) async throws -> WeeklyRecap? {
        try await client.firstRow(WeeklyRecap.self) {
            client.supabase.from("weekly_recaps").select().eq("id", value: id.rawValue).limit(1)
        }
    }

    public func recap(groupID: GroupID, weekStart: LocalDate) async throws -> WeeklyRecap? {
        try await client.firstRow(WeeklyRecap.self) {
            client.supabase.from("weekly_recaps").select()
                .eq("group_id", value: groupID.rawValue)
                .eq("week_start", value: weekStart.description)
                .limit(1)
        }
    }

    /// `update_recap` (any member, once ready). `items` is the new order (nil = unchanged);
    /// `text` nil = unchanged, `""` clears it; `collageIDs` the new order of the recap's collages (nil = unchanged).
    public func updateRecap(id: RecapID, items: [PostID]? = nil, text: String? = nil, collageIDs: [CollageID]? = nil) async throws -> WeeklyRecap {
        var params: [String: AnyJSON] = [
            "p_recap_id": .id(id),
            "p_items": items.map(AnyJSON.ids) ?? .null,
            "p_text": .text(text),
        ]
        if let collageIDs { params["p_collage_ids"] = .array(collageIDs.map { .string($0.rawValue) }) }
        return try await client.rpc("update_recap", params)
    }

    // MARK: Albums

    /// The group's albums with their visible items in order. Cached for offline display.
    public func albums(groupID: GroupID) async throws -> [AlbumWithItems] {
        let albums = try await client.rows(Album.self) {
            client.supabase.from("albums").select()
                .eq("group_id", value: groupID.rawValue)
                .order("created_at", ascending: false)
        }
        let items = try await albumItems(albumIDs: albums.map(\.id))
        let grouped = Dictionary(grouping: items, by: \.albumID)
        let result = albums.map { album in
            AlbumWithItems(album: album, postIDs: (grouped[album.id] ?? []).sorted { $0.position < $1.position }.map(\.postID))
        }
        await cache?.write(result, for: .albums(groupID))
        return result
    }

    public func cachedAlbums(groupID: GroupID) async -> CachedValue<[AlbumWithItems]>? {
        await cache?.read([AlbumWithItems].self, for: .albums(groupID))
    }

    public func albumItems(albumIDs: [AlbumID]) async throws -> [AlbumItem] {
        guard !albumIDs.isEmpty else { return [] }
        return try await client.rows(AlbumItem.self) {
            client.supabase.from("album_items").select()
                .in("album_id", values: albumIDs.map(\.rawValue))
                .order("position", ascending: true)
        }
    }

    /// `save_album` (any member): distinct visible posts of the group, kept in this order.
    public func saveAlbum(groupID: GroupID, name: String, postIDs: [PostID]) async throws -> Album {
        let album: Album = try await client.rpc("save_album", [
            "p_group_id": .id(groupID),
            "p_name": .string(name),
            "p_post_ids": .ids(postIDs),
        ])
        await cache?.remove(.albums(groupID))
        return album
    }

    /// `rename_album` (any member).
    public func renameAlbum(id: AlbumID, name: String) async throws -> Album {
        try await client.rpc("rename_album", ["p_album_id": .id(id), "p_name": .string(name)])
    }

    /// `delete_album` (its creator or a group admin).
    public func deleteAlbum(id: AlbumID, groupID: GroupID) async throws {
        try await client.rpcVoid("delete_album", ["p_album_id": .id(id)])
        await cache?.update([AlbumWithItems].self, for: .albums(groupID)) { $0.removeAll { $0.album.id == id } }
    }

    // MARK: Collages

    /// The group's collages, newest first (show only `isReady` ones).
    public func collages(groupID: GroupID, before: Date? = nil, limit: Int = 30) async throws -> Page<Collage> {
        let collages = try await client.rows(Collage.self) {
            var query = client.supabase.from("collages").select().eq("group_id", value: groupID.rawValue)
            if let before { query = query.lt("created_at", value: Timestamp.format(before)) }
            return query.order("created_at", ascending: false).limit(limit)
        }
        return Page(items: collages, nextCursor: collages.count == limit ? collages.last?.createdAt : nil)
    }

    public func collage(id: CollageID) async throws -> Collage? {
        try await client.firstRow(Collage.self) {
            client.supabase.from("collages").select().eq("id", value: id.rawValue).limit(1)
        }
    }

    /// The collage of one daily invitation (nil until the worker created it).
    public func collage(invitationID: InvitationID) async throws -> Collage? {
        try await client.firstRow(Collage.self) {
            client.supabase.from("collages").select().eq("invitation_id", value: invitationID.rawValue).limit(1)
        }
    }

    /// The collage(s) of a group-local day (via that day's daily invitation).
    public func collages(groupID: GroupID, localDate: LocalDate) async throws -> [Collage] {
        let invitations = try await client.rows(DailyInvitation.self) {
            client.supabase.from("daily_invitations").select()
                .eq("group_id", value: groupID.rawValue)
                .eq("local_date", value: localDate.description)
        }
        guard !invitations.isEmpty else { return [] }
        return try await client.rows(Collage.self) {
            client.supabase.from("collages").select()
                .in("invitation_id", values: invitations.map(\.id.rawValue))
                .order("created_at", ascending: false)
        }
    }

    // MARK: Year stories

    public func yearStories(groupID: GroupID) async throws -> [YearStory] {
        try await client.rows(YearStory.self) {
            client.supabase.from("year_stories").select()
                .eq("group_id", value: groupID.rawValue)
                .order("year", ascending: false)
        }
    }

    public func yearStory(groupID: GroupID, year: Int) async throws -> YearStory? {
        try await client.firstRow(YearStory.self) {
            client.supabase.from("year_stories").select()
                .eq("group_id", value: groupID.rawValue)
                .eq("year", value: year)
                .limit(1)
        }
    }
}
