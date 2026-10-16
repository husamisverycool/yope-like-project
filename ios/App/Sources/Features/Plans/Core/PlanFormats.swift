// Dates, times and name lists of the plan surfaces, all formatted by the platform in the person's locale
// (plans.create "date / time rows", plans.page "Meta lines" and "Who's coming", camera.overnight `{reveal}`): no text
// here is typed by us.
import AppData
import DesignSystem
import Foundation

enum PlanFormats {
    private static func formatter(timeZone: TimeZone, date: DateFormatter.Style, time: DateFormatter.Style, relative: Bool = false) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeZone = timeZone
        formatter.dateStyle = date
        formatter.timeStyle = time
        formatter.doesRelativeDateFormatting = relative
        return formatter
    }

    /// Noon of a group-local day: a time inside the day whatever its daylight-saving changes, for formatting the day.
    static func noon(of day: LocalDate, in timeZone: TimeZone) -> Date {
        PlanCalendar.start(of: day, in: timeZone).addingTimeInterval(12 * 3600) // provenance-ok: noon (arithmetic)
    }

    /// plans.page meta line 1: the locale's full date and short time ("Saturday, October 24, 2026 at 7:30 PM"); an
    /// all-day plan: the date alone. On the plan's day the spec asks for the platform's "today" word + time — that word
    /// is BLOCKED (plans.md §12 item 2), so only DEBUG builds use it; release builds keep the full date.
    static func whenLine(startsAt: Date, allDay: Bool, localDate: LocalDate, timeZone: TimeZone, now: Date) -> String {
        #if DEBUG
        let relative = LocalDate(now, in: timeZone) == localDate
        #else
        let relative = false
        #endif
        if allDay {
            return formatter(timeZone: timeZone, date: .full, time: .none, relative: relative)
                .string(from: noon(of: localDate, in: timeZone))
        }
        return formatter(timeZone: timeZone, date: .full, time: .short, relative: relative).string(from: startsAt)
    }

    /// plans.create date row value: the locale's medium date ("Oct 24, 2026").
    static func mediumDate(_ date: Date, timeZone: TimeZone) -> String {
        formatter(timeZone: timeZone, date: .medium, time: .none).string(from: date)
    }

    /// plans.create time row value and the plan row's time: the locale's short time ("7:30 PM").
    static func shortTime(_ date: Date, timeZone: TimeZone) -> String {
        formatter(timeZone: timeZone, date: .none, time: .short).string(from: date)
    }

    /// The groups.screen plan row's line: the medium date (+ short time unless all-day).
    static func rowLine(startsAt: Date, allDay: Bool, localDate: LocalDate, timeZone: TimeZone) -> String {
        if allDay {
            return formatter(timeZone: timeZone, date: .medium, time: .none).string(from: noon(of: localDate, in: timeZone))
        }
        return formatter(timeZone: timeZone, date: .medium, time: .short).string(from: startsAt)
    }

    /// First names joined by the platform list formatter ("Ana, Ben, and Chloe").
    static func names(_ names: [String]) -> String {
        ListFormatter.localizedString(byJoining: names)
    }

    /// `{reveal}` of `camera.overnight.tile.a11y`: the relative day and time ("tomorrow at 9:00 AM").
    static func reveal(_ date: Date) -> String {
        formatter(timeZone: .current, date: .medium, time: .short, relative: true).string(from: date)
    }
}

/// The weekly question's text from the app's copy by its key (`question.weekly.q01` … `q09`, the keys the server
/// stores in `app_config.weekly_question_keys`); nil for a key this build does not know (the card is not shown).
enum QuestionCopy {
    static func text(forKey key: String) -> String? {
        switch key {
        case "question.weekly.q01": return Copy.questionWeeklyQ01 // provenance-ok: copy key
        case "question.weekly.q02": return Copy.questionWeeklyQ02 // provenance-ok: copy key
        case "question.weekly.q03": return Copy.questionWeeklyQ03 // provenance-ok: copy key
        case "question.weekly.q04": return Copy.questionWeeklyQ04 // provenance-ok: copy key
        case "question.weekly.q05": return Copy.questionWeeklyQ05 // provenance-ok: copy key
        case "question.weekly.q06": return Copy.questionWeeklyQ06 // provenance-ok: copy key
        case "question.weekly.q07": return Copy.questionWeeklyQ07 // provenance-ok: copy key
        case "question.weekly.q08": return Copy.questionWeeklyQ08 // provenance-ok: copy key
        case "question.weekly.q09": return Copy.questionWeeklyQ09 // provenance-ok: copy key
        default: return nil
        }
    }
}
