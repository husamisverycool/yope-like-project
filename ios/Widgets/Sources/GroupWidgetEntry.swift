// Surfaces: widget.home.small / .medium / .large / .xl, widget.lock.rect / .circular / .inline,
// widget.arrival, camera.fromwidget — reference app: Locket (design/surfaces/widget.*.md).
// The timeline entry and how it is resolved from the App Group store (no network, no App Intents
// types, so AppTests exercises it directly).
import AppModels
import Foundation
import UIKit
import WidgetKit

/// Kinds of this extension. The Home Screen kind keeps the shared `WidgetKind.groupPhoto` that the
/// app and the Notification Service Extension reload.
enum GroupWidgetKinds {
    static let home = WidgetKind.groupPhoto
    static let lockScreen = WidgetKind.groupPhotoLock
    static let all = WidgetKind.allGroupPhoto
}

struct GroupPhotoEntry: TimelineEntry {
    let date: Date
    /// The configured group, or the group of the newest photo when none is configured.
    let groupID: String?
    let state: GroupWidgetContent.State
    let snapshot: WidgetSnapshot?
    let photoURL: URL?
    let avatarURL: URL?

    static func loading(at date: Date) -> GroupPhotoEntry {
        GroupPhotoEntry(date: date, groupID: nil, state: .loading, snapshot: nil, photoURL: nil, avatarURL: nil)
    }

    /// Tapping opens the camera for this group (`camera.fromwidget`).
    var tapURL: URL? {
        DeepLinkParser(universalLinkHosts: []).url(for: .camera(groupID: groupID))
    }

    /// The view content; images are read from the App Group files (no network).
    var content: GroupWidgetContent {
        GroupWidgetContent(
            state: state,
            groupName: snapshot?.groupName,
            senderName: snapshot?.senderDisplayName,
            caption: snapshot?.caption,
            postedAt: snapshot?.postedAt,
            photo: photoURL.flatMap { UIImage(contentsOfFile: $0.path) },
            avatar: avatarURL.flatMap { UIImage(contentsOfFile: $0.path) }
        )
    }
}

enum GroupWidgetEntryResolver {
    /// Lock Screen widgets (`widget.lock.rect.layout.content`): always the newest single photo's sender
    /// (avatar, and its caption if any) — when the newest item is a collage, the newest photo before it.
    static func lockScreenEntry(configuredGroupID: String?, store: WidgetStore, at date: Date) -> GroupPhotoEntry {
        let groups = store.groups()
        let snapshot: WidgetSnapshot?
        let groupID: String?
        if let configuredGroupID {
            guard groups.contains(where: { $0.id == configuredGroupID }) else {
                return GroupPhotoEntry(date: date, groupID: nil, state: .notSetUp, snapshot: nil, photoURL: nil, avatarURL: nil)
            }
            groupID = configuredGroupID
            snapshot = store.snapshot(groupID: configuredGroupID, kind: .photo)
        } else {
            guard !groups.isEmpty else {
                return GroupPhotoEntry(date: date, groupID: nil, state: .notSetUp, snapshot: nil, photoURL: nil, avatarURL: nil)
            }
            snapshot = groups.compactMap { store.snapshot(groupID: $0.id, kind: .photo) }.max { $0.postedAt < $1.postedAt }
            groupID = snapshot?.groupID ?? groups.first?.id
        }
        guard let snapshot else {
            return GroupPhotoEntry(date: date, groupID: groupID, state: .empty, snapshot: nil, photoURL: nil, avatarURL: nil)
        }
        var named = snapshot
        if named.groupName == nil { named.groupName = groups.first { $0.id == snapshot.groupID }?.name }
        return GroupPhotoEntry(
            date: date,
            groupID: groupID,
            state: .photo,
            snapshot: named,
            photoURL: nil,
            avatarURL: store.avatarURL(for: snapshot)
        )
    }

    /// - not set up: no group (none chosen, left, deleted, signed out: the app's group list lacks it);
    /// - empty: the configured group has no photo yet;
    /// - photo / collage: the newest item. Muted groups still update.
    static func entry(configuredGroupID: String?, store: WidgetStore, at date: Date) -> GroupPhotoEntry {
        let groups = store.groups()
        let snapshot: WidgetSnapshot?
        let groupID: String?
        if let configuredGroupID {
            guard groups.contains(where: { $0.id == configuredGroupID }) else {
                return GroupPhotoEntry(date: date, groupID: nil, state: .notSetUp, snapshot: nil, photoURL: nil, avatarURL: nil)
            }
            groupID = configuredGroupID
            snapshot = store.latestSnapshot(groupID: configuredGroupID)
        } else {
            guard !groups.isEmpty else {
                return GroupPhotoEntry(date: date, groupID: nil, state: .notSetUp, snapshot: nil, photoURL: nil, avatarURL: nil)
            }
            snapshot = store.latestSnapshot()
            groupID = snapshot?.groupID ?? groups.first?.id
        }
        guard let snapshot else {
            return GroupPhotoEntry(date: date, groupID: groupID, state: .empty, snapshot: nil, photoURL: nil, avatarURL: nil)
        }
        var named = snapshot
        if named.groupName == nil { named.groupName = groups.first { $0.id == snapshot.groupID }?.name }
        return GroupPhotoEntry(
            date: date,
            groupID: groupID,
            state: snapshot.kind == .collage ? .collage : .photo,
            snapshot: named,
            photoURL: store.photoURL(for: snapshot),
            avatarURL: store.avatarURL(for: snapshot)
        )
    }
}
