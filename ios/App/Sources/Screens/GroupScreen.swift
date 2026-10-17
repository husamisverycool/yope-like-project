// Surface: groups.screen — the group: cover, name, members, actions, this week's strip, the members' weeks and the
// group's memories, earlier photos by day. Visual reference: Retro album detail
// (references/auto/retro/press/tc-2024-04-journals-1.webp phone 3, TC-J1: book cover with its shadow, serif title, meta
// line, capsules, dated sections, 3-column grid), Retro's home week strip and friend cards
// (references/auto/retro/store/retro-store-01.png, ST-01; retro-store-02.png, ST-02;
// references/auto/retro/lazyweb/retro-lazyweb-20251020-week43-dark.png, H43; …-20260528-week22-dark-a.png, H22) and the
// friend-card pager (references/auto/retro/store/editorial/retro-appstore-story-1840659619-albums.png, ED-A)
// (design/surfaces/groups.screen.md; MERGE RA-9, RA-10).
import AppData
import AppModels
import DesignSystem
import SwiftUI
import UIKit

/// `AppRoute.group(id:)`.
struct GroupScreen: View {
    let groupID: String
    @Environment(AccountDependencies.self) private var dependencies

    var body: some View {
        GroupFeedView(model: GroupFeedModel(groupID: GroupID(groupID), data: dependencies.data), donatesShareTarget: true)
    }
}

struct GroupFeedView: View {
    @State private var model: GroupFeedModel
    @State private var blockTarget: BlockTarget?
    @State private var reportTarget: ReportTarget?
    /// The developing tile's state (camera.overnight B), made when the screen first loads.
    @State private var developingTile: DevelopingTileModel?
    /// The birthday request rows' and the plans block's models: their days order the two (`GroupEntryOrder`, MERGE FV-1).
    @State private var birthdayEntry: BirthdayRequestsEntryModel
    @State private var planEntry: PlanRowModel
    /// share.in: opening the group makes it one of the share sheet's suggestions (`ShareTargetDonations`; off in snapshots).
    private let donatesShareTarget: Bool
    @Environment(AccountDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @ScaledMetric private var titleSize: CGFloat
    @ScaledMetric private var sectionLabelSize: CGFloat

    init(model: GroupFeedModel, donatesShareTarget: Bool = false) {
        _model = State(initialValue: model)
        self.donatesShareTarget = donatesShareTarget
        _birthdayEntry = State(initialValue: BirthdayRequestsEntryModel(groupID: model.groupID, dependencies: .current))
        _planEntry = State(initialValue: PlanRowModel(groupID: model.groupID, services: .shared))
        _titleSize = ScaledMetric(wrappedValue: TextRole.headerTitle.size, relativeTo: TextRole.headerTitle.relativeTo)
        _sectionLabelSize = ScaledMetric(wrappedValue: TextRole.sectionLabel.size, relativeTo: TextRole.sectionLabel.relativeTo)
    }

    /// The earlier grid's columns (groups.screen Structure 9: "a 3-column grid", TC-J1; no token of its own).
    static let gridColumns = 3 // provenance-ok: column count named by the spec (C-21 album grid)

    private var groupID: String { model.groupID.rawValue }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                if model.phase == .removed {
                    removed(height: proxy.size.height)
                } else {
                    content(width: proxy.size.width)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .refreshable {
                await model.refresh()
                await developingTile?.refresh()
            }
        }
        .background(Tokens.Colors.globalBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task { await model.load() }
        .task { await followDeveloping() }
        .task(id: model.group?.name) {
            guard donatesShareTarget, let group = model.group else { return }
            await ShareTargetDonations.donate([ShareTargetDonations.Group(id: group.id.rawValue, name: group.name)])
        }
        .task(id: PlansServices.shared.revision) { await developingTile?.refresh() }
        .onDisappear { model.stop() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task {
                    await model.refresh()
                    await developingTile?.refresh()
                }
            }
        }
        .onChange(of: model.insertedCount) { _, _ in
            UIAccessibility.post(notification: .layoutChanged, argument: nil)
        }
        .blockConfirmation(target: $blockTarget, toasts: dependencies.toasts) { target in
            try await dependencies.data.block(userID: UserID(target.userID))
        } onBlocked: { target in
            Task { await model.blocked(UserID(target.userID)) }
        }
        .reportFlow(target: $reportTarget, dependencies: dependencies)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("groups.screen")
    }

    // MARK: Layout

