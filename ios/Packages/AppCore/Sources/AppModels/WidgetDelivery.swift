import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// The `widget` object of a new-post / collage push:
///
///     "widget": {
///       "group_id": "…", "post_id": "…",
///       "rendition_url": "https://…signed…",
///       "sender": "Display name" | { "display_name": "…", "avatar_url": "https://…" },
///       "caption": "…", "kind": "photo" | "collage",
///       "group_name": "…",            (optional)
///       "posted_at": 1760000000        (optional; Unix seconds or ISO 8601)
///     }
///
/// Alert pushes carry it with `mutable-content: 1` (handled by the Notification Service
/// Extension); muted groups get it in a background push (handled by the app delegate).
public struct WidgetPushPayload: Hashable, Sendable {
    public static let payloadKey = "widget"

    public struct Sender: Hashable, Sendable {
        public var displayName: String?
        public var avatarURL: URL?
    }

    public var groupID: String
    public var postID: String
    public var renditionURL: URL
    public var sender: Sender?
    public var caption: String?
    public var kind: WidgetSnapshot.Kind
    public var groupName: String?
    public var postedAt: Date?

    public init(
        groupID: String,
        postID: String,
        renditionURL: URL,
        sender: Sender? = nil,
        caption: String? = nil,
        kind: WidgetSnapshot.Kind,
        groupName: String? = nil,
        postedAt: Date? = nil
    ) {
        self.groupID = groupID
        self.postID = postID
        self.renditionURL = renditionURL
        self.sender = sender
        self.caption = caption
        self.kind = kind
        self.groupName = groupName
        self.postedAt = postedAt
    }

    /// Reads the payload from an APNs `userInfo` dictionary. Returns nil when there is no
    /// `widget` object or it is malformed (missing ids, non-HTTPS rendition URL, unsafe ids).
    public init?(userInfo: [AnyHashable: Any]) {
        guard let widget = userInfo[Self.payloadKey] as? [AnyHashable: Any] else { return nil }
        self.init(widget: widget)
    }

    init?(widget: [AnyHashable: Any]) {
        guard let groupID = widget["group_id"] as? String, DeepLinkParser.isValidIdentifier(groupID),
              let postID = widget["post_id"] as? String, DeepLinkParser.isValidIdentifier(postID),
              let renditionText = widget["rendition_url"] as? String,
              let renditionURL = Self.httpsURL(renditionText) else { return nil }
        self.groupID = groupID
        self.postID = postID
        self.renditionURL = renditionURL
        switch widget["sender"] {
        case let name as String:
            sender = Sender(displayName: name, avatarURL: nil)
        case let object as [AnyHashable: Any]:
            sender = Sender(
                displayName: (object["display_name"] as? String) ?? (object["name"] as? String),
                avatarURL: (object["avatar_url"] as? String).flatMap(Self.httpsURL)
            )
        default:
            sender = nil
        }
        caption = (widget["caption"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        if let kindText = widget["kind"] as? String {
            guard let kind = WidgetSnapshot.Kind(rawValue: kindText) else { return nil }
            self.kind = kind
        } else {
            kind = .photo
        }
        groupName = widget["group_name"] as? String
        postedAt = Self.date(widget["posted_at"])
    }

    /// File name the rendition is stored under in the group's folder.
    public var renditionFileName: String {
        "\(kind.rawValue)-\(postID).\(Self.imageExtension(renditionURL))"
    }

    public var avatarFileName: String? {
        sender?.avatarURL.map { "avatar-\(postID).\(Self.imageExtension($0))" }
    }

    static func httpsURL(_ text: String) -> URL? {
        guard let url = URL(string: text), url.scheme?.lowercased() == "https", url.host != nil else { return nil }
        return url
    }

    static func imageExtension(_ url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        return ["jpg", "jpeg", "png", "heic", "webp"].contains(ext) ? ext : "jpg"
    }

    static func date(_ value: Any?) -> Date? {
        switch value {
        case let seconds as Double: return Date(timeIntervalSince1970: seconds)
        case let seconds as Int: return Date(timeIntervalSince1970: TimeInterval(seconds))
        case let number as NSNumber: return Date(timeIntervalSince1970: number.doubleValue)
        case let text as String:
            if let seconds = Double(text) { return Date(timeIntervalSince1970: seconds) }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: text) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            return formatter.date(from: text)
        default:
            return nil
        }
    }
}

/// Downloads a widget rendition (and the sender's avatar, best effort) into `WidgetStore` and
/// records the snapshot. The caller reloads widget timelines afterwards.
public struct WidgetDelivery: Sendable {
    public typealias Download = @Sendable (URL) async throws -> Data

