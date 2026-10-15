// Account group — GroupInviteModel: state and actions of the screen in GroupInviteScreen.swift.
import AppData
import AppModels
import AppServices
import Contacts
import ContactsUI
import DesignSystem
import Observation
import SwiftUI
import UIKit

@MainActor
@Observable
final class GroupInviteModel {
    enum Phase: Equatable {
        case ready
        /// members = `max_group_members`.
        case full
        /// `create_invite` failed (also offline: the link cannot be created offline).
        case error
    }

    let groupID: GroupID
    private(set) var group: PhotoGroup?
    /// The caller's live invite (not revoked, not expired), reused before creating a new one.
    private(set) var invite: GroupInvite?
    private(set) var isAdmin = false
    private(set) var phase: Phase = .ready
    /// `create_invite` in flight (Loading HUD).
    private(set) var isCreating = false
    private(set) var maxMembers: Int?
    /// Contacts shown as rows (chosen in the picker / granted through `ContactAccessButton`).
    private(set) var contacts: [LocalContact] = []
    /// Rows whose SMS was sent ("invited").
    private(set) var invitedContactIDs: Set<String> = []
    private(set) var warningCount = 0
    private(set) var sendCount = 0

    private let data: AccountDataSource
    private let domain: String?

    init(groupID: GroupID, data: AccountDataSource, domain: String?) {
        self.groupID = groupID
        self.data = data
        self.domain = domain
    }

    /// The share URL (`https://<domain>/i/<token>`); nil while no invite exists or the domain is not configured.
    var link: URL? { invite?.link(domain: domain) }

    /// "turn off link" is offered to the link's creator and admins.
    var canTurnOff: Bool {
        guard let invite else { return false }
        return isAdmin || invite.createdBy == data.currentUserID
    }

    func load() async {
        if group == nil, let cached = await data.cachedGroups()?.first(where: { $0.id == groupID }) {
            group = cached
        }
        if let fresh = try? await data.group(id: groupID) { group = fresh }
        let me = data.currentUserID
        var members = (try? await data.members(groupID: groupID)) ?? []
        if members.isEmpty, let cached = await data.cachedMembers(groupID: groupID) {
            members = cached
        }
        isAdmin = members.contains { $0.member.userID == me && $0.member.role == .admin }
        maxMembers = (try? await data.publicConfig())?.maxGroupMembers
        if let maxMembers, members.count >= maxMembers {
            phase = .full
            return
        }
        let invites = (try? await data.activeInvites(groupID: groupID)) ?? []
        invite = invites.first { $0.createdBy == me && $0.isUsable() }
    }

    /// The link to share: reuses the caller's live invite, else `create_invite`. Nil on failure (error state).
    func linkToShare() async -> URL? {
        if let link { return link }
        isCreating = true
        defer { isCreating = false }
        do {
            invite = try await data.createInvite(groupID: groupID)
        } catch {
            phase = .error
            return nil
        }
        guard let link else {
            // config/app.json `domain` is BLOCKED: no link can be built (reported; error state).
            phase = .error
            return nil
        }
        return link
    }

    /// The text that goes with the link (share sheet and SMS). `groups.invite.link.message` uses `{app_name}` (BLOCKED):
    /// release builds send the link alone.
    func message(for link: URL) -> String {
        AccountBlockedCopy.inviteLinkMessage(groupName: group?.name ?? "", link: link.absoluteString) ?? link.absoluteString
    }

    /// "turn off link" confirmed: `revoke_invite`, applied at once and restored if the request fails.
    func turnOffLink() async -> Bool {
        guard let current = invite else { return false }
        invite = nil
        do {
            try await data.revokeInvite(token: current.token)
            warningCount += 1
            return true
        } catch {
            invite = current
            return false
        }
    }

    /// Error state's retry.
    func retry() async {
        phase = .ready
        _ = await linkToShare()
    }

    func add(_ contact: LocalContact) {
        guard !contacts.contains(where: { $0.id == contact.id }) else { return }
        contacts.append(contact)
    }

    func replaceContacts(_ list: [LocalContact]) {
        contacts = list
    }

    func markInvited(_ contactID: String) {
        invitedContactIDs.insert(contactID)
        sendCount += 1
    }
}
