// Surfaces: camera.capture (library pick) and share.in (design/surfaces/camera.capture.md, share.in.md). The day a
// library photo was taken, for `media.taken_on` (migration 0050; docs/RESEARCH_FEATURES_2026-10-17.md #5, Retro's
// "backfill the weeks"): the date only, read from the file's own capture date — EXIF DateTimeOriginal for photos, the
// QuickTime creation date for videos — in the device's time zone. Never a time and never a place: no location key is
// read, and the photo is re-encoded without metadata before upload (CaptureDraftBuilder). The system photo picker needs
// no library access for this (PLATFORM_CONSTRAINTS §6).
import AppData
@preconcurrency import AVFoundation
import Foundation
import ImageIO

enum CaptureTakenOn {
    /// The first day the server accepts (`media.taken_on` check, migration 0050).
    static let earliest = LocalDate(year: 1900, month: 1, day: 1)! // provenance-ok: the server's taken_on range (migration 0050)

    /// The day of an image file's EXIF `DateTimeOriginal` (`yyyy:MM:dd HH:mm:ss`), converted with `OffsetTimeOriginal`
    /// into `timeZone` when the file has one; nil when the image carries no capture date.
    static func fromImage(_ data: Data, timeZone: TimeZone = .current, today: Date = Date()) -> LocalDate? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] else { return nil }
        return fromEXIF(
            dateTimeOriginal: exif[kCGImagePropertyExifDateTimeOriginal] as? String,
            offset: exif[kCGImagePropertyExifOffsetTimeOriginal] as? String,
            timeZone: timeZone,
            today: today
        )
    }

    /// Same, from a file.
    static func fromImage(at url: URL, timeZone: TimeZone = .current, today: Date = Date()) -> LocalDate? {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return nil }
        return fromImage(data, timeZone: timeZone, today: today)
    }

    /// `DateTimeOriginal` is the camera's wall clock: with an offset (`+02:00`) it is an instant, shown on the device's
    /// day; without one, its own calendar day.
    static func fromEXIF(dateTimeOriginal: String?, offset: String?, timeZone: TimeZone = .current, today: Date = Date()) -> LocalDate? {
        guard let text = dateTimeOriginal?.trimmingCharacters(in: .whitespaces), text.count >= 10 else { return nil } // provenance-ok: "yyyy:MM:dd"
        let datePart = String(text.prefix(10)).replacingOccurrences(of: ":", with: "-") // provenance-ok: "yyyy:MM:dd"
        guard let wallDay = LocalDate(datePart) else { return nil }
        if let offset, let seconds = offsetSeconds(offset), let zone = TimeZone(secondsFromGMT: seconds) {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = zone
            formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
            if let instant = formatter.date(from: String(text.prefix(19))) { // provenance-ok: "yyyy:MM:dd HH:mm:ss"
                return valid(LocalDate(instant, in: timeZone), timeZone: timeZone, today: today)
            }
        }
        return valid(wallDay, timeZone: timeZone, today: today)
    }

    /// The day of an instant (a video's creation date) in `timeZone`.
    static func fromDate(_ date: Date?, timeZone: TimeZone = .current, today: Date = Date()) -> LocalDate? {
        guard let date else { return nil }
        return valid(LocalDate(date, in: timeZone), timeZone: timeZone, today: today)
    }

    /// A movie's creation date (QuickTime / MP4 metadata), as a day in the device's zone.
    static func fromMovie(at url: URL, timeZone: TimeZone = .current, today: Date = Date()) async -> LocalDate? {
        let asset = AVURLAsset(url: url)
        guard let item = try? await asset.load(.creationDate),
              let date = try? await item.load(.dateValue) else { return nil }
        return fromDate(date, timeZone: timeZone, today: today)
    }

    /// Only days the server accepts: not before 1900, not after today on the device (a clock set to the future is not a
    /// day the photo was taken).
    static func valid(_ day: LocalDate, timeZone: TimeZone = .current, today: Date = Date()) -> LocalDate? {
        guard day >= earliest, day <= LocalDate(today, in: timeZone) else { return nil }
        return day
    }

    /// `+02:00`, `-0530`, `Z` → seconds east of GMT.
    static func offsetSeconds(_ text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed == "Z" { return 0 }
        guard let sign = trimmed.first, sign == "+" || sign == "-" else { return nil }
        let digits = trimmed.dropFirst().filter(\.isNumber)
        guard digits.count == 4, let hours = Int(digits.prefix(2)), let minutes = Int(digits.suffix(2)) else { return nil } // provenance-ok: HHMM
        let seconds = (hours * 60 + minutes) * 60 // provenance-ok: minutes and seconds per hour / minute
        return sign == "-" ? -seconds : seconds
    }
}
