import Foundation

/// File layout shared by the app, the widget extension and the Notification Service Extension
/// inside the App Group container:
///
///     <container>/WidgetStore/
///         groups.json                       [WidgetGroup] — the widget's group picker
///         groups/<group id>/photo.json      newest photo snapshot
///         groups/<group id>/collage.json    newest same-moment collage snapshot
///         groups/<group id>/<file>          widget renditions and sender avatars
///
/// Every write is atomic (write to a temporary file, then rename), and a rendition is written
/// before the snapshot that references it, so a reader in another process never sees a
/// snapshot pointing at a missing or half-written file.
public struct WidgetStore: Sendable {
    public static let directoryName = "WidgetStore"
    static let groupsFileName = "groups.json"
    static let groupsDirectoryName = "groups"

    public enum StoreError: Error, Equatable, Sendable {
        case invalidIdentifier(String)
        case invalidFileName(String)
    }

    public let rootURL: URL

    public init(rootURL: URL) {
        self.rootURL = rootURL
    }

    /// The store inside the App Group container, or inside `fallbackDirectory` when the container
    /// is unavailable (unsigned simulator builds, unit tests, Linux). A fallback store is private
    /// to the calling process, so widgets only see it when the container exists.
    public static func resolve(appGroupIdentifier: String?, fallbackDirectory: URL) -> WidgetStore {
        if let container = appGroupContainer(appGroupIdentifier) {
            return WidgetStore(rootURL: container.appendingPathComponent(directoryName, isDirectory: true))
        }
        return WidgetStore(rootURL: fallbackDirectory.appendingPathComponent(directoryName, isDirectory: true))
    }

    /// `resolve` with the App Group named in `bundle`'s Info.plist and the default fallback directory.
    public static func forBundle(_ bundle: Bundle) -> WidgetStore {
        resolve(appGroupIdentifier: AppGroup.identifier(in: bundle), fallbackDirectory: defaultFallbackDirectory())
    }

