// Surfaces: walls.mine, walls.member, walls.browse — reference app: Yope. Specs: design/surfaces/walls.mine.md,
// walls.member.md, walls.browse.md. References: references/auto/yope/frames/b-presskit-profile.png (grid, primary),
// references/auto/yope/frames/b-yopeapp-7591560669967682847-t116.00-me-and-friends.png (title, person row),
// …-t118.00-friends-wall.png (wall scrolled). Every wall is the profile "pics" grid (S-11); the free-form canvas is
// BLOCKED (`walls.mine.layout.freeformWall`).
import AppData
import AppModels
import DesignSystem
import SwiftUI

// MARK: - Shared grid

/// The wall grid (`walls.mine` Structure 2): `walls.mine.count.gridColumns` columns, insets
/// `walls.mine.dimension.gridInset`, gaps `walls.mine.dimension.gridGap`, tiles `walls.mine.aspectRatio.gridTile`
/// with `walls.mine.radius.gridTile`, newest first; more pages load at the end.
struct WallGrid: View {
    let model: WallModel
    let openPhoto: (PhotoViewerContext) -> Void

    @State private var width: CGFloat = 0
    @Environment(\.displayScale) private var displayScale

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: Tokens.Sizes.wallsMineDimensionGridGap), count: Int(Tokens.Counts.wallsMineCountGridColumns))
    }

    private var maxPixel: Int? {
        guard width > 0 else { return nil }
        let tile = SocialGrid.tileWidth(container: width, columns: Tokens.Counts.wallsMineCountGridColumns, inset: Tokens.Sizes.wallsMineDimensionGridInset, gap: Tokens.Sizes.wallsMineDimensionGridGap)
        return SocialGrid.maxPixel(width: tile, aspectRatio: Tokens.AspectRatios.wallsMineAspectRatioGridTile, scale: displayScale)
    }

    var body: some View {
        let tiles = model.tiles
        VStack(spacing: Tokens.Sizes.wallsMineDimensionGridGap) {
            LazyVGrid(columns: columns, spacing: Tokens.Sizes.wallsMineDimensionGridGap) {
                ForEach(tiles) { tile in
                    tileView(tile)
                        .onAppear {
                            // Load the next page a row before the end.
                            if tiles.suffix(Int(Tokens.Counts.wallsMineCountGridColumns) * 2).contains(where: { $0.id == tile.id }) {
                                Task { await model.loadMore() }
                            }
                        }
                }
            }
            if model.isLoadingMore { ProgressView() }
        }
        .padding(.horizontal, Tokens.Sizes.wallsMineDimensionGridInset)
        .socialReadsWidth($width)
    }

    @ViewBuilder
    private func tileView(_ tile: WallModel.Tile) -> some View {
        switch tile {
        case let .post(post):
            Button {
                openPhoto(PhotoViewerContext(postIDs: model.photoPostIDs, start: post.id))
            } label: {
                PhotoGridTile(path: post.media?.gridPath, aspectRatio: Tokens.AspectRatios.wallsMineAspectRatioGridTile, cornerRadius: Tokens.Radii.wallsMineRadiusGridTile, maxPixel: maxPixel)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(label(for: post)))
        case let .collage(collage):
            Button {
                if let invitationID = collage.invitationID {
                    SocialNav.push(.capture(.collage(groupID: collage.groupID.rawValue, invitationID: invitationID.rawValue)))
                }
            } label: {
                PhotoGridTile(path: collage.imagePath, aspectRatio: Tokens.AspectRatios.wallsMineAspectRatioGridTile, cornerRadius: Tokens.Radii.wallsMineRadiusGridTile, maxPixel: maxPixel)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(Copy.wallsBrowseA11yCollage(date: SocialFormat.spokenDate(collage.createdAt))))
        }
    }

    private func label(for post: PostWithMedia) -> String {
        let date = SocialFormat.spokenDate(post.post.createdAt)
        if model.owner == .me { return Copy.photoViewerA11yPhotoMine(date: date) }
        return Copy.photoViewerA11yPhoto(name: model.profile?.socialFirstName ?? "", date: date)
    }
}

/// The wall's states under its header (loading indicator, empty, error, offline) or the grid.
struct WallContent: View {
    let model: WallModel
    let openPhoto: (PhotoViewerContext) -> Void

    var body: some View {
        switch model.phase {
        case .loading:
            if model.showsLoading { ProgressView().frame(maxWidth: .infinity) }
        case .ready:
            WallGrid(model: model, openPhoto: openPhoto)
        case .empty:
            if model.owner == .me {
                EmptyStateView(
                    title: Copy.wallsMineEmptyTitle,
                    detail: Copy.wallsMineEmptyDetail,
                    action: .init(Copy.wallsMineEmptyAction, icon: Tokens.Icons.globalCamera) { SocialNav.openCamera(groupID: nil) }
                )
            } else {
                let name = model.profile?.socialFirstName ?? ""
                EmptyStateView(title: Copy.wallsMemberEmptyTitle(name: name), detail: Copy.wallsMemberEmptyDetail(name: name))
            }
        case .failed:
            EmptyStateView(
                title: Copy.wallsMineErrorTitle,
                detail: Copy.chatThreadErrorDetail,
                action: .init(Copy.chatThreadErrorRetry) { Task { await model.retry() } }
            )
        case .offline:
            EmptyStateView(title: Copy.chatThreadOfflineTitle, detail: Copy.chatThreadOfflineDetail)
        }
    }
}

