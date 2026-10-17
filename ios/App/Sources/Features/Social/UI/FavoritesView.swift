// Surface: favorites — your private favorites: the pushed `albums.list` header over the `albums.view` grid.
// Spec: design/surfaces/favorites.md. Mechanics: Apple Photos Favorites
// (https://iphonelife.com/blog/5/tip-day-quick-way-create-album-your-favorite-photos). References:
// references/auto/retro/store/editorial/retro-appstore-story-1854931006-week3-albums.png (pushed header),
// references/auto/retro/press/tc-2024-04-journals-1.webp phone 3 (grid). No count anywhere (tenet 2).
import AppData
import AppModels
import DesignSystem
import SwiftUI

/// C-02 header "Favorites"; the grid `size.global.titleToContent` below: `albums.view.count.gridColumns` columns of
/// `albums.view.aspectRatio.gridCell` cells, `size.global.stripGap` gaps, outer corners `albums.view.radius.grid`; newest
/// favorite first; a cell opens the viewer on the favorites shown.
struct FavoritesScreen: View {
    @State private var model: FavoritesModel
    @State private var viewer: PhotoViewerContext?
    @Environment(\.dismiss) private var dismiss

    init(model: FavoritesModel? = nil) {
        _model = State(initialValue: model ?? FavoritesModel(data: SocialServices.shared.data))
    }

    var body: some View {
        Group {
            if model.phase == .empty {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    Spacer(minLength: 0)
                    EmptyStateView(icon: Tokens.Icons.globalFavorite, title: Copy.favoritesEmptyTitle, detail: Copy.favoritesEmptyDetail)
                        .frame(maxWidth: .infinity)
                    Spacer(minLength: 0)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        header
                        content
                            .padding(.top, Tokens.Sizes.globalTitleToContent)
                    }
                    .padding(.bottom, Tokens.Sizes.globalSectionGap)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Tokens.Colors.globalBackground.ignoresSafeArea())
        .socialHidesNavigationBar()
        .socialAnnouncesLoading(model.showsLoading)
        .task {
            if model.phase == .loading { await model.load() }
            await model.run()
        }
        .onChange(of: viewer) { old, new in
            // Back from the viewer: an Unfavorite there leaves the grid.
            if old != nil, new == nil { Task { await model.load() } }
        }
        .socialPhotoViewer($viewer)
        .accessibilityIdentifier("favorites") // provenance-ok: accessibility identifier for UI tests
    }

    private var header: some View {
        PushedScreenHeader(title: Copy.favoritesTitle, backAccessibilityLabel: Copy.chatThreadA11yBack) { dismiss() }
    }

    private var columns: Int { max(1, Int(Tokens.Counts.albumsViewCountGridColumns)) }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .loading:
            if model.showsLoading {
                AlbumGrid(cells: Array(repeating: nil, count: columns * 2)) { _ in } // provenance-ok: two rows of placeholder cells (loading)
                    .accessibilityLabel(Text(Copy.weekHistoryA11yLoading))
            }
        case .empty:
            EmptyView()
        case .failed, .offline:
            SocialErrorLine(text: Copy.favoritesErrorTitle) { Task { await model.retry() } }
        case .ready:
            grid
            if model.isLoadingMore {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, Tokens.Sizes.globalSectionGap)
            }
        }
    }

    private var grid: some View {
        let items = model.items
        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: Tokens.Sizes.globalStripGap), count: columns),
            spacing: Tokens.Sizes.globalStripGap
        ) {
            ForEach(Array(items.enumerated()), id: \.element.mediaID) { index, item in
                let shape = AlbumGridCorners.shape(index: index, count: items.count, columns: columns)
                Button { viewer = model.viewerContext(start: item.postID) } label: {
                    PhotoView(source: SocialImages.source(item.thumbPath))
                        .aspectRatio(Tokens.AspectRatios.albumsViewAspectRatioGridCell, contentMode: .fit)
                        .overlay(alignment: .topTrailing) {
                            if let durationMs = model.media[item.postID]?.videoDurationMs { VideoTileMarker(durationMs: durationMs) }
                        }
                        .clipShape(shape)
                        .contentShape(shape)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(label(item)))
                .onAppear {
                    if index == items.count - 1 { Task { await model.loadMore() } }
                }
            }
        }
        .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
    }

    /// `photo.viewer.a11y.photoMine` / `.photo` (the day it was posted), then the video length.
    private func label(_ item: FavoritePhoto) -> String {
        let date = SocialFormat.spokenDate(item.takenAt)
        let base = item.authorID == model.me
            ? Copy.photoViewerA11yPhotoMine(date: date)
            : Copy.photoViewerA11yPhoto(name: model.profiles[item.authorID]?.socialFirstName ?? "", date: date)
        return SocialA11y.withVideo(base, media: model.media[item.postID])
    }
}
