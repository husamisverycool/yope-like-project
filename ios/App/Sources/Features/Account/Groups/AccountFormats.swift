// Account group — date and time formats named by the copy notes (`yope.voice.formats`): the platform's locale-aware
// formatters, no fixed pattern beyond what the copy note states.
import AppModels
import Foundation

enum AccountFormats {
    /// `{time}`: "h:mm AM/PM" — the locale's short time (`10:10 AM` in en_US).
    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    /// A wall-clock time (`LocalTime`) as "h:mm AM/PM" (invitation hours, quiet hours).
    static func time(_ time: LocalTime, calendar: Calendar = .current) -> String {
        Self.time(date(for: time, calendar: calendar))
    }

    /// Today at `time` (for `DatePicker(.hourAndMinute)` selections).
    static func date(for time: LocalTime, calendar: Calendar = .current, now: Date = Date()) -> Date {
        calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: now) ?? now
    }

    /// The wall-clock time of `date`.
    static func localTime(of date: Date, calendar: Calendar = .current) -> LocalTime? {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return LocalTime(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
    }
}
