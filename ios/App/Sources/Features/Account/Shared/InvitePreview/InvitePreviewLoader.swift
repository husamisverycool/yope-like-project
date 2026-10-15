// Account group — the invite preview the App Clip and the installed app show before joining
// (invite.appclip "Data & actions" 2): `GET https://<domain>/i/<token>/preview.json` from the web service (images on its
// origin, re-encoded; theme = mean colour of the cover). HTTP 404 / 410 / 429 / 5xx map to the states of
// design/surfaces/invite.appclip.md.
import Foundation

/// `preview.json`.
struct WebInvitePreview: Decodable, Equatable, Sendable {
    struct Cover: Decodable, Equatable, Sendable {
        var url: URL
        var width: Double
        var height: Double
    }

    struct Member: Decodable, Equatable, Sendable {
        var firstName: String?
        var avatarURL: URL?

        enum CodingKeys: String, CodingKey {
            case firstName = "first_name"
            case avatarURL = "avatar_url"
        }
    }

    struct Theme: Decodable, Equatable, Sendable {
        /// "#RRGGBB"
        var background: String
        /// "light" (black text) or "dark" (white text).
        var scheme: String
    }

    var groupName: String
    var groupKind: String?
    var inviterFirstName: String?
    var cover: Cover?
    var members: [Member]
    var theme: Theme?

    enum CodingKeys: String, CodingKey {
        case groupName = "group_name"
        case groupKind = "group_kind"
        case inviterFirstName = "inviter_first_name"
        case cover, members, theme
    }
}

/// What the preview area shows.
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
