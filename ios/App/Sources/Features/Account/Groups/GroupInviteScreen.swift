// Surface: groups.invite — invite by link or from contacts. Reference app: Yope (2026 "invite more friends" pill; 2024
// "Add friends to {group}" sheet; design/surfaces/groups.invite.md). Reference images:
// references/auto/yope/frames/a-yrrah-7452976839846382855-t10.73-add-friends-share-link-2024.png (I24),
// a-itsmthuyope-7644974799302823175-t51.23-group-created-empty-state.png (E26),
// a-yrrah-7434441926000037121-t33.73-group-menu-leave-report-2024.png (M24), …-t49.23-new-group-selected-create.png (NG2),
// a-chuongxetank-7694968408424582452-t7.73-posted-toast-contacts-card.png (CC), a-virgi-7686278541255642390-t44.23-suggested-friends-es.png (SF).
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

/// groups.invite sheet.
struct GroupInviteScreen: View {
    let groupID: String
    @Environment(AccountDependencies.self) private var dependencies

    var body: some View {
        GroupInviteView(model: GroupInviteModel(groupID: GroupID(groupID), data: dependencies.data, domain: dependencies.configuration.domain))
    }
}

struct GroupInviteView: View {
    @State private var model: GroupInviteModel
    @Environment(AccountDependencies.self) private var dependencies
    @State private var share: ShareRequest?
    @State private var message: MessageRequest?
    @State private var confirmTurnOff = false
    @State private var pickingContact = false
    @State private var contactQuery = ""

    init(model: GroupInviteModel) {
        _model = State(initialValue: model)
    }

