// Surface: groups.invite — invite by link or from contacts. Visual reference: Retro album link-sharing flow
// (references/auto/retro/press/tc-2024-04-retro-journals-5.png, TC-J5 phones 1–2: book cover with its shadow, eye note,
// "Turn on link sharing", the grouped menu with "Reset link" and the red row, the circular share targets), the cover
// shadow (references/auto/retro/press/tc-2024-04-journals-1.webp, TC-J1) and Retro's people rows with capsule actions
// (references/auto/retro/press/tc-2023-07-retro-1b.webp, TC-1B). Mechanics: system share sheet, SMS compose, contacts
// (design/surfaces/groups.invite.md; MERGE RA-11, RA-25).
import AppData
import AppModels
import AppServices
import Contacts
import ContactsUI
import DesignSystem
import Observation
import SwiftUI
import UIKit

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
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var share: ShareRequest?
    @State private var message: MessageRequest?
    @State private var confirmTurnOff = false
    @State private var pickingContact = false
    @State private var contactQuery = ""
    @State private var contactsShared = false

    init(model: GroupInviteModel) {
        _model = State(initialValue: model)
    }

    private static let linkFade = DSAnimation.timing(duration: Tokens.Durations.globalFade, easing: Tokens.Easings.globalStandard)

    /// The note under the cover: `groups.invite.color.note` in light (measured on TC-J5), `color.global.textSecondary` in
    /// dark (MERGE RA-28).
    private var noteColor: Color {
        colorScheme == .dark ? Tokens.Colors.globalTextSecondary : Tokens.Colors.groupsInviteColorNote
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(
                title: Copy.groupsInviteTitle(groupName: model.group?.name ?? ""),
                closeAccessibilityLabel: Copy.groupsInviteCloseAccessibilityLabel,
                onClose: close
            )
            ScrollView {
                MetricStack(alignment: .center) {
                    GroupCover(
                        source: model.group?.coverPath.map { PhotoSource.storage($0) },
                        width: Tokens.Sizes.groupsInviteSizeCoverWidth,
                        height: Tokens.Sizes.groupsInviteSizeCoverHeight,
                        showsGroupGlyph: false
                    )
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(Copy.groupsInviteCoverAccessibilityLabel(groupName: model.group?.name ?? "")))
                    .accessibilityAddTraits(.isImage)
                    .metricGap(Tokens.Sizes.globalTitleToContent, from: .top, to: .top)
                    note
                        .metricGap(Tokens.Sizes.groupsInviteSizeCoverToNote, from: .bottom, to: .capTop)
                    linkArea
                        .metricGap(Tokens.Sizes.globalTitleToContent, from: .lastBaseline, to: .top)
                    if model.phase == .ready {
                        contactsSection
                            .metricGap(Tokens.Sizes.globalSectionGap, from: .bottom, to: .top)
                    }
                }
                .padding(.bottom, Tokens.Sizes.globalSectionGap)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(Tokens.Colors.globalBackground.ignoresSafeArea())
        .dsSheetBackground()
        .dsAnimation(Self.linkFade, value: model.isLinkOn)
        .dsHaptic(Tokens.Haptics.globalWarning, trigger: model.warningCount)
        .dsHaptic(Tokens.Haptics.globalSend, trigger: model.sendCount)
        .task {
            await model.load()
            contactsShared = ContactsService.authorization().allowsAccess
        }
        .sheet(item: $share) { request in
            ActivityView(items: request.items)
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $message) { request in
            MessageComposeView(request: request) { sent in
                if sent {
                    if let contactID = request.contactID {
                        model.markInvited(contactID)
                    }
                }
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

    /// True when this sheet is the router's modal; false when another sheet hosts it (groups.settings).
    private var isRouterModal: Bool {
        if case .account(.groupInvite)? = dependencies.router.modal { return true }
        return false
    }

    private func close() {
        if isRouterModal {
            dependencies.router.modal = nil
        } else {
            dismiss()
        }
    }

    // MARK: Note

    /// `groups.invite.icon.note` (`size.global.iconSmall`) + `groups.invite.size.noteGlyphGap` + "Anyone with this link can
    /// join {group_name}" (text role `meta`); with the link on, its expiry on a second line (same style). Read as one
    /// sentence.
    private var note: some View {
        VStack {
            HStack(alignment: .firstTextBaseline, spacing: Tokens.Sizes.groupsInviteSizeNoteGlyphGap) {
                Image(systemName: Tokens.Icons.groupsInviteIconNote)
                    .font(Tokens.Fonts.globalFamily.font(size: Tokens.Sizes.globalIconSmall, weight: Font.Weight.regular))
                    .accessibilityHidden(true)
                Text(Copy.groupsInviteLinkLabel(groupName: model.group?.name ?? ""))
                    .dsTextStyle(TextRole.meta)
            }
            if let invite = model.invite {
                Text(Copy.groupsInviteLinkExpiry(date: AccountFormats.expiryDate(invite.expiresAt)))
                    .dsTextStyle(TextRole.meta)
            }
        }
        .foregroundStyle(noteColor)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
        .accessibilityElement(children: .combine)
        .capHeight(of: TextRole.meta)
    }

    // MARK: Link

    @ViewBuilder
    private var linkArea: some View {
        switch model.phase {
        case .loading:
            LoadingHUD()
        case .full:
            EmptyStateView(
                title: Copy.groupsInviteFullTitle(groupName: model.group?.name ?? ""),
                detail: Copy.groupsInviteFullDetail(maxMembers: model.maxMembers.map { String($0) } ?? "")
            )
            .accessibilityIdentifier("groups.invite.full")
        case .error:
            EmptyStateView(
                title: Copy.groupsInviteErrorTitle,
                detail: Copy.groupsInviteErrorDetail,
                action: EmptyStateView.Action(Copy.groupsInviteErrorRetry) { Task { await model.retry() } }
            )
            .accessibilityIdentifier("groups.invite.error")
        case .ready:
            if model.isLinkOn {
                VStack(spacing: Tokens.Sizes.globalTitleToContent) {
                    linkMenu
                    shareTargets
                }
                .transition(.opacity)
            } else {
                PrimaryButton(Copy.groupsInviteLinkTurnOn, isBusy: model.isCreating) {
                    Task { await model.turnOnLink() }
                }
                .padding(.horizontal, Tokens.Sizes.globalButtonMarginH)
                .accessibilityIdentifier("groups.invite.turnOn")
                .transition(.opacity)
            }
        }
    }

    /// The grouped link menu (C-14 group, inset `size.global.buttonMarginH`): "Reset link" and, for the link's creator or
    /// an admin, the red "Turn off link sharing" (C-10); rows `groups.invite.size.menuRowHeight`, glyph ink at
    /// `groups.invite.size.menuGlyphInset`, label at `groups.invite.size.menuTextInset` (text role `textButton`).
    private var linkMenu: some View {
        VStack(spacing: 0) {
            InviteMenuRow(
                title: Copy.groupsInviteLinkReset,
                icon: Tokens.Icons.groupsInviteIconReset,
                isDestructive: false,
                isBusy: model.isCreating
            ) {
                Task { await model.resetLink() }
            }
            .accessibilityIdentifier("groups.invite.reset")
            if model.canTurnOff {
                HairlineDivider()
                InviteMenuRow(title: Copy.groupsInviteLinkTurnOff, icon: Tokens.Icons.globalLock, isDestructive: true, isBusy: false) {
                    confirmTurnOff = true
                }
                .accessibilityIdentifier("groups.invite.turnOff")
            }
        }
        .background(Tokens.Colors.globalControl)
        .clipShape(DSShape.rounded(Tokens.Radii.globalGroupedRow))
        .padding(.horizontal, Tokens.Sizes.globalButtonMarginH)
    }

    /// Message · Copy Link · Share to… — `size.global.circleButtonLarge` circles, centres `groups.invite.size.targetPitch`
    /// apart, labels `groups.invite.size.targetLabelGap` below.
    private var shareTargets: some View {
        HStack(alignment: .top, spacing: 0) {
            ShareTarget(title: Copy.groupsInviteLinkMessageTarget, icon: Tokens.Icons.globalChats) {
                Task { await sendMessage() }
            }
            .accessibilityIdentifier("groups.invite.message")
            ShareTarget(title: Copy.groupsInviteLinkCopy, icon: Tokens.Icons.globalLink) {
                Task { await copyLink() }
            }
            .accessibilityIdentifier("groups.invite.copy")
            ShareTarget(title: Copy.groupsInviteLinkShare, icon: Tokens.Icons.globalShare) {
                Task { await shareLink() }
            }
            .accessibilityIdentifier("groups.invite.share")
        }
    }

    private func sendMessage() async {
        guard let link = await model.linkToShare() else { return }
        let body = model.message(for: link)
        if MessageComposeView.canSendText {
            message = MessageRequest(recipient: nil, body: body, contactID: nil)
        } else {
            share = ShareRequest(items: body == link.absoluteString ? [link] : [body])
        }
    }

    private func copyLink() async {
        guard let link = await model.linkToShare() else { return }
        UIPasteboard.general.url = link
        dependencies.toasts.show(Copy.groupsInviteLinkCopied)
    }

    private func shareLink() async {
        guard let link = await model.linkToShare() else { return }
        let text = model.message(for: link)
        share = ShareRequest(items: text == link.absoluteString ? [link] : [text])
    }

    // MARK: Contacts (groups.invite.layout.contacts)

    private var contactsSection: some View {
        VStack(alignment: .leading, spacing: Tokens.Sizes.globalSectionHeaderToContent) {
            Text(Copy.groupsInviteContactsLabel)
                .dsTextStyle(TextRole.sectionLabel)
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
            contactAccess
            if contactsShared, model.contacts.isEmpty {
                Text(Copy.groupsInviteContactsEmpty)
                    .dsTextStyle(TextRole.body)
                    .foregroundStyle(Tokens.Colors.globalTextSecondary)
                    .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
            }
            LazyVStack(spacing: Tokens.Sizes.globalSectionHeaderToContent) {
                ForEach(model.contacts) { contact in
                    contactRow(contact)
                        .dsTransition(.opacity)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var contactAccess: some View {
        if #available(iOS 18.0, *) {
            VStack(alignment: .leading) {
                SearchField(
                    Copy.onboardingPermissionContactsSearchPlaceholder,
                    text: $contactQuery,
                    accessibilityLabel: Copy.onboardingPermissionContactsSearchPlaceholder
                )
                ContactAccessButton(queryString: contactQuery) { identifiers in
                    Task {
                        let granted = await GrantedContacts.contacts(withIdentifiers: identifiers)
                        granted.forEach { model.add($0) }
                        contactsShared = true
                    }
                }
            }
            .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
            .task(id: contactQuery) { await loadGrantedContacts() }
        } else {
            CapsuleButton(Copy.onboardingPermissionContactsChoose, style: .outline) { pickingContact = true }
                .fixedSize()
                .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
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

    /// C-16 people row: avatar `size.global.avatarPicker` (contact photos are not read: the C-23 fallback), the name
    /// (`listTitle`) and the outline capsule "Invite" → SMS compose addressed to the number; once sent, "Invited"
    /// (`listSubtitle`, `color.global.textSecondary`).
    private func contactRow(_ contact: LocalContact) -> some View {
        let invited = model.invitedContactIDs.contains(contact.id)
        return PeopleRow(name: contact.displayName, avatar: nil) {
            if invited {
                Text(Copy.groupsInviteContactsInvited)
                    .dsTextStyle(TextRole.listSubtitle)
                    .foregroundStyle(Tokens.Colors.globalTextSecondary)
            } else {
                CapsuleButton(Copy.groupsInviteContactsInvite, style: .outline) {
                    Task { await invite(contact) }
                }
                .fixedSize()
            }
        }
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

/// A row of the link menu (TC-J5): glyph at `groups.invite.size.menuGlyphInset`, label at
/// `groups.invite.size.menuTextInset` (text role `textButton`), height `groups.invite.size.menuRowHeight` (a minimum);
/// destructive rows draw glyph and label in `color.global.destructive` (C-10). Busy: the label's place shows the
/// platform activity indicator.
private struct InviteMenuRow: View {
    let title: String
    let icon: String
    let isDestructive: Bool
    let isBusy: Bool
    let action: () -> Void

    var body: some View {
        Button(role: isDestructive ? .destructive : nil, action: action) {
            ZStack(alignment: .leading) {
                Glyph(icon, relativeTo: TextRole.textButton.relativeTo)
                    .padding(.leading, Tokens.Sizes.groupsInviteSizeMenuGlyphInset)
                Group {
                    if isBusy {
                        LoadingHUD()
                    } else {
                        Text(title)
                            .dsTextStyle(TextRole.textButton)
                            .multilineTextAlignment(.leading)
                    }
                }
                .padding(.leading, Tokens.Sizes.groupsInviteSizeMenuTextInset)
                .padding(.trailing, Tokens.Sizes.groupsInviteSizeMenuGlyphInset)
            }
            .foregroundStyle(isDestructive ? Tokens.Colors.globalDestructive : Tokens.Colors.globalTextPrimary)
            .frame(maxWidth: .infinity, minHeight: Tokens.Sizes.groupsInviteSizeMenuRowHeight, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .accessibilityLabel(Text(title))
    }
}

/// A share target: a `size.global.circleButtonLarge` circle in `color.global.control` with the glyph (`size.global.icon`,
/// `color.global.textPrimary`) — C-11's large circle on a page — and the label `groups.invite.size.targetLabelGap` below
/// (text role `meta`, `color.global.textPrimary`, centred), in a `groups.invite.size.targetPitch` wide column. One button
/// labelled with the visible text.
private struct ShareTarget: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            MetricStack(alignment: .center) {
                Glyph(icon)
                    .foregroundStyle(Tokens.Colors.globalTextPrimary)
                    .frame(width: Tokens.Sizes.globalCircleButtonLarge, height: Tokens.Sizes.globalCircleButtonLarge)
                    .background(Tokens.Colors.globalControl, in: Circle())
                Text(title)
                    .dsTextRole(TextRole.meta)
                    .foregroundStyle(Tokens.Colors.globalTextPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .metricGap(Tokens.Sizes.groupsInviteSizeTargetLabelGap, from: .bottom, to: .capTop)
            }
            .frame(width: Tokens.Sizes.groupsInviteSizeTargetPitch)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(.isButton)
    }
}
