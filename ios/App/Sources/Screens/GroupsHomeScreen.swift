// Surface: groups.list — group list / home; switch between groups. Reference app: Yope home list
// (design/surfaces/groups.list.md). Reference images:
// references/auto/yope/frames/a-savannahclooney-7683341732695592206-t6.73-home-list.png (H1),
// a-virgi-7686278541255642390-t40.23-home-list-es.png (H2), a-itsmthuyope-7644974799302823175-t44.23-home-list-new-group-icon.png (H3),
// a-chuongxetank-7694968408424582452-t7.73-posted-toast-contacts-card.png (H4), references/auto/yope/store/yope-store-02.png (TB),
// references/auto/yope/web/a-bi-2025-onboarding-composite.jpg (BI).
import AppData
import DesignSystem
import SwiftUI

/// Home: root of the main navigation stack.
struct GroupsHomeScreen: View {
    @Environment(AccountDependencies.self) private var dependencies

    var body: some View {
        GroupsListView(model: GroupsListModel(data: dependencies.data))
    }
}

struct GroupsListView: View {
    @State private var model: GroupsListModel
    @Environment(AccountDependencies.self) private var dependencies
    @Environment(\.scenePhase) private var scenePhase

    init(model: GroupsListModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Tokens.Colors.globalBackgroundDeep.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                FloatingTabBar(selected: .groups, avatarPath: model.avatarPath) { tab in
                    select(tab)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .task { await model.load() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await model.refresh() } }
            }
            .onChange(of: dependencies.network.isOffline) { wasOffline, isOffline in
                if wasOffline, !isOffline { Task { await model.refresh() } }
            }
            .accessibilityIdentifier("groups.list")
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .loading:
            LoadingHUD()
        case .empty:
            emptyState
        case .error:
            EmptyStateView(
                title: Copy.groupsListErrorTitle,
                detail: Copy.groupsListErrorDetail,
                action: EmptyStateView.Action(Copy.groupsListErrorRetry) { Task { await model.retry() } }
            )
        case .offline:
            EmptyStateView(title: Copy.groupsListOfflineTitle, detail: Copy.groupsListOfflineDetail)
        case .loaded:
            list
        }
    }

    // MARK: Loaded

    private var list: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(spacing: 0) {
                    if let cover = model.coverRow {
                        coverHeader(cover)
                    }
                    LazyVStack(spacing: Tokens.Sizes.globalListGap) {
                        ForEach(model.rows) { row in
                            GroupCard(row: row) {
                                dependencies.router.path.append(.group(id: row.id.rawValue))
                            } onCamera: {
                                dependencies.router.modal = .camera(groupID: row.id.rawValue, invitationID: nil)
                            }
                        }
                    }
                    .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
                    .padding(.top, Tokens.Sizes.globalListGap)
                }
            }
            .ignoresSafeArea(edges: model.coverRow == nil ? [] : .top)
            .refreshable { await model.refresh() }
            addCircle
                .padding(.trailing, Tokens.Sizes.globalHeaderInset)
        }
    }

    /// Newest photo across the groups, full-bleed from the top edge, `groups.list.size.coverHeight`; ⌄ under it.
    /// Bottom-corner radius: not measured (square, Gaps).
    private func coverHeader(_ row: GroupRow) -> some View {
        VStack(spacing: Tokens.Sizes.globalListGap) {
            Button {
                if let post = row.newest {
                    dependencies.router.path.append(.post(groupID: row.id.rawValue, postID: post.post.id.rawValue))
                }
            } label: {
                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(height: Tokens.Sizes.groupsListSizeCoverHeight)
                    .overlay {
                        StorageImage(path: row.newest?.media?.imagePath(for: .display)) {
                            Tokens.Colors.globalControlRaised
                        }
                    }
                    .clipped()
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(Copy.groupsListCoverAccessibilityLabel(
                firstName: (row.isOwnPost ? model.myFirstName : row.senderFirstName) ?? "",
                groupName: row.group.name
            )))
            .accessibilityIdentifier("groups.list.cover")
            Image(systemName: Tokens.Icons.globalChevronDown)
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
                .accessibilityHidden(true)
        }
    }

    /// "+" over the cover → groups.create. Its fill (`groups.list.color.headerCircleOverPhoto`) is BLOCKED: glyph only.
    private var addCircle: some View {
        HeaderCircleButton(icon: Tokens.Icons.globalAdd, accessibilityLabel: Copy.groupsListHeaderAddAccessibilityLabel, fill: .none) {
            dependencies.router.modal = .account(.groupCreate)
        }
        .accessibilityIdentifier("groups.list.add")
    }

    // MARK: Empty

    /// Yope's 2025 "create your first group" (BI): two-tone title, italic detail, lime button.
    private var emptyState: some View {
        VStack(spacing: 0) {
            TwoToneTitle(text: Copy.groupsListEmptyTitle)
                .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
            Text(Copy.groupsListEmptyDetail)
                .italic()
                .dsTextStyle(TextRole.signUpSubtitle)
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
            PrimaryButton(Copy.groupsListEmptyButton) {
                dependencies.router.modal = .account(.groupCreate)
            }
            .accessibilityIdentifier("groups.list.empty.create")
            .padding(.horizontal, Tokens.Sizes.globalButtonMarginH)
            .padding(.top, Tokens.Sizes.groupsCreateSizeTitleToContent)
        }
    }

    // MARK: Tab bar

    private func select(_ tab: AppTab) {
        let router = dependencies.router
        switch tab {
        case .camera:
            router.modal = .camera(groupID: nil, invitationID: nil)
        case .groups:
            router.path = []
        case .walls:
            if let route = CrossGroupRoutes.wallsBrowse(groupID: nil) { router.path.append(route) }
        case .me:
            if let route = CrossGroupRoutes.wallsMine { router.path.append(route) }
        }
    }
}

