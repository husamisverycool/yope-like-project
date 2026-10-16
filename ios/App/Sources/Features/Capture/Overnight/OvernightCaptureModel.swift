// Surface: camera.overnight, part A (the mode on the camera) — photos that develop at 9 AM. Mechanics Dispo (the
// "DEVELOP 9AM · NOW" switch; shoot straight into chosen rolls, DX1, DUG, DH-TP) and Lapse (full viewfinder, no preview
// after the shutter, L01); components Retro's (C-30, C-09, C-29, camera.sendto's rows).
// Spec: design/surfaces/camera.overnight.md (A; MERGE_DECISIONS ON-1 … ON-11); docs/API.md §14.3.
// The mode, the groups the next photos develop for, the reveal texts and the upload queue; the views are
// OvernightCaptureViews.swift, the shutter is CameraCaptureModel's.
import AppData
import AppModels
import DesignSystem
import Foundation
import Observation
import SwiftUI
import UIKit

/// When overnight photos develop (`camera.overnight.layout.reveal`): the first `time` (09:00) after capture in each
/// group's time zone, wall clock (daylight-saving safe). The server decides (`create_overnight_post`); the camera
/// computes the same rule for what it says before the server answers.
enum OvernightReveal {
    /// `camera.overnight.layout.reveal.time` (the server's `overnight_reveal_local_time`).
    static var localTime: LocalTime? { LocalTime(Tokens.Layouts.CameraOvernightLayoutReveal.time) }

    /// The earliest of the first reveal times strictly after `date` in each zone (a photo sent to groups in two zones
    /// reveals at each group's own 09:00; the first one is the one "{reveal}" names). No zone: the device's.
    static func next(after date: Date, timeZones: [TimeZone]) -> Date {
        guard let time = localTime else { return date }
        let zones = timeZones.isEmpty ? [TimeZone.current] : timeZones
        return zones.map { zone in next(after: date, time: time, in: zone) }.min() ?? date
    }

    private static func next(after date: Date, time: LocalTime, in zone: TimeZone) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let today = calendar.startOfDay(for: date)
        for day in [today, calendar.date(byAdding: .day, value: 1, to: today)].compactMap({ $0 }) {
            if let candidate = calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: day), candidate > date {
                return candidate
            }
        }
        return date
    }

    /// `{time}`: the reveal time of day in the locale's short time format ("9:00 AM", "09:00") — PLATFORM
    /// (`camera.overnight.mode.later`, `.a11y.modeHint`, `.settings.rowDetail`).
    static func timeText(locale: Locale = .current) -> String {
        guard let time = localTime else { return "" }
        var calendar = Calendar(identifier: .gregorian)
        let utc = TimeZone(identifier: "UTC") ?? .current // provenance-ok: a fixed zone to format a time of day
        calendar.timeZone = utc
        let day = calendar.startOfDay(for: Date())
        guard let date = calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: day) else { return "" }
        var style = Date.FormatStyle(date: .omitted, time: .shortened)
        style.locale = locale
        style.timeZone = utc
        return date.formatted(style)
    }

    /// `{reveal}`: the platform's relative day and time inside a sentence ("tomorrow at 9:00 AM") — PLATFORM
    /// (`DateFormatter` relative formatting, iOS's form of `RelativeDateTimeFormatter` + `Date.FormatStyle`).
    static func revealText(_ date: Date, locale: Locale = .current, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true
        formatter.formattingContext = .middleOfSentence
        return formatter.string(from: date)
    }
}

@MainActor
@Observable
final class OvernightCaptureModel {
    /// The two segments in Dispo's order (ON-2): "9 AM" · "Now".
    enum Mode: Hashable, Sendable, CaseIterable {
        case later
        case now
    }

    /// The groups list of the destination sheet (`camera.sendto`'s states).
    enum ListState: Equatable {
        case idle
        case loading
        case loaded
        /// The member has no groups (`camera.sendto.empty.*`).
        case empty
        case offline
        case failed
    }

    /// The mode for this app session: Now at every launch (ON-1), kept while the app stays in memory (Dispo keeps it).
    static var sessionMode: Mode = .now
    /// The groups chosen in this app session (nil: not chosen yet; `camera.overnight.layout.destinationSheet` keep).
    static var sessionSelection: [String]?
    /// The destination sheet opens by itself the first time 9 AM is chosen in an app session.
    static var didOpenDestinationThisSession = false

    /// A new app session (tests): Now, no groups chosen, the sheet not shown yet.
    static func resetSession() {
        sessionMode = .now
        sessionSelection = nil
        didOpenDestinationThisSession = false
    }

