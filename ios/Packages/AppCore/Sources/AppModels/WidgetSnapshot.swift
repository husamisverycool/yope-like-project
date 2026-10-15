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
    /// `AppIntentConfiguration` kind of the per-group photo widget (home and lock screen).
    public static let groupPhoto = "GroupPhotoWidget"
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