    /// Header row, cover, name, members, actions, the birthday row, the plan row, this week (with the developing tile),
    /// the members' weeks, the week's question and memories, earlier photos — each placed by the spec's measured gaps
    /// (TC-J1) and the C-20 / C-17 / C-18 metrics.
    private func content(width: CGFloat) -> some View {
        let cap = TextMetrics(style: TextRole.headerTitle, size: titleSize).capHeight
        let rowTop = Tokens.Sizes.globalTitleTop - cap / 2 - Tokens.Sizes.globalHeaderButton / 2
        let showsWeek = model.phase == .loaded || model.phase == .created || model.phase == .empty || model.phase == .loading
        return MetricStack(alignment: .center) {
            headerRow
                .metricGap(max(0, rowTop), from: .top, to: .top)
            GroupCover(
                source: model.group?.coverPath.map { PhotoSource.storage($0) },
                width: Tokens.Sizes.groupsScreenSizeCoverWidth,
                height: Tokens.Sizes.groupsScreenSizeCoverHeight,
                showsGroupGlyph: model.group != nil
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(Copy.groupsScreenCoverAccessibilityLabel(groupName: model.group?.name ?? "")))
            .accessibilityAddTraits(.isImage)
            .metricGap(Tokens.Sizes.globalTitleToContent + cap / 2 + Tokens.Sizes.globalHeaderButton / 2, from: .top, to: .top)
            Text(model.group?.name ?? "")
                .dsTextRole(TextRole.displayTitle)
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
                .metricGap(Tokens.Sizes.groupsScreenSizeCoverToTitle, from: .bottom, to: .capTop)
            switch model.phase {
            case .offline:
                EmptyStateView(title: Copy.groupsScreenOfflineTitle, detail: Copy.groupsScreenOfflineDetail)
                    .metricGap(Tokens.Sizes.globalSectionGap, from: .lastBaseline, to: .top)
            default:
                memberStack(width: width)
                    .metricGap(Tokens.Sizes.groupsScreenSizeTitleToMeta, from: .lastBaseline, to: .top)
                actions
                    .metricGap(Tokens.Sizes.groupsScreenSizeMetaToActions, from: .bottom, to: .top)
            }
            if model.phase == .error {
                errorLine
                    .metricGap(Tokens.Sizes.globalSectionGap, from: .bottom, to: .top)
            }
            if showsWeek {
                datedEntries
                    .metricGap(0, from: .bottom, to: .top)
                weekHeader
                    .metricGap(Tokens.Sizes.globalSectionGap, from: .bottom, to: .capTop)
                weekStrip
                    .metricGap(Tokens.Sizes.globalSectionHeaderToContent, from: .lastBaseline, to: .top)
                weekBlock
                    .metricGap(Tokens.Sizes.globalSectionGap, from: .bottom, to: .top)
                cardsPager
                    .metricGap(0, from: .bottom, to: .top)
                earlier
                    .metricGap(Tokens.Sizes.globalSectionGap - capTopOffset, from: .bottom, to: .top)
            }
        }
        .padding(.bottom, Tokens.Sizes.globalSectionGap)
    }

    /// From the top of a C-20 header's frame to its cap top at the current Dynamic Type size.
    private var capTopOffset: CGFloat {
        TextMetrics(style: TextRole.sectionLabel, size: sectionLabelSize).capTopOffset
    }

    // MARK: Header row

    /// C-02 without a title: the back chevron at `size.global.backInset`; the trailing glyphs with C-01 metrics (albums →
    /// albums.list, chat → chat.thread; Retro's home header pair, H22), the row centred where C-01 centres its glyphs (the
    /// cap middle of a title at `size.global.titleTop`).
    private var headerRow: some View {
        HStack(spacing: 0) {
            FormBackButton(accessibilityLabel: Copy.groupsScreenBackAccessibilityLabel, identifier: "groups.screen.back") {
                dismiss()
            }
            Spacer(minLength: 0)
            if model.phase != .removed {
                HStack(spacing: Tokens.Sizes.globalHeaderIconPitch - Tokens.Sizes.globalHeaderButton) {
                    // search.photos in this group (owner decision 34; Yope's search glyph in its header).
                    HeaderIconButton(icon: Tokens.Icons.globalSearch, accessibilityLabel: Copy.searchPhotosOpen) {
                        push(.social(.search(groupID: groupID)))
                    }
                    .accessibilityIdentifier("groups.screen.search")
                    HeaderIconButton(icon: Tokens.Icons.globalAlbums, accessibilityLabel: Copy.groupsScreenAlbumsAccessibilityLabel) {
                        push(.social(.albums(groupID: groupID)))
                    }
                    .accessibilityIdentifier("groups.screen.albums")
                    HeaderIconButton(icon: Tokens.Icons.globalChats, accessibilityLabel: Copy.groupsScreenChat) {
                        push(.chat(groupID: groupID, messageID: nil))
                    }
                    .accessibilityIdentifier("groups.screen.chat")
                }
                .padding(.trailing, max(0, Tokens.Sizes.globalHeaderInset - (Tokens.Sizes.globalHeaderButton - Tokens.Sizes.globalIcon) / 2))
            }
        }
        .frame(height: Tokens.Sizes.globalHeaderButton)
        .frame(maxWidth: .infinity)
    }

    // MARK: Members and actions

