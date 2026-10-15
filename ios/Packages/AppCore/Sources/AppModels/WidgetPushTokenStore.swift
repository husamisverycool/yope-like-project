import Foundation

/// Hands the WidgetKit push token (iOS 26 `WidgetPushHandler.pushTokenDidChange`, which runs in
/// the widget extension) to the app through the App Group, so the app can send it with
/// `register_device` (`devices.widget_push_token`). Device-level: it lives next to `WidgetStore`
/// and survives `WidgetStore.removeAll()` on sign-out.
///
///     <container>/WidgetPushToken.json    {"token": "<hex>"} or {"token": null}
public struct WidgetPushTokenStore: Sendable {
    public static let fileName = "WidgetPushToken.json"

    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// The store in the App Group container, or in `fallbackDirectory` when it is unavailable.
    public static func resolve(appGroupIdentifier: String?, fallbackDirectory: URL) -> WidgetPushTokenStore {
        let directory = WidgetStore.appGroupContainer(appGroupIdentifier) ?? fallbackDirectory
        return WidgetPushTokenStore(fileURL: directory.appendingPathComponent(fileName, isDirectory: false))
    }

    public static func forBundle(_ bundle: Bundle) -> WidgetPushTokenStore {
        resolve(appGroupIdentifier: AppGroup.identifier(in: bundle), fallbackDirectory: WidgetStore.defaultFallbackDirectory())
    }

    private struct File: Codable {
        var token: String?
    }

    /// Records the token (lowercase hex), or nil when the system withdrew it.
    public func save(_ token: String?) throws {
        let data = try JSONEncoder().encode(File(token: token?.lowercased()))
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        #if canImport(Darwin)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try data.write(to: fileURL, options: [.atomic])
        #endif
    }

    /// Records the token from the raw push token data.
    public func save(tokenData: Data?) throws {
        try save(tokenData.map(PushToken.hex))
    }

    public func load() -> String? {
        guard let data = try? Data(contentsOf: fileURL),
              let file = try? JSONDecoder().decode(File.self, from: data),
              let token = file.token, !token.isEmpty else { return nil }
        return token
    }
}
