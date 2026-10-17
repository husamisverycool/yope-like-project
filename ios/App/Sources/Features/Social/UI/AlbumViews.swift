// Surfaces: albums.list, albums.view — Retro's Albums list (pushed serif header, search field, rows with a 3:4 cover)
// and album detail (book-like cover, serif name, meta, capsule row, a 3-column grid with rounded outer corners).
// Specs: design/surfaces/albums.list.md, albums.view.md (RS-21).
// References: references/auto/retro/store/editorial/retro-appstore-story-1854931006-week3-albums.png (list, primary),
// references/auto/retro/press/tc-2024-04-journals-1.webp phones 2–3 (rows, album detail), references/auto/retro/web/
// retro.app-42b38811bebcd07d.css (grid corners), references/auto/retro/press/tc-2024-04-retro-journals-5.png (menu).
import AppData
import AppModels
import DesignSystem
import SwiftUI

// MARK: - albums.list

/// C-02 header "Albums"; the C-12 search field `size.global.titleToContent` below the title baseline (when the group
/// has albums); C-15 rows newest first, the first `size.global.titleToContent` below the field, `size.global.listGap`
/// apart: the album's first item as a 3:4 cover, the name (`listTitle`, up to two lines) over "{name} created the album"
/// (the name in the `listTitle` weight; yours: "you created the album"). No stack, no "+". A row opens the album sheet.
struct AlbumsListScreen: View {
    @State private var model: AlbumsListModel
    @State private var open: AlbumSheetTarget?
    @State private var recapsOpen = false
    @Environment(\.dismiss) private var dismiss

    init(groupID: String) {
        self.init(model: AlbumsListModel(groupID: GroupID(groupID), data: SocialServices.shared.data))
    }

    init(model: AlbumsListModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        Group {
            if model.phase == .empty {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    Spacer(minLength: 0)
                    EmptyStateView(
                        icon: Tokens.Icons.globalAlbums,
                        title: Copy.albumsListEmptyTitle,
                        detail: Copy.albumsListEmptyDetail,
                        action: .init(Copy.albumsListEmptyAction) { recapsOpen = true }
                    )
                    .frame(maxWidth: .infinity)
                    Spacer(minLength: 0)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        header
                        content
                    }
                    .padding(.bottom, Tokens.Sizes.globalSectionGap)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Tokens.Colors.globalBackground.ignoresSafeArea())
        .socialHidesNavigationBar()
        .socialAnnouncesLoading(model.showsLoading)
        .task { await model.load() }
        .sheet(item: $open, onDismiss: { Task { await model.load() } }) { target in
            AlbumScreen(groupID: model.groupID.rawValue, albumID: target.albumID.rawValue, initialName: target.name)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .dsSheetBackground()
        }
        .sheet(isPresented: $recapsOpen) {
            WeekRecapListScreen(groupID: model.groupID.rawValue)
        }
        .accessibilityIdentifier("albums.list") // provenance-ok: accessibility identifier for UI tests
    }

