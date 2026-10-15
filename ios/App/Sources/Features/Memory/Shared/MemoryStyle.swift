// Text roles and value formats of the memory surfaces, assembled from tokens only
// (design/tokens/README.md "A text role"; layout.*.textStyleMap; layout.*.dateFormat).
import AppData
import DesignSystem
import Foundation
import SwiftUI

enum MemoryType {
    /// Roles whose weight was not measured (no `fontWeight.*` token): the platform's default
    /// weight applies, as the platform's default leading applies where no line height was measured.
    static let platformDefaultWeight: Font.Weight = .regular // provenance-ok: platform default weight, no fontWeight token for the role

    /// The SwiftUI text style named by a `layout.*.textStyleMap` token value.
    static func textStyle(_ name: String) -> Font.TextStyle {
        switch name {
        case "largeTitle": return .largeTitle
        case "title", "title1": return .title
        case "title2": return .title2
        case "title3": return .title3
        case "headline": return .headline
        case "subheadline": return .subheadline
        case "callout": return .callout
        case "footnote": return .footnote
        case "caption", "caption1": return .caption
        case "caption2": return .caption2
        default: return .body
        }
    }

    static func style(
        _ family: DSFontFamily,
        size: CGFloat,
        weight: Font.Weight = platformDefaultWeight,
        relativeTo: String,
        lineHeight: CGFloat? = nil
    ) -> DSTextStyle {
        DSTextStyle(family: family, size: size, weight: weight, relativeTo: textStyle(relativeTo), lineHeight: lineHeight)
    }

    // MARK: Global roles (Yope foundations)

    static var emptyTitle: DSTextStyle {
        style(Tokens.Fonts.globalFamily, size: Tokens.FontSizes.globalEmptyTitle, weight: Tokens.FontWeights.fontWeightGlobalEmptyTitle,
              relativeTo: Tokens.Layouts.GlobalTextStyleMap.emptyTitle)
    }

    /// Rendered italic (token note: "Rendered italic in the reference; weight not measured").
    static var emptyDetail: DSTextStyle {
        style(Tokens.Fonts.globalFamily, size: Tokens.FontSizes.globalEmptyDetail, relativeTo: Tokens.Layouts.GlobalTextStyleMap.emptyDetail)
    }

    static var listTitle: DSTextStyle {
        style(Tokens.Fonts.globalFamily, size: Tokens.FontSizes.globalListTitle, weight: Tokens.FontWeights.fontWeightGlobalListTitle,
              relativeTo: Tokens.Layouts.GlobalTextStyleMap.listTitle)
    }

    static var listSubtitle: DSTextStyle {
        style(Tokens.Fonts.globalFamily, size: Tokens.FontSizes.globalListSubtitle, weight: Tokens.FontWeights.fontWeightGlobalListSubtitle,
              relativeTo: Tokens.Layouts.GlobalTextStyleMap.listSubtitle)
    }

    static var button: DSTextStyle {
        style(Tokens.Fonts.globalFamily, size: Tokens.FontSizes.globalButton, weight: Tokens.FontWeights.fontWeightGlobalButton,
              relativeTo: Tokens.Layouts.GlobalTextStyleMap.button)
    }

    static var onboardingTitle: DSTextStyle {
        style(Tokens.Fonts.globalFamily, size: Tokens.FontSizes.globalOnboardingTitle, weight: Tokens.FontWeights.fontWeightGlobalOnboardingTitle,
              relativeTo: Tokens.Layouts.GlobalTextStyleMap.onboardingTitle)
    }

    static var sheetTitle: DSTextStyle {
        style(Tokens.Fonts.globalFamily, size: Tokens.FontSizes.globalSheetTitle, weight: Tokens.FontWeights.fontWeightGlobalSheetTitle,
              relativeTo: Tokens.Layouts.GlobalTextStyleMap.sheetTitle)
    }
}

// MARK: - Formats

enum MemoryFormat {
    /// "1 YEAR AGO" / "3 YEARS AGO" (`onthisday.banner.yearsAgo.*`).
    static func yearsAgo(_ years: Int) -> String {
        years == 1 ? Copy.onthisdayBannerYearsAgoOne : Copy.onthisdayBannerYearsAgoOther(count: String(years))
    }

    /// `{weekday}` of `onthisday.memory.meta`: abbreviated and upper-cased ("TUE"), group time zone.
    static func metaWeekday(_ date: Date, timeZone: TimeZone, locale: Locale = .current) -> String {
        formatter(pattern: "EEE", timeZone: timeZone, locale: locale).string(from: date).uppercased(with: locale) // provenance-ok: Unicode date-field pattern for "TUE" (onthisday.memory.meta example)
    }

