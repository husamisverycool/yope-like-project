// Surface: groups.settings — members, notifications, invitation hours, admin, report, leave. Visual reference: Retro
// Settings sheet (references/auto/retro/video/ig-DJXvmqRv2_N-referrals-sheet-f042-059.png, VID-SET: centred title +
// close circle, small grey section headers, Fill grouped rows), the grouped row height and red row
// (references/auto/retro/press/tc-2024-04-retro-journals-5.png, TC-J5) and Retro's people rows
// (references/auto/retro/press/tc-2023-07-retro-1b.webp, TC-1B); Retro's album settings sections (APK strings
// `journal_settings_*`). Native switches, pickers, menus and alerts (design/surfaces/groups.settings.md; MERGE RA-14,
// RA-26).
import AppData
import AppModels
import DesignSystem
import Observation
import SwiftUI
import UIKit

/// groups.settings: a page sheet with its own navigation (`settings.root.layout.list.sheet`); pages pushed from it
/// (settings.notifications, walls.member) use the native back button.
struct GroupSettingsScreen: View {
    let groupID: String
    @Environment(AccountDependencies.self) private var dependencies

    var body: some View {
        GroupSettingsView(model: GroupSettingsModel(groupID: GroupID(groupID), data: dependencies.data, notifications: dependencies.notifications))
    }
}