    /// The members' avatars (C-23 stack, joining order, as many as fit inside the margins; no count) → groups.settings.
    private func memberStack(width: CGFloat) -> some View {
        Button {
            openSettings()
        } label: {
            AvatarStack(
                paths: model.membersInJoiningOrder.map { $0.profile?.avatarPath },
                maxWidth: width - 2 * Tokens.Sizes.globalScreenMargin
            )
            .frame(minHeight: Tokens.Sizes.globalAvatarSmall)
            .minimumHitArea(drawn: CGSize(width: Tokens.Sizes.globalMinTouchTargetIos, height: Tokens.Sizes.globalAvatarSmall))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(Copy.groupsScreenMembersAccessibilityLabel))
        .accessibilityIdentifier("groups.screen.members")
    }

    /// "Recaps" and "Invite" (C-06 outline, equal widths) and the icon-only settings capsule, `size.global.pillGap` apart
    /// inside `size.global.screenMargin` (C-19 action row).
    private var actions: some View {
        CapsuleRow {
            CapsuleButton(Copy.groupsScreenRecapAccessibilityLabel, style: .outline, fillsWidth: true) { openRecaps() }
                .accessibilityIdentifier("groups.screen.recaps")
            CapsuleButton(Copy.groupsScreenInvite, style: .outline, fillsWidth: true) { openInvite() }
                .accessibilityIdentifier("groups.screen.invite")
            CapsuleButton(icon: Tokens.Icons.globalSettings, accessibilityLabel: Copy.groupsScreenSettingsAccessibilityLabel, style: .outline) {
                openSettings()
            }
            .accessibilityIdentifier("groups.screen.settings")
        }
        .disabled(model.group == nil)
        .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
    }

    /// Error (nothing cached): Retro's one tappable line under the actions (tap = retry).
    private var errorLine: some View {
        Button {
            Task { await model.retry() }
        } label: {
            Text(Copy.groupsScreenErrorTitle)
                .dsTextStyle(TextRole.body)
                .foregroundStyle(Tokens.Colors.globalTextSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: Tokens.Sizes.globalMinTouchTargetIos)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
        .accessibilityIdentifier("groups.screen.error")
    }

    // MARK: Birthday request (memory group's entry)

    /// One C-14 single row per open birthday request for you in this group, `size.global.sectionGap` under the capsules:
    /// the honoree's avatar (C-16 `size.global.avatarPicker`), `birthday.request.title` (`listTitle`) and
    /// `birthday.request.due` (`listSubtitle`, grey), `icon.global.chevron` → birthday.request (the memory group supplies
    /// the copy and the tap).
    private var birthdayRequests: some View {
        BirthdayRequestsEntry(groupID: groupID, model: birthdayEntry) { content in
            SettingsGroup(rows: [
                SettingsCustomRow {
                    HStack {
                        AvatarView(path: content.avatarPath, diameter: Tokens.Sizes.globalAvatarPicker)
                        VStack(alignment: .leading) {
                            Text(content.title)
                                .dsTextStyle(TextRole.listTitle)
                                .foregroundStyle(Tokens.Colors.globalTextPrimary)
                            Text(content.subtitle)
                                .dsTextStyle(TextRole.listSubtitle)
                                .foregroundStyle(Tokens.Colors.globalTextSecondary)
                        }
                        .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                        Glyph(Tokens.Icons.globalChevron, relativeTo: TextRole.body.relativeTo)
                            .foregroundStyle(Tokens.Colors.globalTextSecondary)
                    }
                }
                .asSettingsRow(),
            ])
            .padding(.top, Tokens.Sizes.globalSectionGap)
            .accessibilityElement(children: .combine)
        }
    }

    /// The birthday request rows and the plans block, soonest first by their days; the `ForEach` keeps each one's
    /// identity when the order changes.
    private var datedEntries: some View {
        let days: [GroupEntrySlot: GroupEntryDay] = [
            .birthday: GroupEntryDay(birthdayEntry.entryDay),
            .plans: GroupEntryDay(planEntry.entryDay),
        ]
        return VStack(spacing: 0) {
            // The open daily invitation is now, so it leads.
            openInvitationRow
            ForEach(GroupEntryOrder.order(days), id: \.self) { slot in
                switch slot {
                case .birthday: birthdayRequests
                case .plans: planRow
                }
            }
        }
    }

    // MARK: Open daily invitation (capture group's entry)

    /// While the group's daily invitation is open (`open_invitations`): one C-14 single row `size.global.sectionGap` under
    /// the capsules, drawn as the birthday request row — the C-16 `size.global.avatarPicker` circle with
    /// `icon.global.camera` (the avatar placeholder), `notifications.push.dailyInvitation.body` (`listTitle`) over the
    /// countdown (`daily.capture.countdown`, `listSubtitle`, grey, monospaced digits), `icon.global.chevron` → daily.capture
    /// for this invitation, the same answer the notification opens. At `closes_at` the row goes; nothing says "late" and
    /// nothing follows (tenet 5).
    @ViewBuilder
    private var openInvitationRow: some View {
        if let invitation = model.openInvitation {
            TimelineView(.periodic(from: .now, by: 1)) { context in // provenance-ok: one tick per second (MM:SS countdown)
                if let seconds = invitation.remainingSeconds(at: context.date) {
                    Button {
                        dependencies.router.modal = .camera(groupID: groupID, invitationID: invitation.id.rawValue)
                    } label: {
                        SettingsGroup(rows: [
                            SettingsCustomRow {
                                HStack {
                                    AvatarView(source: nil, diameter: Tokens.Sizes.globalAvatarPicker, placeholderIcon: Tokens.Icons.globalCamera)
                                    VStack(alignment: .leading) {
                                        Text(Copy.notificationsPushDailyInvitationBody)
                                            .dsTextStyle(TextRole.listTitle)
                                            .foregroundStyle(Tokens.Colors.globalTextPrimary)
                                        InvitationCountdownText(seconds: seconds)
                                    }
                                    .multilineTextAlignment(.leading)
                                    Spacer(minLength: 0)
                                    Glyph(Tokens.Icons.globalChevron, relativeTo: TextRole.body.relativeTo)
                                        .foregroundStyle(Tokens.Colors.globalTextSecondary)
                                }
                            }
                            .asSettingsRow(),
                        ])
                    }
                    .buttonStyle(.plain)
                    .padding(.top, Tokens.Sizes.globalSectionGap)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(Copy.notificationsPushDailyInvitationBody))
                    .accessibilityValue(Text(CaptureFormat.spokenCountdown(remainingSeconds: seconds)))
                    .accessibilityAddTraits([.isButton, .updatesFrequently])
                    .accessibilityIdentifier("groups.screen.invitation")
                } else {
                    Color.clear
                        .frame(height: 0)
                        .onAppear { model.invitationClosed() }
                }
            }
        }
    }

