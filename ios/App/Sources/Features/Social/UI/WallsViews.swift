// Surfaces: walls.mine, walls.member, walls.browse — Retro's profile (serif name, 64-pt avatar, icon capsule, week
// sections of strips) and its Friends grid. Specs: design/surfaces/walls.mine.md, walls.member.md, walls.browse.md
// (RS-14 … RS-16). References: references/auto/retro/store/retro-store-02.png (profile header, week sections — primary),
// references/auto/retro/press/engadget-2026-08-profile.jpg and jeddacp-2024-05-home-profile-journals.png (current week),
// references/auto/retro/lazyweb/retro-lazyweb-20251020-week43-dark.png (empty week), references/auto/retro/press/
// tc-2023-07-retro-1b.webp (Friends grid, "•••" capsule).
import AppData
import AppModels
import DesignSystem
import SwiftUI

// MARK: - Profile header (C-19 adapted, `walls.mine.layout.header`)

/// The display name in the display serif (text role `headerTitle`, one line, tail truncation), its first baseline
/// `size.global.titleTop` below the top safe area — after the C-02 back chevron on a pushed wall; the avatar
/// (`size.global.avatarProfile`) at the trailing margin, centred on the name's cap middle; then, its top
/// `walls.mine.dimension.nameToActions` below the name's baseline, one C-06 outline icon capsule at the trailing margin.
/// No real-name line and no info rows. (The shared `ProfileHeader` spaces its parts with the platform's stack spacing
/// and centres the avatar on the name block — reported as a component gap — so the wall places them from the tokens.)
struct WallProfileHeader<Action: View>: View {
    let name: String
    let avatar: PhotoSource?
    /// Pushed (walls.member): the back chevron leads the name line.
    var onBack: (() -> Void)?
    /// What VoiceOver reads for the name (walls.member: `walls.member.a11y.wall`); the name itself when nil.
    var nameAccessibilityLabel: String?
    @ViewBuilder let action: () -> Action

    var body: some View {
        MetricStack {
            HStack(alignment: .capMiddle, spacing: Tokens.Sizes.globalHeaderGap) {
                if let onBack {
                    Button(action: onBack) {
                        Image(systemName: Tokens.Icons.globalBack)
                            .font(Tokens.Fonts.globalFamily.font(size: Tokens.Sizes.globalIcon, weight: Font.Weight.regular))
                            .foregroundStyle(Tokens.Colors.globalTextPrimary)
                            .minimumHitArea(drawn: CGSize(width: Tokens.Sizes.globalIcon, height: Tokens.Sizes.globalIcon))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(Copy.chatThreadA11yBack))
                }
                Text(name)
                    .dsTextRole(TextRole.headerTitle)
                    .foregroundStyle(Tokens.Colors.globalTextPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .accessibilityLabel(Text(nameAccessibilityLabel ?? name))
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: Tokens.Sizes.globalPillGap)
                AvatarView(source: avatar, diameter: Tokens.Sizes.globalAvatarProfile)
            }
            .capMiddleRow(TextRole.headerTitle)
            .padding(.leading, onBack == nil ? Tokens.Sizes.globalScreenMargin : Tokens.Sizes.globalBackInset)
            .padding(.trailing, Tokens.Sizes.globalScreenMargin)
            .metricGap(Tokens.Sizes.globalTitleTop, from: .top, to: .firstBaseline)
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                action()
            }
            .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
            .metricGap(Tokens.Sizes.wallsMineDimensionNameToActions, from: .lastBaseline, to: .top)
        }
    }
}

// MARK: - Week sections (`walls.mine.layout.weeks`)

/// The wall's weeks: C-20 header ("Week 27" + the range, no "•••") over a C-17 strip; the current week first (with
/// the add tile on my wall, then empty-day or placeholder tiles per `week.history.layout.currentWeek`), past weeks with
/// photos after it, newest first. The first header's cap top sits `walls.mine.dimension.actionsToWeeks` below the action
/// row; sections `size.global.sectionGap` apart (`WeekSectionList`).
struct WallWeekList: View {
    let model: WallModel
    let openPhoto: (PhotoViewerContext) -> Void

