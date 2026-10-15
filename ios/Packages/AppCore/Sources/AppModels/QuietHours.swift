import Foundation

/// A wall-clock time of day (`HH:mm` or Postgres `time` text `HH:mm:ss`).
public struct LocalTime: Hashable, Comparable, Sendable, Codable, CustomStringConvertible {
    public let hour: Int
    public let minute: Int

    public init?(hour: Int, minute: Int) {
        guard (0..<24).contains(hour), (0..<60).contains(minute) else { return nil }
        self.hour = hour
        self.minute = minute
    }

    public init?(_ text: String) {
        let parts = text.split(separator: ":")
        guard parts.count == 2 || parts.count == 3,
              let hour = Int(parts[0]), let minute = Int(parts[1]) else { return nil }
        if parts.count == 3 {
            // Seconds (possibly fractional) are accepted and ignored.
            guard Double(parts[2]) != nil else { return nil }
        }
        self.init(hour: hour, minute: minute)
    }

    public var minutesSinceMidnight: Int { hour * 60 + minute }

    public var description: String {
        let h = hour < 10 ? "0\(hour)" : "\(hour)"
        let m = minute < 10 ? "0\(minute)" : "\(minute)"
        return "\(h):\(m)"
    }

    public static func < (lhs: LocalTime, rhs: LocalTime) -> Bool {
        lhs.minutesSinceMidnight < rhs.minutesSinceMidnight
    }

    public init(from decoder: Decoder) throws {
        let text = try decoder.singleValueContainer().decode(String.self)
        guard let value = LocalTime(text) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid time \(text)"))
        }
        self = value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}

/// The user's quiet hours (`notification_settings`): a daily interval in the user's time zone
/// during which pushes stay silent. The server applies them when sending; the app uses the same
/// rule to show the current state.
///
/// `start == end` means no quiet hours. An interval whose end is earlier than its start wraps
/// past midnight (e.g. 22:00–07:00). The start is inclusive, the end exclusive.
public struct QuietHours: Hashable, Sendable, Codable {
    public var start: LocalTime
    public var end: LocalTime
    /// IANA identifier; nil uses the device's current time zone.
    public var timeZoneIdentifier: String?

    public init(start: LocalTime, end: LocalTime, timeZoneIdentifier: String? = nil) {
        self.start = start
        self.end = end
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    enum CodingKeys: String, CodingKey {
        case start = "quiet_start"
        case end = "quiet_end"
        case timeZoneIdentifier = "time_zone"
    }

    public var isEmpty: Bool { start == end }

    public var timeZone: TimeZone {
        timeZoneIdentifier.flatMap(TimeZone.init(identifier:)) ?? .current
    }

    /// Whether `date` falls inside quiet hours.
    public func contains(_ date: Date) -> Bool {
        guard !isEmpty else { return false }
        let minute = localMinute(of: date)
        let s = start.minutesSinceMidnight
        let e = end.minutesSinceMidnight
        return s < e ? (minute >= s && minute < e) : (minute >= s || minute < e)
    }

    /// When the quiet period containing `date` ends; nil when `date` is not inside quiet hours.
    public func currentPeriodEnd(after date: Date) -> Date? {
        guard contains(date) else { return nil }
        var components = DateComponents()
        components.hour = end.hour
        components.minute = end.minute
        components.second = 0
        return calendar.nextDate(after: date, matching: components, matchingPolicy: .nextTime)
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    private func localMinute(of date: Date) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }
}
