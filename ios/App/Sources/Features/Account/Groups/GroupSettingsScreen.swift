// Surface: groups.settings — members, mute, quiet hours, invitation hours / pause, leave, report, block. Reference:
// Yope + Apple HIG (native inset-grouped list with Yope's labels; design/surfaces/groups.settings.md). Reference images:
// references/auto/yope/frames/a-yrrah-7434441926000037121-t33.73-group-menu-leave-report-2024.png (M24),
// …-t43.23-members-list-2024.png (ML24), a-itsmthuyope-7644974799302823175-t51.23-group-created-empty-state.png (E26);
// HIG lists and tables, alerts, menus.
import AppData
import AppModels
import DesignSystem
import Observation
import SwiftUI
import UIKit

struct GroupSettingsScreen: View {
    let groupID: String
    @Environment(AccountDependencies.self) private var dependencies

    var body: some View {
        GroupSettingsView(model: GroupSettingsModel(groupID: GroupID(groupID), data: dependencies.data, notifications: dependencies.notifications))
    }
}

struct GroupSettingsView: View {
    @State private var model: GroupSettingsModel
    @State private var editingHours = false
    @State private var hoursStart = Date()
    @State private var hoursEnd = Date()
    @State private var confirmLeave = false
    @State private var removing: MemberProfile?
    @State private var blockTarget: BlockTarget?
    @Environment(AccountDependencies.self) private var dependencies
    @Environment(\.openURL) private var openURL