    private var header: some View {
        PushedScreenHeader(title: Copy.albumsListTitle, backAccessibilityLabel: Copy.chatThreadA11yBack) { dismiss() }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .loading:
            if model.showsLoading {
                VStack(alignment: .leading, spacing: Tokens.Sizes.globalListGap) {
                    ForEach(0..<3, id: \.self) { _ in // provenance-ok: albums.list loading state "three rows"
                        Tokens.Colors.globalControl
                            .frame(width: Tokens.Sizes.globalRowThumbWidth, height: Tokens.Sizes.globalRowThumbHeight)
                            .clipShape(DSShape.rounded(Tokens.Radii.globalThumbnail))
                    }
                }
                .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
                .accessibilityLabel(Text(Copy.weekHistoryA11yLoading))
            }
        case .empty:
            EmptyView()
        case .failed, .offline:
            SocialErrorLine(text: Copy.albumsListErrorTitle) { Task { await model.retry() } }
        case .ready:
            SearchField(Copy.albumsListSearch, text: $model.search, accessibilityLabel: Copy.albumsListSearch)
                .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
            let albums = model.visibleAlbums
            if albums.isEmpty {
                EmptyStateView(title: Copy.albumsListSearchEmpty)
                    .frame(maxWidth: .infinity)
                    .padding(.top, Tokens.Sizes.globalTitleToContent)
            } else {
                ThumbnailRowList {
                    ForEach(albums) { album in
                        let name = model.savedByName(album) ?? ""
                        let subtitle = model.isMine(album) ? Copy.albumsListRowSubtitleMine : Copy.albumsListRowSubtitle(name: name)
                        ThumbnailRow(
                            title: album.album.name,
                            subtitle: subtitle,
                            subtitleEmphasis: model.isMine(album) ? nil : name,
                            thumbnail: SocialImages.source(model.cover(of: album)?.media?.gridPath),
                            accessibilityLabel: album.album.name + ", " + subtitle // provenance-ok: joins the album name and its copy line
                        ) {
                            open = AlbumSheetTarget(albumID: album.id, name: album.album.name)
                        }
                    }
                }
                .padding(.top, Tokens.Sizes.globalTitleToContent)
            }
        }
    }
}

struct AlbumSheetTarget: Identifiable, Hashable {
    let albumID: AlbumID
    let name: String
    var id: String { albumID.rawValue }
}

// MARK: - albums.view

/// Page sheet over albums.list: the cover centred `albums.view.dimension.coverTop` below the sheet top
/// (`.coverWidth` × `.coverHeight`, `radius.global.thumbnail`, the first item, Retro's book-cover drop shadow
/// `albums.view.shadow.cover`); the
/// name in the display serif (`displayMedium`, up to two lines) with its cap top `.coverToTitle` below the cover; the
/// meta line (`listSubtitle`, `color.global.textSecondary`) with its baseline `.titleToMeta` below the name's; the
/// capsule row `.metaToActions` below the meta baseline — "Rename" filling the row and, for the creator and group admins,
/// the "•••" icon capsule (→ "Delete Album", red); the grid `walls.mine.dimension.actionsToWeeks` below the capsules.
struct AlbumScreen: View {
    @State private var model: AlbumModel
    var initialName: String?
    @State private var viewer: PhotoViewerContext?
    @State private var confirmingDelete = false
    @State private var toasts = ToastCenter()
    @Environment(\.dismiss) private var dismiss

    init(groupID: String, albumID: String, initialName: String? = nil) {
        self.init(model: AlbumModel(groupID: GroupID(groupID), albumID: AlbumID(albumID), data: SocialServices.shared.data), initialName: initialName)
    }

    init(model: AlbumModel, initialName: String? = nil) {
        _model = State(initialValue: model)
        self.initialName = initialName
    }

