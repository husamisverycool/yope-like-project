// Plans group — PlanCreateModel: state and actions of plans.create (PlanCreateScreen.swift), in create and edit mode.
import AppData
import AppModels
import DesignSystem
import Observation
import SwiftUI
import UIKit

@MainActor
@Observable
final class PlanCreateModel {
    /// The native picker open under its row (plans.create Structure 4: inline graphical date, time wheel).
    enum Picker: Hashable {
        case date
        case time
    }

    let groupID: GroupID
    /// Nil: create; else the plan being edited (its maker or an admin, from plans.page "Edit Plan").
    let editing: Plan?

    /// The title as typed; 1–80 characters after trimming (`plans.create.error.tooLong` past that).
    private(set) var title = ""
    /// The chosen day (any instant of it in the group's zone); nil until chosen (`plans.create.date.none`).
    private(set) var day: Date?
    /// The chosen time of day; nil = none chosen, which makes the plan all-day (plans.create Structure 4).
    private(set) var time: Date?
    private(set) var allDay = false
    private(set) var place = ""
    private(set) var note = ""
    var openPicker: Picker?

    /// The picked cover (square crop) and its upload-ready JPEG.
    private(set) var coverImage: UIImage?
    private var coverJPEG: Data?
    /// Edit mode: the plan's current cover, until replaced or removed.
    private(set) var existingCoverPath: String?

    private(set) var isWorking = false
    /// The inline line under the button (`plans.create.error.failed`, `.error.cover`, `plans.create.offline`).
    private(set) var failureMessage: String?
    /// The group's zone: the date picker's minimum (today there) and the plan's day are read in it.
    private(set) var timeZone: TimeZone = .current

    static let maxTitleLength = 80
    /// docs/API.md §14.2 (`invalid_place` > 200, `invalid_note` > 2,048): typing stops at the limit.
    static let maxPlaceLength = 200
    static let maxNoteLength = 2048

    private let services: PlansServices

    init(groupID: GroupID, editing: Plan?, services: PlansServices) {
        self.groupID = groupID
        self.editing = editing
        self.services = services
        if let editing {
            title = editing.title
            allDay = editing.allDay
            day = editing.startsAt
            time = editing.allDay ? nil : editing.startsAt
            place = editing.place ?? ""
            note = editing.note ?? ""
            existingCoverPath = editing.coverPath
        }
    }

    var isEditing: Bool { editing != nil }
    var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    var isTitleTooLong: Bool { trimmedTitle.count > Self.maxTitleLength }
    var hasCover: Bool { coverImage != nil || existingCoverPath != nil }
    /// Title and date set (plans.create States: ready).
    var canSubmit: Bool { !trimmedTitle.isEmpty && !isTitleTooLong && day != nil && !isWorking }
    /// All-day when switched on or when no time was chosen.
    var isAllDay: Bool { allDay || time == nil }

