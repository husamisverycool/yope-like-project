// Surface: groups.screen — the group screen, view A (feed: header, photo cards, floating "chat" pill). View B (profile
// page) is GroupProfileScreen. Reference app: Yope (design/surfaces/groups.screen.md). Reference images:
// references/auto/yope/frames/a-itsmthuyope-7644974799302823175-t43.73-group-screen-hourly.png (G1),
// …-t51.23-group-created-empty-state.png (G2), …-t51.73-group-profile-add-20-pics.png (G3),
// references/auto/yope/store/yope-store-01.png (S1), a-yrrah-7434441926000037121-t33.73-group-menu-leave-report-2024.png (M24),
// references/auto/yope/web/a-bi-2025-create-group-composite.jpg (BI).
import AppData
import AppModels
import DesignSystem
import SwiftUI
import UIKit

/// `AppRoute.group(id:)`.
struct GroupScreen: View {
    let groupID: String
    @Environment(AccountDependencies.self) private var dependencies

    var body: some View {
        GroupFeedView(model: GroupFeedModel(groupID: GroupID(groupID), data: dependencies.data))
    }
}

struct GroupFeedView: View {
    @State private var model: GroupFeedModel
    @State private var blockTarget: BlockTarget?
    @Environment(AccountDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.displayScale) private var displayScale