    private static let pickerNameStyle = DSTextStyle(
        family: Tokens.Fonts.globalFamily,
        size: Tokens.FontSizes.groupsInviteFontSizePickerName,
        weight: Tokens.FontWeights.groupsInviteFontWeightPickerName,
        relativeTo: .footnote
    )

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                title
                    .padding(.top, Tokens.Sizes.groupsCreateSizeTitleToContent)
                switch model.phase {
                case .ready:
                    linkSection
                        .padding(.top, Tokens.Sizes.groupsCreateSizeTitleToContent)
                    contactsSection
                        .padding(.top, Tokens.Sizes.groupsCreateSizeTitleToContent)
                case .full:
                    EmptyStateView(
                        title: Copy.groupsInviteFullTitle(groupName: model.group?.name ?? ""),
                        detail: Copy.groupsInviteFullDetail(maxMembers: model.maxMembers.map(String.init) ?? "")
                    )
                    .padding(.top, Tokens.Sizes.groupsCreateSizeTitleToContent)
                case .error:
                    EmptyStateView(
                        title: Copy.groupsInviteErrorTitle,
                        detail: Copy.groupsInviteErrorDetail,
                        action: EmptyStateView.Action(Copy.groupsInviteErrorRetry) { Task { await model.retry() } }
                    )
                    .padding(.top, Tokens.Sizes.groupsCreateSizeTitleToContent)
                }
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Tokens.Colors.globalBackgroundDeep.ignoresSafeArea())
        .loadingHUD(model.isCreating)
        .dsHaptic(Tokens.Haptics.globalWarning, trigger: model.warningCount)
        .dsHaptic(Tokens.Haptics.globalSend, trigger: model.sendCount)
        .task { await model.load() }
        .sheet(item: $share) { request in
            ActivityView(items: request.items)
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $message) { request in
            MessageComposeView(request: request) { sent in
                if sent { model.markInvited(request.contactID) }
                message = nil
            }
            .ignoresSafeArea()
        }
        .background {
            ContactPickerPresenter(isPresented: $pickingContact) { contact in model.add(contact) }
                .frame(width: 0, height: 0)
        }
        .alert(Text(Copy.groupsInviteLinkTurnOffTitle), isPresented: $confirmTurnOff) {
            Button(Copy.groupsInviteLinkTurnOffCancel, role: .cancel) {}
            Button(Copy.groupsInviteLinkTurnOffConfirm, role: .destructive) {
                Task {
                    if await model.turnOffLink() { dependencies.toasts.show(Copy.groupsInviteLinkTurnedOff) }
                }
            }
        } message: {
            Text(Copy.groupsInviteLinkTurnOffMessage)
        }
        .accessibilityIdentifier("groups.invite")
    }

    private var header: some View {
        HStack {
            HeaderCircleButton(icon: Tokens.Icons.globalClose, accessibilityLabel: Copy.groupsInviteCloseAccessibilityLabel, fill: .onDeep) {
                dependencies.router.modal = nil
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Tokens.Sizes.globalHeaderInset)
        .padding(.top, Tokens.Sizes.globalHeaderInset)
    }

    /// "add {members} to" / group name in lime (`groups.create.layout.titleAccent`), by `groups.kind`.
    private var title: some View {
        let name = model.group?.name ?? ""
        let text: String
        switch model.group?.kind ?? .friends {
        case .family: text = Copy.groupsInviteTitleFamily(groupName: name)
        case .roommates: text = Copy.groupsInviteTitleRoommates(groupName: name)
        case .custom, .unknown: text = Copy.groupsInviteTitleCustom(groupName: name)
        case .friends: text = Copy.groupsInviteTitleFriends(groupName: name)
        }
        return TwoToneTitle(text: text, accent: name)
            .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
    }

    private func sectionLabel(_ text: String, icon: String? = nil) -> some View {
        HStack {
            if let icon {
                Image(systemName: icon).accessibilityHidden(true)
            }
            Text(text)
        }
        .dsTextStyle(TextRole.sectionLabel)
        .foregroundStyle(Tokens.Colors.globalTextSecondary)
    }

    // MARK: Link

    private var linkSection: some View {
        VStack {
            sectionLabel(Copy.groupsInviteLinkLabel, icon: Tokens.Icons.globalLink)
            LightPill(Copy.groupsInviteLinkShare, icon: Tokens.Icons.globalLink) {
                Task { await shareLink() }
            }
            .accessibilityIdentifier("groups.invite.share")
            if let invite = model.invite {
                Text(Copy.groupsInviteLinkExpiry(date: AccountFormats.expiryDate(invite.expiresAt)))
                    .dsTextStyle(TextRole.caption)
                    .foregroundStyle(Tokens.Colors.globalTextSecondary)
                if model.canTurnOff {
                    Button {
                        confirmTurnOff = true
                    } label: {
                        Text(Copy.groupsInviteLinkTurnOff)
                            .dsTextStyle(TextRole.textLink)
                            .foregroundStyle(Tokens.Colors.globalAccent)
                            .frame(minHeight: Tokens.Sizes.globalMinTouchTargetIos)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("groups.invite.turnOff")
                }
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
    }

    private func shareLink() async {
        guard let link = await model.linkToShare() else { return }
        let text = model.message(for: link)
        share = ShareRequest(items: text == link.absoluteString ? [link] : [text])
    }

    // MARK: Contacts (groups.invite.layout.contacts)

    private var contactsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel(Copy.groupsInviteContactsLabel)
                .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
            contactAccess
                .padding(.horizontal, Tokens.Sizes.globalButtonMarginH)
            LazyVStack(spacing: 0) {
                ForEach(model.contacts) { contact in
                    contactRow(contact)
                }
            }
        }
    }

    @ViewBuilder
    private var contactAccess: some View {
        if #available(iOS 18.0, *) {
            VStack {
                FormField(
                    Copy.onboardingPermissionContactsSearchPlaceholder,
                    text: $contactQuery,
                    accessibilityLabel: Copy.onboardingPermissionContactsSearchPlaceholder,
                    contentType: .name
                )
                ContactAccessButton(queryString: contactQuery) { identifiers in
                    Task {
                        let granted = await GrantedContacts.contacts(withIdentifiers: identifiers)
                        granted.forEach { model.add($0) }
                    }
                }
            }
            .task(id: contactQuery) { await loadGrantedContacts() }
        } else {
            LightPill(Copy.onboardingPermissionContactsChoose) { pickingContact = true }
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("groups.invite.chooseContacts")
        }
    }

    /// iOS 18: contacts already shared with the app (limited or full access) that match the search.
    private func loadGrantedContacts() async {
        guard ContactsService.authorization().allowsAccess else { return }
        let all = (try? await ContactsService().contactsWithPhoneNumbers()) ?? []
        let query = contactQuery.trimmingCharacters(in: .whitespaces)
        let matches = query.isEmpty ? all : all.filter { $0.displayName.localizedCaseInsensitiveContains(query) }
        model.replaceContacts(matches)
    }

    /// Row pitch `groups.invite.size.pickerRowPitch`, margins `size.global.screenMargin`: avatar
    /// `size.global.avatarPicker` (gray circle + `icon.global.person`; contact photos are not read), bold name
    /// (`groups.invite.fontSize.pickerName`), trailing white "invite" pill → SMS compose; then "invited".
    private func contactRow(_ contact: LocalContact) -> some View {
        let invited = model.invitedContactIDs.contains(contact.id)
        return HStack {
            AvatarView(diameter: Tokens.Sizes.globalAvatarPicker)
            Text(contact.displayName)
                .dsTextStyle(Self.pickerNameStyle)
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
            Spacer(minLength: 0)
            if invited {
                Text(Copy.groupsInviteContactsInvited)
                    .dsTextStyle(TextRole.button)
                    .foregroundStyle(Tokens.Colors.globalTextSecondary)
            } else {
                LightPill(Copy.groupsInviteContactsInvite, metrics: .card) {
                    Task { await invite(contact) }
                }
            }
        }
        .frame(minHeight: Tokens.Sizes.groupsInviteSizePickerRowPitch)
        .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
        .accessibilityElement(children: .combine)
    }

    private func invite(_ contact: LocalContact) async {
        guard let number = contact.phoneNumbers.first?.canonical, let link = await model.linkToShare() else { return }
        let body = model.message(for: link)
        if MessageComposeView.canSendText {
            message = MessageRequest(recipient: number, body: body, contactID: contact.id)
        } else {
            share = ShareRequest(items: body == link.absoluteString ? [link] : [body])
        }
    }
}
