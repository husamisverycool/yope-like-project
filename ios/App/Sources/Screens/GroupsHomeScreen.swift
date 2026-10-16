// Surface: groups.list — the group list (home). Visual reference: Retro Albums list
// (references/auto/retro/store/editorial/retro-appstore-story-1854931006-week3-albums.png, ED-W3;
// references/auto/retro/press/tc-2024-04-journals-1.webp phone 2, TC-J1), "Ideas to Get Started"
// (references/auto/retro/press/jeddacp-2024-05-home-profile-journals.png phone 3, JED) and Retro's tab bar
// (references/auto/retro/lazyweb/retro-lazyweb-20251020-week43-dark.png, H43; …-20260528-week22-dark-a.png, H22).
// Components C-01, C-15, C-23, C-11, C-06, C-04, C-27, C-28 (design/surfaces/groups.list.md; MERGE RA-7, RA-8).
import AppData
import AppModels
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

    /// groups.list States "loading": three placeholder rows.
    private static let loadingRows = 3 // provenance-ok: row count named by the spec's loading state

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ScreenHeader(title: Copy.groupsListTitle, actions: [
                        HeaderAction(icon: Tokens.Icons.globalNewAlbum, accessibilityLabel: Copy.groupsListHeaderAddAccessibilityLabel) {
                            dependencies.router.modal = .account(.groupCreate)
                        },
                    ])
                    content(width: proxy.size.width, height: proxy.size.height)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .refreshable { await model.refresh() }
        }
        .background(Tokens.Colors.globalBackground.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            AppTabBar(selected: .groups) { tab in
                ShellNavigation.select(tab, router: dependencies.router, shell: dependencies.shell)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            // The camera is one tap away (tab bar, the rows' "+"): start its session ahead (capture pass).
            dependencies.shell.prewarm()
            await model.load()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await model.refresh() } }
        }
        .onChange(of: dependencies.network.isOffline) { wasOffline, isOffline in
            if wasOffline, !isOffline { Task { await model.refresh() } }
        }
        .accessibilityIdentifier("groups.list")
    }

    @ViewBuilder
    private func content(width: CGFloat, height: CGFloat) -> some View {
        switch model.phase {
        case .loading:
            // C-28: three C-15 rows whose thumbnails are placeholders (Retro's placeholder-tile loading form).
            ThumbnailRowList {
                ForEach(0..<Self.loadingRows, id: \.self) { _ in
                    GroupRowPlaceholder()
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(Copy.globalA11yLoading))
        case .empty:
            VStack(alignment: .leading, spacing: 0) {
                EmptyStateView(
                    icon: Tokens.Icons.globalAlbums,
                    title: Copy.groupsListEmptyTitle,
                    detail: Copy.groupsListEmptyDetail,
                    action: EmptyStateView.Action(Copy.groupsListEmptyButton, icon: Tokens.Icons.globalAdd) {
                        dependencies.router.modal = .account(.groupCreate)
                    }
                )
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("groups.list.empty.create")
                ideas
                    .padding(.top, Tokens.Sizes.globalSectionGap)
            }
        case .error:
            // Retro's list error: one tappable line under the header (tap = retry).
            Button {
                Task { await model.retry() }
            } label: {
                Text(Copy.groupsListErrorTitle)
                    .dsTextStyle(TextRole.body)
                    .foregroundStyle(Tokens.Colors.globalTextSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: Tokens.Sizes.globalMinTouchTargetIos)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
            .accessibilityIdentifier("groups.list.error")
        case .offline:
            EmptyStateView(title: Copy.groupsListOfflineTitle, detail: Copy.groupsListOfflineDetail)
                .frame(maxWidth: .infinity)
        case .loaded:
            VStack(alignment: .leading, spacing: 0) {
                ThumbnailRowList {
                    ForEach(model.rows) { row in
                        groupRow(row, width: width)
                    }
                }
                .dsAnimation(ComponentMotion.crossfade, value: model.rows.map(\.id))
                ideas
                    .padding(.top, Tokens.Sizes.globalSectionGap)
            }
            .padding(.bottom, Tokens.Sizes.globalSectionGap)
        }
    }

    // MARK: Rows

    private func groupRow(_ row: GroupRow, width: CGFloat) -> some View {
        let subtitle = GroupRowText.subtitle(for: row)
        return ThumbnailRow(
            title: row.group.name,
            subtitle: subtitle.text,
            subtitleEmphasis: subtitle.emphasis,
            thumbnail: row.group.coverPath.map { PhotoSource.storage($0) },
            avatars: GroupRowText.avatars(for: row, rowWidth: width),
            accessibilityLabel: Copy.groupsListRowAccessibilityLabel(groupName: row.group.name, subtitle: subtitle.text),
            addAccessibilityLabel: Copy.groupsListRowCameraAccessibilityLabel(groupName: row.group.name),
            onAdd: { dependencies.router.modal = .camera(groupID: row.id.rawValue, invitationID: nil) },
            action: { dependencies.router.path.append(.group(id: row.id.rawValue)) }
        )
        .lineLimit(1)
        .accessibilityIdentifier("groups.list.row")
        .dsTransition(.opacity)
    }

    // MARK: Ideas to Get Started

    /// The section header (text role `sectionLabel`) and one template row per group kind in `group_kind` order.
    private var ideas: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(Copy.groupsListIdeasTitle)
                .dsTextRole(TextRole.sectionLabel)
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
            ThumbnailRowList {
                ForEach(GroupKindCopy.kinds, id: \.self) { kind in
                    GroupTemplateRow(kind: kind) {
                        dependencies.router.modal = .account(.groupCreateKind(kind))
                    }
                }
            }
            .padding(.top, Tokens.Sizes.globalSectionHeaderToContent)
        }
    }
}

