// Surfaces: photo.viewer (the album picker, `photo.viewer.layout.albumPicker`) and albums.view (the add sheet,
// `albums.view.layout.add`) — albums anyone in the group can add to (owner decision 34, research #10).
// Specs: design/surfaces/photo.viewer.md "Album picker", design/surfaces/albums.view.md "Add sheet".
// References: references/auto/retro/store/editorial/retro-appstore-story-1854931006-week3-albums.png (album rows),
// references/auto/retro/press/tc-2025-12-rewind-panels.png (Rewind "Add to Album"); the pick grid is week.edit's
// (design/surfaces/week.edit.md, `week.edit.layout.selectionMark`).
import AppData
import AppModels
import DesignSystem
import SwiftUI

// MARK: - photo.viewer album picker

/// C-29 sheet: the leading close circle + "Add to Album"; `size.global.titleToContent` below, the "New Album" row (an
/// empty cover) then the group's albums as C-15 rows, newest first. A row adds the photo; "New Album" opens week.edit's
/// name sheet and saves a new album with it.
struct AlbumPickerSheet: View {
    @State private var model: AlbumPickerModel
    let onDone: () -> Void
    @State private var toasts = ToastCenter()
    @Environment(\.dismiss) private var dismiss

    init(model: AlbumPickerModel, onDone: @escaping () -> Void) {
        _model = State(initialValue: model)
        self.onDone = onDone
    }