    public static func defaultFallbackDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("AppGroupFallback", isDirectory: true)
    }

    static func appGroupContainer(_ identifier: String?) -> URL? {
        #if canImport(Darwin)
        guard let identifier, !identifier.isEmpty else { return nil }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
        #else
        return nil
        #endif
    }

    // MARK: Groups

    /// Replaces the group list and deletes the folders of groups that are no longer listed
    /// (left, removed or deleted groups must not keep showing on a widget).
    public func syncGroups(_ groups: [WidgetGroup]) throws {
        for group in groups { try Self.validateIdentifier(group.id) }
        try write(try Self.encoder.encode(groups), to: rootURL.appendingPathComponent(Self.groupsFileName))
        let keep = Set(groups.map(\.id))
        for groupID in storedGroupIDs() where !keep.contains(groupID) {
            try removeGroup(groupID)
        }
    }

    public func groups() -> [WidgetGroup] {
        guard let data = try? Data(contentsOf: rootURL.appendingPathComponent(Self.groupsFileName)) else { return [] }
        return (try? Self.decoder.decode([WidgetGroup].self, from: data)) ?? []
    }

    // MARK: Files

    /// Writes a rendition or avatar into the group's folder and returns its URL.
    @discardableResult
    public func writeFile(_ data: Data, groupID: String, fileName: String) throws -> URL {
        let url = try fileURL(groupID: groupID, fileName: fileName)
        try write(data, to: url)
        return url
    }

    public func fileURL(groupID: String, fileName: String) throws -> URL {
        try Self.validateIdentifier(groupID)
        try Self.validateFileName(fileName)
        return groupDirectory(groupID).appendingPathComponent(fileName, isDirectory: false)
    }

    public func photoURL(for snapshot: WidgetSnapshot) -> URL? {
        existingFile(groupID: snapshot.groupID, fileName: snapshot.photoFileName)
    }

    public func avatarURL(for snapshot: WidgetSnapshot) -> URL? {
        snapshot.senderAvatarFileName.flatMap { existingFile(groupID: snapshot.groupID, fileName: $0) }
    }

    private func existingFile(groupID: String, fileName: String) -> URL? {
        guard let url = try? fileURL(groupID: groupID, fileName: fileName),
              FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    // MARK: Snapshots

    /// Saves `snapshot` as the newest of its kind for its group. Write the files it references first.
    public func save(_ snapshot: WidgetSnapshot) throws {
        try Self.validateIdentifier(snapshot.groupID)
        try Self.validateFileName(snapshot.photoFileName)
        if let avatar = snapshot.senderAvatarFileName { try Self.validateFileName(avatar) }
        try write(try Self.encoder.encode(snapshot), to: snapshotURL(groupID: snapshot.groupID, kind: snapshot.kind))
    }

    public func snapshot(groupID: String, kind: WidgetSnapshot.Kind) -> WidgetSnapshot? {
        guard Self.isValidIdentifier(groupID),
              let data = try? Data(contentsOf: snapshotURL(groupID: groupID, kind: kind)),
              let snapshot = try? Self.decoder.decode(WidgetSnapshot.self, from: data),
              snapshot.groupID == groupID else { return nil }
        return snapshot
    }

    /// The newest snapshot (photo or collage) of a group whose rendition is on disk.
    public func latestSnapshot(groupID: String) -> WidgetSnapshot? {
        WidgetSnapshot.Kind.allCases
            .compactMap { snapshot(groupID: groupID, kind: $0) }
            .filter { photoURL(for: $0) != nil }
            .max(by: Self.isOlder)
    }

    /// The newest snapshot across all groups (a widget with no group chosen yet).
    public func latestSnapshot() -> WidgetSnapshot? {
        storedGroupIDs().compactMap { latestSnapshot(groupID: $0) }.max(by: Self.isOlder)
    }

    /// Removes every snapshot that shows the post or collage `sourceID`, with its rendition.
    /// Returns whether anything was removed. Used when a post is deleted (security invariant 2:
    /// a deleted photo leaves the widgets).
    @discardableResult
    public func removeSource(_ sourceID: String) throws -> Bool {
        var removed = false
        for groupID in storedGroupIDs() {
            for kind in WidgetSnapshot.Kind.allCases {
                guard let snapshot = snapshot(groupID: groupID, kind: kind), snapshot.sourceID == sourceID else { continue }
                try removeIfPresent(snapshotURL(groupID: groupID, kind: kind))
                if let url = try? fileURL(groupID: groupID, fileName: snapshot.photoFileName) {
                    try removeIfPresent(url)
                }
                removed = true
            }
        }
        return removed
    }

    public func removeGroup(_ groupID: String) throws {
        try Self.validateIdentifier(groupID)
        try removeIfPresent(groupDirectory(groupID))
    }

    /// Deletes everything (sign-out, account deletion).
    public func removeAll() throws {
        try removeIfPresent(rootURL)
    }

    /// Deletes files no snapshot references and that were last modified before `now - gracePeriod`.
    /// The grace period protects a rendition another process has just written but not yet
    /// referenced from a snapshot. Returns the number of files deleted.
    @discardableResult
    public func prune(now: Date, gracePeriod: TimeInterval) throws -> Int {
        let fileManager = FileManager.default
        let cutoff = now.addingTimeInterval(-gracePeriod)
        var deleted = 0
        for groupID in storedGroupIDs() {
            let directory = groupDirectory(groupID)
            var referenced: Set<String> = Set(WidgetSnapshot.Kind.allCases.map { Self.snapshotFileName($0) })
            for kind in WidgetSnapshot.Kind.allCases {
                guard let snapshot = snapshot(groupID: groupID, kind: kind) else { continue }
                referenced.insert(snapshot.photoFileName)
                if let avatar = snapshot.senderAvatarFileName { referenced.insert(avatar) }
            }
            let contents = (try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )) ?? []
            for url in contents where !referenced.contains(url.lastPathComponent) {
                let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                guard let modified, modified < cutoff else { continue }
                try removeIfPresent(url)
                deleted += 1
            }
        }
        return deleted
    }

    // MARK: Internals

    func groupDirectory(_ groupID: String) -> URL {
        rootURL
            .appendingPathComponent(Self.groupsDirectoryName, isDirectory: true)
            .appendingPathComponent(groupID, isDirectory: true)
    }

    func snapshotURL(groupID: String, kind: WidgetSnapshot.Kind) -> URL {
        groupDirectory(groupID).appendingPathComponent(Self.snapshotFileName(kind), isDirectory: false)
    }

    static func snapshotFileName(_ kind: WidgetSnapshot.Kind) -> String {
        "\(kind.rawValue).json"
    }

    func storedGroupIDs() -> [String] {
        let directory = rootURL.appendingPathComponent(Self.groupsDirectoryName, isDirectory: true)
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        return names.filter(Self.isValidIdentifier).sorted()
    }

    private func write(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        #if canImport(Darwin)
        // Lock-screen widgets and the Notification Service Extension read and write while the
        // device is locked, so files stay readable after the first unlock.
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try data.write(to: url, options: [.atomic])
        #endif
    }

    private func removeIfPresent(_ url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    private static func isOlder(_ lhs: WidgetSnapshot, _ rhs: WidgetSnapshot) -> Bool {
        lhs.postedAt < rhs.postedAt
    }

    // Coders are created per use: JSONEncoder/JSONDecoder are not Sendable on every SDK.
    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }

    // MARK: Validation

    /// Group ids become folder names: same alphabet as deep-link identifiers.
    public static func isValidIdentifier(_ value: String) -> Bool {
        DeepLinkParser.isValidIdentifier(value)
    }

    /// File names: letters, digits, `-`, `_`, `.`; must not start with `.`; no path separators.
    public static func isValidFileName(_ value: String) -> Bool {
        guard let first = value.utf8.first, first != 0x2E, value.utf8.count <= 128 else { return false }
        return value.utf8.allSatisfy { byte in
            (byte >= 0x30 && byte <= 0x39) || (byte >= 0x41 && byte <= 0x5A) || (byte >= 0x61 && byte <= 0x7A)
                || byte == 0x2D || byte == 0x5F || byte == 0x2E
        }
    }

    static func validateIdentifier(_ value: String) throws {
        guard isValidIdentifier(value) else { throw StoreError.invalidIdentifier(value) }
    }

    static func validateFileName(_ value: String) throws {
        guard isValidFileName(value) else { throw StoreError.invalidFileName(value) }
    }
}