    var body: some View {
        let weeks = model.weeks
        WeekSectionList {
            ForEach(weeks) { week in
                WeekStripSection {
                    let number = SocialCalendar.weekNumber(of: week.weekStart, in: model.timeZone)
                    let showsRange = !(week.isCurrent && week.tiles.isEmpty)
                    SectionHeader(
                        title: Copy.weekHistoryHeaderTitle(weekNumber: String(number)),
                        detail: showsRange ? SocialFormat.weekRange(week.weekStart, timeZone: model.timeZone) : nil,
                        accessibilityLabel: SocialA11y.weekHeader(number: number, weekStart: week.weekStart, timeZone: model.timeZone, showsRange: showsRange)
                    )
                } content: {
                    strip(week)
                }
                .onAppear {
                    if week.id == weeks.last?.id { Task { await model.loadMore() } }
                }
            }
            if model.isLoadingMore {
                ProgressView()
                    .tint(Tokens.Colors.globalTextSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, max(0, Tokens.Sizes.wallsMineDimensionActionsToWeeks - SocialMetrics.capTopOffset(TextRole.sectionLabel)))
    }

    private var canAdd: Bool { model.owner == .me }

    private func strip(_ week: WallModel.Week) -> some View {
        let byID = Dictionary(uniqueKeysWithValues: week.tiles.map { ("photo-" + $0.id, $0) })
        return WeekStrip(
            tiles: WallTiles.tiles(for: week, model: model, canAdd: canAdd),
            accessibilityLabel: { tile in label(tile, byID[tile.id]) },
            onSelect: { tile in select(tile, byID[tile.id]) }
        )
    }

    private func label(_ tile: WeekStripTile, _ wallTile: WallModel.Tile?) -> String {
        switch tile.kind {
        case .add:
            return Copy.weekHistoryA11yAdd
        case .emptyDay, .placeholder:
            return tile.date.map { SocialA11y.emptyDay($0, timeZone: model.timeZone) } ?? ""
        case .photo:
            switch wallTile {
            case let .collage(collage)?:
                return Copy.wallsBrowseA11yCollage(date: SocialFormat.spokenDate(collage.createdAt, timeZone: model.timeZone))
            case let .post(post)?:
                if model.owner == .me { return Copy.photoViewerA11yPhotoMine(date: SocialFormat.spokenDate(post.post.createdAt, timeZone: model.timeZone)) }
                return SocialA11y.tile(date: post.post.createdAt, name: model.profile?.socialFirstName ?? "", timeZone: model.timeZone)
            case nil:
                return ""
            }
        }
    }

    private func select(_ tile: WeekStripTile, _ wallTile: WallModel.Tile?) {
        switch tile.kind {
        case .add:
            SocialNav.openCamera(groupID: nil)
        case .photo:
            switch wallTile {
            case let .post(post)?:
                openPhoto(PhotoViewerContext(postIDs: model.photoPostIDs, start: post.id, showsGroupName: true))
            case let .collage(collage)?:
                if let invitationID = collage.invitationID {
                    SocialNav.presentRoute(.capture(.collage(groupID: collage.groupID.rawValue, invitationID: invitationID.rawValue)))
                }
            case nil:
                break
            }
        case .emptyDay, .placeholder:
            break
        }
    }
}

/// The tiles of one week section (C-17 and `week.history.layout.currentWeek`).
enum WallTiles {
    /// Past weeks: their photo tiles. The current week: no photos → the add tile (when allowed) and seven dated
    /// empty-day tiles; with photos → the photo tiles, the add tile, then one blank placeholder per day without a photo.
    @MainActor
    static func tiles(for week: WallModel.Week, model: WallModel, canAdd: Bool) -> [WeekStripTile] {
        let photos = week.tiles.map { tile -> WeekStripPhoto in
            let path: String?
            switch tile {
            case let .post(post): path = post.media?.gridPath
            case let .collage(collage): path = collage.imagePath
            }
            return WeekStripPhoto(id: tile.id, date: tile.createdAt, source: SocialImages.source(path))
        }
        let days = SocialCalendar.days(of: week.weekStart).map { SocialCalendar.start(of: $0, in: model.timeZone) }
        return currentWeekTiles(
            days: days, photos: photos, isCurrent: week.isCurrent, canAdd: canAdd,
            emptyDays: model.emptyDays(of: week).map { SocialCalendar.start(of: $0, in: model.timeZone) }
        )
    }

    static func currentWeekTiles(days: [Date], photos: [WeekStripPhoto], isCurrent: Bool, canAdd: Bool, emptyDays: [Date]) -> [WeekStripTile] {
        guard isCurrent else { return WeekStripLayout.tiles(days: days, photos: photos, canAdd: false) }
        let tiles = WeekStripLayout.tiles(days: days, photos: photos, canAdd: canAdd)
        guard !photos.isEmpty else { return tiles }
        let placeholders = emptyDays.map { day in
            WeekStripTile(id: "rest-" + String(Int(day.timeIntervalSinceReferenceDate)), kind: .placeholder, date: day)
        }
        return tiles + placeholders
    }
}

/// One tappable line at the margin (text role `body`, `color.global.textSecondary`) — Retro's list-error line.
struct SocialErrorLine: View {
    let text: String
    let retry: () -> Void

    var body: some View {
        Button(action: retry) {
            Text(text)
                .dsTextStyle(TextRole.body)
                .foregroundStyle(Tokens.Colors.globalTextSecondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
    }
}

/// The wall's content under its header by state (the empty wall is laid out by the screen: the current week, then the
/// C-27 block centred in the space below it).
struct WallContent: View {
    let model: WallModel
    let openPhoto: (PhotoViewerContext) -> Void

    var body: some View {
        switch model.phase {
        case .loading:
            if model.showsLoading { loadingSection }
        case .ready, .empty:
            WallWeekList(model: model, openPhoto: openPhoto)
        case .failed, .offline:
            SocialErrorLine(text: Copy.wallsMineErrorTitle) { Task { await model.retry() } }
                .padding(.top, Tokens.Sizes.wallsMineDimensionActionsToWeeks)
        }
    }

    /// One section of seven placeholder tiles under a header without a range (C-28 for Retro's lists).
    private var loadingSection: some View {
        WeekStripSection {
            SectionHeader(title: Copy.weekHistoryHeaderTitle(weekNumber: String(model.currentWeekNumber)))
        } content: {
            WeekStrip(tiles: WeekStripLayout.placeholders(count: SocialCalendar.days(of: model.currentWeekStart).count), accessibilityLabel: { _ in "" })
        }
        .padding(.top, max(0, Tokens.Sizes.wallsMineDimensionActionsToWeeks - SocialMetrics.capTopOffset(TextRole.sectionLabel)))
        .accessibilityLabel(Text(Copy.weekHistoryA11yLoading))
        .socialAnnouncesLoading(true)
    }
}

/// A wall page: scrolling sections, or — for an empty wall — the current week with the C-27 block centred in the space
/// between the strip and the bottom (H43 / H22).
struct WallPage<Header: View>: View {
    let model: WallModel
    let openPhoto: (PhotoViewerContext) -> Void
    @ViewBuilder let header: () -> Header

    var body: some View {
        if model.phase == .empty {
            VStack(alignment: .leading, spacing: 0) {
                header()
                WallWeekList(model: model, openPhoto: openPhoto)
                Spacer(minLength: Tokens.Sizes.globalSectionGap)
                emptyBlock
                Spacer(minLength: Tokens.Sizes.globalSectionGap)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header()
                    WallContent(model: model, openPhoto: openPhoto)
                }
                .padding(.bottom, Tokens.Sizes.globalSectionGap)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    /// My wall: `icon.global.calendar`, "Welcome to Week {n}!", C-07 "Get this week started" (→ camera); someone's: the
    /// glyph, "Nothing to see here" and the detail, no action.
    @ViewBuilder
    private var emptyBlock: some View {
        if model.owner == .me {
            EmptyStateView(
                icon: Tokens.Icons.globalCalendar,
                title: Copy.wallsMineEmptyTitle(weekNumber: String(model.currentWeekNumber)),
                action: .init(Copy.wallsMineEmptyAction, icon: Tokens.Icons.globalAdd) { SocialNav.openCamera(groupID: nil) }
            )
        } else {
            EmptyStateView(
                icon: Tokens.Icons.globalCalendar,
                title: Copy.wallsMemberEmptyTitle,
                detail: Copy.wallsMemberEmptyDetail(name: model.profile?.socialFirstName ?? "")
            )
        }
    }
}

// MARK: - walls.mine

/// My wall: my name, avatar, the gear capsule (→ settings.root), my weeks; the profile tab's root (tab bar below).
struct WallMineScreen: View {
    @State private var model: WallModel
    @State private var viewer: PhotoViewerContext?
    @Environment(\.dismiss) private var dismiss

    init(model: WallModel? = nil) {
        _model = State(initialValue: model ?? WallModel(owner: .me, data: SocialServices.shared.data))
    }

    var body: some View {
        let isTabRoot = SocialTabRoot.isRoot(.wallMine)
        WallPage(model: model, openPhoto: { viewer = $0 }) {
            WallProfileHeader(
                name: model.displayName ?? "",
                avatar: SocialImages.source(model.profile?.avatarPath),
                onBack: isTabRoot ? nil : { dismiss() }
            ) {
                CapsuleButton(icon: Tokens.Icons.globalSettings, accessibilityLabel: Copy.wallsMineA11ySettings) {
                    SocialNav.push(.account(.settings))
                }
            }
        }
        .background(Tokens.Colors.globalBackground.ignoresSafeArea())
        .modifier(SocialTabBar(tab: .me, isTabRoot: isTabRoot))
        .socialHidesNavigationBar()
        .task {
            if model.phase == .loading { await model.load() }
            await model.run()
        }
        .socialPhotoViewer($viewer)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("walls.mine") // provenance-ok: accessibility identifier for UI tests
    }
}

// MARK: - walls.member

/// A member's wall: the back chevron and their name on one line, their avatar, the "•••" capsule (Report Profile /
/// Block Profile, both red), the photos they posted in groups we share (no add tile).
struct WallMemberScreen: View {
    let userID: String
    @State private var model: WallModel
    @State private var viewer: PhotoViewerContext?
    @State private var blockTarget: BlockTarget?
    @State private var toasts = ToastCenter()
    @Environment(\.dismiss) private var dismiss

    init(userID: String, model: WallModel? = nil) {
        self.userID = userID
        _model = State(initialValue: model ?? WallModel(owner: .member(UserID(userID)), data: SocialServices.shared.data))
    }

    var body: some View {
        WallPage(model: model, openPhoto: { viewer = $0 }) {
            WallProfileHeader(
                name: model.displayName ?? "",
                avatar: SocialImages.source(model.profile?.avatarPath),
                onBack: { dismiss() },
                nameAccessibilityLabel: Copy.wallsMemberA11yWall(name: model.profile?.socialFirstName ?? "")
            ) {
                Menu {
                    Button(Copy.wallsMemberMenuReport, role: .destructive) {
                        SocialNav.report(ReportTarget(
                            kind: .user, id: userID, name: model.profile?.socialFirstName,
                            person: BlockTarget(userID: userID, firstName: model.profile?.socialFirstName ?? "")
                        ))
                    }
                    Button(Copy.wallsMemberMenuBlock, role: .destructive) {
                        blockTarget = BlockTarget(userID: userID, firstName: model.profile?.socialFirstName ?? "")
                    }
                } label: {
                    CapsuleLabel(icon: Tokens.Icons.globalMore)
                }
                .accessibilityLabel(Text(Copy.wallsMemberA11yMore))
            }
        }
        .background(Tokens.Colors.globalBackground.ignoresSafeArea())
        .socialHidesNavigationBar()
        .task {
            if model.phase == .loading { await model.load() }
            await model.run()
        }
        .toastHost(toasts)
        .blockConfirmation(
            target: $blockTarget,
            toasts: toasts,
            perform: { target in try await SocialServices.shared.data.block(userID: UserID(target.userID)) },
            onBlocked: { _ in model.blocked() }
        )
        .socialPhotoViewer($viewer)
        .accessibilityIdentifier("walls.member") // provenance-ok: accessibility identifier for UI tests
    }
}

// MARK: - walls.browse

/// Friends: the serif title (C-01; pushed and group-scoped: C-02), the C-12 search field `size.global.titleToContent`
/// below the title baseline, then `size.global.sectionGap` below it the people grid — three columns centred,
/// `walls.browse.dimension.columnPitch` apart, rows `.rowPitch` apart, avatars `size.global.avatarGrid`, the name
/// centred with its baseline `.nameBaseline` below the avatar (`listTitle`, one line). A tap opens the person's wall.
struct WallsBrowseScreen: View {
    let groupID: String?
    @State private var model: WallsBrowseModel
    @Environment(\.dismiss) private var dismiss

    init(groupID: String?, model: WallsBrowseModel? = nil) {
        self.groupID = groupID
        _model = State(initialValue: model ?? WallsBrowseModel(data: SocialServices.shared.data, groupID: groupID.map { GroupID($0) }))
    }

    var body: some View {
        let isTabRoot = SocialTabRoot.isRoot(.wallsBrowse(groupID: groupID))
        Group {
            if model.phase == .empty {
                VStack(alignment: .leading, spacing: 0) {
                    header(isTabRoot: isTabRoot)
                    Spacer(minLength: 0)
                    EmptyStateView(
                        icon: Tokens.Icons.globalGroup,
                        title: Copy.wallsBrowseEmptyTitle,
                        detail: Copy.wallsBrowseEmptyDetail,
                        action: .init(Copy.wallsBrowseEmptyAction) { SocialNav.present(.account(.groupCreate)) }
                    )
                    .frame(maxWidth: .infinity)
                    Spacer(minLength: 0)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        header(isTabRoot: isTabRoot)
                        content
                    }
                    .padding(.bottom, Tokens.Sizes.globalSectionGap)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Tokens.Colors.globalBackground.ignoresSafeArea())
        .modifier(SocialTabBar(tab: .walls, isTabRoot: isTabRoot))
        .socialHidesNavigationBar()
        .socialAnnouncesLoading(model.showsLoading)
        .task {
            if model.phase == .loading { await model.load() }
        }
        .accessibilityIdentifier("walls.browse") // provenance-ok: accessibility identifier for UI tests
    }

    @ViewBuilder
    private func header(isTabRoot: Bool) -> some View {
        if isTabRoot {
            ScreenHeader(title: Copy.wallsBrowseTitle)
        } else {
            PushedScreenHeader(title: Copy.wallsBrowseTitle, backAccessibilityLabel: Copy.chatThreadA11yBack) { dismiss() }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .loading:
            search
            if model.showsLoading {
                LoadingHUD()
                    .frame(maxWidth: .infinity)
                    .padding(.top, Tokens.Sizes.globalSectionGap)
            }
        case .empty:
            EmptyView()
        case .failed, .offline:
            SocialErrorLine(text: Copy.wallsBrowseErrorTitle) { Task { await model.retry() } }
        case .ready:
            search
            let people = model.visiblePeople
            if people.isEmpty {
                EmptyStateView(title: Copy.wallsBrowseSearchEmpty)
                    .frame(maxWidth: .infinity)
                    .padding(.top, Tokens.Sizes.globalSectionGap)
            } else {
                PeopleColumns(people: people)
                    .padding(.top, Tokens.Sizes.globalSectionGap)
            }
        }
    }

    private var search: some View {
        SearchField(Copy.wallsBrowseSearch, text: $model.search, accessibilityLabel: Copy.wallsBrowseSearch)
            .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
    }
}

/// The people grid with Retro's measured pitch (`walls.browse.layout.grid`). (The shared `PeopleGrid` shares the width
/// between flexible columns and uses platform row spacing — reported as a component gap.)
struct PeopleColumns: View {
    let people: [WallsBrowseModel.Person]

    private var columns: [GridItem] {
        let count = SocialTokenNumbers.count(of: "columns", in: Tokens.Layouts.WallsBrowseLayoutGrid.grid) ?? 1
        return Array(repeating: GridItem(.fixed(Tokens.Sizes.wallsBrowseDimensionColumnPitch), spacing: 0, alignment: .top), count: count)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(people) { person in
                Button {
                    SocialNav.push(.social(.wallMember(userID: person.id.rawValue)))
                } label: {
                    MetricStack(alignment: .center) {
                        AvatarView(source: SocialImages.source(person.profile?.avatarPath), diameter: Tokens.Sizes.globalAvatarGrid)
                        Text(person.name)
                            .dsTextStyle(TextRole.listTitle)
                            .foregroundStyle(Tokens.Colors.globalTextPrimary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: Tokens.Sizes.wallsBrowseDimensionColumnPitch)
                            .metricGap(Tokens.Sizes.wallsBrowseDimensionNameBaseline, from: .bottom, to: .firstBaseline)
                    }
                    .frame(width: Tokens.Sizes.wallsBrowseDimensionColumnPitch)
                    .frame(minHeight: Tokens.Sizes.wallsBrowseDimensionRowPitch, alignment: .top)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(Copy.wallsMemberA11yWall(name: person.profile?.socialFirstName ?? person.name)))
                .accessibilityAddTraits(.isButton)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Tab roots

/// walls.mine and walls.browse are the profile and Friends tabs (C-04; the account group's shell pushes them as the only
/// route on the groups stack).
@MainActor
enum SocialTabRoot {
    #if DEBUG
    /// Snapshot tests draw the walls as tab roots.
    static var treatsEveryWallAsRoot = false
    #endif

    static func isRoot(_ route: SocialRoute) -> Bool {
        #if DEBUG
        if treatsEveryWallAsRoot { return true }
        #endif
        let path = SocialNav.router.path
        return path.count == 1 && path.first == .social(route)
    }
}

/// The app's tab bar (C-04, `AppTabBar`) under a tab root (needs the account dependencies for the shell).
struct SocialTabBar: ViewModifier {
    let tab: AppTab
    let isTabRoot: Bool
    @Environment(AccountDependencies.self) private var account: AccountDependencies?

    func body(content: Content) -> some View {
        if isTabRoot, let account {
            content.safeAreaInset(edge: .bottom, spacing: 0) {
                AppTabBar(selected: tab) { selected in
                    ShellNavigation.select(selected, router: account.router, shell: account.shell)
                }
            }
        } else {
            content
        }
    }
}

// MARK: - The viewer over a social screen

/// The camera for a photo reply opens once the covering viewer has gone (two full-screen covers cannot overlap).
@MainActor
enum SocialPendingCamera {
    static var target: PhotoReplyHandoff.Target?
}

@MainActor
extension View {
    /// Presents `photo.viewer` full screen for `context`; a reply with a photo opens the camera after it closed.
    func socialPhotoViewer(_ context: Binding<PhotoViewerContext?>) -> some View {
        fullScreenCover(item: context, onDismiss: {
            guard let target = SocialPendingCamera.target else { return }
            SocialPendingCamera.target = nil
            SocialNav.router.presentCameraReplying(toPost: target.postID, groupID: target.groupID)
        }) { context in
            PhotoViewerView(context: context, presentation: .cover { SocialPendingCamera.target = $0 })
        }
    }
}
