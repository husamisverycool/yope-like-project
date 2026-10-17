import Foundation

/// share.in (design/surfaces/share.in.md): what the Share Extension hands to the app through the App Group container,
/// as Apple's Shared Albums take items from the share sheet ("Share → Add to Shared Album", support.apple.com/108314):
///
///     <container>/ShareInbox/<uuid>.<ext>   one file per shared photo or video
///     <container>/ShareInbox/group.txt     the group chosen in the share sheet's suggestion row (optional)
///     <container>/ShareInbox/items.json    [ShareInbox.Item] in the order shared (written last, atomically)
///
/// The extension replaces whatever an earlier share left; the app takes the items (moving the files out) when the
/// person is home, and the inbox is empty again. Nothing else is stored: no caption, no place, no sender. The group is
/// the id of the `INSendMessageIntent` conversation the person picked (`ShareTargetIntent`); send-to preselects it.
public struct ShareInbox: Sendable {
    public static let directoryName = "ShareInbox"
    static let manifestName = "items.json"
    static let groupFileName = "group.txt"

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

    /// What a take hands to the app: the files in the order shared, and the group chosen in the share sheet (nil: the
    /// app itself was chosen).
    public struct Share: Hashable, Sendable {
        public var files: [File]
        public var groupID: String?

        public init(files: [File], groupID: String?) {
            self.files = files
            self.groupID = groupID
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
    private var groupURL: URL { rootURL.appendingPathComponent(Self.groupFileName) }

    /// The group chosen in the share sheet's suggestion row for what is waiting (nil: none, or not a plain id).
    public func groupID() -> String? {
        guard let data = try? Data(contentsOf: groupURL) else { return nil }
        return Self.plainGroupID(String(decoding: data, as: UTF8.self))
    }

    /// What is waiting, in the order shared (empty when nothing is).
    public func items() -> [Item] {
        guard let data = try? Data(contentsOf: manifestURL),
              let items = try? JSONDecoder().decode([Item].self, from: data) else { return [] }
        return items.filter { Self.isPlainFileName($0.fileName) }
    }

    public var hasItems: Bool { !items().isEmpty }

    /// Replaces what is waiting with copies of `files`, in their order (the share sheet's), and the group chosen in the
    /// share sheet (`groupID`, nil when the app itself was chosen). Throws when nothing could be written.
    public func replace(with files: [File], groupID: String? = nil) throws {
        clear()
        let manager = FileManager.default
        try manager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        if let groupID = groupID.flatMap(Self.plainGroupID) {
            try? Data(groupID.utf8).write(to: groupURL, options: [.atomic])
        }
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
        takeShare(into: destination).files
    }

    /// `take(into:)` with the group chosen in the share sheet (nil when none, or when nothing was waiting).
    public func takeShare(into destination: URL) -> Share {
        let waiting = items()
        let group = groupID()
        guard !waiting.isEmpty else {
            clear()
            return Share(files: [], groupID: nil)
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
        return Share(files: taken, groupID: taken.isEmpty ? nil : group)
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

    /// A group id as the server writes it (a UUID): letters, digits and hyphens, at most 64 characters; anything else
    /// is no group (send-to then preselects as for any share).
    static func plainGroupID(_ raw: String) -> String? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value.count <= 64,
              value.unicodeScalars.allSatisfy({ $0.isASCII && (CharacterSet.alphanumerics.contains($0) || $0 == "-") }) else { return nil }
        return value
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
