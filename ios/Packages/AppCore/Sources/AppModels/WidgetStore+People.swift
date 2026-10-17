import Foundation

/// A person the friend widget can show (`widget_people`: everyone who shares a group with the person, minus blocks).
public struct WidgetPerson: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

/// The friend and memories widgets' files in the App Group store (design/surfaces/widget.friend.md,
/// widget.memories.md, widget.styles.md), next to the per-group layout of `WidgetStore`:
///
///     <container>/WidgetStore/
///         people.json                     [WidgetPerson] — the friend widget's picker (the app writes it)
///         watched.json                    which friends (and whether memories) some placed widget shows, with the time
///                                         its timeline last ran (the widget extension writes it)
///         premium.json                    whether the person has premium (the app writes it; widget styles)
///         people/<user id>/photo.json     that friend's newest photo (a WidgetSnapshot of the photo's group)
///         people/<user id>/<file>         its rendition and the poster's avatar
///         memories/days.json              the days the app looked up: { "from": "2026-10-17", "through": "2026-10-23" }
///         memories/<yyyy-MM-dd>.json      that day's memory (a WidgetSnapshot); no file: the day has none
///         memories/<file>                 the memories' renditions
///
/// Same rules as the group files: atomic writes, a rendition written before the snapshot that references it.
extension WidgetStore {
    static let peopleFileName = "people.json"
    static let watchedFileName = "watched.json"
    static let premiumFileName = "premium.json"
    static let peopleDirectoryName = "people"
    static let memoriesDirectoryName = "memories"
    static let memoryDaysFileName = "days.json"
    static let personSnapshotFileName = "photo.json"

    /// A widget whose timeline has not run for this long is taken as removed (timelines rebuild at least hourly, budget
    /// permitting — docs/PLATFORM_CONSTRAINTS.md §1.1).
    public static let watchExpiry: TimeInterval = 2 * 24 * 60 * 60

    // MARK: People (the friend widget's picker)

    public func syncPeople(_ people: [WidgetPerson]) throws {
        for person in people { try Self.validateIdentifier(person.id) }
        try write(try Self.encoder.encode(people), to: rootURL.appendingPathComponent(Self.peopleFileName))
        // Someone no longer listed (left every shared group, or a block) leaves the friend widgets.
        let keep = Set(people.map(\.id))
        for personID in storedPersonIDs() where !keep.contains(personID) {
            try removeIfPresent(personDirectory(personID))
        }
    }

    public func people() -> [WidgetPerson] {
        guard let data = try? Data(contentsOf: rootURL.appendingPathComponent(Self.peopleFileName)) else { return [] }
        return (try? Self.decoder.decode([WidgetPerson].self, from: data)) ?? []
    }

    /// Whether the app has written the people list on this device (after sign-in; sign-out removes the store).
    public var hasPeopleList: Bool {
        FileManager.default.fileExists(atPath: rootURL.appendingPathComponent(Self.peopleFileName).path)
    }

    // MARK: Premium (widget styles)

    struct PremiumState: Codable {
        var premium: Bool
    }

    public var isPremium: Bool {
        guard let data = try? Data(contentsOf: rootURL.appendingPathComponent(Self.premiumFileName)),
              let state = try? Self.decoder.decode(PremiumState.self, from: data) else { return false }
        return state.premium
    }

    /// Records the person's premium state; returns whether it changed (the caller reloads the widgets then).
    @discardableResult
    public func setPremium(_ premium: Bool) throws -> Bool {
        let fileExists = FileManager.default.fileExists(atPath: rootURL.appendingPathComponent(Self.premiumFileName).path)
        guard !fileExists || isPremium != premium else { return false }
        try write(try Self.encoder.encode(PremiumState(premium: premium)), to: rootURL.appendingPathComponent(Self.premiumFileName))
        return true
    }

    // MARK: Watched (what placed widgets show)

    struct Watched: Codable {
        var people: [String: Date] = [:]
        var memories: Date?
    }

    func watched() -> Watched {
        guard let data = try? Data(contentsOf: rootURL.appendingPathComponent(Self.watchedFileName)),
              let watched = try? Self.decoder.decode(Watched.self, from: data) else { return Watched() }
        return watched
    }

