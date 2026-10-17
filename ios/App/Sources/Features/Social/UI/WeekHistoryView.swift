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
    @State private var calendarOpen = false
    /// The week the calendar jumped to, scrolled to the top once it is in the list.
    @State private var scrollTarget: LocalDate?
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
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            header
                            content
                        }
                        .padding(.bottom, Tokens.Sizes.globalSectionGap)
                    }
                    .refreshable { await model.load() }
                    .onChange(of: scrollTarget) { _, target in
                        guard let target else { return }
                        proxy.scrollTo(target, anchor: .top)
                        scrollTarget = nil
                    }
                }
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
        .sheet(isPresented: $calendarOpen) {
            HistoryCalendarSheet(months: model.months.map(HistoryCalendarMonth.init), timeZone: model.timeZone) { week in
                calendarOpen = false
                Task {
                    if await model.jump(to: week) { scrollTarget = week }
                }
            } onClose: {
                calendarOpen = false
            }
        }
        .fullScreenCover(item: $recapPreview) { target in
            // week.recap.md platform notes: the preview is a `.fullScreenCover`, dark in both appearances.
            WeekRecapPreviewScreen(groupID: model.groupID.rawValue, recapID: target.recapID.rawValue, isPresentedModally: true)
        }
        .accessibilityIdentifier("week.history") // provenance-ok: accessibility identifier for UI tests
    }

    /// C-02: back chevron + the group's name in the display serif, one line; once the history's months are known, the
    /// calendar glyph (`week.history.layout.calendar`).
    private var header: some View {
        PushedScreenHeader(
            title: model.group?.name ?? "",
            backAccessibilityLabel: Copy.chatThreadA11yBack,
            actions: model.months.isEmpty ? [] : [
                HeaderAction(icon: Tokens.Icons.globalCalendar, accessibilityLabel: Copy.weekHistoryCalendarOpen) { calendarOpen = true },
            ]
        ) { dismiss() }
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
                        .id(week.id)
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

    private var showsRange: Bool { !(week.isCurrent && week.isBlank) }

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

    /// Photo tiles in time order (several on a day = several tiles); each day's same-moment collage (the group's
    /// photo of that day, migration 0033) on its day, before that day's photos; the current week per
    /// `week.history.layout.currentWeek` (add tile → camera for this group). Photos posted together are one tile, the
    /// batch's first photo with the batch marker (`layout.global.photoBatch`); the viewer opens on it with the batch.
    private var tiles: [WeekStripTile] {
        let runs = PhotoBatches.runs(posts) { $0.post.batchKey }
        let postPhotos: [WeekStripPhoto] = runs.compactMap { run in
            guard let post = run.first else { return nil }
            return WeekStripPhoto(
                id: post.id.rawValue, date: post.post.visibleAt, source: SocialImages.source(post.media?.gridPath),
                videoDurationMs: post.media?.videoDurationMs, isBatch: run.count > 1
            )
        }
        let photos = postPhotos + week.collages.map { collage in
            WeekStripPhoto(
                id: Self.collagePrefix + collage.collageID.rawValue,
                date: SocialCalendar.start(of: collage.localDate, in: model.timeZone),
                source: SocialImages.source(collage.tilePath)
            )
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
            if let collage = collage(for: tile) {
                return Copy.wallsBrowseA11yCollage(date: SocialFormat.spokenDate(SocialCalendar.start(of: collage.localDate, in: model.timeZone), timeZone: model.timeZone))
            }
            guard let post = post(for: tile) else { return "" }
            let label = SocialA11y.tile(date: post.post.visibleAt, name: model.profiles[post.post.authorID]?.socialFirstName ?? "", timeZone: model.timeZone)
            return SocialA11y.withBatch(SocialA11y.withVideo(label, media: post.media), isBatch: tile.isBatch)
        }
    }

    private func select(_ tile: WeekStripTile) {
        switch tile.kind {
        case .add:
            SocialNav.openCamera(groupID: model.groupID.rawValue)
        case .photo:
            if let collage = collage(for: tile) {
                // collage.view of that day (Retro's recap preview), as from the walls.
                SocialNav.presentRoute(.capture(.collage(groupID: model.groupID.rawValue, invitationID: collage.invitationID.rawValue)))
            } else if let post = post(for: tile) {
                open(week, post.id)
            }
        case .emptyDay, .placeholder:
            break
        }
    }

    private func post(for tile: WeekStripTile) -> PostWithMedia? {
        posts.first { "photo-" + $0.id.rawValue == tile.id }
    }

    private static let collagePrefix = "collage-" // provenance-ok: tile identity, not shown

    private func collage(for tile: WeekStripTile) -> GroupCollage? {
        week.collages.first { "photo-" + Self.collagePrefix + $0.collageID.rawValue == tile.id }
    }
}

