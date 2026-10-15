import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Widget fields of a push (new post or same-moment collage). Two shapes are accepted:
///
/// - an iOS alert push (`mutable-content: 1`, handled by the Notification Service Extension)
///   carrying them as one object: `"widget": { "group_id": …, "post_id": …, "rendition_url": …,
///   "sender": "Name" | { "display_name": …, "avatar_url": … }, "caption": …, "kind": … }`;
/// - a silent push for muted groups (handled by the app delegate) with the flat keys of the
///   shared contract: `"type": "widget", "group_id", "post_id" | "collage_id", "rendition_url",
///   "sender_name", "sender_avatar_url", "caption", "kind", "group_name", "posted_at"`.
///
/// Required: `group_id` and an HTTPS `rendition_url`. `kind` defaults to `photo`; `posted_at`
/// (Unix seconds or milliseconds, or ISO 8601) defaults to the time of receipt.
public struct WidgetPushPayload: Hashable, Sendable {
    public struct Sender: Hashable, Sendable {
        public var displayName: String?
        public var avatarURL: URL?

        public init(displayName: String?, avatarURL: URL?) {
            self.displayName = displayName
            self.avatarURL = avatarURL
        }
    }

    public var groupID: String
    /// The post, or the collage, the rendition shows.
    public var sourceID: String?
    public var renditionURL: URL
    public var sender: Sender?
    public var caption: String?
    public var kind: WidgetSnapshot.Kind
    public var groupName: String?
    public var postedAt: Date?

    public init(
        groupID: String,
        sourceID: String?,
        renditionURL: URL,
        sender: Sender? = nil,
        caption: String? = nil,
        kind: WidgetSnapshot.Kind,
        groupName: String? = nil,
        postedAt: Date? = nil
    ) {
        self.groupID = groupID
        self.sourceID = sourceID
        self.renditionURL = renditionURL
        self.sender = sender
        self.caption = caption
        self.kind = kind
        self.groupName = groupName
        self.postedAt = postedAt
    }

    /// Reads the payload from an APNs `userInfo` dictionary; nil when it has no widget fields or
    /// they are malformed (missing group, non-HTTPS URL, unsafe ids, unknown kind).
    public init?(userInfo: [AnyHashable: Any]) {
        if let nested = userInfo[PushKey.widget] as? [AnyHashable: Any] {
            self.init(fields: nested)
        } else if PayloadValue.string(userInfo[PushKey.type]) == PushType.widget.rawValue {
            self.init(fields: userInfo)
        } else {
            return nil
        }
    }

    init?(fields: [AnyHashable: Any]) {
        func text(_ key: String) -> String? { PayloadValue.string(fields[key]) }
        guard let group = text(PushKey.groupID), DeepLinkParser.isValidIdentifier(group),
              let renditionText = text(PushKey.renditionURL), let renditionURL = Self.httpsURL(renditionText) else { return nil }
        let source = text(PushKey.postID) ?? text(PushKey.collageID)
        if let source, !DeepLinkParser.isValidIdentifier(source) { return nil }
        groupID = group
        sourceID = source
        self.renditionURL = renditionURL

        switch fields["sender"] {
        case let object as [AnyHashable: Any]:
            sender = Sender(
                displayName: PayloadValue.string(object["display_name"]) ?? PayloadValue.string(object["name"]),
                avatarURL: PayloadValue.string(object["avatar_url"]).flatMap(Self.httpsURL)
            )
        default:
            let name = PayloadValue.string(fields["sender"]) ?? text(PushKey.senderName)
            let avatar = text(PushKey.senderAvatarURL).flatMap(Self.httpsURL)
            sender = (name == nil && avatar == nil) ? nil : Sender(displayName: name, avatarURL: avatar)
        }

        caption = text(PushKey.caption)
        if let kindText = text(PushKey.kind) {
            guard let kind = WidgetSnapshot.Kind(rawValue: kindText) else { return nil }
            self.kind = kind
        } else {
            kind = .photo
        }
        groupName = text(PushKey.groupName)
        postedAt = PayloadValue.date(fields[PushKey.postedAt])
    }

    /// File name the rendition is stored under in the group's folder (`fallbackID` names it
    /// when the payload has no post or collage id).
    public func renditionFileName(fallbackID: String) -> String {
        "\(kind.rawValue)-\(sourceID ?? fallbackID).\(Self.imageExtension(renditionURL))"
    }

    public func avatarFileName(fallbackID: String) -> String? {
        sender?.avatarURL.map { "avatar-\(sourceID ?? fallbackID).\(Self.imageExtension($0))" }
    }

    static func httpsURL(_ text: String) -> URL? {
        guard let url = URL(string: text), url.scheme?.lowercased() == "https", url.host != nil else { return nil }
        return url
    }

    static func imageExtension(_ url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        return ["jpg", "jpeg", "png", "heic", "webp"].contains(ext) ? ext : "jpg"
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
        let fallbackID = String(Int64((receivedAt.timeIntervalSince1970 * 1000).rounded()))
        let photoFileName = payload.renditionFileName(fallbackID: fallbackID)
        let photo = try await download(payload.renditionURL)
        try Task.checkCancellation()
        try store.writeFile(photo, groupID: payload.groupID, fileName: photoFileName)

        var avatarFileName: String?
        if let avatarURL = payload.sender?.avatarURL, let name = payload.avatarFileName(fallbackID: fallbackID),
           let avatar = try? await download(avatarURL) {
            try store.writeFile(avatar, groupID: payload.groupID, fileName: name)
            avatarFileName = name
        }
        try Task.checkCancellation()

        let snapshot = WidgetSnapshot(
            groupID: payload.groupID,
            groupName: payload.groupName ?? store.groups().first { $0.id == payload.groupID }?.name,
            sourceID: payload.sourceID,
            photoFileName: photoFileName,
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
