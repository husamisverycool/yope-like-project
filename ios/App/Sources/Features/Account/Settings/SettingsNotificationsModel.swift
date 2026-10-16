// Account group — SettingsNotificationsModel: state and actions of the screen in SettingsNotificationsScreen.swift.
import AppData
import AppModels
import DesignSystem
import Observation
import SwiftUI
import UIKit

@MainActor
@Observable
final class SettingsNotificationsModel {
    struct GroupMute: Identifiable, Equatable {
        let group: PhotoGroup
        var muted: Bool
        var id: GroupID { group.id }
    }

    private(set) var groups: [GroupMute] = []
    private(set) var isLoading = true
    private(set) var quietStart: LocalTime?
    private(set) var quietEnd: LocalTime?
    /// Quiet hours toggle on (times may not be saved yet: nothing is sent until the two times differ).
    private(set) var quietHoursOn = false
    /// System notifications off or never asked (section 1).
    private(set) var systemOff = false
    /// The push when overnight photos develop (`camera.overnight.settings.row`; `notification_settings.overnight`), on
    /// by default and when no settings row exists.
    private(set) var overnightOn = true
    /// The failed change of each section (`settings.notifications.error`); the screen shows it as a message-only alert
    /// (trigger `errorCount`).
    private(set) var groupsError: String?
    private(set) var quietError: String?
    private(set) var overnightError: String?
    private(set) var errorCount = 0

    private let data: AccountDataSource
    private let notifications: NotificationAuthorizing

    init(data: AccountDataSource, notifications: NotificationAuthorizing) {
        self.data = data
        self.notifications = notifications
    }

    func load() async {
        if let cached = await data.cachedGroups() {
            groups = cached.map { GroupMute(group: $0, muted: false) }
        }
        let status = await notifications.authorizationStatus()
        systemOff = status == .denied || status == .notDetermined
        if let fresh = try? await data.myGroups() {
            var rows: [GroupMute] = []
            for group in fresh {
                let muted = (try? await data.myMembership(groupID: group.id))?.muted ?? false
                rows.append(GroupMute(group: group, muted: muted))
            }
            groups = rows
        }
        if let settings = try? await data.notificationSettings() {
            quietStart = settings.quietStart
            quietEnd = settings.quietEnd
            quietHoursOn = quietStart != nil && quietEnd != nil
            overnightOn = settings.overnight
        }
        isLoading = false
    }

    /// Row toggle: on = not muted. Optimistic; reverts with the footer error.
    func setNotifies(_ notifies: Bool, groupID: GroupID) async {
        guard let index = groups.firstIndex(where: { $0.id == groupID }) else { return }
        let previous = groups[index].muted
        groups[index].muted = !notifies
        groupsError = nil
        do {
            try await data.setMuted(groupID: groupID, muted: !notifies)
        } catch {
            if let current = groups.firstIndex(where: { $0.id == groupID }) { groups[current].muted = previous }
            groupsError = Copy.settingsNotificationsError
            errorCount += 1
        }
    }

    /// Off: `set_quiet_hours(null, null)`. On: shows the two times; saved once they differ.
    func setQuietHoursOn(_ on: Bool) async {
        quietError = nil
        guard !on else {
            quietHoursOn = true
            return
        }
        let previous = (quietStart, quietEnd)
        quietHoursOn = false
        quietStart = nil
        quietEnd = nil
        do {
            try await data.setQuietHours(start: nil, end: nil)
        } catch {
            (quietStart, quietEnd) = previous
            quietHoursOn = previous.0 != nil
            quietError = Copy.settingsNotificationsError
            errorCount += 1
        }
    }

    func setQuietHours(start: LocalTime, end: LocalTime) async {
        guard start != end, start != quietStart || end != quietEnd else { return }
        let previous = (quietStart, quietEnd)
        quietStart = start
        quietEnd = end
        quietError = nil
        do {
            try await data.setQuietHours(start: start, end: end)
        } catch {
            (quietStart, quietEnd) = previous
            quietError = Copy.settingsNotificationsError
            errorCount += 1
        }
    }

    /// `set_overnight_alerts` (camera.overnight's switch). Optimistic; reverts with the error alert.
    func setOvernightAlerts(_ on: Bool) async {
        guard on != overnightOn else { return }
        overnightOn = on
        overnightError = nil
        do {
            try await data.setOvernightAlerts(on)
        } catch {
            overnightOn = !on
            overnightError = Copy.settingsNotificationsError
            errorCount += 1
        }
    }

    /// The latest failure's message (the alert).
    var alertMessage: String? { overnightError ?? quietError ?? groupsError }
}
