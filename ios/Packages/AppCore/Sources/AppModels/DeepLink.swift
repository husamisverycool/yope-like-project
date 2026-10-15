import Foundation

/// Every place the app can be opened into from outside: invite links, widget taps and
/// notification taps. `AppRouter` (App target) turns these into navigation state.
public enum DeepLink: Hashable, Sendable {
    /// `https://<domain>/i/<token>` — universal link / App Clip invocation.
    case invite(token: String)
    /// Widget tap: open straight into the camera, preselecting the widget's group when known.
    case camera(groupID: String?)
    /// A new post in a group.
    case post(groupID: String, postID: String)
    /// A chat message (text, photo or voice) in a group.
    case chatMessage(groupID: String, messageID: String)
    /// The daily same-moment invitation for a group.
    case dailyInvitation(groupID: String, invitationID: String)
    /// A group's weekly recap.
    case recap(groupID: String, recapID: String)
    /// A private request to contribute to someone's birthday tribute.
    case birthdayRequest(requestID: String, groupID: String?)
    /// A delivered birthday tribute.
    case tribute(tributeID: String, groupID: String?)
    /// A group's year story.
    case yearStory(groupID: String, year: Int)
}

/// Route names shared by custom-scheme URLs (`app://<route>?…`) and notification payloads
/// (`"route": "<route>"`). The worker sends exactly these strings.
public enum DeepLinkRoute: String, CaseIterable, Sendable {
    case camera
    case post
    case chatMessage = "chat_message"
    case dailyInvitation = "daily_invitation"
    case recap
    case birthdayRequest = "birthday_request"
    case tribute
    case yearStory = "year_story"
}

/// The identifiers a deep link carries. URLs use `queryName` (`app://camera?group=<id>`);
/// notification payloads use `payloadKey` (`"group_id": "<id>"`, matching the database columns).
public enum DeepLinkField: String, CaseIterable, Sendable {
    case group
    case post
    case message
    case invitation
    case recap
    case request
    case tribute
    case year

    public var queryName: String { rawValue }

    public var payloadKey: String {
        self == .year ? rawValue : rawValue + "_id"
    }
}

extension DeepLink {
    public var route: DeepLinkRoute? {
        switch self {
        case .invite: return nil
        case .camera: return .camera
        case .post: return .post
        case .chatMessage: return .chatMessage
        case .dailyInvitation: return .dailyInvitation
        case .recap: return .recap
        case .birthdayRequest: return .birthdayRequest
        case .tribute: return .tribute
        case .yearStory: return .yearStory
        }
    }

    /// Fields in a stable order, used for both URLs and payload dictionaries.
    public var fields: [(DeepLinkField, String)] {
        switch self {
        case .invite:
            return []
        case .camera(let groupID):
            return groupID.map { [(.group, $0)] } ?? []
        case .post(let groupID, let postID):
            return [(.group, groupID), (.post, postID)]
        case .chatMessage(let groupID, let messageID):
            return [(.group, groupID), (.message, messageID)]
        case .dailyInvitation(let groupID, let invitationID):
            return [(.group, groupID), (.invitation, invitationID)]
        case .recap(let groupID, let recapID):
            return [(.group, groupID), (.recap, recapID)]
        case .birthdayRequest(let requestID, let groupID):
            return [(.request, requestID)] + (groupID.map { [(.group, $0)] } ?? [])
        case .tribute(let tributeID, let groupID):
            return [(.tribute, tributeID)] + (groupID.map { [(.group, $0)] } ?? [])
        case .yearStory(let groupID, let year):
            return [(.group, groupID), (.year, String(year))]
        }
    }

    /// The group this link belongs to, when it names one.
    public var groupID: String? {
        switch self {
        case .invite: return nil
        case .camera(let groupID): return groupID
        case .post(let groupID, _), .chatMessage(let groupID, _), .dailyInvitation(let groupID, _),
             .recap(let groupID, _), .yearStory(let groupID, _):
            return groupID
        case .birthdayRequest(_, let groupID), .tribute(_, let groupID):
            return groupID
        }
    }
}