/// One group card: avatar (group cover in a circle) · name + subtitle · camera glyph.
///
/// Tokens: fill `groups.list.color.card`, height `groups.list.size.cardHeight` (minimum; grows with Dynamic Type),
/// corners `radius.global.card`; avatar `size.global.avatarList` at `groups.list.size.avatarInset` (empty cover:
/// `color.global.controlRaised` + `icon.global.group`); name text role `listTitle` (one line, tail truncation);
/// subtitle text role `listSubtitle` in `color.global.textSecondary` with the sender's first name in
/// `color.global.accent`; camera `icon.global.camera` at `groups.list.size.cameraGlyph`, trailing inset
/// `groups.list.size.avatarInset`, hit area `size.global.minTouchTarget.ios`.
struct GroupCard: View {
    let row: GroupRow
    let onOpen: () -> Void
    let onCamera: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onOpen) {
                HStack {
                    AvatarView(path: row.group.coverPath, diameter: Tokens.Sizes.globalAvatarList, placeholderIcon: Tokens.Icons.globalGroup)
                    VStack(alignment: .leading) {
                        Text(row.group.name)
                            .dsTextStyle(TextRole.listTitle)
                            .foregroundStyle(Tokens.Colors.globalTextPrimary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Text(Self.subtitle(for: row))
                            .dsTextStyle(TextRole.listSubtitle)
                            .foregroundStyle(Tokens.Colors.globalTextSecondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.leading, Tokens.Sizes.groupsListSizeAvatarInset)
                .frame(minHeight: Tokens.Sizes.groupsListSizeCardHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(Copy.groupsListRowAccessibilityLabel(groupName: row.group.name, subtitle: Self.plainSubtitle(for: row))))
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("groups.list.row")
            Button(action: onCamera) {
                Image(systemName: Tokens.Icons.globalCamera)
                    .resizable()
                    .scaledToFit()
                    .frame(width: Tokens.Sizes.groupsListSizeCameraGlyph, height: Tokens.Sizes.groupsListSizeCameraGlyph)
                    .foregroundStyle(Tokens.Colors.globalTextPrimary)
                    .frame(width: Tokens.Sizes.globalMinTouchTargetIos, height: Tokens.Sizes.globalMinTouchTargetIos)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(Copy.groupsListRowCameraAccessibilityLabel(groupName: row.group.name)))
            // The 44-pt hit area is centred on the glyph, which sits `avatarInset` from the trailing edge.
            .padding(.trailing, Tokens.Sizes.groupsListSizeAvatarInset - (Tokens.Sizes.globalMinTouchTargetIos - Tokens.Sizes.groupsListSizeCameraGlyph) / 2)
        }
        .background(Tokens.Colors.groupsListColorCard, in: RoundedRectangle(cornerRadius: Tokens.Radii.globalCard))
    }

    /// `groups.list.row.sentPic` (sender in lime) / `.newPic` (own post) / `.noPics`.
    static func subtitle(for row: GroupRow) -> AttributedString {
        let plain = plainSubtitle(for: row)
        var text = AttributedString(plain)
        if !row.isOwnPost, let name = row.senderFirstName, row.newest != nil, let range = text.range(of: name) {
            text[range].swiftUI.foregroundColor = Tokens.Colors.globalAccent
        }
        return text
    }

    static func plainSubtitle(for row: GroupRow) -> String {
        guard let post = row.newest else { return Copy.groupsListRowNoPics }
        let time = AccountFormats.time(post.post.createdAt)
        if !row.isOwnPost, let name = row.senderFirstName {
            return Copy.groupsListRowSentPic(firstName: name, time: time)
        }
        return Copy.groupsListRowNewPic(time: time)
    }
}