    /// A friend widget showing `personID` built its timeline at `date`.
    public func watch(personID: String, at date: Date) throws {
        try Self.validateIdentifier(personID)
        var state = watched()
        state.people[personID] = date
        state.people = state.people.filter { date.timeIntervalSince($0.value) < Self.watchExpiry }
        try write(try Self.encoder.encode(state), to: rootURL.appendingPathComponent(Self.watchedFileName))
    }

    /// A memories widget built its timeline at `date`.
    public func watchMemories(at date: Date) throws {
        var state = watched()
        state.memories = date
        try write(try Self.encoder.encode(state), to: rootURL.appendingPathComponent(Self.watchedFileName))
    }

    /// The friends some placed widget showed within `watchExpiry` of `now`.
    public func watchedPeople(now: Date) -> Set<String> {
        Set(watched().people.filter { now.timeIntervalSince($0.value) < Self.watchExpiry }.keys)
    }

    public func watchesMemories(now: Date) -> Bool {
        guard let last = watched().memories else { return false }
        return now.timeIntervalSince(last) < Self.watchExpiry
    }

    // MARK: A friend's newest photo

    public func personSnapshot(personID: String) -> WidgetSnapshot? {
        guard Self.isValidIdentifier(personID),
              let data = try? Data(contentsOf: personDirectory(personID).appendingPathComponent(Self.personSnapshotFileName)),
              let snapshot = try? Self.decoder.decode(WidgetSnapshot.self, from: data),
              personPhotoURL(personID: personID, snapshot: snapshot) != nil else { return nil }
        return snapshot
    }

    public func personPhotoURL(personID: String, snapshot: WidgetSnapshot) -> URL? {
        existing(personDirectory(personID), snapshot.photoFileName)
    }

    public func personAvatarURL(personID: String, snapshot: WidgetSnapshot) -> URL? {
        snapshot.senderAvatarFileName.flatMap { existing(personDirectory(personID), $0) }
    }

    /// Makes `snapshot` (with `photo` and the optional `avatar` bytes) the friend's newest photo.
    public func savePerson(_ snapshot: WidgetSnapshot, personID: String, photo: Data, avatar: Data? = nil) throws {
        try Self.validateIdentifier(personID)
        try Self.validateIdentifier(snapshot.groupID)
        try Self.validateFileName(snapshot.photoFileName)
        let directory = personDirectory(personID)
        try write(photo, to: directory.appendingPathComponent(snapshot.photoFileName))
        var stored = snapshot
        if let avatar, let name = snapshot.senderAvatarFileName, Self.isValidFileName(name) {
            try write(avatar, to: directory.appendingPathComponent(name))
        } else {
            stored.senderAvatarFileName = nil
        }
        try write(try Self.encoder.encode(stored), to: directory.appendingPathComponent(Self.personSnapshotFileName))
    }

    /// A group photo by a friend some widget follows becomes that friend's newest photo when it is newer than the one
    /// shown (the push that carried it names the poster). The rendition is copied from the group's folder.
    /// Returns whether a friend widget changed.
    @discardableResult
    public func copyToWatchedPerson(_ snapshot: WidgetSnapshot, now: Date) throws -> Bool {
        guard snapshot.kind == .photo, let personID = snapshot.senderID, watchedPeople(now: now).contains(personID),
              let photoURL = photoURL(for: snapshot) else { return false }
        if let shown = personSnapshot(personID: personID), !Self.isOlder(shown, snapshot) { return false }
        let avatar = avatarURL(for: snapshot).flatMap { try? Data(contentsOf: $0) }
        try savePerson(snapshot, personID: personID, photo: try Data(contentsOf: photoURL), avatar: avatar)
        return true
    }

    /// The friend has no photo the person may see (any more): the widget shows its empty state. The friend's folder
    /// stays, marking that the app looked them up (`isPersonLookedUp`).
    public func removePersonSnapshot(personID: String) throws {
        try Self.validateIdentifier(personID)
        try FileManager.default.createDirectory(at: personDirectory(personID), withIntermediateDirectories: true)
        try removeIfPresent(personDirectory(personID).appendingPathComponent(Self.personSnapshotFileName))
    }

