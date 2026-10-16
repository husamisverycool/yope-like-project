// Surface: week.history — Retro's profile week sections (screens 4–5: "Week 27  Jul 3 - 9" + "•••", 3:4 strip tiles
// with weekday labels) and its current-week strip (add tile, dated empty-day tiles; 2026: photos, add, blank
// placeholders), as the group's weeks. Spec: design/surfaces/week.history.md (RS-20).
// References: references/auto/retro/store/retro-store-02.png (primary), references/auto/retro/lazyweb/
// retro-lazyweb-20251020-week43-dark.png and retro-lazyweb-20260528-week22-dark-a.png (strip geometry, empty week),
// references/auto/retro/press/engadget-2026-08-profile.jpg (current week), references/auto/retro/store/editorial/
// retro-appstore-story-1854931006-week3-albums.png (C-02 header), references/auto/retro/press/tc-2025-12-rewind-panels.png (menu).
import AppData
import AppModels
import DesignSystem
import SwiftUI

struct WeekHistoryScreen: View {
    @State private var model: WeekHistoryModel
    @State private var viewer: PhotoViewerContext?
    @State private var albumWeek: AlbumWeek?
    @State private var recapPreview: RecapPreviewTarget?
    @State private var toasts = ToastCenter()
    @Environment(\.dismiss) private var dismiss

    init(groupID: String) {
        self.init(model: WeekHistoryModel(groupID: GroupID(groupID), data: SocialServices.shared.data))
    }

    init(model: WeekHistoryModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        Group {
            if model.line == .empty, !model.isLoading {
                emptyPage
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        header
                        content
                    }
                    .padding(.bottom, Tokens.Sizes.globalSectionGap)
                }
                .refreshable { await model.load() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Tokens.Colors.globalBackground.ignoresSafeArea())
        .socialHidesNavigationBar()
        .socialAnnouncesLoading(model.showsLoading)
        .task {
            if model.isLoading { await model.load() }
            await model.run()
        }
        .toastHost(toasts)
        .socialPhotoViewer($viewer)
        .sheet(item: $albumWeek) { item in
            WeekEditView(groupID: model.groupID, mode: .album(weekStart: item.weekStart), toasts: toasts)
        }
        .fullScreenCover(item: $recapPreview) { target in
            // week.recap.md platform notes: the preview is a `.fullScreenCover`, dark in both appearances.
            WeekRecapPreviewScreen(groupID: model.groupID.rawValue, recapID: target.recapID.rawValue, isPresentedModally: true)
        }
        .accessibilityIdentifier("week.history") // provenance-ok: accessibility identifier for UI tests
    }

    /// C-02: back chevron + the group's name in the display serif, one line.
    private var header: some View {
        PushedScreenHeader(title: model.group?.name ?? "", backAccessibilityLabel: Copy.chatThreadA11yBack) { dismiss() }
            .lineLimit(1)
            .truncationMode(.tail)
    }

    /// The first section's header cap top sits `size.global.titleToContent` below the title baseline (where the C-02
    /// header ends).
    private var firstSectionOffset: CGFloat { -SocialMetrics.capTopOffset(TextRole.sectionLabel) }

    @ViewBuilder
    private var content: some View {
        if model.isLoading {
            if model.showsLoading { loadingSections }
        } else if model.line == .error {
            SocialErrorLine(text: Copy.weekHistoryError) { Task { await model.load() } }
        } else {
            if model.line == .offline {
                SocialErrorLine(text: Copy.weekHistoryOffline) { Task { await model.load() } }
                    .padding(.bottom, Tokens.Sizes.globalSectionGap)
            }
            WeekSectionList {
                ForEach(model.weeks) { week in
                    WeekHistorySection(
                        model: model, week: week, open: open,
                        viewRecap: { recapPreview = RecapPreviewTarget(recapID: $0) },
                        saveAsAlbum: { albumWeek = AlbumWeek(weekStart: week.weekStart) }
                    )
                        .onAppear {
                            if week.id == model.weeks.last?.id { Task { await model.loadMore() } }
                        }
                }
                if model.isLoadingMore {
                    ProgressView()
                        .tint(Tokens.Colors.globalTextSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, model.line == .offline ? 0 : firstSectionOffset)
        }
    }

    /// Two sections of placeholder tiles under headers without ranges (C-28 for Retro's lists).
    private var loadingSections: some View {
        WeekSectionList {
            ForEach(0..<2, id: \.self) { index in // provenance-ok: week.history loading state "two sections"
                let week = model.currentWeekStart.adding(days: -7 * index) // provenance-ok: one week back per section
                WeekStripSection {
                    SectionHeader(title: Copy.weekHistoryHeaderTitle(weekNumber: String(SocialCalendar.weekNumber(of: week, in: model.timeZone))))
                } content: {
                    WeekStrip(tiles: WeekStripLayout.placeholders(count: SocialCalendar.days(of: week).count), accessibilityLabel: { _ in "" })
                }
            }
        }
        .padding(.top, firstSectionOffset)
        .accessibilityLabel(Text(Copy.weekHistoryA11yLoading))
    }

    /// No photos in the group yet: the current week (add + seven empty days), then the C-27 block centred in the space
    /// below — `icon.global.calendar`, "Welcome to Week {n}!", C-07 "Get this week started" (→ camera for this group).
    private var emptyPage: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            WeekSectionList {
                ForEach(model.weeks.filter(\.isCurrent)) { week in
                    WeekHistorySection(model: model, week: week, open: open, viewRecap: { _ in }, saveAsAlbum: {})
                }
            }
            .padding(.top, firstSectionOffset)
            Spacer(minLength: Tokens.Sizes.globalSectionGap)
            EmptyStateView(
                icon: Tokens.Icons.globalCalendar,
                title: Copy.weekHistoryEmptyTitle(weekNumber: String(model.currentWeekNumber)),
                action: .init(Copy.weekHistoryEmptyAction, icon: Tokens.Icons.globalAdd) {
                    SocialNav.openCamera(groupID: model.groupID.rawValue)
                }
            )
            .frame(maxWidth: .infinity)
            Spacer(minLength: Tokens.Sizes.globalSectionGap)
        }
    }