struct GroupSettingsView: View {
    @State private var model: GroupSettingsModel
    @State private var path: [AppRoute] = []
    @State private var editingHours = false
    @State private var confirmLeave = false
    @State private var removing: MemberProfile?
    @State private var blockTarget: BlockTarget?
    @State private var reportTarget: ReportTarget?
    @State private var showsInvite = false
    @State private var showsEdit = false
    @Environment(AccountDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss

    init(model: GroupSettingsModel) {
        _model = State(initialValue: model)
    }

    private var isOffline: Bool { dependencies.network.isOffline }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                SheetHeader(title: Copy.groupsSettingsTitle, closeAccessibilityLabel: Copy.groupsSettingsCloseAccessibilityLabel) {
                    dismiss()
                }
                SettingsList {
                    if model.isLoading {
                        loadingSections
                    } else {
                        membersSection
                        notificationsSection
                        invitationSection
                        if model.isAdmin {
                            SettingsGroup(header: Copy.groupsSettingsGroupHeader, rows: [
                                SettingsRow(Copy.groupsSettingsGroupEdit, kind: .navigation { showsEdit = true }, isEnabled: !isOffline)
                                    .accessibilityIdentifier("groups.settings.edit")
                                    .asSettingsRow(),
                            ])
                            // question.weekly E: the weekly question's switch (admins, as the group's other settings).
                            QuestionSettingsSection(groupID: model.groupID.rawValue, isOffline: isOffline)
                        }
                        SettingsGroup(rows: [
                            SettingsRow(Copy.groupsSettingsReport, kind: .destructive { reportGroup() })
                                .accessibilityIdentifier("groups.settings.report")
                                .asSettingsRow(),
                            SettingsRow(Copy.groupsSettingsLeave, kind: .destructive { confirmLeave = true }, isEnabled: !isOffline)
                                .accessibilityIdentifier("groups.settings.leave")
                                .asSettingsRow(),
                        ])
                    }
                }
            }
            .background(Tokens.Colors.globalBackground.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: AppRoute.self) { route in
                RouteDestination(route: route)
            }
        }
        .environment(\.settingsPush, SettingsPushAction(path: $path))
        .dsSheetBackground()
        .task { await model.load() }
        .leaveGroupAlert(
            isPresented: $confirmLeave,
            group: model.group,
            isLastMember: model.members.count <= 1,
            data: dependencies.data,
            onFailed: { model.leaveFailed() }
        ) {
            model.didLeave()
            dismiss()
            ShellState.active?.presentedRoute = nil
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
        .reportFlow(target: $reportTarget, dependencies: dependencies)
        .formErrorAlert(model.alertMessage, trigger: model.errorCount)
        .sheet(isPresented: $showsInvite) {
            GroupInviteScreen(groupID: model.groupID.rawValue)
                .environment(dependencies)
                .environment(\.storageURLResolver, dependencies.storageURLResolver)
        }
        .sheet(isPresented: $showsEdit, onDismiss: { Task { await model.load() } }) {
            GroupCreateScreen(editingGroupID: model.groupID.rawValue)
                .environment(dependencies)
                .environment(\.storageURLResolver, dependencies.storageURLResolver)
        }
        .sheet(isPresented: $editingHours) {
            InvitationHoursSheet(group: model.group) { start, end in
                Task { await model.setInvitationHours(start: start, end: end) }
            }
        }
        .dsHaptic(Tokens.Haptics.globalWarning, trigger: model.warningCount)
        .dsHaptic(Tokens.Haptics.globalError, trigger: model.errorCount)
        .accessibilityIdentifier("groups.settings")
    }

    // MARK: Loading

    /// Loading: each section with one row showing the platform activity indicator (C-28).
    private var loadingSections: some View {
        ForEach([Copy.groupsSettingsMembersHeader, Copy.groupsSettingsNotificationsHeader, Copy.groupsSettingsInvitationHeader], id: \.self) { header in
            SettingsGroup(header: header, rows: [SettingsRow("", kind: .busy).asSettingsRow()])
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(Copy.globalA11yLoading))
    }

    // MARK: Members

    private var membersSection: some View {
        var rows: [AnyView] = model.membersInJoiningOrder.map { memberRow($0).asSettingsRow() }
        if !model.isFull {
            rows.append(
                SettingsCustomRow {
                    OutlineCTA(GroupKindCopy.settingsInvite(model.group?.kind)) { showsInvite = true }
                        .fixedSize()
                        .accessibilityIdentifier("groups.settings.invite")
                }
                .asSettingsRow()
            )
        }
        return SettingsGroup(header: Copy.groupsSettingsMembersHeader, rows: rows)
    }

    /// C-16 in a C-14 row: avatar `size.global.avatarPicker`, first name (`listTitle`), "You" / "Admin" (`listSubtitle`,
    /// grey); others' rows end with "•••" (native menu: Remove from Group for admins, Report Profile, Block Profile —
    /// destructive items red). The row opens that person's wall (walls.member) inside the sheet.
    private func memberRow(_ member: MemberProfile) -> some View {
        let isMe = member.member.userID == model.me
        let firstName = member.profile?.firstName ?? member.profile?.displayName ?? ""
        let line: String? = isMe ? Copy.groupsSettingsMembersYou : (member.member.role == .admin ? Copy.groupsSettingsMembersAdmin : nil)
        return HStack(spacing: 0) {
            Button {
                if let route = CrossGroupRoutes.wallMember(userID: member.member.userID.rawValue) { path.append(route) }
            } label: {
                HStack {
                    AvatarView(path: member.profile?.avatarPath, diameter: Tokens.Sizes.globalAvatarPicker)
                    VStack(alignment: .leading) {
                        Text(firstName)
                            .dsTextStyle(TextRole.listTitle)
                            .foregroundStyle(Tokens.Colors.globalTextPrimary)
                        if let line {
                            Text(line)
                                .dsTextStyle(TextRole.listSubtitle)
                                .foregroundStyle(Tokens.Colors.globalTextSecondary)
                        }
                    }
                    .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                }
                .modifier(SettingsRowFrame())
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            if !isMe {
                HeaderIconMenu(icon: Tokens.Icons.globalMore, accessibilityLabel: Copy.groupsSettingsMembersMoreAccessibilityLabel) {
                    if model.isAdmin {
                        Button(Copy.groupsSettingsMembersMenuRemove, role: .destructive) { removing = member }
                    }
                    Button(Copy.groupsSettingsMembersMenuReport, role: .destructive) {
                        reportTarget = ReportTarget(
                            kind: .user, id: member.member.userID.rawValue, name: firstName,
                            person: BlockTarget(userID: member.member.userID.rawValue, firstName: firstName),
                            groupID: model.groupID.rawValue, groupName: model.group?.name
                        )
                    }
                    Button(Copy.groupsSettingsMembersMenuBlock, role: .destructive) {
                        blockTarget = BlockTarget(userID: member.member.userID.rawValue, firstName: firstName)
                    }
                }
                .padding(.trailing, Tokens.Sizes.globalScreenMargin - (Tokens.Sizes.globalHeaderButton - Tokens.Sizes.globalIcon) / 2)
            }
        }
        .accessibilityIdentifier("groups.settings.member")
    }

    // MARK: Notifications

    private var notificationsSection: some View {
        SettingsGroup(
            header: Copy.groupsSettingsNotificationsHeader,
            footer: [Copy.groupsSettingsNotificationsFooter],
            rows: [
                SettingsRow(
                    Copy.groupsSettingsNotificationsUpdates,
                    kind: .toggle(Binding(get: { !model.muted }, set: { on in Task { await model.setMuted(!on) } })),
                    isEnabled: !isOffline
                )
                .accessibilityIdentifier("groups.settings.updates")
                .asSettingsRow(),
                SettingsRow(Copy.groupsSettingsNotificationsQuietHours, kind: .navigation { path.append(.account(.settingsNotifications)) })
                    .accessibilityIdentifier("groups.settings.quietHours")
                    .asSettingsRow(),
            ]
        )
    }

    // MARK: Daily invitation

    /// Invitation Hours (value: the window or "Default") → native time pickers; Pause Invitations. Members who are not
    /// admins see the rows disabled and the admin-only line.
    private var invitationSection: some View {
        var footer = [Copy.groupsSettingsInvitationFooter]
        if !model.isAdmin { footer.append(Copy.groupsSettingsInvitationAdminOnly) }
        return SettingsGroup(
            header: Copy.groupsSettingsInvitationHeader,
            footer: footer,
            rows: [
                SettingsRow(
                    Copy.groupsSettingsInvitationHours,
                    value: model.invitationHoursText,
                    kind: .navigation { editingHours = true },
                    isEnabled: model.isAdmin && !isOffline
                )
                .accessibilityIdentifier("groups.settings.hours")
                .asSettingsRow(),
                SettingsRow(
                    Copy.groupsSettingsInvitationPause,
                    kind: .toggle(Binding(get: { model.paused }, set: { value in Task { await model.setPaused(value) } })),
                    isEnabled: model.isAdmin && !isOffline
                )
                .accessibilityIdentifier("groups.settings.pause")
                .asSettingsRow(),
            ]
        )
    }

    private func reportGroup() {
        reportTarget = ReportTarget(
            kind: .group, id: model.groupID.rawValue, name: model.group?.name,
            groupID: model.groupID.rawValue, groupName: model.group?.name
        )
    }
}

