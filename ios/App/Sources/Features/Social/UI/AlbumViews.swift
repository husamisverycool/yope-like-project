// Surfaces: albums.list, albums.view — reference apps: Yope (header, states, name sheet, menu) + Apple Photos (the album
// cover grid, albums.list.layout.yopeAlbums, MERGE_DECISIONS G-17). Specs: design/surfaces/albums.list.md, albums.view.md.
// References: references/auto/apple-photos/apple-support/photos-albums-ios27.png (cover grid), references/owner/yope-week-recap.jpg
// (header, pics grid), references/auto/yope/frames/a-yrrah-7434441926000037121-t33.73-group-menu-leave-report-2024.png
// (native ••• menu), a-itsmthuyope-7644974799302823175-t45.23-new-group-empty.png (name sheet).
import AppData
import AppModels
import DesignSystem
import SwiftUI

// MARK: - albums.list

struct AlbumsListScreen: View {
    @State private var model: AlbumsListModel
    @Environment(\.dismiss) private var dismiss

    init(groupID: String) {
        self.init(model: AlbumsListModel(groupID: GroupID(groupID), data: SocialServices.shared.data))
    }

    init(model: AlbumsListModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        ZStack {
            Tokens.Colors.globalBackgroundDeep.ignoresSafeArea()
            content
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            SocialCenteredHeader(title: Copy.albumsListTitle, leadingAction: { dismiss() }) { EmptyView() }
        }
        .socialHidesNavigationBar()
        .task { await model.load() }
        .accessibilityIdentifier("albums.list") // provenance-ok: accessibility identifier for UI tests
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .loading:
            if model.showsLoading { LoadingHUD() }
        case .empty:
            EmptyStateView(
                title: Copy.albumsListEmptyTitle,
                detail: Copy.albumsListEmptyDetail,
                action: model.latestRecapID.map { recapID in
                    EmptyStateView.Action(Copy.albumsListEmptyAction) {
                        SocialNav.push(.recap(groupID: model.groupID.rawValue, recapID: recapID.rawValue))
                    }
                }
            )
        case .failed:
            EmptyStateView(
                title: Copy.albumsListErrorTitle,
                detail: Copy.chatThreadErrorDetail,
                action: .init(Copy.chatThreadErrorRetry) { Task { await model.retry() } }
            )
        case .offline:
            EmptyStateView(title: Copy.chatThreadOfflineTitle, detail: Copy.chatThreadOfflineDetail)
        case .ready:
            ScrollView {
                LazyVGrid(columns: columns, spacing: Covers.gap) {
                    ForEach(model.albums) { album in
                        NavigationLink(value: AppRoute.social(.album(groupID: model.groupID.rawValue, albumID: album.id.rawValue))) {
                            AlbumCover(
                                name: album.album.name,
                                subtitle: model.savedByName(album).map { Copy.albumsListRowSubtitle(name: $0) },
                                coverPath: model.cover(of: album)?.media?.gridPath
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Covers.marginH)
            }
        }
    }

    private typealias Covers = Tokens.Layouts.AlbumsListLayoutYopeAlbums

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: Covers.gap), count: Int(Covers.columns))
    }
}

/// An album in the Apple Photos "Album Cover" format (`albums.list.layout.yopeAlbums`, G-17): a square cover
/// (`coverAspect`, corners `coverRadius`) of the album's first photo, aspect fill; the name over its bottom-leading corner
/// (`titleFontSize`, ink `titleInsetLeading` from the leading edge, baseline `titleBaselineBottom` above the bottom),
/// one line, tail truncation, `color.global.textPrimary`. The subtitle `albums.list.row.subtitle` is not drawn: it joins
/// the accessibility label (the platform combines the name and subtitle texts).
struct AlbumCover: View {
    let name: String
    let subtitle: String?
    let coverPath: String?

    @State private var width: CGFloat = 0
    @Environment(\.displayScale) private var displayScale

    private typealias Covers = Tokens.Layouts.AlbumsListLayoutYopeAlbums

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Covers.coverRadius)
        SocialPhoto(path: coverPath, maxPixel: width > 0 ? Int((width * displayScale).rounded(.up)) : nil)
            .aspectRatio(Covers.coverAspect, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .socialReadsWidth($width)
            .overlay(alignment: .bottomLeading) {
                Text(name)
                    .dsTextStyle(SocialText.albumCoverTitle)
                    .foregroundStyle(Tokens.Colors.globalTextPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.leading, Covers.titleInsetLeading)
                    .padding(.trailing, Covers.titleInsetLeading)
                    .alignmentGuide(.bottom) { $0[.lastTextBaseline] + Covers.titleBaselineBottom }
            }
            .clipShape(shape)
            .contentShape(shape)
            .accessibilityRepresentation {
                VStack {
                    Text(name)
                    if let subtitle { Text(subtitle) }
                }
                .accessibilityElement(children: .combine)
            }
            .accessibilityAddTraits(.isButton)
    }
}

// MARK: - albums.view

struct AlbumScreen: View {
    @State private var model: AlbumModel
    @State private var viewer: PhotoViewerContext?
    @State private var confirmingDelete = false
    @State private var toasts = ToastCenter()
    @Environment(\.dismiss) private var dismiss

    init(groupID: String, albumID: String) {
        self.init(model: AlbumModel(groupID: GroupID(groupID), albumID: AlbumID(albumID), data: SocialServices.shared.data))
    }

    init(model: AlbumModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        ZStack {
            Tokens.Colors.globalBackground.ignoresSafeArea()
            content
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            SocialCenteredHeader(title: model.album?.name ?? "", leadingAction: { dismiss() }) {
                if model.album != nil {
                    HeaderCircleMenu(icon: Tokens.Icons.globalMore, accessibilityLabel: Copy.photoViewerA11yMore, fill: .onDeep) {
                        Button { model.startRename() } label: {
                            Label(Copy.albumsViewMenuRename, systemImage: Tokens.Icons.globalEdit)
                        }
                        if model.canDelete {
                            Button(role: .destructive) { confirmingDelete = true } label: {
                                Label(Copy.albumsViewMenuDelete, systemImage: Tokens.Icons.photoViewerIconDelete)
                            }
                        }
                    }
                }
            }
        }
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
            AlbumNameSheet(
                title: Copy.albumsViewRenameTitle,
                name: $model.renameText,
                isEnabled: !model.renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                showsMissingName: model.renameMissing,
                onNameChange: {},
                onSave: { Task { await model.rename() } }
            )
        }
        .accessibilityIdentifier("albums.view") // provenance-ok: accessibility identifier for UI tests
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .loading:
            if model.showsLoading { LoadingHUD() }
        case .empty:
            EmptyStateView(title: Copy.albumsViewEmptyTitle, detail: Copy.albumsViewEmptyDetail)
        case .notFound:
            EmptyStateView(title: Copy.albumsViewEmptyTitle)
        case .failed:
            EmptyStateView(
                title: Copy.albumsListErrorTitle,
                detail: Copy.chatThreadErrorDetail,
                action: .init(Copy.chatThreadErrorRetry) { Task { await model.retry() } }
            )
        case .offline:
            EmptyStateView(title: Copy.chatThreadOfflineTitle, detail: Copy.chatThreadOfflineDetail)
        case .ready:
            ScrollView {
                WeekPicsGrid(
                    posts: model.posts,
                    label: { SocialA11y.photo($0, author: model.profiles[$0.post.authorID], me: model.me) },
                    open: { post in viewer = PhotoViewerContext(postIDs: model.postIDs, start: post.id, groupID: model.groupID) }
                )
            }
        }
    }
}
