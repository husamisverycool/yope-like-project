// Surfaces: camera.capture, camera.sendto, daily.capture, daily.dualimage, collage.view, collage.share.
// Reference images: listed in each design/surfaces/<id>.md. Formats of the capture group's data placeholders
// (design/copy/capture.json; `retro.voice.formats` in design/copy-patterns.md). Text roles are the global ones
// (Components/TextRoles.swift `TextRole`); the capture group defines no role of its own except the counter of the
// "Add a Message" sheet (`CaptureType.counter`).
import AppData
import AppModels
import DesignSystem
import Foundation
import SwiftUI

/// The one capture-specific text role: the "Add a Message" counter '58/250' (`camera.sendto.fontSize.counter` 16,
/// monospaced digits, Dynamic Type `camera.sendto.layout.textStyleMap.counter`). Its weight was not measured: the
/// platform's regular weight.
enum CaptureType {
    static var counter: DSTextStyle {
        DSTextStyle(
            family: Tokens.Fonts.globalFamily,
            size: Tokens.FontSizes.cameraSendtoFontSizeCounter,
            weight: Font.Weight.regular,
            relativeTo: Font.TextStyle(tokenName: Tokens.Layouts.CameraSendtoLayoutTextStyleMap.counter)
        )
    }
}

/// Formats of the capture surfaces' data placeholders.
enum CaptureFormat {
    /// `camera.capture.title` {number}: the ISO-8601 week of `date` (Monday first), the way `week.history` numbers weeks
    /// (`week.history.layout` weekNumber); the camera has no group, so the device's time zone.
    static func weekNumber(of date: Date, timeZone: TimeZone = .current) -> Int {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = timeZone
        return calendar.component(.weekOfYear, from: date)
    }

    /// `daily.capture.countdown`: MM:SS, both fields zero-padded, no label.
    static func countdown(remainingSeconds: Int) -> String {
        let seconds = max(0, remainingSeconds)
        return Copy.dailyCaptureCountdown(mm: twoDigits(seconds / 60), ss: twoDigits(seconds % 60))
    }

    /// The countdown's accessibility value: the platform's spoken duration
    /// (`Duration.formatted(.units(width: .wide))`, daily.capture Accessibility).
    static func spokenCountdown(remainingSeconds: Int) -> String {
        Duration.seconds(max(0, remainingSeconds)).formatted(.units(allowed: [.minutes, .seconds], width: .wide))
    }

    /// A voice note's length in `chat.voice.layout.durationFormat` (m:ss, whole seconds; Retro's "1:00").
    static func voiceDuration(milliseconds: Int) -> String {
        let seconds = max(0, milliseconds / 1000)
        return "\(seconds / 60):" + twoDigits(seconds % 60)
    }

    static func twoDigits(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }

    /// {date} of `collage.view.a11y.collage` and `collage.share.sheetTitle`: the invitation's group-local day in the
    /// locale's long date ("May 26, 2026" — `retro.voice.formats`: "May 1, 2019").
    static func collageDate(_ date: LocalDate, locale: Locale = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        let utc = TimeZone(identifier: "UTC") ?? .current
        calendar.timeZone = utc
        guard let day = calendar.date(from: DateComponents(year: date.year, month: date.month, day: date.day)) else {
            return date.description
        }
        var style = Date.FormatStyle(date: .long, time: .omitted)
        style.locale = locale
        style.timeZone = utc
        style.calendar = calendar
        return day.formatted(style)
    }

    /// {name} in member-facing texts: the first word of a display name (notifications.push, widget.home.small).
    static func firstName(_ displayName: String?) -> String {
        guard let displayName else { return "" }
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.split(separator: " ").first.map(String.init) ?? trimmed
    }

    /// `camera.sendto.message.counter` ('58/250').
    static func messageCounter(count: Int, max: Int) -> String {
        Copy.cameraSendtoMessageCounter(count: String(count), max: String(max))
    }
}