    // MARK: Plan row (plans group's entry)

    /// The plans block (`PlanRowEntry`): the "Plans" label → plans.list while the group has plans, then the next plan or
    /// "Make a Plan" (one C-14 row), `size.global.sectionGap` under the capsules or the birthday rows; beside a birthday
    /// row in date order (`datedEntries`).
    private var planRow: some View {
        PlanRowEntry(groupID: groupID, model: planEntry)
    }

    // MARK: This week

    /// C-20 header as one button: "Week {number}" (text role `sectionLabel`) + the week's range (`listSubtitle`, grey;
    /// none while the week has no photos) and, in place of C-20's '•••' (Retro's week menu was not captured),
    /// `icon.global.chevron` in `color.global.textSecondary` at the right margin → week.history.
    private var weekHeader: some View {
        let title = Copy.groupsScreenWeekTitle(number: String(model.weekNumber))
        let range = model.thisWeekPosts.isEmpty && model.thisWeekCollages.isEmpty ? nil : GroupDates.weekRange(model.currentWeek, calendar: model.calendar)
        return Button {
            if let route = CrossGroupRoutes.weekHistory(groupID: groupID) { push(route) }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(title)
                    .dsTextStyle(TextRole.sectionLabel)
                    .foregroundStyle(Tokens.Colors.globalTextPrimary)
                if let range {
                    Text(" " + range) // provenance-ok: the space between the two runs of C-20
                        .dsTextStyle(TextRole.listSubtitle)
                        .foregroundStyle(Tokens.Colors.globalTextSecondary)
                }
                Spacer(minLength: 0)
                Glyph(Tokens.Icons.globalChevron, relativeTo: TextRole.sectionLabel.relativeTo)
                    .foregroundStyle(Tokens.Colors.globalTextSecondary)
                    .alignmentGuide(.firstTextBaseline) { glyph in glyph[VerticalAlignment.center] + capHeightHalf }
            }
            .lineLimit(1)
            .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text([title, range].compactMap { $0 }.joined(separator: " "))) // provenance-ok: joins copy runs
        .accessibilityHint(Text(Copy.groupsScreenWeeksAccessibilityLabel))
        .accessibilityAddTraits([.isHeader, .isButton])
        .accessibilityIdentifier("groups.screen.week")
        .capHeight(of: TextRole.sectionLabel)
    }

    /// Half the section label's cap height: the chevron centres on the header's cap middle.
    private var capHeightHalf: CGFloat {
        TextMetrics(style: TextRole.sectionLabel, size: sectionLabelSize).capHeight / 2
    }

    /// C-17: this week's photos oldest → newest with the add tile last; a week without photos: the add tile first, then an
    /// empty-day tile per remaining day. Loading: placeholder tiles.
    private var weekStrip: some View {
        let tiles: [WeekStripTile]
        if model.phase == .loading {
            tiles = WeekStripLayout.placeholders(count: WeekStripLayout.days(ofWeekContaining: Date(), calendar: model.calendar).count)
        } else {
            // photos posted together: one tile, the batch's first photo with the batch marker (`layout.global.photoBatch`)
            let photos = model.thisWeekRuns.compactMap { run -> WeekStripPhoto? in
                guard let post = run.first else { return nil }
                return WeekStripPhoto(
                    id: post.id.rawValue, date: post.post.visibleAt,
                    source: post.media?.imagePath(for: .thumb).map { PhotoSource.storage($0) }, isBatch: run.count > 1
                )
            } + model.thisWeekCollages.map { collage in
                // the day's same-moment collage once composed, on its day (migration 0033)
                WeekStripPhoto(id: Self.collageTilePrefix + collage.collageID.rawValue, date: collageDay(collage), source: collage.tilePath.map { PhotoSource.storage($0) })
            }
            tiles = WeekStripLayout.tiles(days: model.remainingDaysOfWeek, photos: photos, canAdd: true)
        }
        return GroupWeekStrip(
            tiles: tiles,
            accessibilityLabel: tileLabel,
            onSelect: selectTile,
            menuPost: { tile in post(for: tile) },
            developing: model.phase == .loading ? nil : developingLabel
        ) { post in
            photoMenu(post)
        }
    }

    /// The developing tile's label while the group has photos developing (camera.overnight B), else nil.
    private var developingLabel: String? {
        guard let developingTile, developingTile.isDeveloping else { return nil }
        return developingTile.accessibilityLabel
    }

    /// `group_developing` now and after each of the group's post changes (a reveal inserts the developed photos).
    private func followDeveloping() async {
        let tile = developingTile ?? DevelopingTileModel(groupID: model.groupID, services: .shared)
        developingTile = tile
        await tile.refresh()
        await tile.follow()
    }

    private func tileLabel(_ tile: WeekStripTile) -> String {
        switch tile.kind {
        case .add:
            return Copy.groupsScreenWeekAddAccessibilityLabel
        case .emptyDay:
            let date = tile.date ?? Date()
            return Copy.weekHistoryA11yEmptyDay(weekday: GroupDates.weekday(date, calendar: model.calendar), date: GroupDates.monthDay(date, calendar: model.calendar))
        case .photo:
            if let collage = collage(for: tile) {
                return Copy.wallsBrowseA11yCollage(date: GroupDates.monthDay(collageDay(collage), calendar: model.calendar))
            }
            guard let post = post(for: tile) else { return "" }
            return SocialA11y.withBatch(photoLabel(post), isBatch: tile.isBatch)
        case .placeholder:
            return ""
        }
    }

    private static let collageTilePrefix = "collage-" // provenance-ok: tile identity, not shown

    /// The start of the collage's day in the group's time zone.
    private func collageDay(_ collage: GroupCollage) -> Date {
        SocialCalendar.start(of: collage.localDate, in: model.calendar.timeZone)
    }

    private func collage(for tile: WeekStripTile) -> GroupCollage? {
        guard case .photo = tile.kind else { return nil }
        return model.thisWeekCollages.first { "photo-" + Self.collageTilePrefix + $0.collageID.rawValue == tile.id }
    }

    private func post(for tile: WeekStripTile) -> PostWithMedia? {
        guard case .photo = tile.kind else { return nil }
        return model.thisWeekPosts.first { "photo-" + $0.id.rawValue == tile.id }
    }

    private func selectTile(_ tile: WeekStripTile) {
        switch tile.kind {
        case .add:
            dependencies.router.modal = .camera(groupID: groupID, invitationID: nil)
        case .photo:
            if let collage = collage(for: tile) {
                // collage.view (a full-screen cover, `PresentedRoute`)
                push(.capture(.collage(groupID: groupID, invitationID: collage.invitationID.rawValue)))
            } else if let post = post(for: tile) {
                open(post)
            }
        case .emptyDay, .placeholder:
            break
        }
    }

    /// Under an empty strip: the created block (C-27: `icon.global.calendar`, title, explanation, C-07 → groups.invite) or
    /// the empty block (C-07 → camera.capture). A quiet week shows none.
    @ViewBuilder
    private var weekBlock: some View {
        switch model.phase {
        case .created:
            EmptyStateView(
                icon: Tokens.Icons.globalCalendar,
                title: Copy.groupsScreenCreatedTitle,
                detail: Copy.groupsScreenCreatedDetail,
                action: EmptyStateView.Action(GroupKindCopy.createdInvite(model.group?.kind), icon: Tokens.Icons.globalAdd) { openInvite() }
            )
            .accessibilityIdentifier("groups.screen.created")
        case .empty:
            EmptyStateView(
                icon: Tokens.Icons.globalCalendar,
                title: Copy.groupsScreenEmptyTitle,
                detail: Copy.groupsScreenEmptyDetail,
                action: EmptyStateView.Action(Copy.groupsScreenEmptyButton, icon: Tokens.Icons.globalAdd) {
                    dependencies.router.modal = .camera(groupID: groupID, invitationID: nil)
                }
            )
            .accessibilityIdentifier("groups.screen.empty")
        default:
            EmptyView()
        }
    }

    // MARK: Members' weeks and memories

    /// Retro's home feed pager: one C-18 friend card per member who shared this week (newest first), then the week's
    /// question card, then the memory feed cards (birthday videos, on this day, the year story) while they have content. Each card
    /// carries the `size.global.sectionGap` above it, so the row takes no space when there is nothing to show.
    private var cardsPager: some View {
        FriendCardPager {
            ForEach(model.memberWeeks) { week in
                FriendCard(
                    name: week.member.profile?.firstName ?? "",
                    avatar: week.member.profile?.avatarPath.map { PhotoSource.storage($0) },
                    photo: week.newest.media?.imagePath(for: .display).map { PhotoSource.storage($0) },
                    accessibilityLabel: photoLabel(week.newest)
                ) {
                    open(week.newest)
                }
                .contextMenu { photoMenu(week.newest) }
                .padding(.top, Tokens.Sizes.globalSectionGap)
                .dsTransition(.opacity)
            }
            // question.weekly A: the week's question is the first feed card, after the friend cards.
            QuestionCardEntry(groupID: groupID)
            // birthday.tribute entry: the birthday videos the viewer may watch (the honoree's own, a contributor's),
            // newest first, before the older memories (MERGE FV-3).
            TributeEntry(groupID: groupID) { content in
                MemoryFeedCard(
                    glyph: content.icon ?? Tokens.Icons.globalVideo,
                    title: content.title,
                    line: content.subtitle,
                    action: content.buttonTitle ?? Copy.birthdayTributeEntryButton,
                    photo: content.photoPath.map { PhotoSource.storage($0) }
                )
                .padding(.top, Tokens.Sizes.globalSectionGap)
            }
            OnThisDayEntry(groupID: groupID) { content in
                MemoryFeedCard(
                    glyph: content.icon ?? Tokens.Icons.globalRewind,
                    title: content.title,
                    line: content.subtitle,
                    action: content.buttonTitle ?? Copy.onthisdayEntryButton,
                    photo: content.photoPath.map { PhotoSource.storage($0) }
                )
                .padding(.top, Tokens.Sizes.globalSectionGap)
            }
            YearStoryEntry(groupID: groupID) { content in
                MemoryFeedCard(
                    glyph: content.icon ?? Tokens.Icons.globalRecap,
                    title: content.title,
                    line: content.subtitle,
                    action: content.buttonTitle ?? Copy.yearStoryEntryButton,
                    photo: content.photoPath.map { PhotoSource.storage($0) }
                )
                .padding(.top, Tokens.Sizes.globalSectionGap)
            }
        }
        .dsAnimation(ComponentMotion.fade, value: model.memberWeeks.map(\.id))
        .accessibilityIdentifier("groups.screen.cards")
    }

    // MARK: Earlier

    /// Photos from before this week, newest first: C-20 dated sections (the day in the long date format, no '•••') over a
    /// 3-column grid of square cells (C-21), `size.global.sectionGap` between sections; the next page loads when the last
    /// section appears. Loading: one row of placeholder cells.
    @ViewBuilder
    private var earlier: some View {
        if model.phase == .loading {
            GroupPhotoGrid(cells: (0..<Self.gridColumns).map { GroupPhotoCell(id: "placeholder-\($0)", post: nil, label: "") }, columns: Self.gridColumns, onSelect: { _ in }) { _ in
                EmptyView()
            }
            .accessibilityHidden(true)
        } else {
            WeekSectionList {
                ForEach(model.earlierSections) { section in
                    WeekStripSection {
                        SectionHeader(title: GroupDates.longDate(section.day, calendar: model.calendar))
                    } content: {
                        GroupPhotoGrid(
                            cells: section.posts.map { GroupPhotoCell(id: $0.id.rawValue, post: $0, label: photoLabel($0)) },
                            columns: Self.gridColumns,
                            onSelect: { cell in if let post = cell.post { open(post) } }
                        ) { cell in
                            if let post = cell.post { photoMenu(post) }
                        }
                    }
                    .onAppear {
                        if section.id == model.earlierSections.last?.id { Task { await model.loadMore() } }
                    }
                }
            }
            .dsAnimation(ComponentMotion.crossfade, value: model.earlierSections.map(\.id))
        }
    }

    // MARK: Removed

    /// `not_group_member`: the header row (back only) and the C-27 block centred.
    private func removed(height: CGFloat) -> some View {
        VStack(spacing: 0) {
            headerRow
            Spacer(minLength: 0)
            EmptyStateView(title: Copy.groupsScreenRemovedTitle, detail: Copy.groupsScreenRemovedDetail)
            Spacer(minLength: 0)
        }
        .frame(minHeight: height)
        .accessibilityIdentifier("groups.screen.removed")
    }

    // MARK: Photos

    /// `groups.screen.photo.accessibilityLabel`: "{date}, photo by {first_name}" (the weekday, month and day).
    private func photoLabel(_ post: PostWithMedia) -> String {
        Copy.groupsScreenPhotoAccessibilityLabel(
            date: GroupDates.weekdayMonthDay(post.post.visibleAt, calendar: model.calendar),
            firstName: model.profile(of: post.post.authorID)?.firstName ?? ""
        )
    }

    /// The long-press menu (`groups.screen.layout.menu`): others' photos "Report Post" and "Block {first_name}"
    /// (destructive); own photos none (the viewer has the full menu).
    @ViewBuilder
    private func photoMenu(_ post: PostWithMedia) -> some View {
        if post.post.authorID != model.me {
            let firstName = model.profile(of: post.post.authorID)?.firstName ?? ""
            let person = BlockTarget(userID: post.post.authorID.rawValue, firstName: firstName)
            Button(Copy.groupsScreenPhotoMenuReport, role: .destructive) {
                reportTarget = ReportTarget(
                    kind: .post, id: post.id.rawValue, person: person, groupID: groupID, groupName: model.group?.name
                )
            }
            Button(Copy.groupsScreenPhotoMenuBlock(firstName: firstName), role: .destructive) {
                blockTarget = person
            }
        }
    }

    private func open(_ post: PostWithMedia) {
        push(.post(groupID: groupID, postID: post.id.rawValue))
    }

    // MARK: Navigation

    private func push(_ route: AppRoute) {
        dependencies.router.path.append(route)
    }

    /// The latest recap, or week.history when there is none.
    /// "Recaps": the recap list (`week.recap` A, a page sheet — week.recap "Navigation in": the recaps entry → list), or
    /// `week.history` while the group has no recap yet (groups.screen Elements).
    private func openRecaps() {
        if model.latestRecapID != nil {
            dependencies.router.modal = .social(.recaps(groupID: groupID))
        } else if let route = CrossGroupRoutes.weekHistory(groupID: groupID) {
            push(route)
        }
    }

    private func openInvite() {
        dependencies.router.modal = .account(.groupInvite(groupID: groupID))
    }

    /// groups.settings (a sheet: the shell presents the route, `PresentedRoute`).
    private func openSettings() {
        push(.account(.groupSettings(groupID: groupID)))
    }
}