    var body: some View {
        VStack(spacing: 0) {
            LeadingCloseSheetHeader(title: Copy.photoViewerMenuAddToAlbum, closeAccessibilityLabel: Copy.photoViewerA11yClose) { dismiss() }
                .padding(.top, Tokens.Sizes.globalScreenMargin)
            ScrollView {
                ThumbnailRowList {
                    ThumbnailRow(title: Copy.weekEditAlbumTitle, thumbnail: nil, accessibilityLabel: Copy.weekEditAlbumTitle) {
                        model.startNaming()
                    }
                    rows
                }
                .padding(.top, Tokens.Sizes.globalTitleToContent)
                .padding(.bottom, Tokens.Sizes.globalSectionGap)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Tokens.Colors.globalBackground.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .dsSheetBackground()
        .disabled(model.isSaving)
        .task { await model.load() }
        .onChange(of: model.isDone) { _, done in
            if done {
                onDone()
                dismiss()
            }
        }
        .socialFeedback(model.signals.feedback)
        .socialNotices(model.signals.notice, toasts: toasts)
        .toastHost(toasts)
        .sheet(isPresented: $model.isNaming) {
            SocialNameSheet(
                title: Copy.weekEditAlbumTitle,
                placeholder: Copy.weekEditAlbumNamePlaceholder,
                buttonTitle: Copy.weekEditAlbumCreate,
                name: $model.newName,
                isEnabled: !model.newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !model.isSaving,
                isBusy: model.isSaving,
                showsMissingName: model.nameMissing,
                closeAccessibilityLabel: Copy.photoViewerA11yClose,
                onNameChange: {},
                onSave: { Task { await model.createAlbum() } },
                onClose: { model.isNaming = false }
            )
        }
        .accessibilityIdentifier("photo.viewer.albumPicker") // provenance-ok: accessibility identifier for UI tests
    }

    @ViewBuilder
    private var rows: some View {
        switch model.phase {
        case .loading:
            ForEach(0..<3, id: \.self) { _ in // provenance-ok: the picker's loading state "three rows" (photo.viewer.md)
                Tokens.Colors.globalControl
                    .frame(width: Tokens.Sizes.globalRowThumbWidth, height: Tokens.Sizes.globalRowThumbHeight)
                    .clipShape(DSShape.rounded(Tokens.Radii.globalThumbnail))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(Copy.weekHistoryA11yLoading))
        case .empty:
            EmptyView()
        case .failed, .offline:
            SocialErrorLine(text: Copy.albumsListErrorTitle) { Task { await model.retry() } }
        case .ready:
            ForEach(model.albums) { album in
                let name = model.savedByName(album)
                let mine = model.isMine(album)
                let subtitle = mine ? Copy.albumsListRowSubtitleMine : Copy.albumsListRowSubtitle(name: name)
                ThumbnailRow(
                    title: album.album.name,
                    subtitle: subtitle,
                    subtitleEmphasis: mine ? nil : name,
                    thumbnail: SocialImages.source(model.cover(of: album)?.media?.gridPath),
                    accessibilityLabel: album.album.name + ", " + subtitle // provenance-ok: joins the album name and its copy line
                ) {
                    Task { await model.add(to: album) }
                }
            }
        }
    }
}

// MARK: - albums.view add sheet

/// C-29 sheet: the leading close circle + "Add Photos"; the group's photos the album lacks in week.edit's pick grid
/// (`week.edit.count.gridColumns` square cells, `size.global.stripGap`); the C-05 "Add" capsule at the bottom, disabled
/// until a photo is picked.
struct AlbumAddSheet: View {
    @State private var model: AlbumAddModel
    let onDone: () -> Void
    @State private var toasts = ToastCenter()
    @Environment(\.dismiss) private var dismiss

    init(model: AlbumAddModel, onDone: @escaping () -> Void) {
        _model = State(initialValue: model)
        self.onDone = onDone
    }

    var body: some View {
        VStack(spacing: 0) {
            LeadingCloseSheetHeader(title: Copy.albumsViewMenuAdd, closeAccessibilityLabel: Copy.photoViewerA11yClose) { dismiss() }
                .padding(.top, Tokens.Sizes.globalScreenMargin)
            ScrollView {
                content
                    .padding(.top, Tokens.Sizes.globalTitleToContent)
                    .padding(.bottom, Tokens.Sizes.globalSectionGap)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PrimaryButton(Copy.albumsViewAddConfirm, height: .sheet, isEnabled: model.canAdd, isBusy: model.isSaving) {
                Task { await model.add() }
            }
            .padding(.horizontal, Tokens.Sizes.globalButtonMarginHSheet)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Tokens.Colors.globalBackground.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .dsSheetBackground()
        .task { if model.phase == .loading { await model.load() } }
        .onChange(of: model.isDone) { _, done in
            if done {
                onDone()
                dismiss()
            }
        }
        .socialFeedback(model.signals.feedback)
        .socialNotices(model.signals.notice, toasts: toasts)
        .toastHost(toasts)
        .accessibilityIdentifier("albums.view.add") // provenance-ok: accessibility identifier for UI tests
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: Tokens.Sizes.globalStripGap), count: max(1, Int(Tokens.Counts.weekEditCountGridColumns)))
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .loading:
            LazyVGrid(columns: columns, spacing: Tokens.Sizes.globalStripGap) {
                ForEach(0..<(columns.count * 2), id: \.self) { _ in // provenance-ok: two rows of placeholder cells (loading)
                    Tokens.Colors.globalControl.aspectRatio(1, contentMode: .fit) // provenance-ok: square cells (C-21 composer grid)
                }
            }
            .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(Copy.weekHistoryA11yLoading))
            .socialAnnouncesLoading(true)
        case .empty:
            EmptyStateView(title: Copy.albumsViewAddEmpty)
                .frame(maxWidth: .infinity)
        case .failed, .offline:
            SocialErrorLine(text: Copy.albumsListErrorTitle) { Task { await model.retry() } }
        case .ready:
            LazyVGrid(columns: columns, spacing: Tokens.Sizes.globalStripGap) {
                ForEach(model.posts) { post in
                    let checked = model.isPicked(post.id)
                    Button { model.toggle(post.id) } label: {
                        SelectionMarkedCell(source: SocialImages.source(post.media?.gridPath), checked: checked)
                            .overlay(alignment: .topTrailing) {
                                if let durationMs = post.media?.videoDurationMs { VideoTileMarker(durationMs: durationMs) }
                            }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(SocialA11y.withVideo(SocialA11y.photo(post, author: model.profiles[post.post.authorID], me: model.me), media: post.media)))
                    .accessibilityAddTraits(checked ? .isSelected : [])
                }
            }
            .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
        }
    }
}