    public let store: WidgetStore
    private let download: Download

    public init(store: WidgetStore, download: @escaping Download) {
        self.store = store
        self.download = download
    }

    public init(store: WidgetStore, downloader: HTTPDownloader) {
        self.init(store: store, download: { try await downloader.data(from: $0) })
    }

    @discardableResult
    public func deliver(_ payload: WidgetPushPayload, receivedAt: Date) async throws -> WidgetSnapshot {
        let photo = try await download(payload.renditionURL)
        try Task.checkCancellation()
        try store.writeFile(photo, groupID: payload.groupID, fileName: payload.renditionFileName)

        var avatarFileName: String?
        if let avatarURL = payload.sender?.avatarURL, let name = payload.avatarFileName,
           let avatar = try? await download(avatarURL) {
            try store.writeFile(avatar, groupID: payload.groupID, fileName: name)
            avatarFileName = name
        }
        try Task.checkCancellation()

        let snapshot = WidgetSnapshot(
            groupID: payload.groupID,
            groupName: payload.groupName ?? store.groups().first { $0.id == payload.groupID }?.name,
            postID: payload.postID,
            photoFileName: payload.renditionFileName,
            senderDisplayName: payload.sender?.displayName,
            senderAvatarFileName: avatarFileName,
            caption: payload.caption,
            kind: payload.kind,
            postedAt: payload.postedAt ?? receivedAt
        )
        try store.save(snapshot)
        return snapshot
    }
}

/// HTTPS GET with a request timeout and a size cap, cancellable through Swift task cancellation.
public struct HTTPDownloader: Sendable {
    public enum DownloadError: Error, Equatable, Sendable {
        case insecureURL
        case httpStatus(Int)
        case tooLarge(Int)
        case noData
    }

    public let timeout: TimeInterval
    public let maxBytes: Int

    /// `timeout` bounds each request; the Notification Service Extension passes a value inside its
    /// own execution window. `maxBytes` rejects anything larger than a widget rendition can be.
    public init(timeout: TimeInterval, maxBytes: Int) {
        self.timeout = timeout
        self.maxBytes = maxBytes
    }

    public func data(from url: URL) async throws -> Data {
        guard url.scheme?.lowercased() == "https" else { throw DownloadError.insecureURL }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        let session = URLSession(configuration: configuration)
        defer { session.finishTasksAndInvalidate() }
        let holder = TaskHolder()
        let maxBytes = self.maxBytes
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
                let task = session.dataTask(with: url) { data, response, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                        continuation.resume(throwing: DownloadError.httpStatus(http.statusCode))
                        return
                    }
                    guard let data else {
                        continuation.resume(throwing: DownloadError.noData)
                        return
                    }
                    guard data.count <= maxBytes else {
                        continuation.resume(throwing: DownloadError.tooLarge(data.count))
                        return
                    }
                    continuation.resume(returning: data)
                }
                holder.set(task)
                task.resume()
            }
        } onCancel: {
            holder.cancel()
        }
    }
}

/// Holds the in-flight task so the cancellation handler (which may run first) can cancel it.
private final class TaskHolder: @unchecked Sendable {
    private let lock = NSLock()
    private var task: URLSessionTask?
    private var cancelled = false

    func set(_ task: URLSessionTask) {
        lock.lock()
        self.task = task
        let cancelNow = cancelled
        lock.unlock()
        if cancelNow { task.cancel() }
    }

    func cancel() {
        lock.lock()
        cancelled = true
        let task = self.task
        lock.unlock()
        task?.cancel()
    }
}