    init(model: GroupSettingsModel) {
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
        .navigationTitle(Text(Copy.groupsSettingsTitle))
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
        .leaveGroupAlert(
            isPresented: $confirmLeave,
            group: model.group,
            isLastMember: model.members.count <= 1,
            data: dependencies.data,
            onFailed: { model.leaveFailed() }
        ) {
            dependencies.router.path = []
        }
        .alert(
            Text(Copy.groupsSettingsRemoveTitle(firstName: removing?.profile?.firstName ?? "")),
            isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }),
            presenting: removing
        ) { member in
            Button(Copy.groupsSettingsAlertCancel, role: .cancel) {}
            Button(Copy.groupsSettingsRemoveConfirm, role: .destructive) {
                Task { await model.remove(member) }
            }
        } message: { _ in
            Text(Copy.groupsSettingsRemoveMessage)
        }
        .blockConfirmation(target: $blockTarget, toasts: dependencies.toasts) { target in
            try await dependencies.data.block(userID: UserID(target.userID))
        }
        .dsHaptic(Tokens.Haptics.globalWarning, trigger: model.warningCount)
        .dsHaptic(Tokens.Haptics.globalError, trigger: model.errorCount)
        .accessibilityIdentifier("groups.settings")
    }

    private var isOffline: Bool { dependencies.network.isOffline }

    private var list: some View {
        List {
            membersSection
            notificationsSection
            invitationSection
            if model.isAdmin {
                Section(Copy.groupsSettingsGroupHeader) {
                    Button(Copy.groupsSettingsGroupEdit) {
                        dependencies.router.modal = .account(.groupEdit(groupID: model.groupID.rawValue))
                    }
                }
            }
            Section {
                Button(Copy.groupsSettingsShareInvite) {
                    dependencies.router.modal = .account(.groupInvite(groupID: model.groupID.rawValue))
                }
                Button(Copy.groupsSettingsReport, systemImage: Tokens.Icons.globalReport, role: .destructive) {
                    dependencies.router.modal = .account(.report(ReportTarget(kind: .group, id: model.groupID.rawValue, name: model.group?.name)))
                }
                Button(Copy.groupsSettingsLeave, systemImage: Tokens.Icons.globalLeave, role: .destructive) {
                    confirmLeave = true
                }
                .accessibilityIdentifier("groups.settings.leave")
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: Members

    private var membersSection: some View {
        Section {
            ForEach(model.members) { member in
                memberRow(member)
            }
            if !model.isFull {
                Button {
                    dependencies.router.modal = .account(.groupInvite(groupID: model.groupID.rawValue))
                } label: {
                    Label(GroupKindCopy.settingsInvite(model.group?.kind), systemImage: Tokens.Icons.globalLink)
                }
            }
        } header: {
            Text(Copy.groupsSettingsMembersHeader)
        } footer: {
            if let error = model.memberError { Text(error) }
        }
    }

    private func memberRow(_ member: MemberProfile) -> some View {
        let isMe = member.member.userID == model.me
        let firstName = member.profile?.firstName ?? ""
        return HStack {
            Button {
                if let route = CrossGroupRoutes.wallMember(userID: member.member.userID.rawValue) {
                    dependencies.router.path.append(route)
                }
            } label: {
                HStack {
                    AvatarView(path: member.profile?.avatarPath, diameter: Tokens.Sizes.globalAvatarPicker)
                    VStack(alignment: .leading) {
                        Text(member.profile?.displayName ?? "")
                        if isMe {
                            Text(Copy.groupsSettingsMembersYou).font(.subheadline).foregroundStyle(.secondary) // provenance-ok: system list subhead style (layout.global.system.typography)
                        } else if member.member.role == .admin {
                            Text(Copy.groupsSettingsMembersAdmin).font(.subheadline).foregroundStyle(.secondary) // provenance-ok: system list subhead style (layout.global.system.typography)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)
            if !isMe {
                Menu {
                    if model.isAdmin {
                        Button(Copy.groupsSettingsMembersMenuRemove, role: .destructive) { removing = member }
                    }
                    Button(Copy.groupsSettingsMembersMenuReport) {
                        dependencies.router.modal = .account(.report(ReportTarget(
                            kind: .user,
                            id: member.member.userID.rawValue,
                            name: firstName,
                            person: BlockTarget(userID: member.member.userID.rawValue, firstName: firstName)
                        )))
                    }
                    Button(Copy.groupsSettingsMembersMenuBlock, role: .destructive) {
                        blockTarget = BlockTarget(userID: member.member.userID.rawValue, firstName: firstName)
                    }
                } label: {
                    Image(systemName: Tokens.Icons.globalMore)
                        .frame(width: Tokens.Sizes.globalMinTouchTargetIos, height: Tokens.Sizes.globalMinTouchTargetIos)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(Text(Copy.groupsSettingsMembersMoreAccessibilityLabel(firstName: firstName)))
            }
        }
    }

    // MARK: Notifications

    private var notificationsSection: some View {
        Section {
            Toggle(Copy.groupsSettingsNotificationsMute, isOn: Binding(
                get: { model.muted },
                set: { value in Task { await model.setMuted(value) } }
            ))
            .disabled(isOffline)
            .accessibilityIdentifier("groups.settings.mute")
            NavigationLink(value: AppRoute.account(.settingsNotifications)) {
                Text(Copy.groupsSettingsNotificationsQuietHours)
            }
            if model.systemNotificationsOff {
                Button(Copy.settingsNotificationsOpenSettings) { openNotificationSettings() }
            }
        } header: {
            Text(Copy.groupsSettingsNotificationsHeader)
        } footer: {
            VStack(alignment: .leading) {
                Text(model.notificationsError ?? Copy.groupsSettingsNotificationsFooter)
                if model.systemNotificationsOff, let off = AccountBlockedCopy.notificationsOffFooter {
                    Text(off)
                }
            }
        }
    }

    private func openNotificationSettings() {
        if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
    }

    // MARK: Daily invitation

    private var invitationSection: some View {
        Section {
            if model.isAdmin {
                Button {
                    beginEditingHours()
                } label: {
                    LabeledContent(Copy.groupsSettingsInvitationHours, value: model.invitationHoursText)
                }
                .foregroundStyle(.primary) // provenance-ok: system label colour (color.global.system.ios label)
                .disabled(isOffline)
                if editingHours {
                    HStack {
                        DatePicker(selection: $hoursStart, displayedComponents: .hourAndMinute) {
                            Text(Copy.settingsNotificationsQuietHoursStart)
                        }
                        DatePicker(selection: $hoursEnd, displayedComponents: .hourAndMinute) {
                            Text(Copy.settingsNotificationsQuietHoursEnd)
                        }
                    }
                    .labelsHidden()
                    .onChange(of: hoursStart) { _, _ in saveHours() }
                    .onChange(of: hoursEnd) { _, _ in saveHours() }
                }
            } else {
                LabeledContent(Copy.groupsSettingsInvitationHours, value: model.invitationHoursText)
            }
            Toggle(Copy.groupsSettingsInvitationPause, isOn: Binding(
                get: { model.paused },
                set: { value in Task { await model.setPaused(value) } }
            ))
            .disabled(!model.isAdmin || isOffline)
        } header: {
            Text(Copy.groupsSettingsInvitationHeader)
        } footer: {
            VStack(alignment: .leading) {
                Text(model.invitationError ?? Copy.groupsSettingsInvitationFooter)
                if !model.isAdmin { Text(Copy.groupsSettingsInvitationAdminOnly) }
            }
        }
    }

    /// The pickers start at the group's window, or at the current time when it uses the default window (nothing is
    /// saved until the two times differ).
    private func beginEditingHours() {
        editingHours.toggle()
        guard editingHours else { return }
        let now = Date()
        hoursStart = model.group?.wakingStart.map { AccountFormats.date(for: $0, now: now) } ?? now
        hoursEnd = model.group?.wakingEnd.map { AccountFormats.date(for: $0, now: now) } ?? now
    }

    private func saveHours() {
        guard let start = AccountFormats.localTime(of: hoursStart), let end = AccountFormats.localTime(of: hoursEnd),
              start != end else { return }
        if start == model.group?.wakingStart, end == model.group?.wakingEnd { return }
        Task { await model.setInvitationHours(start: start, end: end) }
    }
}