/// Title at `walls.browse.dimension.titleBaseline` below the top safe-area inset (text role `sheetTitle`), header
/// circles vertically centred on it at `size.global.headerInset`; the content starts `walls.mine.dimension.titleToGrid`
/// below the baseline.
struct WallHeader<Leading: View, Trailing: View>: View {
    let title: String
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        ZStack(alignment: .top) {
            Color.clear.frame(height: Tokens.Sizes.wallsBrowseDimensionTitleBaseline + Tokens.Sizes.wallsMineDimensionTitleToGrid)
            HStack {
                leading()
                Spacer(minLength: 0)
                trailing()
            }
            .padding(.horizontal, Tokens.Sizes.globalHeaderInset)
            .overlay {
                Text(title)
                    .dsTextStyle(TextRole.sheetTitle)
                    .foregroundStyle(Tokens.Colors.globalTextPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.horizontal, Tokens.Sizes.globalHeaderInset + Tokens.Sizes.globalHeaderButton + Tokens.Sizes.globalHeaderGap)
                    .accessibilityAddTraits(.isHeader)
            }
            .alignmentGuide(.top) { $0[VerticalAlignment.center] - titleCentre }
        }
    }

    /// The title's vertical centre: its baseline minus half its cap height.
    private var titleCentre: CGFloat {
        Tokens.Sizes.wallsBrowseDimensionTitleBaseline - SocialMetrics.capHeight(TextRole.sheetTitle) / 2
    }
}

// MARK: - walls.mine

/// "my wall": settings circle top-right, title, my wall items; the tab bar floats over the bottom.
struct WallMineScreen: View {
    @State private var model: WallModel
    @State private var viewer: PhotoViewerContext?

    init(model: WallModel? = nil) {
        _model = State(initialValue: model ?? WallModel(owner: .me, data: SocialServices.shared.data))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                WallHeader(title: Copy.wallsMineTitle) {
                    EmptyView()
                } trailing: {
                    HeaderCircleButton(icon: Tokens.Icons.globalSettings, accessibilityLabel: Copy.wallsMineA11ySettings, fill: .onDeep) {
                        SocialNav.push(.account(.settings))
                    }
                }
                WallContent(model: model) { viewer = $0 }
            }
            .padding(.bottom, Tokens.Sizes.globalTabBarHeight)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Tokens.Colors.globalBackgroundDeep.ignoresSafeArea())
        .socialHidesNavigationBar()
        .task {
            if model.phase == .loading { await model.load() }
            await model.run()
        }
        .fullScreenCover(item: $viewer) { context in
            PhotoViewerView(context: context, presentation: .cover { target in SocialPendingCamera.target = target })
        }
        .socialOpensPendingCamera(after: viewer)
        .accessibilityIdentifier("walls.mine") // provenance-ok: accessibility identifier for UI tests
    }
}

// MARK: - walls.member

/// A member's wall: back circle, their display name, the photos they posted in groups you share.
struct WallMemberScreen: View {
    let userID: String
    @State private var model: WallModel
    @State private var viewer: PhotoViewerContext?
    @Environment(\.dismiss) private var dismiss

    init(userID: String, model: WallModel? = nil) {
        self.userID = userID
        _model = State(initialValue: model ?? WallModel(owner: .member(UserID(userID)), data: SocialServices.shared.data))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                WallHeader(title: model.displayName ?? "") {
                    HeaderCircleButton(icon: Tokens.Icons.globalBack, accessibilityLabel: Copy.chatThreadA11yBack, fill: .onDeep) { dismiss() }
                } trailing: {
                    EmptyView()
                }
                .accessibilityLabel(Text(Copy.wallsMemberA11yWall(name: model.displayName ?? "")))
                WallContent(model: model) { viewer = $0 }
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Tokens.Colors.globalBackgroundDeep.ignoresSafeArea())
        .socialHidesNavigationBar()
        .task {
            if model.phase == .loading { await model.load() }
            await model.run()
        }
        .fullScreenCover(item: $viewer) { context in
            PhotoViewerView(context: context, presentation: .cover { target in SocialPendingCamera.target = target })
        }
        .socialOpensPendingCamera(after: viewer)
        .accessibilityIdentifier("walls.member") // provenance-ok: accessibility identifier for UI tests
    }
}

// MARK: - walls.browse

/// "me & friends": title, the row of person circles (me first), the selected person's wall; everything scrolls.
struct WallsBrowseScreen: View {
    let groupID: String?
    @State private var model: WallsBrowseModel
    @State private var viewer: PhotoViewerContext?

