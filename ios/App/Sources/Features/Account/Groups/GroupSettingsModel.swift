// Account group — GroupSettingsModel: state and actions of the screen in GroupSettingsScreen.swift.
import AppData
import AppModels
import DesignSystem
import Observation
import SwiftUI
import UIKit

@MainActor
@Observable
final class GroupSettingsModel {
    let groupID: GroupID
    private(set) var group: PhotoGroup?
    private(set) var members: [MemberProfile] = []
    private(set) var isLoading = true
    private(set) var muted = false
    private(set) var paused = false
    private(set) var maxMembers: Int?
    /// System notifications are off (permission-denied footer).
    private(set) var systemNotificationsOff = false
    /// Section footers after a failed save (`groups.settings.error.generic` / `.invitation.invalid`).
    private(set) var notificationsError: String?
    private(set) var invitationError: String?
    private(set) var memberError: String?
    private(set) var warningCount = 0
    private(set) var errorCount = 0

    private let data: AccountDataSource
    private let notifications: NotificationAuthorizing

    init(groupID: GroupID, data: AccountDataSource, notifications: NotificationAuthorizing) {
        self.groupID = groupID
        self.data = data
        self.notifications = notifications
    }

    var me: UserID? { data.currentUserID }
    var isAdmin: Bool { members.contains { $0.member.userID == me && $0.member.role == .admin } }
    var isFull: Bool { maxMembers.map { members.count >= $0 } ?? false }

    /// The window's value: `groups.settings.invitation.range` ("{start}-{end}") or `.default`.
    var invitationHoursText: String {
        guard let start = group?.wakingStart, let end = group?.wakingEnd else { return Copy.groupsSettingsInvitationDefault }
        return Copy.groupsSettingsInvitationRange(start: AccountFormats.time(start), end: AccountFormats.time(end))
    }

    func load() async {
        if let cached = await data.cachedMembers(groupID: groupID) { apply(members: cached) }
        if group == nil { group = await data.cachedGroups()?.first { $0.id == groupID } }
        if !members.isEmpty || group != nil { isLoading = false }
        if let fresh = try? await data.group(id: groupID) { group = fresh }
        if let fresh = try? await data.members(groupID: groupID) { apply(members: fresh) }
        paused = group?.invitationPaused ?? false
        maxMembers = (try? await data.publicConfig())?.maxGroupMembers
        systemNotificationsOff = await notifications.authorizationStatus() == .denied
        isLoading = false
    }

    private func apply(members: [MemberProfile]) {
        self.members = members
        muted = members.first { $0.member.userID == me }?.member.muted ?? false
    }

    // MARK: Writes (optimistic; the control reverts and the section footer shows the error on failure)

    func setMuted(_ value: Bool) async {
        let previous = muted
        muted = value
        notificationsError = nil
        do {
            try await data.setMuted(groupID: groupID, muted: value)
        } catch {
            muted = previous
            notificationsError = Copy.groupsSettingsErrorGeneric
            errorCount += 1
        }
    }

    func setPaused(_ value: Bool) async {
        let previous = paused
        paused = value
        invitationError = nil
        do {
            group = try await data.setInvitationPaused(groupID: groupID, paused: value)
        } catch {
            paused = previous
            invitationError = Copy.groupsSettingsErrorGeneric
            errorCount += 1
        }
    }

    /// Both times are saved together (`set_group_invitation_hours`); equal times are not sent.
    func setInvitationHours(start: LocalTime, end: LocalTime) async {
        guard start != end else { return }
        let previous = group
        invitationError = nil
        if var optimistic = group {
            optimistic.wakingStart = start
            optimistic.wakingEnd = end
            group = optimistic
        }
        do {
            group = try await data.setInvitationHours(groupID: groupID, start: start, end: end)
        } catch {
            group = previous
            invitationError = DataError.from(error).apiCode == .invalidWakingWindow
                ? Copy.groupsSettingsInvitationInvalid
                : Copy.groupsSettingsErrorGeneric
            errorCount += 1
        }
    }

    /// `remove_member` (admins), confirmed in the remove alert.
    func remove(_ member: MemberProfile) async {
        let previous = members
        members.removeAll { $0.id == member.id }
        memberError = nil
        do {
            try await data.removeMember(groupID: groupID, userID: member.member.userID)
            warningCount += 1
        } catch {
            members = previous
            memberError = Copy.groupsSettingsErrorGeneric
            errorCount += 1
        }
    }

    func leaveFailed() {
        memberError = Copy.groupsSettingsErrorGeneric
        errorCount += 1
    }

    func seed(group: PhotoGroup, members: [MemberProfile]) {
        self.group = group
        apply(members: members)
        paused = group.invitationPaused
        isLoading = false
    }
}
