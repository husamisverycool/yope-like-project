import Foundation

/// share.in (design/surfaces/share.in.md): what the Share Extension hands to the app through the App Group container,
/// as Apple's Shared Albums take items from the share sheet ("Share → Add to Shared Album", support.apple.com/108314):
///
///     <container>/ShareInbox/<uuid>.<ext>   one file per shared photo or video
///     <container>/ShareInbox/items.json    [ShareInbox.Item] in the order shared (written last, atomically)
///
/// The extension replaces whatever an earlier share left; the app takes the items (moving the files out) when the
/// person is home, and the inbox is empty again. Nothing else is stored: no caption, no place, no sender.
public struct ShareInbox: Sendable {
    public static let directoryName = "ShareInbox"
    static let manifestName = "items.json"

    public enum Kind: String, Codable, Sendable {
        case image
        case movie
    }

    /// One shared item: its file inside the inbox and what it is.
    public struct Item: Codable, Hashable, Sendable {
        public var fileName: String
        public var kind: Kind

        public init(fileName: String, kind: Kind) {
            self.fileName = fileName
            self.kind = kind
        }
    }

    /// A file handed in or taken out.
    public struct File: Hashable, Sendable {
        public var url: URL
        public var kind: Kind

        public init(url: URL, kind: Kind) {
            self.url = url
            self.kind = kind
        }
    }

    public let rootURL: URL

    public init(rootURL: URL) {
        self.rootURL = rootURL
    }

    /// The inbox in the App Group container named in `bundle`'s Info.plist (`AppGroupIdentifier`), or in the process's
    /// fallback directory when there is no container (unsigned builds, tests, Linux) — then only that process sees it.
    public static func forBundle(_ bundle: Bundle) -> ShareInbox {
        let container = WidgetStore.appGroupContainer(AppGroup.identifier(in: bundle)) ?? WidgetStore.defaultFallbackDirectory()
        return ShareInbox(rootURL: container.appendingPathComponent(directoryName, isDirectory: true))
    }

    private var manifestURL: URL { rootURL.appendingPathComponent(Self.manifestName) }

    /// What is waiting, in the order shared (empty when nothing is).
    public func items() -> [Item] {
        guard let data = try? Data(contentsOf: manifestURL),
              let items = try? JSONDecoder().decode([Item].self, from: data) else { return [] }
        return items.filter { Self.isPlainFileName($0.fileName) }
    }

    public var hasItems: Bool { !items().isEmpty }

    /// Replaces what is waiting with copies of `files`, in their order (the share sheet's). Throws when nothing could be
    /// written.
    public func replace(with files: [File]) throws {
        clear()
        let manager = FileManager.default
        try manager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        var items: [Item] = []
        for file in files {
            let ext = file.url.pathExtension.lowercased()
            let name = UUID().uuidString.lowercased() + (ext.isEmpty ? "" : "." + ext)
            do {
                try manager.copyItem(at: file.url, to: rootURL.appendingPathComponent(name))
                items.append(Item(fileName: name, kind: file.kind))
            } catch {
                continue
            }
        }
        let data = try JSONEncoder().encode(items)
        try data.write(to: manifestURL, options: [.atomic])
    }

    /// Takes every waiting item: its file is moved into `destination` (created when missing) and the inbox is emptied.
    /// Items whose file is gone are left out.
    public func take(into destination: URL) -> [File] {
        let waiting = items()
        guard !waiting.isEmpty else {
            clear()
            return []
        }
        let manager = FileManager.default
        try? manager.createDirectory(at: destination, withIntermediateDirectories: true)
        var taken: [File] = []
        for item in waiting {
            let source = rootURL.appendingPathComponent(item.fileName)
            let target = destination.appendingPathComponent(item.fileName)
            do {
                try manager.moveItem(at: source, to: target)
                taken.append(File(url: target, kind: item.kind))
            } catch {
                continue
            }
        }
        clear()
        return taken
    }

    /// Removes everything waiting.
    public func clear() {
        try? FileManager.default.removeItem(at: rootURL)
    }

    /// A manifest name is a single path component (the extension writes `<uuid>.<ext>`), so a damaged manifest cannot
    /// point outside the inbox.
    static func isPlainFileName(_ name: String) -> Bool {
        !name.isEmpty && !name.contains("/") && name != "." && name != ".." && !name.hasPrefix(".")
    }
}

/// The URL the Share Extension opens to hand over to the app: `<scheme>://share`, where the scheme is the app's own
/// (its bundle identifier, `CFBundleURLTypes` in ios/App/Info.plist; Info.plist key `AppURLScheme` in the app and the
/// extension). It carries nothing: the items are in the App Group inbox.
public enum ShareInLink {
    public static let host = "share"
    /// Info.plist key holding the scheme (`$(APP_BUNDLE_ID)`).
    public static let infoPlistKey = "AppURLScheme"

    public static func scheme(in bundle: Bundle) -> String? {
        guard let value = bundle.object(forInfoDictionaryKey: infoPlistKey) as? String,
              !value.isEmpty, !value.contains("$(") else { return nil }
        return value.lowercased()
    }

    public static func url(scheme: String) -> URL? {
        URL(string: "\(scheme.lowercased())://\(host)")
    }

    public static func matches(_ url: URL, scheme: String?) -> Bool {
        guard let scheme, let urlScheme = url.scheme?.lowercased(), urlScheme == scheme.lowercased() else { return false }
        let route = url.host.flatMap { $0.isEmpty ? nil : $0 } ?? url.path.split(separator: "/").first.map(String.init)
        return route?.lowercased() == host
    }
}