    init(model: GroupFeedModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        GeometryReader { proxy in
            content(width: proxy.size.width)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Tokens.Colors.globalBackground.ignoresSafeArea())
        .safeAreaInset(edge: .top, spacing: 0) { header }
        .overlay(alignment: .bottom) {
            if model.phase == .loaded { chatPill }
        }
        .toolbar(.hidden, for: .navigationBar)
        .loadingHUD(model.phase == .loading)
        .task { await model.load() }
        .onDisappear { model.stop() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await model.refresh() } }
        }
        .onChange(of: model.insertedCount) { _, _ in
            UIAccessibility.post(notification: .layoutChanged, argument: nil)
        }
        .blockConfirmation(target: $blockTarget, toasts: dependencies.toasts) { target in
            try await dependencies.data.block(userID: UserID(target.userID))
        } onBlocked: { target in
            Task { await model.blocked(UserID(target.userID)) }
        }
        .accessibilityIdentifier("groups.screen")
    }

    // MARK: Header (S1)

    /// ‹ · capsule (avatar · name · ›) · calendar · recap; circles `size.global.headerButton` in `color.global.control`,
    /// `size.global.headerGap` apart, `size.global.headerInset` from the edges.
    private var header: some View {
        HStack(spacing: Tokens.Sizes.globalHeaderGap) {
            HeaderCircleButton(icon: Tokens.Icons.globalBack, accessibilityLabel: Copy.groupsScreenBackAccessibilityLabel, fill: .onBackground) {
                dismiss()
            }
            .accessibilityIdentifier("groups.screen.back")
            if model.phase != .removed, let group = model.group {
                GroupHeaderCapsule(group: group) {
                    dependencies.router.path.append(.account(.groupProfile(groupID: model.groupID.rawValue)))
                }
                .layoutPriority(1)
                Spacer(minLength: 0)
                HeaderCircleButton(icon: Tokens.Icons.globalCalendar, accessibilityLabel: Copy.groupsScreenWeeksAccessibilityLabel, fill: .onBackground) {
                    openWeeks()
                }
                HeaderCircleButton(icon: Tokens.Icons.globalRecap, accessibilityLabel: Copy.groupsScreenRecapAccessibilityLabel, fill: .onBackground) {
                    openRecap()
                }
            } else {
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, Tokens.Sizes.globalHeaderInset)
    }

    private func openWeeks() {
        if let route = CrossGroupRoutes.weekHistory(groupID: model.groupID.rawValue) {
            dependencies.router.path.append(route)
        }
    }

    /// The latest recap, or `week.history` when there is none.
    private func openRecap() {
        if let recap = model.latestRecapID {
            dependencies.router.path.append(.recap(groupID: model.groupID.rawValue, recapID: recap.rawValue))
        } else {
            openWeeks()
        }
    }

    // MARK: Content

    @ViewBuilder
    private func content(width: CGFloat) -> some View {
        switch model.phase {
        case .loading:
            Color.clear
        case .loaded:
            feed(width: width)
        case .created:
            EmptyStateView(
                title: Copy.groupsScreenCreatedTitle,
                detail: model.joinedNames.map { Copy.groupsScreenCreatedDetail(names: $0) },
                action: EmptyStateView.Action(GroupKindCopy.createdInvite(model.group?.kind), icon: Tokens.Icons.globalLink) {
                    dependencies.router.modal = .account(.groupInvite(groupID: model.groupID.rawValue))
                }
            )
            .accessibilityIdentifier("groups.screen.created")
        case .empty:
            EmptyStateView(
                title: Copy.groupsScreenEmptyTitle,
                detail: Copy.groupsScreenEmptyDetail,
                action: EmptyStateView.Action(Copy.groupsScreenEmptyButton, icon: Tokens.Icons.globalCamera) {
                    dependencies.router.modal = .camera(groupID: model.groupID.rawValue, invitationID: nil)
                }
            )
        case .error:
            EmptyStateView(
                title: Copy.groupsScreenErrorTitle,
                detail: Copy.groupsScreenErrorDetail,
                action: EmptyStateView.Action(Copy.groupsScreenErrorRetry) { Task { await model.retry() } }
            )
        case .offline:
            EmptyStateView(title: Copy.groupsScreenOfflineTitle, detail: Copy.groupsScreenOfflineDetail)
        case .removed:
            EmptyStateView(title: Copy.groupsScreenRemovedTitle, detail: Copy.groupsScreenRemovedDetail)
        }
    }

    private func feed(width: CGFloat) -> some View {
        let cardWidth = width - Tokens.Sizes.groupsScreenSizeCardMarginH * 2
        let pixels = Int((max(cardWidth, Tokens.Sizes.groupsScreenSizeCardHeight) * displayScale).rounded(.up))
        let items = model.items
        return ScrollView {
            LazyVStack(spacing: Tokens.Sizes.groupsScreenSizeCardGap) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    feedItem(item)
                        .dsTransition(.move(edge: .top).combined(with: .opacity))
                        .onAppear {
                            if index >= items.count - 3 {
                                Task {
                                    await model.loadMore()
                                    await model.prefetchImages(after: index, pixels: pixels)
                                }
                            }
                        }
                }
            }
            .padding(.horizontal, Tokens.Sizes.groupsScreenSizeCardMarginH)
            .padding(.bottom, Tokens.Sizes.groupsScreenSizeChatPillHeight + Tokens.Sizes.groupsScreenSizeCardGap)
            .dsAnimation(.spring(Tokens.Springs.globalPlatformDefaultIos), value: model.posts.map(\.id))
        }
        .refreshable { await model.refresh() }
    }

    @ViewBuilder
    private func feedItem(_ item: FeedItem) -> some View {
        switch item {
        case let .post(post):
            PhotoCard(
                post: post,
                author: model.profile(of: post.post.authorID),
                isOwn: post.post.authorID == model.me,
                onOpen: { openPost(post) },
                onReport: { report(post) },
                onBlock: { block(post) }
            )
        case let .joined(member):
            JoinedPill(member: member)
        }
    }

    private func openPost(_ post: PostWithMedia) {
        dependencies.router.path.append(.post(groupID: model.groupID.rawValue, postID: post.id.rawValue))
    }

    private func report(_ post: PostWithMedia) {
        let author = model.profile(of: post.post.authorID)
        dependencies.router.modal = .account(.report(ReportTarget(
            kind: .post,
            id: post.id.rawValue,
            person: BlockTarget(userID: post.post.authorID.rawValue, firstName: author?.firstName ?? "")
        )))
    }

    private func block(_ post: PostWithMedia) {
        let author = model.profile(of: post.post.authorID)
        blockTarget = BlockTarget(userID: post.post.authorID.rawValue, firstName: author?.firstName ?? "")
    }

    /// Floating "chat" pill, bottom centre: `groups.screen.size.chatPillWidth` × `.chatPillHeight` (minimums),
    /// `groups.screen.color.chatPill`, corners `radius.global.button` (approximation, not measured),
    /// `icon.global.chats` + `groups.screen.chat` (`groups.screen.fontSize.chatPill`, bold per the spec, white).
    private var chatPill: some View {
        Button {
            dependencies.router.path.append(.chat(groupID: model.groupID.rawValue, messageID: nil))
        } label: {
            HStack {
                Image(systemName: Tokens.Icons.globalChats)
                    .accessibilityHidden(true)
                Text(Copy.groupsScreenChat)
                    .dsTextStyle(GroupScreenStyle.chatPill)
            }
            .foregroundStyle(Tokens.Colors.globalTextPrimary)
            .frame(minWidth: Tokens.Sizes.groupsScreenSizeChatPillWidth, minHeight: Tokens.Sizes.groupsScreenSizeChatPillHeight)
            .background(Tokens.Colors.groupsScreenColorChatPill, in: RoundedRectangle(cornerRadius: Tokens.Radii.globalButton))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("groups.screen.chat")
    }
}

