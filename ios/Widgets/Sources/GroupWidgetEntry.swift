// Surfaces: widget.home.small / .medium / .large / .xl, widget.lock.rect / .circular / .inline, widget.arrival,
// camera.fromwidget — visual reference Retro's Glance widgets, mechanics Locket (design/surfaces/widget.*.md; RC-9 …
// RC-11). Reference images: references/auto/retro/apk/widget_preview_journals.webp,
// references/auto/locket/store/locket-store-03.png (newest photo of one group, tap → camera).
// The timeline entry and how it is resolved from the App Group store (no network, no App Intents types, so AppTests
// exercises it directly).
import AppModels
import Foundation
import UIKit
import WidgetKit

/// Kinds of this extension. The Home Screen kind keeps the shared `WidgetKind.groupPhoto` that the app and the
/// Notification Service Extension reload.
enum GroupWidgetKinds {
    static let home = WidgetKind.groupPhoto
    static let lockScreen = WidgetKind.groupPhotoLock
    static let all = WidgetKind.allGroupPhoto
}

struct GroupPhotoEntry: TimelineEntry {
    let date: Date
    /// The configured group, or the group of the newest item when none is configured.
    let groupID: String?
    let state: GroupWidgetContent.State
    let snapshot: WidgetSnapshot?
    let photoURL: URL?
    let avatarURL: URL?

    static func loading(at date: Date) -> GroupPhotoEntry {
        GroupPhotoEntry(date: date, groupID: nil, state: .loading, snapshot: nil, photoURL: nil, avatarURL: nil)
    }

    static func state(_ state: GroupWidgetContent.State, groupID: String? = nil, at date: Date) -> GroupPhotoEntry {
        GroupPhotoEntry(date: date, groupID: groupID, state: state, snapshot: nil, photoURL: nil, avatarURL: nil)
    }

    /// Tapping opens the camera for this group (`camera.fromwidget`: `app://camera?group=<id>`; no id → no preselection).
    var tapURL: URL? {
        DeepLinkParser(universalLinkHosts: []).url(for: .camera(groupID: groupID))
    }

    /// The view content; images are read from the App Group files (no network).
    var content: GroupWidgetContent {
        GroupWidgetContent(
            state: state,
            groupName: snapshot?.groupName,
            senderName: snapshot?.senderDisplayName,
            postedAt: snapshot?.postedAt,
            photo: photoURL.flatMap { UIImage(contentsOfFile: $0.path) },
            avatar: avatarURL.flatMap { UIImage(contentsOfFile: $0.path) }
        )
    }
}

enum GroupWidgetEntryResolver {
    /// - signed out: the app wrote no group list on this device (sign-out removes the store);
    /// - not set up: no group (none chosen, left or deleted: the app's group list lacks it);
    /// - empty: the configured group has no photo yet;
    /// - photo / collage: the newest item. Muted groups still update.
    ///
    /// `includesPhoto` false (Lock Screen kinds, vibrant: no colour photo — PLATFORM_CONSTRAINTS) skips the rendition.
    static func entry(configuredGroupID: String?, store: WidgetStore, at date: Date, includesPhoto: Bool = true) -> GroupPhotoEntry {
        guard store.hasGroupList else { return .state(.signedOut, at: date) }
        let groups = store.groups()
        let snapshot: WidgetSnapshot?
        let groupID: String?
        if let configuredGroupID {
            guard groups.contains(where: { $0.id == configuredGroupID }) else { return .state(.notSetUp, at: date) }
            groupID = configuredGroupID
            snapshot = store.latestSnapshot(groupID: configuredGroupID)
        } else {
            guard !groups.isEmpty else { return .state(.notSetUp, at: date) }
            snapshot = store.latestSnapshot()
            groupID = snapshot?.groupID ?? groups.first?.id
        }
        guard let snapshot else { return .state(.empty, groupID: groupID, at: date) }
        var named = snapshot
        if named.groupName == nil { named.groupName = groups.first { $0.id == snapshot.groupID }?.name }
        return GroupPhotoEntry(
            date: date,
            groupID: groupID,
            state: snapshot.kind == .collage ? .collage : .photo,
            snapshot: named,
            photoURL: includesPhoto ? store.photoURL(for: snapshot) : nil,
            avatarURL: snapshot.kind == .photo ? store.avatarURL(for: snapshot) : nil
        )
    }

    /// The Lock Screen kinds (`widget.lock.rect.layout.content`): the same newest item — a collage shows the group name
    /// (rectangular, inline) or the camera glyph (circular).
    static func lockScreenEntry(configuredGroupID: String?, store: WidgetStore, at date: Date) -> GroupPhotoEntry {
        entry(configuredGroupID: configuredGroupID, store: store, at: date, includesPhoto: false)
    }
}

extension WidgetStore {
    /// Whether the app has written its group list (`groups.json` in the store's layout, AppModels `WidgetStore`): the app
    /// writes it after sign-in, even when empty, and sign-out removes the whole store.
    var hasGroupList: Bool {
        FileManager.default.fileExists(atPath: rootURL.appendingPathComponent("groups.json").path)
    }
}
