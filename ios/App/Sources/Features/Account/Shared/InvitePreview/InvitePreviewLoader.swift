// Account group — the invite preview the App Clip and the installed app show before joining
// (invite.appclip "Data & actions"): `GET https://<domain>/i/<token>/preview.json` from the web service (images signed on
// its origin). HTTP 404 / 410 / 429 / 5xx map to the card states of design/surfaces/invite.appclip.md / invite.web.md.
// Without a configured domain the installed app reads the `invite_preview` RPC instead (storage paths, not URLs).
import AppData
import AppModels
import Foundation

/// `preview.json` (web/src/app.ts): `group_name`, `group_kind`, `inviter_first_name`, `inviter_avatar_url`,
/// `cover {url, width, height}`, `members [{first_name, avatar_url}]` in joining order.
struct WebInvitePreview: Decodable, Equatable, Sendable {
    struct Cover: Decodable, Equatable, Sendable {
        var url: URL
        var width: Double
        var height: Double
    }

    struct Member: Decodable, Equatable, Sendable {
        var firstName: String?
        var avatarURL: URL?
        /// The storage path when the preview came from the RPC (installed app without a web domain).
        var avatarPath: String? = nil

        enum CodingKeys: String, CodingKey {
            case firstName = "first_name"
            case avatarURL = "avatar_url"
        }
    }

    var groupName: String
    var groupKind: String?
    var inviterFirstName: String?
    /// The inviter's photo (signed on the web origin); nil without one.
    var inviterAvatarURL: URL?
    var cover: Cover?
    var members: [Member]
    /// The cover's storage path when the preview came from the RPC.
    var coverPath: String? = nil
    /// The inviter's avatar storage path when the preview came from the RPC (`inviter_avatar_path`).
    var inviterAvatarPath: String? = nil

    enum CodingKeys: String, CodingKey {
        case groupName = "group_name"
        case groupKind = "group_kind"
        case inviterFirstName = "inviter_first_name"
        case inviterAvatarURL = "inviter_avatar_url"
        case cover, members
    }
}

extension WebInvitePreview {
    /// The `invite_preview` RPC's answer (docs/API.md §6.1), with storage paths for the images.
    init(_ preview: InvitePreview) {
        self.init(
            groupName: preview.groupName,
            groupKind: preview.groupKind.rawValue,
            inviterFirstName: preview.inviterFirstName,
            inviterAvatarURL: nil,
            cover: nil,
            members: preview.members.map { Member(firstName: $0.firstName, avatarURL: nil, avatarPath: $0.avatarPath) },
            coverPath: preview.coverPath,
            inviterAvatarPath: preview.inviterAvatarPath
        )
    }

    /// The inviter among the members when the answer carries no inviter photo (an older web service): the one member
    /// whose first name is the inviter's; nil when there is no inviter name or the name is not unique.
    var inviterIndex: Int? {
        guard let name = inviterFirstName else { return nil }
        let matches = members.indices.filter { members[$0].firstName == name }
        return matches.count == 1 ? matches.first : nil
    }

    var coverSource: PhotoSource? {
        if let cover { return .url(cover.url) }
        return coverPath.map { PhotoSource.storage($0) }
    }

    func avatarSource(of index: Int) -> PhotoSource? {
        guard members.indices.contains(index) else { return nil }
        let member = members[index]
        if let url = member.avatarURL { return .url(url) }
        return member.avatarPath.map { PhotoSource.storage($0) }
    }

    /// The inviter's photo, when there is one: `inviter_avatar_url` / `inviter_avatar_path`, else the matching member's.
    var inviterAvatarSource: PhotoSource? {
        if let url = inviterAvatarURL { return .url(url) }
        if let path = inviterAvatarPath { return .storage(path) }
        return inviterIndex.flatMap { avatarSource(of: $0) }
    }

    /// The card's backdrop (invite.web Structure 1): the cover, else the inviter's photo, else none
    /// (`color.global.backgroundDeep`).
    var backdropSource: PhotoSource? {
        coverSource ?? inviterAvatarSource
    }
}

/// What the invite card shows.
enum InvitePreviewState: Equatable {
    case loading
    case valid(WebInvitePreview)
    /// 410: expired or revoked (one page for both).
    case unavailable
    /// 404, or a launch without a valid invite URL.
    case notFound
    /// 429.
    case rateLimited
    /// 5xx / unexpected answer.
    case error
    /// No connection.
    case offline
    /// `join_group` → `group_full`.
    case full
}

extension InvitePreviewState {
    /// The card for a failed `invite_preview` / `join_group` (docs/API.md §6.1, §9.3).
    static func state(for error: Error) -> InvitePreviewState {
        switch DataError.from(error) {
        case .api(.groupFull, _): return .full
        case .api(.inviteExpired, _), .api(.inviteRevoked, _): return .unavailable
        case .api(.inviteNotFound, _): return .notFound
        case .offline: return .offline
        default: return .error
        }
    }
}

/// The invite token of a URL the App Clip is opened with: the invite link itself (`https://<domain>/i/<token>`, Safari's
/// App Clip card and Messages) or the App Clip link the invite page's "Let's go" builds
/// (`https://appclip.apple.com/id?p=<bundle id>.Clip&token=<token>`, web/src/platform.ts `appClipUrl`).
enum InviteClipLink {
    static let appClipHost = "appclip.apple.com" // provenance-ok: Apple's App Clip link host, not user-facing
    static let tokenQueryItem = "token" // provenance-ok: query item name shared with web/src/platform.ts

    static func token(from url: URL, parser: DeepLinkParser) -> String? {
        if case let .invite(token)? = parser.parse(url) { return token }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.host?.lowercased() == appClipHost,
              let token = components.queryItems?.first(where: { $0.name == tokenQueryItem })?.value,
              DeepLinkParser.isValidToken(token) else { return nil }
        return token
    }
}

/// Loads `preview.json` for a token.
struct InvitePreviewLoader: Sendable {
    /// config/app.json `domain` (nil while BLOCKED: every load is an error).
    let domain: String?
    var session: URLSession = .shared

    func previewURL(token: String) -> URL? {
        guard let domain, !domain.isEmpty else { return nil }
        var components = URLComponents()
        components.scheme = "https"
        components.host = domain
        components.path = "/i/" + token + "/preview.json"
        return components.url
    }

    func load(token: String) async -> InvitePreviewState {
        guard let url = previewURL(token: token) else { return .error }
        do {
            let (data, response) = try await session.data(from: url)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            return Self.state(status: status, data: data)
        } catch let error as URLError where error.code != .cancelled {
            return [.notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost, .cannotConnectToHost, .dataNotAllowed]
                .contains(error.code) ? .offline : .error
        } catch {
            return .error
        }
    }

    static func state(status: Int, data: Data) -> InvitePreviewState {
        switch status {
        case 200:
            guard let preview = try? JSONDecoder().decode(WebInvitePreview.self, from: data) else { return .error }
            return .valid(preview)
        case 404: return .notFound
        case 410: return .unavailable
        case 429: return .rateLimited
        default: return .error
        }
    }
}
