import Foundation

/// Parses URLs and notification payloads into `DeepLink`s, and builds URLs back.
///
/// Accepted forms:
/// - `https://<domain>/i/<token>` for each configured universal-link host (invites, App Clip).
/// - `<customScheme>://<route>?<field>=<id>…`, e.g. `app://camera?group=<id>` from widgets,
///   `app://plan?plan=<id>&group=<id>` from the countdown widget (Android `DeepLink.Plan`, same format).
/// - Notification `userInfo`: a `link` URL, or `type` (`PushType`) with `<field>_id` keys.
///
/// Identifiers are accepted only when they consist of URL-safe characters, so a crafted link
/// cannot carry path separators or query syntax into the app.
///
/// The custom scheme is not registered (no `CFBundleURLTypes`), so no other app or web page can open it: widget and Live
/// Activity taps reach the app without a registration ("the system activates the containing app and passes the URL to
/// onOpenURL", Apple, "Linking to specific app scenes from your widget or Live Activity"), and notification taps are
/// parsed from their payload (`parse(notificationPayload:)`). Android matches: `app://` links are explicit intents
/// (`android/core/links` `AppLinks`). Register an app-specific scheme only when something outside the app must open
/// one (e.g. a Control Center control's `OpenURLIntent`).
public struct DeepLinkParser: Sendable {
    public static let defaultCustomScheme = "app"
    public static let invitePathPrefix = "i"

    public let universalLinkHosts: Set<String>
    public let customScheme: String

    public init(universalLinkHosts: Set<String>, customScheme: String = DeepLinkParser.defaultCustomScheme) {
        self.universalLinkHosts = Set(universalLinkHosts.map { $0.lowercased() })
        self.customScheme = customScheme.lowercased()
    }

    /// Hosts come from `config/app.json` → `domain`; a missing (BLOCKED) domain accepts no universal links.
    public init(configuration: AppConfiguration, customScheme: String = DeepLinkParser.defaultCustomScheme) {
        self.init(universalLinkHosts: configuration.domain.map { [$0] } ?? [], customScheme: customScheme)
    }

    // MARK: URLs