    /// Anything typed or chosen: closing asks first (`plans.create.discard.*`); an empty form closes at once.
    var hasInput: Bool {
        if let editing {
            return trimmedTitle != editing.title || startsAt != editing.startsAt || isAllDay != editing.allDay
                || trimmedPlace != editing.place || trimmedNote != editing.note || coverJPEG != nil || existingCoverPath != editing.coverPath
        }
        return !title.isEmpty || day != nil || time != nil || allDay || !place.isEmpty || !note.isEmpty || coverJPEG != nil
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    /// The date picker's minimum: today in the group's time zone (`invalid_date` before it).
    var minimumDate: Date {
        calendar.startOfDay(for: services.now())
    }

    /// The chosen day and time combined in the group's zone (00:00 of the day when all-day).
    var startsAt: Date? {
        guard let day else { return nil }
        let date = calendar.dateComponents([.year, .month, .day], from: day)
        guard !isAllDay, let time else { return calendar.date(from: date) }
        let clock = calendar.dateComponents([.hour, .minute], from: time)
        return calendar.date(from: DateComponents(year: date.year, month: date.month, day: date.day, hour: clock.hour, minute: clock.minute))
    }

    /// The date row's value: the locale's medium date, or nil until chosen.
    var dateText: String? {
        day.map { PlanFormats.mediumDate($0, timeZone: timeZone) }
    }

    /// The time row's value: the locale's short time, or nil until chosen.
    var timeText: String? {
        time.map { PlanFormats.shortTime($0, timeZone: timeZone) }
    }

    private var trimmedPlace: String? {
        let text = place.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    private var trimmedNote: String? {
        note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note
    }

    // MARK: Input

    /// Reads the group's time zone (the pickers and the day are the group's).
    func load() async {
        if let group = try? await services.plans.group(id: groupID) {
            timeZone = group.resolvedTimeZone
        }
    }

    func setTitle(_ value: String) {
        title = value
    }

    func setDay(_ value: Date) {
        day = max(value, minimumDate)
    }

    func setTime(_ value: Date) {
        time = value
    }

    func setAllDay(_ value: Bool) {
        allDay = value
        if value, openPicker == .time { openPicker = nil }
    }

    func setPlace(_ value: String) {
        place = String(value.prefix(Self.maxPlaceLength))
    }

    func setNote(_ value: String) {
        note = String(value.prefix(Self.maxNoteLength))
    }

    /// The date / time row was tapped: its picker opens under it (another open picker closes).
    func toggle(_ picker: Picker) {
        openPicker = openPicker == picker ? nil : picker
    }

    /// A photo from the system picker, stored as a square crop (Partiful's 1:1 poster).
    func setCover(imageData: Data) {
        guard let square = Self.squareJPEG(from: imageData) else {
            failureMessage = Copy.plansCreateErrorCover
            return
        }
        coverJPEG = square.data
        coverImage = square.image
        failureMessage = nil
    }

    // MARK: Submit

    /// Uploads the cover (if a new one was picked), then `create_plan` / `update_plan`. Returns the plan when done.
    func submit() async -> Plan? {
        guard canSubmit, let startsAt else { return nil }
        failureMessage = nil
        isWorking = true
        defer { isWorking = false }
        var coverPath = existingCoverPath
        if let coverJPEG {
            do {
                coverPath = try await services.plans.uploadCover(jpeg: coverJPEG)
            } catch {
                self.coverJPEG = nil
                coverImage = nil
                failureMessage = PlansFailure(error) == .offline ? Copy.plansCreateOffline : Copy.plansCreateErrorCover
                return nil
            }
        }
        let fields = PlanFields(
            title: trimmedTitle, startsAt: startsAt, allDay: isAllDay, place: trimmedPlace, note: trimmedNote, coverPath: coverPath
        )
        do {
            let plan: Plan
            if let editing {
                plan = try await services.plans.updatePlan(id: editing.id, fields: fields)
            } else {
                plan = try await services.plans.createPlan(groupID: groupID, fields: fields)
            }
            services.didChange()
            return plan
        } catch {
            failureMessage = PlansFailure(error) == .offline ? Copy.plansCreateOffline : Copy.plansCreateErrorFailed
            return nil
        }
    }

    // MARK: Cover

    /// The centre square of a picked photo as an upload-ready JPEG (location metadata dropped: the image is redrawn).
    static func squareJPEG(from data: Data) -> (data: Data, image: UIImage)? {
        guard let jpeg = try? UploadImage.jpeg(from: data), let image = UIImage(data: jpeg) else { return nil }
        let side = min(image.size.width, image.size.height)
        guard side > 0 else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)
        let square = renderer.image { _ in
            image.draw(at: CGPoint(x: (side - image.size.width) / 2, y: (side - image.size.height) / 2))
        }
        guard let output = square.jpegData(compressionQuality: 1) else { return nil } // provenance-ok: encoder quality (as UploadImage)
        return (output, square)
    }
}
