import AppModels
import Foundation

/// The app's own writes to the widgets (docs/WIDGET_REFRESH.md "The app itself"). Pushes alone left a newly added widget
/// or a newly joined group on "No photos yet" although the group had photos, and people without a push token never got
/// an update: whenever the app loads its groups (sign-in, a joined or left group, each return to the foreground) or a
/// group's feed, it writes each group's newest photo it may see and newest ready same-moment collage into the App
/// Group's `WidgetStore`, downloading the widget rendition exactly as the Notification Service Extension does
/// (`WidgetDelivery`). Nothing is downloaded again for an item the store already shows; a group with no photo left loses
/// its photo snapshot. The caller reloads widget timelines when something changed (unbudgeted while the app is in the
/// foreground, docs/PLATFORM_CONSTRAINTS.md §1.1).
public struct WidgetContentSync: Sendable {
    public typealias Download = WidgetDelivery.Download

    /// Collages looked at per group for the newest ready one (a new day's collage is pending until its window closes).
    static let recentCollages = 5

    let posts: PostRepository
    let memories: MemoriesRepository
    let profiles: ProfileRepository
    let signedURLs: SignedURLCache
    let store: WidgetStore
    let download: Download
    /// The friend and memories widgets' functions (nil: those widgets are not filled, e.g. in tests of the group path).
    let widgets: WidgetRepository?

    /// Days of memories stored ahead (today included): the widget turns over at midnight without the app for a week
    /// (`widget.memories.layout.content`; an engineering bound, one rendition a day).
    public static let memoryDays = 7

    public init(
        posts: PostRepository, memories: MemoriesRepository, profiles: ProfileRepository, signedURLs: SignedURLCache,
        store: WidgetStore, download: @escaping Download, widgets: WidgetRepository? = nil
    ) {
        self.posts = posts
        self.memories = memories
        self.profiles = profiles
        self.signedURLs = signedURLs
        self.store = store
        self.download = download
        self.widgets = widgets
    }

    /// Brings `group`'s photo and collage snapshots up to date. Returns whether a snapshot changed. Failures (offline,
    /// a rendition not made yet) leave the store as it was.
    public func sync(_ group: PhotoGroup, now: Date = Date()) async -> Bool {
        let photo = await syncPhoto(group, now: now)
        let collage = await syncCollage(group, now: now)
        return photo || collage
    }

    private func syncPhoto(_ group: PhotoGroup, now: Date) async -> Bool {
        guard let page = try? await posts.page(groupID: group.id, limit: 1) else { return false }
        guard let post = page.items.first else {
            // Nothing left to show (every photo deleted, or none yet): the widget shows its empty state.
            guard let shown = store.snapshot(groupID: group.id.rawValue, kind: .photo)?.sourceID else { return false }
            return (try? store.removeSource(shown)) ?? false
        }
        guard !isShown(post.id.rawValue, kind: .photo, groupID: group.id) else { return false }
        guard let media = try? await posts.media(ids: [post.mediaID]).first, let widgetPath = media.widgetPath,
              let rendition = try? await signedURLs.url(for: widgetPath) else { return false }
        let author = try? await profiles.profiles(ids: [post.authorID]).first
        var avatar: URL?
        if let path = author?.avatarPath { avatar = try? await signedURLs.url(for: path) }
        let sender = author.map { WidgetPushPayload.Sender(displayName: $0.displayName.isEmpty ? nil : $0.displayName, avatarURL: avatar) }
        let payload = WidgetPushPayload(
            groupID: group.id.rawValue, sourceID: post.id.rawValue, renditionURL: rendition, sender: sender,
            caption: post.caption, kind: .photo, groupName: group.name, postedAt: post.createdAt
        )
        return (try? await WidgetDelivery(store: store, download: download).deliver(payload, receivedAt: now)) != nil
    }

    private func syncCollage(_ group: PhotoGroup, now: Date) async -> Bool {
        guard let page = try? await memories.collages(groupID: group.id, limit: Self.recentCollages),
              let collage = page.items.first(where: { $0.status == .ready && $0.widgetPath != nil }),
              let widgetPath = collage.widgetPath,
              !isShown(collage.id.rawValue, kind: .collage, groupID: group.id),
              let rendition = try? await signedURLs.url(for: widgetPath) else { return false }
        let payload = WidgetPushPayload(
            groupID: group.id.rawValue, sourceID: collage.id.rawValue, renditionURL: rendition, kind: .collage,
            groupName: group.name, postedAt: collage.composedAt ?? collage.createdAt
        )
        return (try? await WidgetDelivery(store: store, download: download).deliver(payload, receivedAt: now)) != nil
    }

    // MARK: Friend and memories widgets (design/surfaces/widget.friend.md, widget.memories.md)

