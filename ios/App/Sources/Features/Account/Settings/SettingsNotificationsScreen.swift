// Surface: settings.notifications — per-group mute, quiet hours, Live Activity. Reference: Apple HIG (system surface;
// design/surfaces/settings.notifications.md). Reference: HIG lists and tables, HIG Live Activities ("offer an in-app
// control"), docs/WIDGET_REFRESH.md (muted groups still update widgets).
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
    /// Section footer errors (`settings.notifications.error`).
    private(set) var groupsError: String?
    private(set) var quietError: String?

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
        }
    }
}

struct SettingsNotificationsScreen: View {
    @Environment(AccountDependencies.self) private var dependencies

    var body: some View {
        SettingsNotificationsView(model: SettingsNotificationsModel(data: dependencies.data, notifications: dependencies.notifications))
    }
}

struct SettingsNotificationsView: View {
    @State private var model: SettingsNotificationsModel
    @State private var start = Date()
    @State private var end = Date()
    @State private var liveActivityOn = true
    @Environment(AccountDependencies.self) private var dependencies
    @Environment(\.openURL) private var openURL

    init(model: SettingsNotificationsModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        Group {
            if model.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                list
            }
        }
        .navigationTitle(Text(Copy.settingsNotificationsTitle))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            liveActivityOn = dependencies.liveActivity.isEnabled
            await model.load()
            syncPickers()
        }
        .accessibilityIdentifier("settings.notifications")
    }

    private var isOffline: Bool { dependencies.network.isOffline }

    private var list: some View {
        List {
            if model.systemOff {
                Section {
                    Button(Copy.settingsNotificationsOpenSettings) {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                    }
                } footer: {
                    if let footer = AccountBlockedCopy.notificationsOffFooter { Text(footer) }
                }
            }
            if !model.groups.isEmpty {
                Section {
                    ForEach(model.groups) { row in
                        Toggle(row.group.name, isOn: Binding(
                            get: { !row.muted },
                            set: { value in Task { await model.setNotifies(value, groupID: row.id) } }
                        ))
                        .disabled(isOffline)
                    }
                } header: {
                    Text(Copy.settingsNotificationsGroupsHeader)
                } footer: {
                    Text(model.groupsError ?? Copy.settingsNotificationsGroupsFooter)
                }
            }
            Section {
                Toggle(Copy.settingsNotificationsQuietHours, isOn: Binding(
                    get: { model.quietHoursOn },
                    set: { value in
                        if value { syncPickers() }
                        Task { await model.setQuietHoursOn(value) }
                    }
                ))
                .disabled(isOffline)
                if model.quietHoursOn {
                    DatePicker(Copy.settingsNotificationsQuietHoursStart, selection: $start, displayedComponents: .hourAndMinute)
                    DatePicker(Copy.settingsNotificationsQuietHoursEnd, selection: $end, displayedComponents: .hourAndMinute)
                }
            } footer: {
                Text(model.quietError ?? Copy.settingsNotificationsQuietHoursFooter)
            }
            .onChange(of: start) { _, _ in saveQuietHours() }
            .onChange(of: end) { _, _ in saveQuietHours() }
            Section {
                Toggle(Copy.settingsNotificationsLiveActivity, isOn: $liveActivityOn)
                    .onChange(of: liveActivityOn) { _, value in
                        dependencies.liveActivity.isEnabled = value
                        dependencies.liveActivityChanged()
                    }
            } footer: {
                Text(Copy.settingsNotificationsLiveActivityFooter)
            }
        }
        .listStyle(.insetGrouped)
    }

    /// Pickers show the saved times, or the current time when none are saved yet.
    private func syncPickers() {
        let now = Date()
        start = model.quietStart.map { AccountFormats.date(for: $0, now: now) } ?? now
        end = model.quietEnd.map { AccountFormats.date(for: $0, now: now) } ?? now
    }

    private func saveQuietHours() {
        guard model.quietHoursOn, let from = AccountFormats.localTime(of: start), let to = AccountFormats.localTime(of: end) else { return }
        Task { await model.setQuietHours(start: from, end: to) }
    }
}
