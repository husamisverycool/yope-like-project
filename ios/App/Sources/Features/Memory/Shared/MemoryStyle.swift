// Value formats of the memory surfaces, each the date format token its spec names (layout.*.dateFormat). Text roles
// are the global ones (Components/TextRoles.swift, `TextRole`); nothing here chooses a size, weight or colour.
import AppData
import DesignSystem
import Foundation

enum MemoryFormat {
    /// The memory's date on the Rewind page (`layout.onthisday.dateFormat`: medium date, "Jul 22, 2022"), in the
    /// group's time zone.
    static func memoryDate(_ date: Date, timeZone: TimeZone, locale: Locale = .current) -> String {
        var style = Date.FormatStyle(date: .abbreviated, time: .omitted)
        style.timeZone = timeZone
        style.locale = locale
        return date.formatted(style)
    }

    /// Day and month only (`layout.birthday.add.dateFormat`, "July 5"): the saved birthday and the On This Day entry's
    /// `{date}`. The year is never shown.
    static func dayMonth(_ day: LocalDate, locale: Locale = .current) -> String {
        var style = Date.FormatStyle().month(.wide).day()
        style.timeZone = utc
        style.locale = locale
        return calendarDate(day).formatted(style)
    }

    /// Weekday, month and day (`layout.year.story.dateFormat` / `layout.birthday.request.dueDate`:
    /// "Wednesday, July 5"): year-story photo and collage cards, the share sheet's title on Rewind, the request's
    /// due line.
    static func weekdayMonthDay(_ day: LocalDate, locale: Locale = .current) -> String {
        var style = Date.FormatStyle().weekday(.wide).month(.wide).day()
        style.timeZone = utc
        style.locale = locale
        return calendarDate(day).formatted(style)
    }

    /// `{date}` of `birthday.request.due`: the day before the birthday (`layout.birthday.request.dueDate`) — a date,
    /// never a countdown.
    static func dueDate(birthday: LocalDate, locale: Locale = .current) -> String {
        weekdayMonthDay(birthday.adding(days: -1), locale: locale)
    }

    /// A month on a year-story card (`layout.year.story.monthFormat`, "December"); `month` is 1–12.
    static func storyMonth(_ month: Int, year: Int, locale: Locale = .current) -> String? {
        guard let day = LocalDate(year: year, month: month, day: 1) else { return nil }
        var style = Date.FormatStyle().month(.wide)
        style.timeZone = utc
        style.locale = locale
        return calendarDate(day).formatted(style)
    }

    /// A position as the locale writes whole numbers ("3" of "12").
    static func number(_ value: Int, locale: Locale = .current) -> String {
        value.formatted(.number.locale(locale))
    }

    /// First names joined the locale's way ("Ana, Bea and Caio"; `ListFormatter`, the platform list formatter).
    static func names(_ names: [String], locale: Locale = .current) -> String {
        let formatter = ListFormatter()
        formatter.locale = locale
        return formatter.string(from: names) ?? names.joined(separator: " ") // provenance-ok: fallback separator when the formatter returns nil
    }

    static let utc = TimeZone(identifier: "UTC")! // provenance-ok: time zone used to format calendar days without shifting them

    /// Noon UTC on that day, so formatting in UTC never moves it to a neighbouring day.
    static func calendarDate(_ day: LocalDate) -> Date {
        Date(timeIntervalSince1970: TimeInterval(day.dayNumber) * 86_400 + 43_200) // provenance-ok: seconds per day / half a day (calendar arithmetic)
    }
}
