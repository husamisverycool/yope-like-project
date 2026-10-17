import Foundation

/// A database enum decoded leniently: a value added on the server later decodes as `unknown`
/// instead of failing the whole page (docs/API.md §4).
public protocol LenientEnum: RawRepresentable, Codable, Hashable, Sendable, CaseIterable where RawValue == String {
    static var unknownCase: Self { get }
}

extension LenientEnum {
    public init(from decoder: Decoder) throws {
        let text = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: text) ?? Self.unknownCase
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// `group_kind`
public enum GroupKind: String, LenientEnum {
    case friends, family, roommates, custom
    case unknown
    public static var unknownCase: GroupKind { .unknown }
}

/// `member_role`
public enum MemberRole: String, LenientEnum {
    case admin, member
    case unknown
    public static var unknownCase: MemberRole { .unknown }
}

/// `media_kind`
public enum MediaKind: String, LenientEnum {
    case photo
    case livePhoto = "live_photo"
    case video
    case unknown
    public static var unknownCase: MediaKind { .unknown }
}

/// `message_kind`
public enum MessageKind: String, LenientEnum {
    case text, photo, voice
    /// The chat's "{name} joined" / "{name} left the group" lines (migration 0042): `author_id` is the person, `body`
    /// their display name at that moment. Written by the server only; no menu, never unsent.
    case joined, left
    case unknown
    public static var unknownCase: MessageKind { .unknown }

    /// A joined / left line rather than something someone said.
    public var isSystemLine: Bool { self == .joined || self == .left }
}

/// `device_platform`
public enum DevicePlatform: String, LenientEnum {
    case ios, android
    case unknown
    public static var unknownCase: DevicePlatform { .unknown }
}

/// `invitation_status` (set by the worker; use the timestamps for UI state, docs/API.md §5.12).
public enum InvitationStatus: String, LenientEnum {
    case scheduled, fired, closed, cancelled
    case unknown
    public static var unknownCase: InvitationStatus { .unknown }
}

/// `render_status`
public enum RenderStatus: String, LenientEnum {
    case pending, ready, failed
    case unknown
    public static var unknownCase: RenderStatus { .unknown }
}

/// `report_target_kind`
public enum ReportTargetKind: String, LenientEnum {
    case post, message, user, group
    /// A selfie reaction, by its `selfie_reactions.id` (docs/API.md §14.1).
    case selfie
    /// Another member's plan, by `plans.id` (migration 0032).
    case plan
    /// A birthday video you can watch, by `tributes.id` (0032).
    case tribute
    /// A group's year story, by `year_stories.id` (0032).
    case yearStory = "year_story"
    /// A same-moment collage, by `collages.id` (0032).
    case collage
    /// A weekly recap, by `weekly_recaps.id` (0032).
    case recap
    case unknown
    public static var unknownCase: ReportTargetKind { .unknown }
}

/// A JSON value owned by another component (e.g. `year_stories.data`, written by the worker).
public enum JSONValue: Codable, Hashable, Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: JSONValue].self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case let .bool(value): try container.encode(value)
        case let .number(value): try container.encode(value)
        case let .string(value): try container.encode(value)
        case let .array(value): try container.encode(value)
        case let .object(value): try container.encode(value)
        }
    }

    public subscript(key: String) -> JSONValue? {
        if case let .object(object) = self { return object[key] }
        return nil
    }

    public var intValue: Int? {
        if case let .number(value) = self, value.rounded() == value { return Int(value) }
        return nil
    }

    public var stringValue: String? {
        if case let .string(value) = self { return value }
        return nil
    }
}
