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

    public init(
        posts: PostRepository, memories: MemoriesRepository, profiles: ProfileRepository, signedURLs: SignedURLCache,
        store: WidgetStore, download: @escaping Download
    ) {
        self.posts = posts
        self.memories = memories
        self.profiles = profiles
        self.signedURLs = signedURLs
        self.store = store
        self.download = download
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

    /// The store already shows `sourceID` as the group's `kind` snapshot, with its rendition on disk.
    private func isShown(_ sourceID: String, kind: WidgetSnapshot.Kind, groupID: GroupID) -> Bool {
        guard let snapshot = store.snapshot(groupID: groupID.rawValue, kind: kind), snapshot.sourceID == sourceID else { return false }
        return store.photoURL(for: snapshot) != nil
    }
}
