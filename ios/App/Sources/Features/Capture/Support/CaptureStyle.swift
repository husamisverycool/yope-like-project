// Surfaces: camera.capture, camera.sendto, daily.capture, daily.dualimage, collage.view, collage.share.
// Reference images: listed in each design/surfaces/<id>.md. Text roles and formats of the capture
// group, assembled from generated tokens (design/tokens/README.md "A text role") and copy.
import AppData
import AppModels
import DesignSystem
import Foundation
import SwiftUI

/// Resolves the Dynamic Type style names used by the token text-style maps
/// (`layout.global.textStyleMap`, `camera.capture.layout.textStyleMap`, …). Values such as
/// "headline (17 pt semibold, Dynamic Type)" resolve by their first word.
enum CaptureTextStyleName {
    static func resolve(_ name: String) -> Font.TextStyle {
        let first = name.split(whereSeparator: { $0 == " " || $0 == "," || $0 == "(" }).first.map(String.init) ?? name
        switch first {
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
}

/// Text roles of the capture surfaces. Every size, weight and Dynamic Type style is a token.
enum CaptureType {
    /// Roles whose weight was never measured have no weight token (design/tokens/README.md "Not
    /// available yet": placeholder / emptyDetail weight); they keep the platform's regular weight.
    /// `daily.capture.fontWeight.countdown` is BLOCKED and uses the same platform weight until its
    /// verification render closes it (design/surfaces/daily.capture.md Gaps).
    static let platformWeight: Font.Weight = .regular

    private static func role(_ size: CGFloat, _ weight: Font.Weight, _ style: String) -> DSTextStyle {
        DSTextStyle(family: Tokens.Fonts.globalFamily, size: size, weight: weight, relativeTo: CaptureTextStyleName.resolve(style))
    }

    // MARK: Global roles

    static var overlayTimeCamera: DSTextStyle {
        role(Tokens.FontSizes.globalOverlayTimeCamera, Tokens.FontWeights.fontWeightGlobalOverlayTimeCamera, Tokens.Layouts.GlobalTextStyleMap.overlayTimeCamera)
    }

    static var sheetTitle: DSTextStyle {
        role(Tokens.FontSizes.globalSheetTitle, Tokens.FontWeights.fontWeightGlobalSheetTitle, Tokens.Layouts.GlobalTextStyleMap.sheetTitle)
    }

    static var headerTitle: DSTextStyle {
        role(Tokens.FontSizes.globalHeaderTitle, Tokens.FontWeights.fontWeightGlobalHeaderTitle, Tokens.Layouts.GlobalTextStyleMap.headerTitle)
    }

    static var button: DSTextStyle {
        role(Tokens.FontSizes.globalButton, Tokens.FontWeights.fontWeightGlobalButton, Tokens.Layouts.GlobalTextStyleMap.button)
    }

    static var emptyTitle: DSTextStyle {
        role(Tokens.FontSizes.globalEmptyTitle, Tokens.FontWeights.fontWeightGlobalEmptyTitle, Tokens.Layouts.GlobalTextStyleMap.emptyTitle)
    }

    static var emptyDetail: DSTextStyle {
        role(Tokens.FontSizes.globalEmptyDetail, platformWeight, Tokens.Layouts.GlobalTextStyleMap.emptyDetail)
    }

    static var body: DSTextStyle {
        role(Tokens.FontSizes.globalBody, Tokens.FontWeights.fontWeightGlobalBody, Tokens.Layouts.GlobalTextStyleMap.body)
    }

    // MARK: camera.capture / camera.sendto

    static var coach: DSTextStyle {
        role(Tokens.FontSizes.cameraCaptureFontSizeCoach, Tokens.FontWeights.cameraCaptureFontWeightCoach, Tokens.Layouts.CameraCaptureLayoutTextStyleMap.coach)
    }

    static var sendCaption: DSTextStyle {
        role(Tokens.FontSizes.cameraSendtoFontSizeCaption, Tokens.FontWeights.cameraSendtoFontWeightCaption, Tokens.Layouts.CameraSendtoLayoutTextStyleMap.caption)
    }

    static var messagePlaceholder: DSTextStyle {
        role(Tokens.FontSizes.cameraSendtoFontSizeMessagePlaceholder, platformWeight, Tokens.Layouts.CameraSendtoLayoutTextStyleMap.messagePlaceholder)
    }

    static var countNumber: DSTextStyle {
        role(Tokens.FontSizes.cameraSendtoFontSizeCountNumber, Tokens.FontWeights.cameraSendtoFontWeightCountNumber, Tokens.Layouts.CameraSendtoLayoutTextStyleMap.countNumber)
    }

    // MARK: daily.capture

    static var countdown: DSTextStyle {
        role(Tokens.FontSizes.dailyCaptureFontSizeCountdown, platformWeight, Tokens.Layouts.DailyCaptureLayoutTextStyleMap.countdown)
    }

    static var prompt: DSTextStyle {
        role(Tokens.FontSizes.dailyCaptureFontSizePrompt, platformWeight, Tokens.Layouts.DailyCaptureLayoutTextStyleMap.prompt)
    }

    static var chip: DSTextStyle {
        role(Tokens.FontSizes.dailyCaptureFontSizeChip, platformWeight, Tokens.Layouts.DailyCaptureLayoutTextStyleMap.chip)
    }

    static var send: DSTextStyle {
        role(Tokens.FontSizes.dailyCaptureFontSizeSend, Tokens.FontWeights.dailyCaptureFontWeightSend, Tokens.Layouts.DailyCaptureLayoutTextStyleMap.send)
    }

    // MARK: collage.view / collage.share

    static var collageTitle: DSTextStyle {
        role(Tokens.FontSizes.collageViewFontSizeTitle, Tokens.FontWeights.collageViewFontWeightTitle, Tokens.Layouts.CollageViewLayoutTextStyleMap.title)
    }

    static var shareLabel: DSTextStyle {
        role(Tokens.FontSizes.collageShareFontSizeLabel, Tokens.FontWeights.collageShareFontWeightLabel, Tokens.Layouts.CollageShareLayoutTextStyleMap.label)
    }
}

/// Formats of the capture surfaces' data placeholders (design/copy/capture.json notes).
enum CaptureFormat {
    /// The start of the hour `date` falls in (the hour slot a photo is filed under).
    static func hourStart(of date: Date, calendar: Calendar = .current) -> Date {
        calendar.dateInterval(of: .hour, for: date)?.start ?? date
    }

    /// The next time the hour overlay changes.
    static func nextHour(after date: Date, calendar: Calendar = .current) -> Date {
        calendar.dateInterval(of: .hour, for: date)?.end ?? date
    }

    /// `camera.capture.hourOverlay`: {time} = start of the current hour, device short-time style.
    static func hourOverlay(at date: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let start = hourStart(of: date, calendar: calendar)
        var style = Date.FormatStyle(date: .omitted, time: .shortened)
        style.locale = locale
        style.timeZone = calendar.timeZone
        return Copy.cameraCaptureHourOverlay(time: start.formatted(style))
    }

    /// `daily.capture.countdown`: MM:SS, both fields zero-padded, no label.
    static func countdown(remainingSeconds: Int) -> String {
        let seconds = max(0, remainingSeconds)
        return Copy.dailyCaptureCountdown(mm: twoDigits(seconds / 60), ss: twoDigits(seconds % 60))
    }

    /// The countdown's accessibility value: the platform's spoken duration.
    static func spokenCountdown(remainingSeconds: Int) -> String {
        Duration.seconds(max(0, remainingSeconds)).formatted(.units(allowed: [.minutes, .seconds], width: .wide))
    }

    static func twoDigits(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }

    /// `collage.view.title` {date}: the invitation's group-local date as 'd Month' (en: '26 May').
    static func collageDate(_ date: LocalDate, locale: Locale = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        let utc = TimeZone(identifier: "UTC") ?? .current
        calendar.timeZone = utc
        guard let day = calendar.date(from: DateComponents(year: date.year, month: date.month, day: date.day)) else {
            return date.description
        }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = utc
        formatter.locale = locale
        formatter.dateFormat = "d MMMM"
        return formatter.string(from: day)
    }

    /// {name} in member-facing texts: the first word of a display name (docs: notifications.push).
    static func firstName(_ displayName: String?) -> String {
        guard let displayName else { return "" }
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.split(separator: " ").first.map(String.init) ?? trimmed
    }
}

extension DSAnimation {
    /// A spring with the platform default damping and the measured duration as its response
    /// (daily.capture Motion: "each is a spring with the platform default damping … and
    /// response = the measured duration"). `milliseconds` comes from a token.
    static func measured(milliseconds: CGFloat) -> DSAnimation {
        .spring(DSSpring(response: Double(milliseconds) / 1000, dampingFraction: Tokens.Springs.globalPlatformDefaultIos.dampingFraction))
    }
}