/// Dates on the group screen, in the group's time zone and the person's locale.
enum GroupDates {
    private static func formatter(_ template: String, calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter
    }

    /// The C-20 range of a week ("Jul 3 – 9" in the locale's interval format).
    static func weekRange(_ week: DateInterval?, calendar: Calendar) -> String? {
        guard let week else { return nil }
        let formatter = DateIntervalFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateTemplate = "MMMd" // provenance-ok: date template (abbreviated month and day, C-20 range)
        let lastDay = week.end.addingTimeInterval(-1)
        return formatter.string(from: week.start, to: lastDay)
    }

    /// The dated section header ("January 25, 2024": the locale's long date).
    static func longDate(_ date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    /// "Monday, June 26" for accessibility labels.
    static func weekdayMonthDay(_ date: Date, calendar: Calendar) -> String {
        formatter("EEEEMMMMd", calendar: calendar).string(from: date) // provenance-ok: date template
    }

    static func weekday(_ date: Date, calendar: Calendar) -> String {
        formatter("EEEE", calendar: calendar).string(from: date) // provenance-ok: date template
    }

    static func monthDay(_ date: Date, calendar: Calendar) -> String {
        formatter("MMMMd", calendar: calendar).string(from: date) // provenance-ok: date template
    }
}

/// C-17 week strip with a long-press menu on photo tiles (`groups.screen.layout.menu`) — a local variant of `WeekStrip`
/// (Components/WeekStrip.swift), which has no per-tile menu (reported as a component gap). Same anatomy: `DayTile`s
/// `size.global.stripGap` apart from the leading `size.global.screenMargin`, only the strip's outer corners rounded
/// (`radius.global.card`), tiles inserting with `duration.global.stripInsert` and fading in with `duration.global.fade`.
struct GroupWeekStrip<Menu: View>: View {
    let tiles: [WeekStripTile]
    let accessibilityLabel: (WeekStripTile) -> String
    let onSelect: (WeekStripTile) -> Void
    let menuPost: (WeekStripTile) -> PostWithMedia?
    /// camera.overnight B: while the group has photos developing, the label of the one developing tile, which sits just
    /// before the add tile (the newest position); nil: no tile.
    var developing: String? = nil
    @ViewBuilder let menu: (PostWithMedia) -> Menu