    /// Whether the app has looked the friend up on this device: before that, a friend widget without a photo is still
    /// loading — it must not say there are no photos when it does not know.
    public func isPersonLookedUp(personID: String) -> Bool {
        Self.isValidIdentifier(personID) && FileManager.default.fileExists(atPath: personDirectory(personID).path)
    }

    // MARK: Memories

    /// The days the app looked up (both ends included), as `yyyy-MM-dd` in the device's calendar; nil before the first
    /// look-up. A day in this range without a memory file has no memory; a day outside it is unknown.
    public func memoryDays() -> ClosedRange<String>? {
        guard let data = try? Data(contentsOf: memoriesDirectory.appendingPathComponent(Self.memoryDaysFileName)),
              let days = try? Self.decoder.decode([String: String].self, from: data),
              let from = days["from"], let through = days["through"],
              Self.isValidDay(from), Self.isValidDay(through), from <= through else { return nil }
        return from...through
    }

    public func memory(day: String) -> WidgetSnapshot? {
        guard Self.isValidDay(day),
              let data = try? Data(contentsOf: memoriesDirectory.appendingPathComponent("\(day).json")),
              let snapshot = try? Self.decoder.decode(WidgetSnapshot.self, from: data),
              memoryPhotoURL(snapshot) != nil else { return nil }
        return snapshot
    }

    public func memoryPhotoURL(_ snapshot: WidgetSnapshot) -> URL? {
        existing(memoriesDirectory, snapshot.photoFileName)
    }

    /// Whether `day`'s stored memory already shows `sourceID` (nothing to download again).
    public func hasMemory(day: String, sourceID: String) -> Bool {
        memory(day: day)?.sourceID == sourceID
    }

    /// Records the looked-up days and their memories at once: `memories` (day → snapshot, with the photo bytes of the
    /// ones not stored yet in `photos`, by file name) replaces whatever the store had; days before `days.lowerBound`
    /// are dropped.
    public func replaceMemories(days: ClosedRange<String>, memories: [String: WidgetSnapshot], photos: [String: Data]) throws {
        guard Self.isValidDay(days.lowerBound), Self.isValidDay(days.upperBound) else { throw StoreError.invalidFileName(days.lowerBound) }
        for (day, snapshot) in memories {
            guard Self.isValidDay(day) else { throw StoreError.invalidFileName(day) }
            try Self.validateFileName(snapshot.photoFileName)
        }
        for (name, data) in photos {
            try Self.validateFileName(name)
            try write(data, to: memoriesDirectory.appendingPathComponent(name))
        }
        let names = (try? FileManager.default.contentsOfDirectory(atPath: memoriesDirectory.path)) ?? []
        for name in names where name.hasSuffix(".json") && name != Self.memoryDaysFileName {
            let day = String(name.dropLast(5))
            if memories[day] == nil { try removeIfPresent(memoriesDirectory.appendingPathComponent(name)) }
        }
        for (day, snapshot) in memories {
            try write(try Self.encoder.encode(snapshot), to: memoriesDirectory.appendingPathComponent("\(day).json"))
        }
        try write(try Self.encoder.encode(["from": days.lowerBound, "through": days.upperBound]),
                  to: memoriesDirectory.appendingPathComponent(Self.memoryDaysFileName))
    }

