// Surface: settings.notifications — per-group notifications, quiet hours, Live Activity. Visual reference: Retro
// Notification Settings (strings references/auto/retro/apk/retro-android-2026.10.1150-strings.txt
// `notification_settings_*`; grouped rows references/auto/retro/video/ig-DJXvmqRv2_N-referrals-sheet-f042-059.png,
// VID-SET; the off block on references/auto/retro/lazyweb/retro-lazyweb-20251020-week43-dark.png, H43). Native switches
// and time pickers (design/surfaces/settings.notifications.md).
import AppData
import AppModels
import DesignSystem
import Observation
import SwiftUI
import UIKit

struct SettingsNotificationsScreen: View {
    @Environment(AccountDependencies.self) private var dependencies

    var body: some View {
        SettingsNotificationsView(model: SettingsNotificationsModel(data: dependencies.data, notifications: dependencies.notifications))
    }
}

extension View {
    /// A page pushed inside a settings sheet: the native back button and the centred inline title
    /// (`settings.root.layout.list.sheet`), the system tint `color.global.selection` (C-29), page
    /// `color.global.background`.
    func settingsPage(title: String) -> some View {
        background(Tokens.Colors.globalBackground.ignoresSafeArea())
            .navigationTitle(Text(title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
            .tint(Tokens.Colors.globalSelection)
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

    private static let fade = DSAnimation.timing(duration: Tokens.Durations.globalFade, easing: Tokens.Easings.globalStandard)

    private var isOffline: Bool { dependencies.network.isOffline }

    var body: some View {
        SettingsList {
            if model.systemOff {
                permissionOff
                    .transition(.opacity)
            }
            groupsSection
            quietHoursSection
            overnightSection
            SettingsGroup(footer: [Copy.settingsNotificationsLiveActivityFooter], rows: [
                SettingsRow(Copy.settingsNotificationsLiveActivity, kind: .toggle($liveActivityOn))
                    .accessibilityIdentifier("settings.notifications.liveActivity")
                    .asSettingsRow(),
            ])
        }
        .dsAnimation(Self.fade, value: model.systemOff)
        .settingsPage(title: Copy.settingsNotificationsTitle)
        .onChange(of: liveActivityOn) { _, value in
            dependencies.liveActivity.isEnabled = value
            dependencies.liveActivityChanged()
        }
        .onChange(of: start) { _, _ in saveQuietHours() }
        .onChange(of: end) { _, _ in saveQuietHours() }
        .task {
            liveActivityOn = dependencies.liveActivity.isEnabled
            await model.load()
            syncPickers()
        }
        .dsHaptic(Tokens.Haptics.globalError, trigger: model.errorCount)
        .formErrorAlert(model.alertMessage, trigger: model.errorCount)
        .accessibilityIdentifier("settings.notifications")
    }

    /// Permission off: the C-27 block at the top, left-aligned inside the margins, no glyph — "Keep up to date!", the
    /// explanation and the outline capsule "Enable push" → the app's notification settings. The rows below stay editable.
    private var permissionOff: some View {
        MetricStack {
            VStack(alignment: .leading) {
                Text(Copy.settingsNotificationsOffTitle)
                    .dsTextStyle(TextRole.emptyTitle)
                    .foregroundStyle(Tokens.Colors.globalTextPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text(Copy.settingsNotificationsOffFooter)
                    .dsTextStyle(TextRole.emptyDetail)
                    .foregroundStyle(Tokens.Colors.globalTextSecondary)
            }
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            CapsuleButton(Copy.settingsNotificationsOpenSettings, style: .outline) {
                if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
            }
            .fixedSize()
            .accessibilityIdentifier("settings.notifications.openSettings")
            .metricGap(Tokens.Sizes.globalEmptyTitleToAction, from: .lastBaseline, to: .top)
        }
        .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// One row per group: the cover in a `size.global.avatarComment` circle (C-23; no cover: `icon.global.group`), the
    /// name (`body`) and a switch (on = notifications on). Hidden when there are no groups; loading: one busy row.
    @ViewBuilder
    private var groupsSection: some View {
        if model.isLoading {
            SettingsGroup(header: Copy.settingsNotificationsGroupsHeader, rows: [SettingsRow("", kind: .busy).asSettingsRow()])
                .accessibilityLabel(Text(Copy.globalA11yLoading))
        } else if !model.groups.isEmpty {
            SettingsGroup(
                header: Copy.settingsNotificationsGroupsHeader,
                footer: [Copy.settingsNotificationsGroupsFooter],
                rows: model.groups.map { row in
                    SettingsCustomRow {
                        Toggle(isOn: Binding(
                            get: { !row.muted },
                            set: { value in Task { await model.setNotifies(value, groupID: row.id) } }
                        )) {
                            HStack {
                                AvatarView(path: row.group.coverPath, diameter: Tokens.Sizes.globalAvatarComment, placeholderIcon: Tokens.Icons.globalGroup)
                                Text(row.group.name)
                                    .dsTextStyle(TextRole.body)
                                    .foregroundStyle(Tokens.Colors.globalTextPrimary)
                            }
                        }
                        .tint(Tokens.Colors.globalSelection)
                        .disabled(isOffline)
                    }
                    .asSettingsRow()
                }
            )
        }
    }

    /// Quiet Hours: the switch; when on, Start and End with the system's compact time pickers in the rows.
    private var quietHoursSection: some View {
        var rows: [AnyView] = [
            SettingsRow(
                Copy.settingsNotificationsQuietHours,
                kind: .toggle(Binding(
                    get: { model.quietHoursOn },
                    set: { value in
                        if value { syncPickers() }
                        Task { await model.setQuietHoursOn(value) }
                    }
                )),
                isEnabled: !isOffline
            )
            .accessibilityIdentifier("settings.notifications.quietHours")
            .asSettingsRow(),
        ]
        if model.quietHoursOn {
            rows.append(timeRow(Copy.settingsNotificationsQuietHoursStart, selection: $start))
            rows.append(timeRow(Copy.settingsNotificationsQuietHoursEnd, selection: $end))
        }
        return SettingsGroup(footer: [Copy.settingsNotificationsQuietHoursFooter], rows: rows)
    }

    /// camera.overnight's switch: "Developed Photos" (`camera.overnight.settings.row`), on by default, with
    /// `camera.overnight.settings.rowDetail` ({time}: the reveal time in the locale's short format) as its footer —
    /// `set_overnight_alerts`.
    private var overnightSection: some View {
        SettingsGroup(footer: [Copy.cameraOvernightSettingsRowDetail(time: OvernightReveal.timeText())], rows: [
            SettingsRow(
                Copy.cameraOvernightSettingsRow,
                kind: .toggle(Binding(
                    get: { model.overnightOn },
                    set: { value in Task { await model.setOvernightAlerts(value) } }
                )),
                isEnabled: !isOffline
            )
            .accessibilityIdentifier("settings.notifications.overnight") // provenance-ok: accessibility identifier for UI tests
            .asSettingsRow(),
        ])
    }

    private func timeRow(_ title: String, selection: Binding<Date>) -> AnyView {
        SettingsCustomRow {
            DatePicker(selection: selection, displayedComponents: .hourAndMinute) {
                Text(title)
                    .dsTextStyle(TextRole.body)
                    .foregroundStyle(Tokens.Colors.globalTextPrimary)
            }
            .disabled(isOffline)
        }
        .asSettingsRow()
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