    var body: some View {
        Group {
            if model.phase == .notFound {
                EmptyStateView(title: Copy.albumsViewNotFound)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    page
                        .padding(.bottom, Tokens.Sizes.globalSectionGap)
                }
            }
        }
        .background(Tokens.Colors.globalBackground.ignoresSafeArea())
        .socialHidesNavigationBar()
        .task {
            if model.phase == .loading { await model.load() }
            await model.run()
        }
        .onChange(of: model.isDeleted) { _, deleted in if deleted { dismiss() } }
        .socialFeedback(model.signals.feedback)
        .socialNotices(model.signals.notice, toasts: toasts)
        .toastHost(toasts)
        .socialPhotoViewer($viewer)
        .confirmationDialog(Copy.albumsViewDeleteTitle, isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button(Copy.albumsViewDeleteConfirm, role: .destructive) { Task { await model.delete() } }
            Button(Copy.photoViewerDeleteCancel, role: .cancel) {}
        } message: {
            Text(Copy.albumsViewDeleteMessage)
        }
        .sheet(isPresented: $model.isRenaming) {
            SocialNameSheet(
                title: Copy.albumsViewRenameTitle,
                placeholder: Copy.weekEditAlbumNamePlaceholder,
                buttonTitle: Copy.albumsViewRenameSave,
                name: $model.renameText,
                isEnabled: !model.renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !model.isWorking,
                isBusy: model.isWorking,
                showsMissingName: model.renameMissing,
                closeAccessibilityLabel: Copy.photoViewerA11yClose,
                onNameChange: {},
                onSave: { Task { await model.rename() } },
                onClose: { model.isRenaming = false }
            )
        }
        .accessibilityIdentifier("albums.view") // provenance-ok: accessibility identifier for UI tests
    }

    private var name: String { model.album?.name ?? initialName ?? "" }

    private var meta: String {
        model.isMine ? Copy.albumsListRowSubtitleMine : Copy.albumsListRowSubtitle(name: model.creatorName ?? "")
    }

    private var page: some View {
        MetricStack(alignment: .center) {
            cover
                .metricGap(Tokens.Sizes.albumsViewDimensionCoverTop, from: .top, to: .top)
            Text(name)
                .dsTextRole(TextRole.displayTitle)
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
                .metricGap(Tokens.Sizes.albumsViewDimensionCoverToTitle, from: .bottom, to: .capTop)
            Text(model.album == nil ? "" : meta)
                .dsTextStyle(TextRole.listSubtitle)
                .foregroundStyle(Tokens.Colors.globalTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
                .metricGap(Tokens.Sizes.albumsViewDimensionTitleToMeta, from: .lastBaseline, to: .firstBaseline)
            actions
                .metricGap(Tokens.Sizes.albumsViewDimensionMetaToActions, from: .lastBaseline, to: .top)
            gridArea
                .metricGap(Tokens.Sizes.wallsMineDimensionActionsToWeeks, from: .bottom, to: .top)
        }
    }

    /// The cover: the album's first item (a placeholder while loading or when empty) with Retro's book-cover drop shadow
    /// (`albums.view.shadow.cover`, TC-J1). Tap → the viewer on the first item.
    private var cover: some View {
        Button {
            if let first = model.posts.first { open(first.id) }
        } label: {
            PhotoView(source: SocialImages.source(model.posts.first?.media?.displayImagePath))
                .frame(width: Tokens.Sizes.albumsViewDimensionCoverWidth, height: Tokens.Sizes.albumsViewDimensionCoverHeight)
                .clipShape(DSShape.rounded(Tokens.Radii.globalThumbnail))
                .dsShadow(Tokens.Shadows.albumsViewShadowCover)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(Copy.albumsViewA11yCover(albumName: name)))
    }

    /// "Rename" (C-06 outline, fills the row) and, for the creator and admins, the "•••" icon capsule.
    @ViewBuilder
    private var actions: some View {
        if model.album != nil {
            CapsuleRow {
                CapsuleButton(Copy.albumsViewMenuRename, fillsWidth: true) { model.startRename() }
                if model.canDelete {
                    Menu {
                        Button(Copy.albumsViewMenuDelete, role: .destructive) { confirmingDelete = true }
                    } label: {
                        CapsuleLabel(icon: Tokens.Icons.globalMore)
                    }
                    .accessibilityLabel(Text(Copy.albumsViewA11yMore))
                }
            }
            .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
        }
    }

    @ViewBuilder
    private var gridArea: some View {
        switch model.phase {
        case .loading:
            if model.showsLoading {
                AlbumGrid(cells: Array(repeating: nil, count: Int(Tokens.Counts.albumsViewCountGridColumns) * 2)) { _ in } // provenance-ok: two rows of placeholder cells (loading)
                    .accessibilityLabel(Text(Copy.weekHistoryA11yLoading))
            }
        case .empty:
            EmptyStateView(title: Copy.albumsViewEmptyTitle, detail: Copy.albumsViewEmptyDetail)
        case .failed, .offline:
            SocialErrorLine(text: Copy.albumsListErrorTitle) { Task { await model.retry() } }
        case .ready:
            AlbumGrid(
                cells: model.posts.map { $0 },
                label: { SocialA11y.photo($0, author: model.profiles[$0.post.authorID], me: model.me) }
            ) { post in
                if let post { open(post.id) }
            }
        case .notFound:
            EmptyView()
        }
    }

    private func open(_ postID: PostID) {
        viewer = PhotoViewerContext(postIDs: model.postIDs, start: postID, groupID: model.groupID)
    }
}