    init(groupID: String?, model: WallsBrowseModel? = nil) {
        self.groupID = groupID
        _model = State(initialValue: model ?? WallsBrowseModel(data: SocialServices.shared.data, groupID: groupID.map { GroupID($0) }))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    Color.clear.frame(height: Tokens.Sizes.wallsBrowseDimensionWallTop)
                    Text(Copy.wallsBrowseTitle)
                        .dsTextStyle(TextRole.sheetTitle)
                        .foregroundStyle(Tokens.Colors.globalTextPrimary)
                        .accessibilityAddTraits(.isHeader)
                        .alignmentGuide(.top) { $0[.firstTextBaseline] - Tokens.Sizes.wallsBrowseDimensionTitleBaseline }
                    if model.phase == .ready {
                        personRow
                            .padding(.top, Tokens.Sizes.wallsBrowseDimensionRowCenter - Tokens.Sizes.wallsBrowseDimensionAvatar / 2)
                    }
                }
                content
            }
            .padding(.bottom, Tokens.Sizes.globalTabBarHeight)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Tokens.Colors.globalBackgroundDeep.ignoresSafeArea())
        .socialHidesNavigationBar()
        .socialFeedback(model.signals.feedback)
        .task {
            if model.phase == .loading { await model.load() }
            await model.selectedWall?.run()
        }
        .fullScreenCover(item: $viewer) { context in
            PhotoViewerView(context: context, presentation: .cover { target in SocialPendingCamera.target = target })
        }
        .socialOpensPendingCamera(after: viewer)
        .accessibilityIdentifier("walls.browse") // provenance-ok: accessibility identifier for UI tests
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .loading:
            ProgressView().frame(maxWidth: .infinity)
        case .failed:
            EmptyStateView(
                title: Copy.wallsMineErrorTitle,
                detail: Copy.chatThreadErrorDetail,
                action: .init(Copy.chatThreadErrorRetry) { Task { await model.retry() } }
            )
        case .offline:
            EmptyStateView(title: Copy.chatThreadOfflineTitle, detail: Copy.chatThreadOfflineDetail)
        case .empty, .ready:
            if model.hasNobodyElse {
                EmptyStateView(
                    title: Copy.wallsBrowseEmptyTitle,
                    detail: Copy.wallsBrowseEmptyDetail,
                    action: .init(Copy.wallsBrowseEmptyAction) { SocialNav.present(.account(.groupCreate)) }
                )
            } else if let wall = model.selectedWall {
                WallContent(model: wall) { viewer = $0 }
                    .id(model.selectedID)
            }
        }
    }

    /// Circles `walls.browse.dimension.avatar` at pitch `.avatarPitch`, the first `.rowInset` from the edge; first
    /// names (text role `caption`) with their baseline `.labelBaselineGap` below the circle, one line no wider than
    /// the pitch. The selected person's marking is BLOCKED (`walls.browse.layout.selection`): VoiceOver only.
    private var personRow: some View {
        let pitch = Tokens.Sizes.wallsBrowseDimensionAvatarPitch
        let avatar = Tokens.Sizes.wallsBrowseDimensionAvatar
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(model.people) { person in
                    Button {
                        Task { await model.select(person.id) }
                    } label: {
                        ZStack(alignment: .top) {
                            SocialAvatar(path: person.profile?.avatarPath, diameter: avatar)
                            Text(person.isMe ? Copy.wallsBrowseMe : (person.profile?.socialFirstName ?? ""))
                                .dsTextStyle(TextRole.caption)
                                .foregroundStyle(Tokens.Colors.globalTextPrimary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .frame(maxWidth: pitch)
                                .alignmentGuide(.top) { $0[.firstTextBaseline] - avatar - Tokens.Sizes.wallsBrowseDimensionLabelBaselineGap }
                        }
                        .frame(width: pitch)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(person.isMe ? Copy.wallsMineTitle : Copy.wallsMemberA11yWall(name: person.profile?.socialFirstName ?? "")))
                    .accessibilityAddTraits(person.id == model.selectedID ? .isSelected : [])
                }
            }
            .padding(.leading, Tokens.Sizes.wallsBrowseDimensionRowInset - (pitch - avatar) / 2)
        }
    }
}

// MARK: - Reply camera after a covered viewer closes

/// The camera for a photo reply opens once the covering viewer has gone (two full-screen covers cannot overlap).
@MainActor
enum SocialPendingCamera {
    static var target: PhotoReplyHandoff.Target?
}

extension View {
    /// Opens the reply camera when `viewer` (the presented context) closes with a pending reply target.
    func socialOpensPendingCamera(after viewer: PhotoViewerContext?) -> some View {
        onChange(of: viewer == nil) { _, closed in
            guard closed, let target = SocialPendingCamera.target else { return }
            SocialPendingCamera.target = nil
            SocialNav.router.presentCameraReplying(toPost: target.postID, groupID: target.groupID)
        }
    }
}