    /// The friend widget's picker (`widget_people`): everyone who shares a group with the person, minus blocks; someone
    /// no longer listed leaves the friend widgets. Returns whether the list changed.
    public func syncPeople() async -> Bool {
        guard let widgets, let rows = try? await widgets.people() else { return false }
        let people = rows.map { WidgetPerson(id: $0.userID.rawValue, name: $0.displayName) }
        guard !store.hasPeopleList || store.people() != people else { return false }
        return (try? store.syncPeople(people)) != nil
    }

    /// Each friend a placed widget follows gets their newest photo the person may see (`newest_photos_of`): their own
    /// posts and the photos they tagged themselves in. Self-tags send no push, so this is how they reach the widget.
    /// Offline or failed look-ups leave the store as it was. Returns whether a friend widget changed.
    public func syncFriends(now: Date = Date()) async -> Bool {
        guard let widgets else { return false }
        var changed = false
        for personID in store.watchedPeople(now: now).sorted() {
            guard let photos = try? await widgets.newestPhotos(of: UserID(personID)) else { continue }
            guard let photo = photos.first(where: { $0.widgetPath != nil }), let widgetPath = photo.widgetPath else {
                // Nothing the person may see (yet, or any more: deleted, a block, no shared group): the empty state.
                if photos.isEmpty, store.personSnapshot(personID: personID) != nil || !store.isPersonLookedUp(personID: personID) {
                    changed = ((try? store.removePersonSnapshot(personID: personID)) != nil) || changed
                }
                continue
            }
            if store.personSnapshot(personID: personID)?.sourceID == photo.postID.rawValue { continue }
            guard let renditionURL = try? await signedURLs.url(for: widgetPath),
                  let bytes = try? await download(renditionURL) else { continue }
            var avatar: Data?
            var avatarName: String?
            if let path = photo.authorAvatarPath, let url = try? await signedURLs.url(for: path), let data = try? await download(url) {
                avatar = data
                avatarName = "avatar-\(photo.postID.rawValue).\(WidgetPushPayload.imageExtension(url))"
            }
            let snapshot = WidgetSnapshot(
                groupID: photo.groupID.rawValue, groupName: photo.groupName, sourceID: photo.postID.rawValue,
                photoFileName: "photo-\(photo.postID.rawValue).\(WidgetPushPayload.imageExtension(renditionURL))",
                senderID: photo.authorID.rawValue, senderDisplayName: photo.authorName.isEmpty ? nil : photo.authorName,
                senderAvatarFileName: avatarName, caption: photo.caption, kind: .photo, postedAt: photo.visibleAt
            )
            if (try? store.savePerson(snapshot, personID: personID, photo: bytes, avatar: avatar)) != nil { changed = true }
        }
        return changed
    }

    /// The person's own memories for today and the next days (`my_memories`, the device's zone), when a memories widget
    /// is placed. Days without a memory are recorded as such (the widget's empty state); a memory whose rendition is
    /// not made shows as none rather than as another photo. A failed download keeps the stored days. Returns whether the
    /// store changed.
    public func syncMemories(now: Date = Date(), calendar: Calendar = .current) async -> Bool {
        guard let widgets, store.watchesMemories(now: now) else { return false }
        let today = LocalDate(now, in: calendar.timeZone)
        guard let rows = try? await widgets.memories(from: today, days: Self.memoryDays, timeZone: calendar.timeZone) else { return false }
        var memories: [String: WidgetSnapshot] = [:]
        var photos: [String: Data] = [:]
        for row in rows {
            guard let widgetPath = row.widgetPath else { continue }
            let day = row.day.description
            let snapshot = WidgetSnapshot(
                groupID: row.groupID.rawValue, groupName: row.groupName, sourceID: row.postID.rawValue,
                photoFileName: "memory-\(row.postID.rawValue).jpg", senderID: row.authorID.rawValue,
                senderDisplayName: row.authorName.isEmpty ? nil : row.authorName, kind: .photo, postedAt: row.takenAt
            )
            if store.hasMemory(day: day, sourceID: row.postID.rawValue) || photos[snapshot.photoFileName] != nil {
                memories[day] = snapshot
                continue
            }
            guard let url = try? await signedURLs.url(for: widgetPath), let bytes = try? await download(url) else { return false }
            memories[day] = snapshot
            photos[snapshot.photoFileName] = bytes
        }
        let through = today.adding(days: Self.memoryDays - 1)
        return (try? store.replaceMemories(days: today.description...through.description, memories: memories, photos: photos)) != nil
    }

    /// The store already shows `sourceID` as the group's `kind` snapshot, with its rendition on disk.
    private func isShown(_ sourceID: String, kind: WidgetSnapshot.Kind, groupID: GroupID) -> Bool {
        guard let snapshot = store.snapshot(groupID: groupID.rawValue, kind: kind), snapshot.sourceID == sourceID else { return false }
        return store.photoURL(for: snapshot) != nil
    }
}