/// The album grid (`albums.view` Structure 5): `albums.view.count.gridColumns` columns inside `size.global.screenMargin`,
/// `size.global.stripGap` gaps, cells `albums.view.aspectRatio.gridCell` (aspect fill), in the saved order. Only the
/// grid's outer contour rounds at `albums.view.radius.grid`: the first row's end cells at the top, the last row's first
/// and last cells at the bottom — and, when the last row is short, the trailing cell of the row above at its
/// bottom-trailing corner; inner corners stay square. (The shared `PhotoGrid` draws square cells with square corners —
/// reported as a component gap.)
struct AlbumGrid: View {
    let cells: [PostWithMedia?]
    var label: (PostWithMedia) -> String = { _ in "" }
    let open: (PostWithMedia?) -> Void

    private var columns: Int { max(1, Int(Tokens.Counts.albumsViewCountGridColumns)) }

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: Tokens.Sizes.globalStripGap), count: columns),
            spacing: Tokens.Sizes.globalStripGap
        ) {
            ForEach(Array(cells.enumerated()), id: \.offset) { index, post in
                let shape = AlbumGridCorners.shape(index: index, count: cells.count, columns: columns)
                Button { open(post) } label: {
                    PhotoView(source: SocialImages.source(post?.media?.gridPath))
                        .aspectRatio(Tokens.AspectRatios.albumsViewAspectRatioGridCell, contentMode: .fit)
                        .overlay(alignment: .topTrailing) {
                            if let durationMs = post?.media?.videoDurationMs { VideoTileMarker(durationMs: durationMs) }
                        }
                        .clipShape(shape)
                        .contentShape(shape)
                }
                .buttonStyle(.plain)
                .disabled(post == nil)
                .accessibilityLabel(Text(post.map { SocialA11y.withVideo(label($0), media: $0.media) } ?? ""))
                .accessibilityHidden(post == nil)
            }
        }
        .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
    }
}

/// Which corners of a grid cell round (`albums.view.radius.grid`).
enum AlbumGridCorners {
    struct Corners: Equatable {
        var topLeading = false
        var topTrailing = false
        var bottomLeading = false
        var bottomTrailing = false
    }

    static func corners(index: Int, count: Int, columns: Int) -> Corners {
        guard count > 0, columns > 0, (0..<count).contains(index) else { return Corners() }
        let rows = (count + columns - 1) / columns
        let lastRowStart = (rows - 1) * columns
        var result = Corners()
        result.topLeading = index == 0
        result.topTrailing = index == min(columns, count) - 1
        result.bottomLeading = index == lastRowStart
        result.bottomTrailing = index == count - 1 || (rows > 1 && count % columns != 0 && index == lastRowStart - 1)
        return result
    }

    static func shape(index: Int, count: Int, columns: Int) -> UnevenRoundedRectangle {
        let corners = corners(index: index, count: count, columns: columns)
        let radius = Tokens.Radii.albumsViewRadiusGrid
        return UnevenRoundedRectangle(
            topLeadingRadius: corners.topLeading ? radius : 0,
            bottomLeadingRadius: corners.bottomLeading ? radius : 0,
            bottomTrailingRadius: corners.bottomTrailing ? radius : 0,
            topTrailingRadius: corners.topTrailing ? radius : 0,
            style: .continuous
        )
    }
}