/// The subtitle and avatar stack of a group row.
enum GroupRowText {
    /// The subtitle and its actor (drawn in the `listTitle` weight): the newest post by someone else
    /// (`groups.list.row.sentPic`, the sender), your newest post (`groups.list.row.newPic`, "you"), else who created the
    /// group (`groups.list.row.createdByYou` / `.createdBy`) or `groups.list.row.noPics` when the creator is unknown. The
    /// "you" strings put the actor first (copy pattern), so their first word is the actor.
    static func subtitle(for row: GroupRow) -> (text: String, emphasis: String?) {
        if row.newest != nil {
            if !row.isOwnPost, let name = row.senderFirstName {
                return (Copy.groupsListRowSentPic(firstName: name), name)
            }
            if row.isOwnPost {
                return firstWordEmphasised(Copy.groupsListRowNewPic)
            }
        }
        if row.isCreatedByMe {
            return firstWordEmphasised(Copy.groupsListRowCreatedByYou)
        }
        if let creator = row.creatorFirstName {
            return (Copy.groupsListRowCreatedBy(firstName: creator), creator)
        }
        return (Copy.groupsListRowNoPics, nil)
    }

    private static func firstWordEmphasised(_ text: String) -> (text: String, emphasis: String?) {
        (text, text.split(separator: " ").first.map(String.init))
    }

    /// The members' avatars in joining order, as many as fit the row's text column (screen − margins − thumbnail − gap −
    /// the "+" circle); never a count.
    static func avatars(for row: GroupRow, rowWidth: CGFloat) -> [PhotoSource?] {
        let column = rowWidth - 2 * Tokens.Sizes.globalScreenMargin - Tokens.Sizes.globalRowThumbWidth
            - Tokens.Sizes.globalRowThumbGap - Tokens.Sizes.globalCircleButton
        let fitting = AvatarStackLayout.fittingCount(
            width: column, diameter: Tokens.Sizes.globalAvatarSmall, overlap: Tokens.Sizes.globalAvatarStackOverlap
        )
        return row.members.prefix(fitting).map { member in member.profile?.avatarPath.map { PhotoSource.storage($0) } }
    }
}

/// A loading row (C-28): the C-15 thumbnail as a `color.global.control` placeholder, no text.
struct GroupRowPlaceholder: View {
    var body: some View {
        HStack(spacing: 0) {
            Tokens.Colors.globalControl
                .frame(width: Tokens.Sizes.globalRowThumbWidth, height: Tokens.Sizes.globalRowThumbHeight)
                .clipShape(DSShape.rounded(Tokens.Radii.globalThumbnail))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
    }
}

/// A template row of "Ideas to Get Started" (JED; C-15 geometry): the kind's cover photo
/// (`groups.list.layout.templateCovers`, owner decision 9: people-free sample photos bundled in the asset catalog;
/// aspect-fill, `radius.global.thumbnail`), the kind's title (text role `listTitle`) and description (text role
/// `listSubtitle`, `color.global.textSecondary`, ≤ 2 lines) `size.global.rowThumbGap` after it, and the fill capsule
/// C-06 "Create" at the right margin. The row and the capsule both open groups.create at its name step with the
/// kind chosen. Accessibility: the row is one button (title + description); the capsule a separate one.
struct GroupTemplateRow: View {
    let kind: GroupKind
    let action: () -> Void

    var body: some View {
        HStack(spacing: Tokens.Sizes.globalRowThumbGap) {
            Button(action: action) {
                HStack(spacing: Tokens.Sizes.globalRowThumbGap) {
                    Image(GroupKindCopy.coverAsset(kind))
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: Tokens.Sizes.globalRowThumbWidth, height: Tokens.Sizes.globalRowThumbHeight)
                        .background(Tokens.Colors.globalControl)
                        .clipShape(DSShape.rounded(Tokens.Radii.globalThumbnail))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading) {
                        Text(GroupKindCopy.title(kind))
                            .dsTextStyle(TextRole.listTitle)
                            .foregroundStyle(Tokens.Colors.globalTextPrimary)
                        Text(GroupKindCopy.detail(kind))
                            .dsTextStyle(TextRole.listSubtitle)
                            .foregroundStyle(Tokens.Colors.globalTextSecondary)
                            .lineLimit(2)
                    }
                    .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            CapsuleButton(Copy.groupsCreateTypeCreate, style: .fill, action: action)
                .fixedSize()
                .accessibilityIdentifier("groups.template.create")
        }
        .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
        .accessibilityIdentifier("groups.template." + kind.rawValue)
    }
}