/// The invitation window's native time pickers in a sheet (`DatePicker(.hourAndMinute)`): Start and End rows and the
/// system toolbar (Cancel / Save). The pickers start at the group's window, or at the current time when it uses the
/// default window; equal times are not saved.
struct InvitationHoursSheet: View {
    let group: PhotoGroup?
    let onSave: (LocalTime, LocalTime) -> Void
    @State private var start = Date()
    @State private var end = Date()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            SettingsList {
                SettingsGroup(rows: [
                    SettingsCustomRow {
                        DatePicker(selection: $start, displayedComponents: .hourAndMinute) {
                            Text(Copy.settingsNotificationsQuietHoursStart)
                                .dsTextStyle(TextRole.body)
                                .foregroundStyle(Tokens.Colors.globalTextPrimary)
                        }
                    }
                    .asSettingsRow(),
                    SettingsCustomRow {
                        DatePicker(selection: $end, displayedComponents: .hourAndMinute) {
                            Text(Copy.settingsNotificationsQuietHoursEnd)
                                .dsTextStyle(TextRole.body)
                                .foregroundStyle(Tokens.Colors.globalTextPrimary)
                        }
                    }
                    .asSettingsRow(),
                ])
            }
            .sheetToolbar(
                title: Copy.groupsSettingsInvitationHours,
                cancelTitle: Copy.groupsSettingsAlertCancel,
                onCancel: { dismiss() },
                confirmTitle: Copy.groupsCreateSave,
                onConfirm: save
            )
        }
        .presentationDetents([.medium])
        .dsSheetBackground()
        .onAppear {
            let now = Date()
            start = group?.wakingStart.map { AccountFormats.date(for: $0, now: now) } ?? now
            end = group?.wakingEnd.map { AccountFormats.date(for: $0, now: now) } ?? now
        }
    }

    private func save() {
        defer { dismiss() }
        guard let from = AccountFormats.localTime(of: start), let to = AccountFormats.localTime(of: end), from != to else { return }
        if from == group?.wakingStart, to == group?.wakingEnd { return }
        onSave(from, to)
    }
}

extension View {
    /// The leave confirmation (`settings.account.layout.alert`): title `groups.settings.leave.title`, message `.message`
    /// or `.messageLast` (last member), destructive `.confirm`, `groups.settings.alert.cancel`. Confirm →
    /// `leave_group` → `onLeft`.
    func leaveGroupAlert(
        isPresented: Binding<Bool>,
        group: PhotoGroup?,
        isLastMember: Bool,
        data: AccountDataSource,
        onFailed: @escaping @MainActor () -> Void = {},
        onLeft: @escaping @MainActor () -> Void
    ) -> some View {
        alert(Text(Copy.groupsSettingsLeaveTitle(groupName: group?.name ?? "")), isPresented: isPresented) {
            Button(Copy.groupsSettingsAlertCancel, role: .cancel) {}
            Button(Copy.groupsSettingsLeaveConfirm, role: .destructive) {
                guard let group else { return }
                Task { @MainActor in
                    do {
                        try await data.leaveGroup(id: group.id)
                        onLeft()
                    } catch {
                        onFailed()
                    }
                }
            }
        } message: {
            Text(isLastMember ? Copy.groupsSettingsLeaveMessageLast : Copy.groupsSettingsLeaveMessage)
        }
    }
}