    private(set) var mode: Mode
    private(set) var groups: [CaptureGroup] = []
    /// Selected group ids in list order.
    private(set) var selection: [String]
    private(set) var listState: ListState = .idle
    private(set) var covers: [String: UIImage] = [:]
    /// The destination sheet (`camera.overnight.layout.destinationSheet`) is up.
    var isDestinationOpen = false
    /// `my_developing()`: read for the developing stack, whose drawing is BLOCKED (`camera.overnight.layout.stackCards`,
    /// ON-8) — the leading slot stays empty meanwhile.
    private(set) var developing = OvernightStatus.notDeveloping
    /// Increments on every group toggle (`haptic.global.select` trigger, as camera.sendto's rows).
    private(set) var selectionChanges = 0
    /// The last announcement (tests; posted to VoiceOver).
    private(set) var lastAnnouncement: String?

    let contextGroupID: String?
    private let groupSource: CaptureGroupSource
    private let posting: CapturePosting
    private let queue: CaptureOvernightQueue
    private let clock: @MainActor () -> Date
    private let announce: @MainActor (String) -> Void

    init(
        contextGroupID: String?,
        groups: CaptureGroupSource,
        posting: CapturePosting,
        queue: CaptureOvernightQueue,
        clock: @escaping @MainActor () -> Date = { Date() },
        announce: @escaping @MainActor (String) -> Void = { AccessibilityNotification.Announcement($0).post() }
    ) {
        self.contextGroupID = contextGroupID
        groupSource = groups
        self.posting = posting
        self.queue = queue
        self.clock = clock
        self.announce = announce
        mode = Self.sessionMode
        selection = Self.sessionSelection ?? []
    }

    var isLater: Bool { mode == .later }

    // MARK: Mode (`camera.overnight.layout.modeControl`)

    /// The segment's label: `camera.overnight.mode.later` ({time}) / `.mode.now`.
    func title(of mode: Mode) -> String {
        switch mode {
        case .later: return Copy.cameraOvernightModeLater(time: OvernightReveal.timeText())
        case .now: return Copy.cameraOvernightModeNow
        }
    }

    /// The first switch to 9 AM in a session opens the destination sheet (and any switch while no group is chosen).
    func setMode(_ new: Mode) {
        guard new != mode else { return }
        mode = new
        Self.sessionMode = new
        guard new == .later else { return }
        if !Self.didOpenDestinationThisSession || selection.isEmpty {
            Self.didOpenDestinationThisSession = true
            isDestinationOpen = true
        }
        Task {
            await loadGroups()
            await refreshDeveloping()
        }
    }

    // MARK: Groups (`camera.overnight.layout.destinationSheet`)

    /// The camera appeared in 9 AM mode: the groups (cached first) and whether photos are developing. In Now mode
    /// nothing is read until 9 AM is chosen.
    func appear() async {
        guard isLater else { return }
        await loadGroups()
        await refreshDeveloping()
    }

    func loadGroups() async {
        if let cached = await groupSource.cachedGroups(), !cached.isEmpty {
            apply(cached)
        } else if groups.isEmpty {
            listState = .loading
        }
        do {
            apply(try await groupSource.loadGroups())
        } catch {
            guard groups.isEmpty else { return }
            listState = groupSource.isOffline || DataError.from(error) == .offline ? .offline : .failed
        }
    }

    private func apply(_ list: [CaptureGroup]) {
        groups = list
        listState = list.isEmpty ? .empty : .loaded
        let ids = list.map(\.id)
        if let chosen = Self.sessionSelection {
            // Kept for the session; a group the member left drops out.
            selection = ids.filter { chosen.contains($0) }
        } else if let contextGroupID, ids.contains(contextGroupID) {
            selection = [contextGroupID]
        } else {
            // Every group (owner decision 11, as camera.sendto).
            selection = ids
        }
        for group in list where covers[group.id] == nil {
            guard let path = group.coverPath else { continue }
            Task { [weak self] in
                guard let self, let image = await self.groupSource.coverImage(path: path) else { return }
                self.covers[group.id] = image
            }
        }
    }

    func isSelected(_ groupID: String) -> Bool {
        selection.contains(groupID)
    }

    func toggle(_ groupID: String) {
        if let index = selection.firstIndex(of: groupID) {
            selection.remove(at: index)
        } else {
            selection = groups.map(\.id).filter { $0 == groupID || selection.contains($0) }
        }
        Self.sessionSelection = selection
        selectionChanges += 1
    }

    /// Done, or the sheet swiped away: the choice is kept for the session; with nothing selected the mode goes back to
    /// Now (`destinationSheet.nothingSelected`).
    func destinationClosed() {
        isDestinationOpen = false
        Self.sessionSelection = selection
        if selection.isEmpty, mode == .later {
            mode = .now
            Self.sessionMode = .now
        }
    }

    // MARK: Texts

