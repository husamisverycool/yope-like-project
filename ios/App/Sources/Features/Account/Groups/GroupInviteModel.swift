// Account group — GroupInviteModel: state and actions of groups.invite (GroupInviteScreen.swift): link sharing turned on
// explicitly (`create_invite`), reset (revoke + create) and turned off (`revoke_invite`) as Retro's link-sharing sheet does
// (MERGE RA-11), the share targets, and the contacts section.
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
        /// Reading the group and `group_invites`.
        case loading
        /// Link off (no live invite of yours) or on.
        case ready
        /// members = `max_group_members`.
        case full
        /// The invite read / create failed (also offline: a link cannot be created offline; and while config/app.json
        /// has no `domain`, no link can be built).
        case error
    }

    let groupID: GroupID
    private(set) var group: PhotoGroup?
    /// The caller's live invite (not revoked, not expired): link sharing is on.
    private(set) var invite: GroupInvite?
    private(set) var isAdmin = false
    private(set) var phase: Phase = .loading
    /// `create_invite` (turn on / reset) in flight: the capsule is busy.
    private(set) var isCreating = false
    private(set) var maxMembers: Int?
    /// Contacts shown as rows (chosen in the picker / granted through `ContactAccessButton`).
    private(set) var contacts: [LocalContact] = []
    /// Rows whose SMS was sent ("Invited").
    private(set) var invitedContactIDs: Set<String> = []
    /// `haptic.global.warning` (link turned off) and `haptic.global.send` (SMS sent) triggers.
    private(set) var warningCount = 0
    private(set) var sendCount = 0

    private let data: AccountDataSource
    private let domain: String?

    init(groupID: GroupID, data: AccountDataSource, domain: String?) {
        self.groupID = groupID
        self.data = data
        self.domain = domain
    }

    /// The share URL (`https://<domain>/i/<token>`); nil while no invite is live or the domain is not configured.
    var link: URL? { invite?.link(domain: domain) }
    var isLinkOn: Bool { invite != nil }

    /// "Turn off link sharing" is offered to the link's creator and admins.
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
        do {
            let invites = try await data.activeInvites(groupID: groupID)
            invite = invites.first { $0.createdBy == me && $0.isUsable() }
            phase = .ready
        } catch {
            phase = .error
        }
    }

    /// The link to share: the caller's live invite, else `create_invite` ("Turn on link sharing"). Nil on failure
    /// (error state).
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
        phase = .ready
        return link
    }

    /// "Turn on link sharing".
    func turnOnLink() async {
        _ = await linkToShare()
    }

    /// "Reset link": `revoke_invite(old)` then `create_invite` — a new link; the old one stops working.
    func resetLink() async {
        guard let current = invite else { return }
        isCreating = true
        defer { isCreating = false }
        do {
            try await data.revokeInvite(token: current.token)
            invite = nil
            invite = try await data.createInvite(groupID: groupID)
            if link == nil { phase = .error }
        } catch {
            phase = .error
        }
    }

    /// The text that goes with the link (Message and Share to…): `groups.invite.link.message`.
    func message(for link: URL) -> String {
        Copy.groupsInviteLinkMessage(groupName: group?.name ?? "", link: link.absoluteString)
    }

    /// "Turn off link sharing" confirmed: `revoke_invite`, applied at once and restored if the request fails.
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

    /// The error block's "Try again".
    func retry() async {
        phase = .loading
        await load()
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