    public func parse(_ url: URL) -> DeepLink? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = components.scheme?.lowercased() else { return nil }
        if scheme == "https" {
            return parseUniversalLink(components)
        }
        if scheme == customScheme {
            return parseCustomScheme(components)
        }
        return nil
    }

    private func parseUniversalLink(_ components: URLComponents) -> DeepLink? {
        guard let host = components.host?.lowercased(), universalLinkHosts.contains(host) else { return nil }
        let segments = components.path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        guard segments.count == 2, segments[0] == Self.invitePathPrefix else { return nil }
        let token = segments[1]
        guard Self.isValidToken(token) else { return nil }
        return .invite(token: token)
    }

    private func parseCustomScheme(_ components: URLComponents) -> DeepLink? {
        // `app://camera?…` puts the route in the host; `app:camera?…` / `app:///camera` in the path.
        let host = components.host.flatMap { $0.isEmpty ? nil : $0 }
        let routeName = host ?? components.path.split(separator: "/").first.map(String.init)
        guard let routeName, let route = DeepLinkRoute(rawValue: routeName.lowercased()) else { return nil }
        var values: [String: String] = [:]
        for item in components.queryItems ?? [] {
            guard let field = DeepLinkField(rawValue: item.name), let value = item.value else { continue }
            values[field.rawValue] = value
        }
        if route == .premium {
            // The destination is read from the same fields; it is never itself a premium link.
            guard let perk = values[DeepLinkField.perk.rawValue], Self.isValidIdentifier(perk) else { return nil }
            let next = values[DeepLinkField.to.rawValue].flatMap { DeepLinkRoute(rawValue: $0) }.flatMap { $0 == .premium ? nil : $0 }
            return .premium(perk: perk, then: next.flatMap { route in Self.make(route: route) { values[$0.rawValue] } })
        }
        return Self.make(route: route) { values[$0.rawValue] }
    }

    /// The URL that opens `link`. Invites need a universal-link host; returns nil when none is configured.
    public func url(for link: DeepLink) -> URL? {
        if case .invite(let token) = link {
            guard let host = universalLinkHosts.sorted().first else { return nil }
            var components = URLComponents()
            components.scheme = "https"
            components.host = host
            components.path = "/\(Self.invitePathPrefix)/\(token)"
            return components.url
        }
        guard let route = link.route else { return nil }
        var components = URLComponents()
        components.scheme = customScheme
        components.host = route.rawValue
        let fields = link.fields
        if !fields.isEmpty {
            components.queryItems = fields.map { URLQueryItem(name: $0.0.queryName, value: $0.1) }
        }
        return components.url
    }

    // MARK: Notification payloads

    /// The destination of a notification tap. `userInfo` is the APNs payload (top-level keys
    /// next to `aps`). A `link` wins; otherwise the `type` and its ids decide.
    public func parse(notificationPayload userInfo: [AnyHashable: Any]) -> DeepLink? {
        if let text = PayloadValue.string(userInfo[PushKey.link]), let url = URL(string: text), let link = parse(url) {
            return link
        }
        guard let typeName = PayloadValue.string(userInfo[PushKey.type]),
              let type = PushType(rawValue: typeName) else { return nil }
        let value: (DeepLinkField) -> String? = { PayloadValue.string(userInfo[$0.payloadKey]) }
        let route: DeepLinkRoute
        switch type {
        // A memory opens its photo in the viewer (docs/API.md §5.21: "The apps open the photo").
        case .newPost, .reaction, .memory: route = .post
        case .reply: route = value(.message) != nil ? .chat : .post
        case .recapReady: route = .recap
        case .birthdayRequest: route = .birthdayRequest
        case .tribute: route = .tribute
        case .yearStory: route = .yearStory
        case .dailyInvitation: route = .daily
        case .plan: route = .plan
        case .widget, .dailyInvitationEnded: return nil
        }
        return Self.make(route: route, value: value)
    }

    /// A payload that taps through to `link` (tests, local notifications).
    public func payload(for link: DeepLink) -> [String: String] {
        let type: PushType?
        switch link.route {
        case .post?: type = .newPost
        case .chat?: type = .reply
        case .daily?: type = .dailyInvitation
        case .recap?: type = .recapReady
        case .birthdayRequest?: type = .birthdayRequest
        case .tribute?: type = .tribute
        case .yearStory?: type = .yearStory
        case .plan?: type = .plan
        case .camera?, .collage?, .premium?, nil: type = nil
        }
        guard let type else {
            return url(for: link).map { [PushKey.link: $0.absoluteString] } ?? [:]
        }
        var payload = [PushKey.type: type.rawValue]
        for (field, value) in link.fields { payload[field.payloadKey] = value }
        return payload
    }

    // MARK: Shared

    private static func make(route: DeepLinkRoute, value: (DeepLinkField) -> String?) -> DeepLink? {
        func id(_ field: DeepLinkField) -> String? {
            guard let raw = value(field), isValidIdentifier(raw) else { return nil }
            return raw
        }
        switch route {
        case .camera:
            // An unreadable group id still opens the camera, without preselecting a group.
            return .camera(groupID: id(.group))
        case .post:
            guard let group = id(.group), let post = id(.post) else { return nil }
            return .post(groupID: group, postID: post)
        case .chat:
            guard let group = id(.group), let message = id(.message) else { return nil }
            return .chatMessage(groupID: group, messageID: message)
        case .daily:
            guard let group = id(.group), let invitation = id(.invitation) else { return nil }
            return .dailyInvitation(groupID: group, invitationID: invitation)
        case .recap:
            guard let group = id(.group), let recap = id(.recap) else { return nil }
            return .recap(groupID: group, recapID: recap)
        case .birthdayRequest:
            guard let request = id(.request) else { return nil }
            return .birthdayRequest(requestID: request, groupID: id(.group))
        case .tribute:
            guard let tribute = id(.tribute) else { return nil }
            return .tribute(tributeID: tribute, groupID: id(.group))
        case .yearStory:
            guard let group = id(.group), let yearText = value(.year), let year = Int(yearText),
                  (1...9999).contains(year) else { return nil }
            return .yearStory(groupID: group, year: year)
        case .plan:
            // The group is optional: an unreadable one is dropped and the plan still opens.
            guard let plan = id(.plan) else { return nil }
            return .plan(planID: plan, groupID: id(.group))
        case .collage:
            guard let group = id(.group), let collage = id(.collage) else { return nil }
            return .collage(groupID: group, collageID: collage)
        case .premium:
            // Only from URLs (`parseCustomScheme`); a notification never carries one.
            return nil
        }
    }

    static let maxIdentifierLength = 128
    static let maxTokenLength = 256

    /// Database identifiers (UUIDs or similar): letters, digits, `-`, `_`.
    public static func isValidIdentifier(_ value: String) -> Bool {
        isURLSafe(value, maxLength: maxIdentifierLength)
    }

    /// Invite tokens: URL-safe base64 alphabet.
    public static func isValidToken(_ value: String) -> Bool {
        isURLSafe(value, maxLength: maxTokenLength)
    }

    private static func isURLSafe(_ value: String, maxLength: Int) -> Bool {
        guard !value.isEmpty, value.utf8.count <= maxLength else { return false }
        return value.utf8.allSatisfy { byte in
            (byte >= 0x30 && byte <= 0x39) || (byte >= 0x41 && byte <= 0x5A) || (byte >= 0x61 && byte <= 0x7A)
                || byte == 0x2D || byte == 0x5F
        }
    }
}