    /// The weekday in full for VoiceOver ("Tuesday"; spec: "spoken weekday in full").
    static func spokenWeekday(_ date: Date, timeZone: TimeZone, locale: Locale = .current) -> String {
        formatter(pattern: "EEEE", timeZone: timeZone, locale: locale).string(from: date) // provenance-ok: Unicode date-field pattern, full weekday name
    }

    /// `{time}` of `onthisday.memory.meta` ("10:34 PM"): the locale's short time, group time zone.
    static func metaTime(_ date: Date, timeZone: TimeZone, locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// `{date}` of `birthday.request.due`: the day before the birthday, full date
    /// (`layout.birthday.request.dueDate`; iOS `Date.FormatStyle(date: .complete)`).
    static func dueDate(birthday: LocalDate, locale: Locale = .current) -> String {
        let day = birthday.adding(days: -1)
        var style = Date.FormatStyle(date: .complete, time: .omitted)
        style.timeZone = utc
        style.locale = locale
        return calendarDate(day).formatted(style)
    }

    /// Day and month only (`layout.birthday.add.dateFormat`, "26 May"); the year is never shown.
    static func birthdayDayMonth(_ date: LocalDate, locale: Locale = .current) -> String {
        formatter(pattern: Tokens.Layouts.BirthdayAddDateFormat.pattern, timeZone: utc, locale: locale).string(from: calendarDate(date))
    }

    /// A day on a year-story card (`layout.year.story.dateFormat`, "February 25").
    static func storyDate(_ date: LocalDate, locale: Locale = .current) -> String {
        formatter(pattern: Tokens.Layouts.YearStoryDateFormat.pattern, timeZone: utc, locale: locale).string(from: calendarDate(date))
    }

    /// A month on a year-story card (`layout.year.story.monthFormat`, "January"); `month` is 1–12.
    static func storyMonth(_ month: Int, year: Int, locale: Locale = .current) -> String? {
        guard let day = LocalDate(year: year, month: month, day: 1) else { return nil }
        return formatter(pattern: Tokens.Layouts.YearStoryMonthFormat.pattern, timeZone: utc, locale: locale).string(from: calendarDate(day))
    }

    /// The group-local calendar day of an instant.
    static func localDate(_ date: Date, timeZone: TimeZone) -> LocalDate {
        LocalDate(date, in: timeZone)
    }

    static let utc = TimeZone(identifier: "UTC")! // provenance-ok: time zone used to format calendar days without shifting them

    /// Noon UTC on that day, so formatting in UTC never moves it to a neighbouring day.
    static func calendarDate(_ day: LocalDate) -> Date {
        Date(timeIntervalSince1970: TimeInterval(day.dayNumber) * 86_400 + 43_200) // provenance-ok: seconds per day / half a day (calendar arithmetic)
    }

    private static func formatter(pattern: String, timeZone: TimeZone, locale: Locale) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateFormat = pattern
        return formatter
    }
}

/// Colours that a layout token stores as text (e.g. `layout.year.story.summary.dots` selectedColor /
/// unselectedColor), in the token file's hex form: six digits (opaque) or eight (last pair = alpha).
enum MemoryTokenColor {
    struct Components: Equatable {
        let red: Double
        let green: Double
        let blue: Double
        let opacity: Double
    }

    /// The channels of `text`, each 0…1; nil when it is not a hex colour.
    static func components(_ text: String) -> Components? {
        var digits = text.trimmingCharacters(in: .whitespaces)
        if digits.first == "#" { digits.removeFirst() }
        guard digits.count == 6 || digits.count == 8, digits.allSatisfy(\.isHexDigit),
              let value = UInt64(digits, radix: 16) else { return nil }
        let rgba = digits.count == 8 ? value : value << 8 | 0xFF
        func channel(_ byte: UInt64) -> Double {
            Double(rgba >> (byte * 8) & 0xFF) / 0xFF
        }
        return Components(red: channel(3), green: channel(2), blue: channel(1), opacity: channel(0))
    }

    static func color(_ text: String) -> Color? {
        components(text).map {
            Color(.sRGB, red: $0.red, green: $0.green, blue: $0.blue, opacity: $0.opacity) // provenance-ok: channels parsed from the token's colour text
        }
    }
}