    /// `yyyy-MM-dd` of `date` in `calendar` (the device's).
    public static func dayString(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0) // provenance-ok: ISO date key, not UI
    }

    static func isValidDay(_ value: String) -> Bool {
        let bytes = Array(value.utf8)
        guard bytes.count == 10, bytes[4] == 0x2D, bytes[7] == 0x2D else { return false }
        return bytes.enumerated().allSatisfy { index, byte in index == 4 || index == 7 || (byte >= 0x30 && byte <= 0x39) }
    }

    // MARK: Internals

    var memoriesDirectory: URL {
        rootURL.appendingPathComponent(Self.memoriesDirectoryName, isDirectory: true)
    }

    func personDirectory(_ personID: String) -> URL {
        rootURL.appendingPathComponent(Self.peopleDirectoryName, isDirectory: true).appendingPathComponent(personID, isDirectory: true)
    }

    func storedPersonIDs() -> [String] {
        let directory = rootURL.appendingPathComponent(Self.peopleDirectoryName, isDirectory: true)
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        return names.filter(Self.isValidIdentifier).sorted()
    }

    private func existing(_ directory: URL, _ fileName: String) -> URL? {
        guard Self.isValidFileName(fileName) else { return nil }
        let url = directory.appendingPathComponent(fileName, isDirectory: false)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Removes the friend and memory snapshots `matches` selects (a deleted photo, a group left). Returns whether any was
    /// removed. Their renditions go with the next prune.
    @discardableResult
    func removeExtraSnapshots(where matches: (WidgetSnapshot) -> Bool) throws -> Bool {
        var removed = false
        for personID in storedPersonIDs() {
            let url = personDirectory(personID).appendingPathComponent(Self.personSnapshotFileName)
            guard let data = try? Data(contentsOf: url), let snapshot = try? Self.decoder.decode(WidgetSnapshot.self, from: data),
                  matches(snapshot) else { continue }
            try removeIfPresent(url)
            if let photo = Self.isValidFileName(snapshot.photoFileName) ? personDirectory(personID).appendingPathComponent(snapshot.photoFileName) : nil {
                try removeIfPresent(photo)
            }
            removed = true
        }
        let names = (try? FileManager.default.contentsOfDirectory(atPath: memoriesDirectory.path)) ?? []
        for name in names where name.hasSuffix(".json") && name != Self.memoryDaysFileName {
            let url = memoriesDirectory.appendingPathComponent(name)
            guard let data = try? Data(contentsOf: url), let snapshot = try? Self.decoder.decode(WidgetSnapshot.self, from: data),
                  matches(snapshot) else { continue }
            try removeIfPresent(url)
            if Self.isValidFileName(snapshot.photoFileName) {
                try removeIfPresent(memoriesDirectory.appendingPathComponent(snapshot.photoFileName))
            }
            removed = true
        }
        return removed
    }

    /// Deletes friend and memory files no snapshot references, last modified before `cutoff`. Returns how many.
    func pruneExtras(cutoff: Date) throws -> Int {
        var deleted = 0
        func prune(_ directory: URL, keep: Set<String>) throws {
            let contents = (try? FileManager.default.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]
            )) ?? []
            for url in contents where !keep.contains(url.lastPathComponent) && !url.hasDirectoryPath {
                let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                guard let modified, modified < cutoff else { continue }
                try removeIfPresent(url)
                deleted += 1
            }
        }
        for personID in storedPersonIDs() {
            var keep: Set<String> = [Self.personSnapshotFileName]
            let url = personDirectory(personID).appendingPathComponent(Self.personSnapshotFileName)
            if let data = try? Data(contentsOf: url), let snapshot = try? Self.decoder.decode(WidgetSnapshot.self, from: data) {
                keep.insert(snapshot.photoFileName)
                if let avatar = snapshot.senderAvatarFileName { keep.insert(avatar) }
            }
            try prune(personDirectory(personID), keep: keep)
        }
        var keep: Set<String> = [Self.memoryDaysFileName]
        let names = (try? FileManager.default.contentsOfDirectory(atPath: memoriesDirectory.path)) ?? []
        for name in names where name.hasSuffix(".json") && name != Self.memoryDaysFileName {
            keep.insert(name)
            if let data = try? Data(contentsOf: memoriesDirectory.appendingPathComponent(name)),
               let snapshot = try? Self.decoder.decode(WidgetSnapshot.self, from: data) {
                keep.insert(snapshot.photoFileName)
            }
        }
        try prune(memoriesDirectory, keep: keep)
        return deleted
    }
}

/// The widget styles (design/surfaces/widget.styles.md, `widget.styles.layout.styles`): Photo is free; Date and Frame
/// are premium. A premium style chosen without premium draws Photo — the widget never stops working.
public enum WidgetPhotoStyle: String, CaseIterable, Codable, Hashable, Sendable {
    case photo
    case date
    case frame

    public var isPremium: Bool { self != .photo }

    /// The style the widget draws for a person with or without premium.
    public func drawn(isPremium premium: Bool) -> WidgetPhotoStyle {
        isPremium && !premium ? .photo : self
    }

    /// Chosen but not drawn: the widget's tap opens the paywall (once per session) before its usual destination.
    public func isLocked(isPremium premium: Bool) -> Bool {
        isPremium && !premium
    }
}