    /// A strip position: a day tile, or the developing tile.
    private enum Item: Identifiable {
        case tile(WeekStripTile)
        case developing(String)

        var id: String {
            switch self {
            case let .tile(tile): return tile.id
            case .developing: return "developing" // provenance-ok: list identity, not user-facing
            }
        }
    }

    private var items: [Item] {
        var items = tiles.map(Item.tile)
        guard let developing else { return items }
        let addIndex = tiles.firstIndex { $0.kind == .add } ?? tiles.endIndex
        items.insert(.developing(developing), at: addIndex)
        return items
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Tokens.Sizes.globalStripGap) {
                ForEach(items) { item in
                    Group {
                        switch item {
                        case let .tile(tile):
                            tileView(tile)
                        case let .developing(label):
                            DevelopingTile(accessibilityLabel: label)
                        }
                    }
                    .dsTransition(AnyTransition.opacity.animation(ComponentMotion.fade.animation))
                }
            }
            .clipShape(DSShape.rounded(Tokens.Radii.globalCard))
            .padding(.leading, Tokens.Sizes.globalScreenMargin)
            .dsAnimation(ComponentMotion.stripInsert, value: items.map(\.id))
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func tileView(_ tile: WeekStripTile) -> some View {
        if tile.kind == .placeholder {
            DayTile(tile: tile)
                .accessibilityHidden(true)
        } else {
            Button {
                onSelect(tile)
            } label: {
                DayTile(tile: tile)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(accessibilityLabel(tile)))
            .contextMenu {
                if let post = menuPost(tile) { menu(post) }
            }
        }
    }
}

/// One cell of the dated grid.
struct GroupPhotoCell: Identifiable, Hashable {
    let id: String
    let post: PostWithMedia?
    let label: String
}

/// C-21 album grid with a long-press menu per cell — a local variant of `PhotoGrid` (Components/PhotoGrid.swift), which
/// has no per-cell menu (reported as a component gap). Same anatomy: square cells (`radius.global.photo`),
/// `size.global.stripGap` apart in both directions, full width inside `size.global.screenMargin`; cells without a
/// photo are `color.global.control` (C-28 placeholder).
struct GroupPhotoGrid<Menu: View>: View {
    let cells: [GroupPhotoCell]
    let columns: Int
    let onSelect: (GroupPhotoCell) -> Void
    @ViewBuilder let menu: (GroupPhotoCell) -> Menu

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: Tokens.Sizes.globalStripGap), count: max(1, columns)),
            spacing: Tokens.Sizes.globalStripGap
        ) {
            ForEach(cells) { cell in
                Button {
                    onSelect(cell)
                } label: {
                    PhotoView(source: cell.post?.media?.imagePath(for: .thumb).map { PhotoSource.storage($0) })
                        .aspectRatio(1, contentMode: .fit) // provenance-ok: square cells (C-21)
                        .clipShape(Rectangle())
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(cell.label))
                .contextMenu { menu(cell) }
            }
        }
        .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
        .accessibilityElement(children: .contain)
    }
}