// MARK: - Calendar (jump to a date)

/// `week.history.layout.calendar` — BeReal's Memories calendar mechanics (help.bereal.com 7531349180829: only the days
/// with something open) in Retro's components: a page sheet (C-29) with the sheet header ("Memories", close circle),
/// then the months newest first — the month title (`sectionLabel`, a button to the month's newest week) over a
/// seven-column grid, Monday first; a day with something is its number (`pill`) on a `color.global.control` circle of
/// `size.global.pillHeight` (C-06 fill) and opens its week; other days are tertiary numbers. No count anywhere.
struct HistoryCalendarSheet: View {
    let months: [HistoryCalendarMonth]
    let timeZone: TimeZone
    let onSelect: (LocalDate) -> Void
    let onClose: () -> Void

    /// Days in a week: the grid's columns.
    private static let columns = 7 // provenance-ok: days in a week (calendar grid)

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: Copy.weekHistoryCalendarTitle, closeAccessibilityLabel: Copy.weekHistoryCalendarA11yClose, onClose: onClose)
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Sizes.globalSectionGap) {
                    ForEach(months) { month in
                        monthSection(month)
                    }
                }
                .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
                .padding(.vertical, Tokens.Sizes.globalSectionHeaderToContent)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .dsSheetBackground()
        .accessibilityIdentifier("week.history.calendar") // provenance-ok: accessibility identifier for UI tests
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 0), count: Self.columns)
    }

    private func monthSection(_ month: HistoryCalendarMonth) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Sizes.globalSectionHeaderToContent) {
            Button {
                onSelect(month.newestWeek)
            } label: {
                Text(SocialFormat.monthTitle(month.month, timeZone: timeZone))
                    .dsTextStyle(TextRole.sectionLabel)
                    .foregroundStyle(Tokens.Colors.globalTextPrimary)
                    .frame(minHeight: Tokens.Sizes.globalMinTouchTargetIos, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isHeader)
            LazyVGrid(columns: gridColumns, spacing: 0) {
                ForEach(Array(SocialFormat.weekdayInitials().enumerated()), id: \.offset) { _, initial in
                    Text(initial)
                        .dsTextStyle(TextRole.meta)
                        .foregroundStyle(Tokens.Colors.globalTextSecondary)
                        .accessibilityHidden(true)
                }
                ForEach(0..<month.leadingBlanks, id: \.self) { _ in
                    Color.clear
                        .frame(minHeight: Tokens.Sizes.globalMinTouchTargetIos)
                        .accessibilityHidden(true)
                }
                ForEach(month.days, id: \.self) { day in
                    dayCell(day, active: month.active.contains(day))
                }
            }
        }
    }

    @ViewBuilder
    private func dayCell(_ day: LocalDate, active: Bool) -> some View {
        let number = Text(day.day.formatted())
        if active {
            Button {
                onSelect(SocialCalendar.weekStart(containing: SocialCalendar.start(of: day, in: timeZone), in: timeZone))
            } label: {
                number
                    .dsTextStyle(TextRole.pill)
                    .foregroundStyle(Tokens.Colors.globalTextPrimary)
                    .frame(width: Tokens.Sizes.globalPillHeight, height: Tokens.Sizes.globalPillHeight)
                    .background(Tokens.Colors.globalControl, in: Circle())
                    .frame(maxWidth: .infinity, minHeight: Tokens.Sizes.globalMinTouchTargetIos)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(SocialFormat.spokenFullDate(day, timeZone: timeZone)))
        } else {
            number
                .dsTextStyle(TextRole.listSubtitle)
                .foregroundStyle(Tokens.Colors.globalTextTertiary)
                .frame(maxWidth: .infinity, minHeight: Tokens.Sizes.globalMinTouchTargetIos)
                .accessibilityLabel(Text(SocialA11y.emptyDay(SocialCalendar.start(of: day, in: timeZone), timeZone: timeZone)))
        }
    }
}
