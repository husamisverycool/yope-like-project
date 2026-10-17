import Foundation

/// What a group's widget shows: the newest photo, or the day's same-moment collage.
/// Written by the Notification Service Extension (or the app), read by the widget's timeline provider.
public struct WidgetSnapshot: Codable, Hashable, Sendable {
    public enum Kind: String, Codable, Hashable, Sendable, CaseIterable {
        case photo
        case collage
    }

    public var groupID: String
    public var groupName: String?
    /// The post or collage the rendition shows; used to remove it when that is deleted.
    public var sourceID: String?
    /// File name of the widget rendition inside the group's folder in `WidgetStore`.
    public var photoFileName: String
    /// The poster's user id (a photo), when known: friend widgets keep the photos of the person they follow.
    public var senderID: String?
    public var senderDisplayName: String?
    /// File name of the sender's avatar inside the group's folder, when one was delivered.
    public var senderAvatarFileName: String?
    public var caption: String?
    public var kind: Kind
    public var postedAt: Date

    public init(
        groupID: String,
        groupName: String? = nil,
        sourceID: String?,
        photoFileName: String,
        senderID: String? = nil,
        senderDisplayName: String? = nil,
        senderAvatarFileName: String? = nil,
        caption: String? = nil,
        kind: Kind,
        postedAt: Date
    ) {
        self.groupID = groupID
        self.groupName = groupName
        self.sourceID = sourceID
        self.photoFileName = photoFileName
        self.senderID = senderID
        self.senderDisplayName = senderDisplayName
        self.senderAvatarFileName = senderAvatarFileName
        self.caption = caption
        self.kind = kind
        self.postedAt = postedAt
    }

    enum CodingKeys: String, CodingKey {
        case groupID = "group_id"
        case groupName = "group_name"
        case sourceID = "source_id"
        case photoFileName = "photo_file"
        case senderID = "sender_id"
        case senderDisplayName = "sender_name"
        case senderAvatarFileName = "sender_avatar_file"
        case caption
        case kind
        case postedAt = "posted_at"
    }
}

/// A group the user belongs to, as listed in the widget's "choose group" configuration.
/// The app writes the list whenever its groups change.
public struct WidgetGroup: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

/// Identifiers shared by the app and its extensions.
public enum WidgetKind {
    /// `AppIntentConfiguration` kind of the per-group Home Screen photo widget.
    public static let groupPhoto = "GroupPhotoWidget"
    /// Kind of the per-group Lock Screen widget (its own gallery entry, `widget.lock.*`).
    public static let groupPhotoLock = "GroupPhotoLockWidget"
    /// The friend widget (`widget.friend`): one person's newest photo.
    public static let friendPhoto = "FriendPhotoWidget"
    /// The memories widget (`widget.memories`): the person's own photo from this day in an earlier year.
    public static let memories = "MemoriesWidget"
    /// Every kind that shows group photos; reload all of them when a photo arrives or is deleted.
    public static let allGroupPhoto = [groupPhoto, groupPhotoLock, friendPhoto, memories]
}

public enum AppGroup {
    /// Info.plist key holding the App Group identifier (`group.$(APP_BUNDLE_ID)`), set in each
    /// target's Info.plist from the `APP_GROUP_ID` build setting.
    public static let infoPlistKey = "AppGroupIdentifier"

    public static func identifier(in bundle: Bundle) -> String? {
        guard let value = bundle.object(forInfoDictionaryKey: infoPlistKey) as? String,
              !value.isEmpty, !value.contains("$(") else { return nil }
        return value
    }
}