/// A memory feed card in the members' pager (Retro's Rewind / "Year in Photos" feed cards; composition of C-18, C-09 and
/// the display role): C-18 geometry — the header line shows the feature's glyph in the `size.global.avatarList` box in
/// place of an avatar, the card `size.global.friendCardWidth` × `.friendCardHeight`, `radius.global.card` — on
/// `color.global.backgroundDeep` with the bottom scrim (`layout.global.photoScrim`); at the bottom inside
/// `size.global.screenMargin`: the title (text role `displaySmall`, `color.global.textOnMedia`), the line (`listSubtitle`,
/// `color.global.textOnMedia`) and the C-09 light pill with the action. The memory entry draws it inside its button, so
/// it is read as one element. Without a photo (`MemoryEntryContent.photoPath` nil) the card is the media black.
struct MemoryFeedCard: View {
    let glyph: String
    let title: String
    let line: String
    let action: String
    var photo: PhotoSource?

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Sizes.globalCardHeaderGap) {
            Glyph(glyph, size: Tokens.Sizes.globalAvatarList)
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
            ZStack(alignment: .bottomLeading) {
                Tokens.Colors.globalBackgroundDeep
                PhotoView(source: photo)
                    .opacity(photo == nil ? 0 : 1)
                PhotoScrim()
                VStack(alignment: .leading) {
                    Text(title)
                        .dsTextStyle(TextRole.displaySmall)
                    Text(line)
                        .dsTextStyle(TextRole.listSubtitle)
                    LightPillLabel(action)
                }
                .foregroundStyle(Tokens.Colors.globalTextOnMedia)
                .multilineTextAlignment(.leading)
                .padding(Tokens.Sizes.globalScreenMargin)
            }
            .frame(width: Tokens.Sizes.globalFriendCardWidth, height: Tokens.Sizes.globalFriendCardHeight)
            .clipShape(DSShape.rounded(Tokens.Radii.globalCard))
        }
        .frame(width: Tokens.Sizes.globalFriendCardWidth, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text([title, line, action].joined(separator: ", "))) // provenance-ok: joins copy strings
        .accessibilityAddTraits(.isButton)
    }
}