/// Text styles of the group screen.
enum GroupScreenStyle {
    /// `groups.screen.fontSize.chatPill`, bold (spec; no weight token), Dynamic Type subheadline.
    static let chatPill = DSTextStyle(family: Tokens.Fonts.globalFamily, size: Tokens.FontSizes.groupsScreenFontSizeChatPill, weight: Font.Weight.bold, relativeTo: .subheadline)
    /// Author first name on a card: text role listSubtitle (`fontSize.global.listSubtitle`, `fontWeight.global.listSubtitle`).
    static let cardName = TextRole.listSubtitle
    /// Profile page name: `groups.screen.fontSize.profileName` / `.fontWeight.profileName`, Dynamic Type title1.
    static let profileName = DSTextStyle(family: Tokens.Fonts.globalFamily, size: Tokens.FontSizes.groupsScreenFontSizeProfileName, weight: Tokens.FontWeights.groupsScreenFontWeightProfileName, relativeTo: .title)
}

/// Per-type copy of the group screens.
enum GroupKindCopy {
    /// `groups.screen.created.invite.*`
    static func createdInvite(_ kind: GroupKind?) -> String {
        switch kind {
        case .family: return Copy.groupsScreenCreatedInviteFamily
        case .roommates: return Copy.groupsScreenCreatedInviteRoommates
        case .custom, .unknown: return Copy.groupsScreenCreatedInviteCustom
        case .friends, .none: return Copy.groupsScreenCreatedInviteFriends
        }
    }

    /// `groups.settings.members.invite.*`
    static func settingsInvite(_ kind: GroupKind?) -> String {
        switch kind {
        case .family: return Copy.groupsSettingsMembersInviteFamily
        case .roommates: return Copy.groupsSettingsMembersInviteRoommates
        case .custom, .unknown: return Copy.groupsSettingsMembersInviteCustom
        case .friends, .none: return Copy.groupsSettingsMembersInviteFriends
        }
    }
}

/// The header capsule: group avatar `size.global.avatarHeader` · name (text role `headerTitle`, one line) ·
/// `icon.global.chevron` in `color.global.textSecondary`; height `size.global.headerButton`, fill `color.global.control`,
/// `radius.global.capsule`. The avatar sits concentric with the capsule's rounded end (inset
/// (`headerButton` − `avatarHeader`) / 2 on every side; Yope's inner insets were not measured).
struct GroupHeaderCapsule: View {
    let group: PhotoGroup
    let action: () -> Void

    private var inset: CGFloat { (Tokens.Sizes.globalHeaderButton - Tokens.Sizes.globalAvatarHeader) / 2 }

    var body: some View {
        Button(action: action) {
            HStack {
                AvatarView(path: group.coverPath, diameter: Tokens.Sizes.globalAvatarHeader, placeholderIcon: Tokens.Icons.globalGroup)
                Text(group.name)
                    .dsTextStyle(TextRole.headerTitle)
                    .foregroundStyle(Tokens.Colors.globalTextPrimary)
                    .lineLimit(1)
                Image(systemName: Tokens.Icons.globalChevron)
                    .foregroundStyle(Tokens.Colors.globalTextSecondary)
                    .accessibilityHidden(true)
            }
            .padding(.leading, inset)
            .padding(.trailing, Tokens.Sizes.globalHeaderButton / 2)
            .frame(minHeight: Tokens.Sizes.globalHeaderButton)
            .background(Tokens.Colors.globalControl, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(Copy.groupsScreenHeaderAccessibilityLabel(groupName: group.name)))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("groups.screen.capsule")
    }
}

/// A photo card: full width minus `groups.screen.size.cardMarginH`, height `groups.screen.size.cardHeight`, corners
/// `groups.screen.radius.card`, photo aspect-fill. Centred time (text role `overlayTime`, white) and caption (text
/// role `listSubtitle`, white); author avatar `size.global.avatarHeader` + first name at the bottom-leading corner and a
/// ••• circle (`icon.global.more` on `color.global.controlRaised`, approximation) at the bottom-trailing corner, both
/// `groups.screen.size.cardGap` from the edges (insets not measured, spec Gaps). No scrim (`color.global.scrim` is
/// BLOCKED): overlay contrast depends on the photo.
struct PhotoCard: View {
    let post: PostWithMedia
    let author: Profile?
    let isOwn: Bool
    let onOpen: () -> Void
    let onReport: () -> Void
    let onBlock: () -> Void

