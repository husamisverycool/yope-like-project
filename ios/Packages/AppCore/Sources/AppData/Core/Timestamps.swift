import AppModels
import Foundation

/// Parses and formats the API's `timestamptz` text (docs/API.md §1), e.g.
/// `2026-10-15T13:35:09.329469+00:00`, without `DateFormatter` (not thread-safe on every
/// platform) and with microsecond precision, so a `created_at` read from one page can be sent
/// back as a pagination cursor (`.lt("created_at", …)`, `p_before`) without skipping rows that
/// share its millisecond.
public enum Timestamp {
    /// Accepts `YYYY-MM-DD[T ]HH:MM[:SS[.fraction]][Z|±HH[:MM]|±HHMM]`; no offset means UTC.
    public static func parse(_ text: String) -> Date? {
        let bytes = Array(text.utf8)
        var index = 0

        func digits(_ count: Int) -> Int? {
            guard index + count <= bytes.count else { return nil }
            var value = 0
            for offset in 0..<count {
                let byte = bytes[index + offset]
                guard byte >= 0x30, byte <= 0x39 else { return nil }
                value = value * 10 + Int(byte - 0x30)
            }
            index += count
            return value
        }
        func expect(_ byte: UInt8) -> Bool {
            guard index < bytes.count, bytes[index] == byte else { return false }
            index += 1
            return true
        }

        guard let year = digits(4), expect(0x2D), let month = digits(2), expect(0x2D), let day = digits(2) else { return nil }
        guard index < bytes.count, bytes[index] == 0x54 || bytes[index] == 0x74 || bytes[index] == 0x20 else { return nil }
        index += 1
        guard let hour = digits(2), expect(0x3A), let minute = digits(2) else { return nil }
        var second = 0
        var fraction = 0.0
        if expect(0x3A) {
            guard let value = digits(2) else { return nil }
            second = value
            if expect(0x2E) || expect(0x2C) {
                var scale = 0.1
                var sawDigit = false
                while index < bytes.count, bytes[index] >= 0x30, bytes[index] <= 0x39 {
                    fraction += Double(bytes[index] - 0x30) * scale
                    scale /= 10
                    index += 1
                    sawDigit = true
                }
                guard sawDigit else { return nil }
            }
        }

        var offsetSeconds = 0
        if index < bytes.count {
            let sign = bytes[index]
            if sign == 0x5A || sign == 0x7A { // Z
                index += 1
            } else if sign == 0x2B || sign == 0x2D { // + -
                index += 1
                guard let offsetHours = digits(2) else { return nil }
                var offsetMinutes = 0
                if expect(0x3A) {
                    guard let value = digits(2) else { return nil }
                    offsetMinutes = value
                } else if let value = digits(2) {
                    offsetMinutes = value
                }
                offsetSeconds = (offsetHours * 3600 + offsetMinutes * 60) * (sign == 0x2D ? -1 : 1)
            } else {
                return nil
            }
        }
        guard index == bytes.count else { return nil }
        guard (1...12).contains(month), (1...31).contains(day), hour < 24, minute < 60, second < 61 else { return nil }

        let days = Self.daysFromCivil(year: year, month: month, day: day)
        let whole = days * 86_400 + hour * 3600 + minute * 60 + second - offsetSeconds
        return Date(timeIntervalSince1970: Double(whole) + fraction)
    }

    /// `YYYY-MM-DDTHH:MM:SS.ffffffZ` (UTC, microseconds).
    public static func format(_ date: Date) -> String {
        let micros = Int64((date.timeIntervalSince1970 * 1_000_000).rounded())
        var seconds = micros / 1_000_000
        var fraction = micros % 1_000_000
        if fraction < 0 {
            fraction += 1_000_000
            seconds -= 1
        }
        var days = seconds / 86_400
        var secondOfDay = seconds % 86_400
        if secondOfDay < 0 {
            secondOfDay += 86_400
            days -= 1
        }
        let civil = civilFromDays(Int(days))
        let hour = Int(secondOfDay / 3600)
        let minute = Int((secondOfDay % 3600) / 60)
        let second = Int(secondOfDay % 60)
        return pad(civil.year, 4) + "-" + pad(civil.month, 2) + "-" + pad(civil.day, 2)
            + "T" + pad(hour, 2) + ":" + pad(minute, 2) + ":" + pad(second, 2)
            + "." + pad(Int(fraction), 6) + "Z"
    }

    // Howard Hinnant's civil-from-days algorithms (proleptic Gregorian, days since 1970-01-01).
    static func daysFromCivil(year: Int, month: Int, day: Int) -> Int {
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let mp = (month + 9) % 12
        let doy = (153 * mp + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146_097 + doe - 719_468
    }

    static func civilFromDays(_ days: Int) -> (year: Int, month: Int, day: Int) {
        let z = days + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let doe = z - era * 146_097
        let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let day = doy - (153 * mp + 2) / 5 + 1
        let month = mp < 10 ? mp + 3 : mp - 9
        return (yoe + era * 400 + (month <= 2 ? 1 : 0), month, day)
    }

    static func pad(_ value: Int, _ width: Int) -> String {
        let text = String(value)
        return text.count >= width ? text : String(repeating: "0", count: width - text.count) + text
    }
}

/// A calendar day without a time or zone (`date`, `YYYY-MM-DD`): birthdays, `local_date`,
/// `week_start`, the date passed to `on_this_day`.
public struct LocalDate: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    public init?(year: Int, month: Int, day: Int) {
        guard (1...9999).contains(year), (1...12).contains(month), (1...31).contains(day) else { return nil }
        // Rejects 2026-02-30 and the like by round-tripping through the day count.
        let civil = Timestamp.civilFromDays(Timestamp.daysFromCivil(year: year, month: month, day: day))
        guard civil.year == year, civil.month == month, civil.day == day else { return nil }
        self.year = year
        self.month = month
        self.day = day
    }

    /// `YYYY-MM-DD`
    public init?(_ text: String) {
        let parts = text.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]) else { return nil }
        self.init(year: year, month: month, day: day)
    }

    /// The calendar day `date` falls on in `timeZone` (a group's IANA zone for group-local days).
    public init(_ date: Date, in timeZone: TimeZone) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        self.year = parts.year ?? 1970
        self.month = parts.month ?? 1
        self.day = parts.day ?? 1
    }

    public var description: String {
        Timestamp.pad(year, 4) + "-" + Timestamp.pad(month, 2) + "-" + Timestamp.pad(day, 2)
    }

    /// Days since 1970-01-01.
    public var dayNumber: Int { Timestamp.daysFromCivil(year: year, month: month, day: day) }

    public func adding(days: Int) -> LocalDate {
        let civil = Timestamp.civilFromDays(dayNumber + days)
        return LocalDate(year: civil.year, month: civil.month, day: civil.day)!
    }

    public static func < (lhs: LocalDate, rhs: LocalDate) -> Bool { lhs.dayNumber < rhs.dayNumber }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        guard let value = LocalDate(text) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date \(text)")
        }
        self = value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}

/// JSON coders matching the API's wire format: timestamps as ISO 8601 text with microseconds.
/// Used for PostgREST, RPC bodies, realtime records and the offline cache.
public enum DataCoding {
    public static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            guard let date = Timestamp.parse(text) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid timestamp \(text)")
            }
            return date
        }
        return decoder
    }

    public static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(Timestamp.format(date))
        }
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

extension LocalTime {
    /// `HH:MM:SS`, the form RPC `time` parameters accept.
    var wireValue: String { description + ":00" }
}
