import Foundation

/// One upcoming plan as the countdown widget shows it (`widget.countdown`): written by the app from `next_plans()` on
/// every foreground and after the member's own plan changes, read by the widget's timeline provider. Canceled and past
/// plans are never written (`next_plans` leaves them out).
public struct PlanWidgetSnapshot: Codable, Hashable, Sendable, Identifiable {
    public var planID: String
    public var groupID: String
    public var groupName: String
    public var title: String
    /// The plan's day in its group's time zone (`YYYY-MM-DD`): the countdown compares calendar dates.
    public var localDate: String
    public var startsAt: Date
    /// The downloaded cover inside the store's plans folder, when the plan has one.
    public var coverFileName: String?

    public var id: String { planID }

    public init(
        planID: String, groupID: String, groupName: String, title: String, localDate: String, startsAt: Date,
        coverFileName: String? = nil
    ) {
        self.planID = planID
        self.groupID = groupID
        self.groupName = groupName
        self.title = title
        self.localDate = localDate
        self.startsAt = startsAt
        self.coverFileName = coverFileName
    }

    enum CodingKeys: String, CodingKey {
        case planID = "plan_id"
        case groupID = "group_id"
        case groupName = "group_name"
        case title
        case localDate = "local_date"
        case startsAt = "starts_at"
        case coverFileName = "cover_file"
    }
}

extension WidgetKind {
    /// `AppIntentConfiguration` kind of the countdown widget (`widget.countdown`); reload it when plans change.
    public static let planCountdown = "PlanCountdownWidget"
}

/// The countdown's day arithmetic (`widget.countdown` "The countdown line"): days are counted between calendar dates —
/// the plan's `local_date` (group time zone) against today in the device's calendar — never 24-hour spans, so
/// "Tomorrow" never shows for a plan 30 hours away on the day after tomorrow. Nothing here formats text.
public enum PlanCountdown {
    /// Year, month and day of a `YYYY-MM-DD` date.
    static func components(of localDate: String) -> DateComponents? {
        let parts = localDate.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
              (1...12).contains(month), (1...31).contains(day) else { return nil }
        return DateComponents(year: year, month: month, day: day)
    }

    /// A calendar date as a day count (proleptic Gregorian in UTC, so no zone or daylight-saving shift applies).
    private static func dayNumber(_ components: DateComponents) -> Int? {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC") ?? .current // provenance-ok: arithmetic zone, not shown
        guard let date = utc.date(from: DateComponents(year: components.year, month: components.month, day: components.day)) else {
            return nil
        }
        return Int((date.timeIntervalSince1970 / 86_400).rounded(.down)) // provenance-ok: seconds per day (arithmetic)
    }

    /// Whole calendar days from the day `now` falls on in `calendar` to `localDate`; negative once the day has passed.
    public static func days(until localDate: String, from now: Date, calendar: Calendar) -> Int? {
        guard let plan = components(of: localDate).flatMap(dayNumber) else { return nil }
        let today = calendar.dateComponents([.year, .month, .day], from: now)
        guard let start = dayNumber(today) else { return nil }
        return plan - start
    }

    /// The plan the widget features at `now`: the soonest whose day is today or later, of `groupID` (nil = all groups).
    public static func featured(_ plans: [PlanWidgetSnapshot], groupID: String?, at now: Date, calendar: Calendar) -> PlanWidgetSnapshot? {
        plans
            .filter { groupID == nil || $0.groupID == groupID }
            .filter { (days(until: $0.localDate, from: now, calendar: calendar) ?? -1) >= 0 }
            .min { lhs, rhs in lhs.startsAt == rhs.startsAt ? lhs.planID < rhs.planID : lhs.startsAt < rhs.startsAt }
    }

    /// The timeline's entry dates (`widget.countdown` "Data & actions"): `now`, then each following local midnight up to
    /// and including the day after `lastDay` (that entry falls through to the next plan), at most `maxEntries` dates —
    /// the timeline is rebuilt at its end (`.atEnd`).
    public static func entryDates(through lastDay: String?, from now: Date, calendar: Calendar, maxEntries: Int) -> [Date] {
        var dates = [now]
        guard let lastDay, let remaining = days(until: lastDay, from: now, calendar: calendar), remaining >= 0 else { return dates }
        var midnight = calendar.startOfDay(for: now)
        for _ in 0...remaining {
            guard dates.count < maxEntries, let next = calendar.date(byAdding: .day, value: 1, to: midnight) else { break }
            midnight = next
            dates.append(next)
        }
        return dates
    }
}

/// File layout of the countdown widget's data inside `WidgetStore` (next to the group folders, which
/// `WidgetStore.syncGroups` and `prune` manage; sign-out removes it with the whole store):
///
///     <container>/WidgetStore/plans/plans.json     [PlanWidgetSnapshot], soonest first
///     <container>/WidgetStore/plans/<file>         downloaded covers
extension WidgetStore {
    static let plansDirectoryName = "plans"
    static let plansFileName = "plans.json"

    public var plansDirectory: URL {
        rootURL.appendingPathComponent(Self.plansDirectoryName, isDirectory: true)
    }

    /// Whether the app has written the plan list on this device (signed in at least once since the last sign-out).
    public var hasPlanList: Bool {
        FileManager.default.fileExists(atPath: plansDirectory.appendingPathComponent(Self.plansFileName).path)
    }

    /// Writes a cover into the plans folder and returns its URL. Write it before the list that references it.
    @discardableResult
    public func writePlanFile(_ data: Data, fileName: String) throws -> URL {
        try Self.validateFileName(fileName)
        let url = plansDirectory.appendingPathComponent(fileName, isDirectory: false)
        try writeAtomically(data, to: url)
        return url
    }

    /// The cover file of `snapshot`, when it is on disk.
    public func coverURL(for snapshot: PlanWidgetSnapshot) -> URL? {
        guard let name = snapshot.coverFileName, Self.isValidFileName(name) else { return nil }
        let url = plansDirectory.appendingPathComponent(name, isDirectory: false)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Replaces the plan list, then deletes cover files the new list no longer references.
    public func savePlans(_ plans: [PlanWidgetSnapshot]) throws {
        for plan in plans {
            try Self.validateIdentifier(plan.planID)
            try Self.validateIdentifier(plan.groupID)
            if let cover = plan.coverFileName { try Self.validateFileName(cover) }
        }
        try writeAtomically(try Self.encoder.encode(plans), to: plansDirectory.appendingPathComponent(Self.plansFileName))
        var keep = Set(plans.compactMap(\.coverFileName))
        keep.insert(Self.plansFileName)
        let names = (try? FileManager.default.contentsOfDirectory(atPath: plansDirectory.path)) ?? []
        for name in names where !keep.contains(name) {
            try? FileManager.default.removeItem(at: plansDirectory.appendingPathComponent(name))
        }
    }

    /// The plan list the app last wrote (empty when none).
    public func plans() -> [PlanWidgetSnapshot] {
        guard let data = try? Data(contentsOf: plansDirectory.appendingPathComponent(Self.plansFileName)) else { return [] }
        return (try? Self.decoder.decode([PlanWidgetSnapshot].self, from: data)) ?? []
    }

    /// Atomic write with the store's file protection (readable after the first unlock, as the group snapshots).
    private func writeAtomically(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        #if canImport(Darwin)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try data.write(to: url, options: [.atomic])
        #endif
    }
}