    private var time: String { AccountFormats.time(post.post.createdAt) }

    var body: some View {
        Button(action: onOpen) {
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: Tokens.Sizes.groupsScreenSizeCardHeight)
                .overlay {
                    StorageImage(path: post.media?.imagePath(for: .display)) {
                        Tokens.Colors.globalControl
                    }
                }
                .overlay {
                    VStack(spacing: 0) {
                        Text(time)
                            .dsTextStyle(TextRole.overlayTime)
                        if let caption = post.post.caption, !caption.isEmpty {
                            Text(caption)
                                .dsTextStyle(TextRole.listSubtitle)
                                .lineLimit(2)
                        }
                    }
                    .foregroundStyle(Tokens.Colors.globalTextPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Tokens.Sizes.groupsScreenSizeCardGap)
                }
                .overlay(alignment: .bottomLeading) {
                    HStack {
                        AvatarView(path: author?.avatarPath, diameter: Tokens.Sizes.globalAvatarHeader)
                        if let name = author?.firstName {
                            Text(name)
                                .dsTextStyle(GroupScreenStyle.cardName)
                                .foregroundStyle(Tokens.Colors.globalTextPrimary)
                                .lineLimit(1)
                        }
                    }
                    .padding(Tokens.Sizes.groupsScreenSizeCardGap)
                }
                .clipShape(RoundedRectangle(cornerRadius: Tokens.Radii.groupsScreenRadiusCard))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(Copy.groupsScreenPhotoAccessibilityLabel(firstName: author?.firstName ?? "", time: time)))
        .accessibilityValue(Text(post.post.caption ?? ""))
        .accessibilityAddTraits(.isImage)
        .overlay(alignment: .bottomTrailing) {
            moreMenu
                .padding(Tokens.Sizes.groupsScreenSizeCardGap - (Tokens.Sizes.globalMinTouchTargetIos - Tokens.Sizes.globalAvatarHeader) / 2)
        }
        .accessibilityIdentifier("groups.screen.card")
    }

    /// Native menu (`safety.block.layout.menu`): others' photos "Report…" / "Block {first_name}"; own photos "Open".
    private var moreMenu: some View {
        Menu {
            if isOwn {
                Button(Copy.groupsScreenPhotoMenuOpen, action: onOpen)
            } else {
                Button(Copy.groupsScreenPhotoMenuReport, systemImage: Tokens.Icons.globalReport, role: .destructive, action: onReport)
                Button(Copy.groupsScreenPhotoMenuBlock(firstName: author?.firstName ?? ""), role: .destructive, action: onBlock)
            }
        } label: {
            Image(systemName: Tokens.Icons.globalMore)
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
                .frame(width: Tokens.Sizes.globalAvatarHeader, height: Tokens.Sizes.globalAvatarHeader)
                .background(Tokens.Colors.globalControlRaised, in: Circle())
                .frame(width: Tokens.Sizes.globalMinTouchTargetIos, height: Tokens.Sizes.globalMinTouchTargetIos)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(Text(Copy.groupsScreenPhotoMoreAccessibilityLabel))
    }
}

/// "{first_name} joined" system pill between cards (BI): capsule in `color.global.control`, avatar
/// `size.global.avatarSmall` leading, text role `listSubtitle` in `color.global.textPrimary`. Sizes were not measured:
/// the capsule hugs the avatar and keeps its rounded end's radius after the text.
struct JoinedPill: View {
    let member: MemberProfile

    var body: some View {
        HStack {
            AvatarView(path: member.profile?.avatarPath, diameter: Tokens.Sizes.globalAvatarSmall)
            Text(Copy.groupsScreenMemberJoined(firstName: member.profile?.firstName ?? ""))
                .dsTextStyle(TextRole.listSubtitle)
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
        }
        .padding(.trailing, Tokens.Sizes.globalAvatarSmall / 2)
        .background(Tokens.Colors.globalControl, in: Capsule())
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}