    private func open(_ week: WeekHistoryModel.Week, _ postID: PostID) {
        viewer = PhotoViewerContext(postIDs: week.postIDs, start: postID, groupID: model.groupID)
    }
}

struct AlbumWeek: Identifiable {
    let weekStart: LocalDate
    var id: LocalDate { weekStart }
}

/// One week: the C-20 header ("Week {n}" + the range — left out for the current week without photos — and "•••" with
/// the week menu when it has a ready recap or photos), then the C-17 strip `size.global.sectionHeaderToContent` below
/// the header's baseline.
struct WeekHistorySection: View {
    let model: WeekHistoryModel
    let week: WeekHistoryModel.Week
    let open: (WeekHistoryModel.Week, PostID) -> Void
    let viewRecap: (RecapID) -> Void
    let saveAsAlbum: () -> Void

    var body: some View {
        WeekStripSection {
            header
        } content: {
            WeekStrip(tiles: tiles, accessibilityLabel: label, onSelect: select)
        }
        .accessibilityElement(children: .contain)
    }

    private var posts: [PostWithMedia] { week.postIDs.compactMap { model.posts[$0] } }

    private var showsRange: Bool { !(week.isCurrent && week.postIDs.isEmpty) }

    @ViewBuilder
    private var header: some View {
        let number = model.weekNumber(of: week)
        let recapID = model.readyRecaps[week.weekStart]
        let hasMenu = recapID != nil || !week.postIDs.isEmpty
        SectionHeader(
            title: Copy.weekHistoryHeaderTitle(weekNumber: String(number)),
            detail: showsRange ? SocialFormat.weekRange(week.weekStart, timeZone: model.timeZone) : nil,
            accessibilityLabel: SocialA11y.weekHeader(number: number, weekStart: week.weekStart, timeZone: model.timeZone, showsRange: showsRange),
            moreAccessibilityLabel: hasMenu ? Copy.weekHistoryA11yMore : nil
        ) {
            // `week.history.layout.weekMenu`: native menu, Sentence case.
            if let recapID {
                Button(Copy.weekHistoryMenuViewRecap) { viewRecap(recapID) }
            }
            if !week.postIDs.isEmpty {
                Button(Copy.weekHistoryMenuSaveAsAlbum, action: saveAsAlbum)
            }
        }
    }

    /// Photo tiles in time order (several on a day = several tiles); the current week per
    /// `week.history.layout.currentWeek` (add tile → camera for this group).
    private var tiles: [WeekStripTile] {
        let photos = posts.map { post in
            WeekStripPhoto(id: post.id.rawValue, date: post.post.createdAt, source: SocialImages.source(post.media?.gridPath))
        }
        let days = SocialCalendar.days(of: week.weekStart).map { SocialCalendar.start(of: $0, in: model.timeZone) }
        let emptyDays = (model.emptyDays(of: week) ?? []).map { SocialCalendar.start(of: $0, in: model.timeZone) }
        return WallTiles.currentWeekTiles(days: days, photos: photos, isCurrent: week.isCurrent, canAdd: true, emptyDays: emptyDays)
    }

    private func label(_ tile: WeekStripTile) -> String {
        switch tile.kind {
        case .add:
            return Copy.weekHistoryA11yAdd
        case .emptyDay, .placeholder:
            return tile.date.map { SocialA11y.emptyDay($0, timeZone: model.timeZone) } ?? ""
        case .photo:
            guard let post = post(for: tile) else { return "" }
            return SocialA11y.tile(date: post.post.createdAt, name: model.profiles[post.post.authorID]?.socialFirstName ?? "", timeZone: model.timeZone)
        }
    }

    private func select(_ tile: WeekStripTile) {
        switch tile.kind {
        case .add:
            SocialNav.openCamera(groupID: model.groupID.rawValue)
        case .photo:
            if let post = post(for: tile) { open(week, post.id) }
        case .emptyDay, .placeholder:
            break
        }
    }

    private func post(for tile: WeekStripTile) -> PostWithMedia? {
        posts.first { "photo-" + $0.id.rawValue == tile.id }
    }
}