    /// The destination pill's label: one group's name (`camera.overnight.destination.one`), "All groups" (`.all`) or
    /// "Selected groups" (`.some`) — never a number.
    var pillLabel: String {
        if selection.count == 1, let group = groups.first(where: { $0.id == selection[0] }) {
            return Copy.cameraOvernightDestinationOne(group: group.name)
        }
        if !groups.isEmpty, selection.count == groups.count {
            return Copy.cameraOvernightDestinationAll
        }
        return Copy.cameraOvernightDestinationSome
    }

    /// When a photo taken now develops for the chosen groups (their time zones; the device's when unknown).
    func revealDate(at date: Date? = nil) -> Date {
        let zones = groups.filter { selection.contains($0.id) }.compactMap { $0.timeZone.flatMap(TimeZone.init(identifier:)) }
        return OvernightReveal.next(after: date ?? clock(), timeZones: zones)
    }

    /// `camera.overnight.destination.detail` with {reveal}.
    var detailText: String {
        Copy.cameraOvernightDestinationDetail(reveal: OvernightReveal.revealText(revealDate()))
    }

    // MARK: Capture (`camera.overnight` A: shutter in 9 AM mode)

    /// A photo taken in 9 AM mode: no preview and no send-to — it goes to the upload queue for the chosen groups and
    /// the camera stays ready; the announcement `camera.overnight.a11y.captured` names when it develops.
    func capture(_ still: CaptureStill, capturedAt: Date) {
        guard !selection.isEmpty else {
            isDestinationOpen = true
            return
        }
        let text = Copy.cameraOvernightA11yCaptured(reveal: OvernightReveal.revealText(revealDate(at: capturedAt)))
        lastAnnouncement = text
        announce(text)
        let task = queue.enqueue(still, groupIDs: selection, capturedAt: capturedAt)
        Task { [weak self] in
            _ = await task.value
            await self?.refreshDeveloping()
        }
    }

    func refreshDeveloping() async {
        if let status = try? await posting.myDeveloping() { developing = status }
    }
}

/// The 9 AM uploads (`camera.overnight.layout.uploadQueue`): each photo is re-encoded as JPEG without metadata and
/// handed to the outbox (AppData `PostPublisher`), which uploads it to app storage paths, calls
/// `create_overnight_post`, deletes its local copy once done, and resumes after a relaunch or when the connection
/// returns. The camera never waits; nothing is drawn while photos upload or wait offline; the system photo library is
/// never written. A photo that cannot be sent (after the uploader's retries, or refused) is announced with
/// `camera.sendto.error.sendFailed` (C-26 on iOS: an announcement).
@MainActor
@Observable
final class CaptureOvernightQueue {
    enum Outcome: Equatable {
        /// Posted to develop.
        case developing
        /// Kept in the outbox until the connection returns.
        case waiting
        case failed
    }

    /// Photos being encoded or sent right now (tests).
    private(set) var inFlight = 0
    /// Sends that failed (tests).
    private(set) var failures = 0

    private let posting: CapturePosting
    private let announce: @MainActor (String) -> Void

    init(posting: CapturePosting, announce: @escaping @MainActor (String) -> Void = { AccessibilityNotification.Announcement($0).post() }) {
        self.posting = posting
        self.announce = announce
    }

    @discardableResult
    func enqueue(_ still: CaptureStill, groupIDs: [String], capturedAt: Date) -> Task<Outcome, Never> {
        var photo = still
        // Photos only: no Live Photo motion leaves the camera in 9 AM mode (a motion file the camera still wrote is
        // deleted).
        if let movie = photo.livePhotoMovieURL, movie.path.hasPrefix(FileManager.default.temporaryDirectory.path) {
            try? FileManager.default.removeItem(at: movie)
        }
        photo.livePhotoMovieURL = nil
        let request = CaptureSendRequest(
            payload: .media(.photo(photo, capturedAt: capturedAt)), groupIDs: groupIDs, overnight: true
        )
        inFlight += 1
        return Task {
            let outcome = await send(request)
            inFlight -= 1
            return outcome
        }
    }

    private func send(_ request: CaptureSendRequest) async -> Outcome {
        let draft: PostDraft
        do {
            draft = try await Task.detached(priority: .userInitiated) {
                try await CaptureDraftBuilder.build(request)
            }.value
        } catch {
            CaptureDraftBuilder.cleanUp(request)
            return fail()
        }
        do {
            try await posting.publish(draft)
            CaptureDraftBuilder.cleanUp(request)
            return .developing
        } catch {
            // The outbox holds its own copy of the files.
            CaptureDraftBuilder.cleanUp(request)
            let failure = DataError.from(error)
            if failure == .offline { return .waiting }
            if failure.isTransient {
                // Retried by the outbox when the app comes back online or relaunches.
                announce(Copy.cameraSendtoErrorSendFailed)
                failures += 1
                return .waiting
            }
            await posting.discard(draft.mediaID)
            return fail()
        }
    }

    private func fail() -> Outcome {
        failures += 1
        announce(Copy.cameraSendtoErrorSendFailed)
        return .failed
    }
}
