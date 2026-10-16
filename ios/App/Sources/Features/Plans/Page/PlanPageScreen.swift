// Surface: plans.page — one plan: details, answers, who's coming, album. Visual reference: Retro's album detail as used
// by albums.view / groups.screen (references/auto/retro/press/tc-2024-04-journals-1.webp phone 3, TC-J1: cover with its
// shadow, serif name centred, grey meta line, a row of C-06 capsules, sections, a 3-column grid); mechanics Apple
// Invites' event page (references/auto/apple-invites/store/apple-invites-store-04.png, -05.png, -07.png: order, guest
// sections; canceled = crossed-out name) and Partiful (references/auto/partiful/store/partiful-store-01.png: Going ·
// Maybe · Can't Go, guests see Going and Maybe). Composition of C-02, C-01 glyph, cover, C-06, C-16, C-20, C-23, C-14,
// C-21 (design/surfaces/plans.page.md; MERGE PL-1 … PL-8).
import AppData
import AppModels
import DesignSystem
import SwiftUI
import UIKit

/// `AppRoute.plans(.page(planID:groupID:))`.
@MainActor
struct PlanPageScreen: View {
    let planID: String
    let groupID: String?

    var body: some View {
        PlanPageView(model: PlanPageModel(planID: PlanID(planID), services: .shared))
    }
}

struct PlanPageView: View {
    @State private var model: PlanPageModel
    @State private var editing: Plan?
    @State private var confirmingCancel = false
    @State private var peopleOpen = false
    @State private var viewerContext: PhotoViewerContext?
    @Environment(AccountDependencies.self) private var dependencies: AccountDependencies?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @ScaledMetric private var titleSize: CGFloat

    init(model: PlanPageModel) {
        _model = State(initialValue: model)
        _titleSize = ScaledMetric(wrappedValue: TextRole.headerTitle.size, relativeTo: TextRole.headerTitle.relativeTo)
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                switch model.phase {
                case .loaded:
                    content(width: proxy.size.width)
                case .loading:
                    loading
                case .notFound:
                    centred(height: proxy.size.height) {
                        EmptyStateView(title: Copy.plansPageNotFoundTitle, detail: Copy.plansPageNotFoundDetail)
                            .accessibilityIdentifier("plans.page.notFound")
                    }
                case .error:
                    centred(height: proxy.size.height) { errorBlock }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .refreshable { await model.refresh() }
        }
        .background(Tokens.Colors.globalBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task(id: PlansServices.shared.revision) { await model.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await model.refresh() } }
        }
        .onChange(of: model.answerFailureCount) { _, _ in
            dependencies?.toasts.show(Copy.plansPageErrorAnswer)
        }
        .dsHaptic(Tokens.Haptics.globalSelect, trigger: model.selectionCount)
        .alert(
            Text(Copy.plansPageCancelTitle(title: model.plan?.title ?? "")),
            isPresented: $confirmingCancel
        ) {
            Button(Copy.plansPageCancelKeep, role: .cancel) {}
            Button(Copy.plansPageCancelConfirm, role: .destructive) {
                Task { await model.cancel() }
            }
        } message: {
            Text(Copy.plansPageCancelMessage)
        }
        .sheet(item: $editing) { plan in
            PlanCreateView(model: PlanCreateModel(groupID: plan.groupID, editing: plan, services: .shared)) { saved in
                model.edited(saved)
            }
            .modifier(PlanPresentedContent(dependencies: dependencies))
        }
        .sheet(isPresented: $peopleOpen) {
            PlanPeopleSheet(model: model)
                .modifier(PlanPresentedContent(dependencies: dependencies))
        }
        .socialPhotoViewer($viewerContext)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plans.page")
    }

    // MARK: Layout

    /// Header row, cover (when the plan has one), title, meta lines, the answer row, made by + note, who's coming, the
    /// album — each placed by the spec's gaps (the `groups.screen` album-detail metrics).
    private func content(width: CGFloat) -> some View {
        let cap = TextMetrics(style: TextRole.headerTitle, size: titleSize).capHeight
        let rowTop = Tokens.Sizes.globalTitleTop - cap / 2 - Tokens.Sizes.globalHeaderButton / 2
        let headerLine = Tokens.Sizes.globalTitleToContent + cap / 2 + Tokens.Sizes.globalHeaderButton / 2
        let hasCover = model.plan?.coverPath != nil
        return MetricStack(alignment: .center) {
            headerRow
                .metricGap(max(0, rowTop), from: .top, to: .top)
            if hasCover {
                cover
                    .metricGap(headerLine, from: .top, to: .top)
                title
                    .metricGap(Tokens.Sizes.groupsScreenSizeCoverToTitle, from: .bottom, to: .capTop)
            } else {
                title
                    .metricGap(headerLine, from: .top, to: .capTop)
            }
            meta
                .metricGap(Tokens.Sizes.groupsScreenSizeTitleToMeta, from: .lastBaseline, to: .top)
            if model.showsAnswerRow {
                answerRow
                    .metricGap(Tokens.Sizes.groupsScreenSizeMetaToActions, from: .bottom, to: .top)
            }
            madeBy
                .metricGap(Tokens.Sizes.globalSectionGap, from: .bottom, to: .top)
            ForEach(listKinds, id: \.self) { kind in
                listBlock(kind, width: width)
                    .metricGap(Tokens.Sizes.globalSectionGap, from: .bottom, to: .top)
            }
            if !model.albumPhotos.isEmpty {
                album
                    .metricGap(Tokens.Sizes.globalSectionGap, from: .bottom, to: .top)
            }
        }
        .padding(.bottom, Tokens.Sizes.globalSectionGap)
        .dsTransition(.opacity)
    }

    /// Loading: the header and, when a cover is expected, its `color.global.control` placeholder; nothing else until
    /// loaded (C-28), then the content fades in (`duration.global.fade`).
    private var loading: some View {
        VStack(spacing: 0) {
            headerRow
        }
        .frame(maxWidth: .infinity)
    }

    private func centred<Content: View>(height: CGFloat, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            headerRow
            Spacer(minLength: 0)
            content()
            Spacer(minLength: 0)
        }
        .frame(minHeight: height)
    }

    /// C-27 error variant: one tappable line (tap = retry); offline: `plans.page.offline`.
    private var errorBlock: some View {
        Button {
            Task { await model.retry() }
        } label: {
            EmptyStateView(title: model.isOfflineFailure ? Copy.plansPageOffline : Copy.plansPageErrorTitle)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("plans.page.error")
    }

    // MARK: Header

    /// C-02 back at `size.global.backInset`; trailing C-01 glyph `icon.global.more` (maker and admins) → native menu.
    private var headerRow: some View {
        HStack(spacing: 0) {
            FormBackButton(accessibilityLabel: Copy.plansPageBackAccessibilityLabel, identifier: "plans.page.back") {
                dismiss()
            }
            Spacer(minLength: 0)
            if model.showsMenu, let plan = model.plan {
                HeaderIconMenu(icon: Tokens.Icons.globalMore, accessibilityLabel: Copy.plansPageMoreAccessibilityLabel) {
                    if plan.isCanceled {
                        Button(Copy.plansPageMenuRestore) { Task { await model.restore() } }
                    } else {
                        Button(Copy.plansPageMenuEdit) { editing = plan }
                        Button(Copy.plansPageMenuCancel, role: .destructive) { confirmingCancel = true }
                    }
                }
                .disabled(model.isWorking || model.isOffline)
                .padding(.trailing, max(0, Tokens.Sizes.globalHeaderInset - (Tokens.Sizes.globalHeaderButton - Tokens.Sizes.globalIcon) / 2))
                .accessibilityIdentifier("plans.page.more")
            }
        }
        .frame(height: Tokens.Sizes.globalHeaderButton)
        .frame(maxWidth: .infinity)
    }

    // MARK: Cover, title, meta

    private var cover: some View {
        GroupCover(
            source: model.plan?.coverPath.map { PhotoSource.storage($0) },
            width: Tokens.Sizes.groupsScreenSizeCoverWidth,
            height: Tokens.Sizes.groupsScreenSizeCoverHeight,
            showsGroupGlyph: false
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(Copy.plansPageCoverAccessibilityLabel(title: model.plan?.title ?? "")))
        .accessibilityAddTraits(.isImage)
        .accessibilityIdentifier("plans.page.cover")
    }

    /// `font.global.display` at `displayMedium`, centred, up to 3 lines; canceled: struck through (the platform text
    /// attribute) in `color.global.textSecondary`.
    private var title: some View {
        Text(model.plan?.title ?? "")
            .strikethrough(model.isCanceled)
            .dsTextRole(TextRole.displayTitle)
            .foregroundStyle(model.isCanceled ? Tokens.Colors.globalTextSecondary : Tokens.Colors.globalTextPrimary)
            .multilineTextAlignment(.center)
            .lineLimit(Self.titleLines)
            .accessibilityAddTraits(.isHeader)
            .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
            .accessibilityIdentifier("plans.page.title")
    }

    /// plans.page item 3: "up to 3 lines".
    static let titleLines = 3 // provenance-ok: line count named by the spec

    /// Two centred lines (`listSubtitle`, `color.global.textSecondary`): the date and time (or "Canceled"), the place;
    /// read as one element.
    private var meta: some View {
        VStack(spacing: 0) {
            Text(model.whenLine)
            if let place = model.plan?.place, !model.isCanceled {
                Text(place)
            }
        }
        .dsTextStyle(TextRole.listSubtitle)
        .foregroundStyle(Tokens.Colors.globalTextSecondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("plans.page.meta")
    }

    // MARK: Answer row

    /// Three C-06 capsules of equal widths, `size.global.pillGap` apart, inside `size.global.screenMargin`: Going ·
    /// Maybe · Can't go. The member's answer is primary, the others outline; the fill cross-fades
    /// (`duration.global.crossfade`). One group "Your answer"; the selected one carries the selected trait and a "Clear
    /// answer" action. Offline: disabled.
    private var answerRow: some View {
        CapsuleRow {
            ForEach(PlanAnswerKind.choices, id: \.self) { answer in
                let isSelected = model.myAnswer == answer
                Button {
                    Task { await model.select(answer) }
                } label: {
                    CapsuleLabel(title: Self.label(answer), style: isSelected ? .primary : .outline, fillsWidth: true, isEnabled: !model.isOffline)
                }
                .buttonStyle(.plain)
                .disabled(model.isOffline)
                .accessibilityLabel(Text(Self.label(answer)))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityActions {
                    if isSelected {
                        Button(Copy.plansPageAnswerClear) { Task { await model.select(answer) } }
                    }
                }
                .accessibilityIdentifier("plans.page.answer.\(answer.rawValue)")
            }
        }
        .dsAnimation(ComponentMotion.crossfade, value: model.myAnswer)
        .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(Copy.plansPageAnswerGroupLabel))
        .accessibilityIdentifier("plans.page.answers")
    }

    static func label(_ answer: PlanAnswerKind) -> String {
        switch answer {
        case .going: return Copy.plansPageAnswerGoing
        case .maybe: return Copy.plansPageAnswerMaybe
        case .cantGo, .unknown: return Copy.plansPageAnswerCantGo
        }
    }

    // MARK: Made by + note

    /// C-16 people row with the maker's avatar (`size.global.avatarPicker`) and "Made by {name}" (`listTitle`); the
    /// note under it (`body`, `color.global.textPrimary`, full text). No crown or badge.
    @ViewBuilder
    private var madeBy: some View {
        VStack(alignment: .leading) {
            if let maker = model.maker {
                PeopleRow(name: Copy.plansPageMadeBy(name: maker.firstName), avatar: maker.avatarPath.map { PhotoSource.storage($0) })
                    .accessibilityIdentifier("plans.page.madeBy")
            }
            if let note = model.plan?.note {
                Text(note)
                    .dsTextStyle(TextRole.body)
                    .foregroundStyle(Tokens.Colors.globalTextPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
                    .accessibilityIdentifier("plans.page.note")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Who's coming

    /// Going, then Maybe — only the lists with people (never "0 going", never "no one yet").
    private var listKinds: [PlanAnswerKind] {
        [PlanAnswerKind.going, .maybe].filter { !model.people($0).isEmpty }
    }

    /// The block's label: "Going" / "Maybe"; after the plan's day the Going list reads in the past — that word
    /// (`plans.page.went`) is BLOCKED, so release builds leave the label out (the names stay).
    private func listLabel(_ kind: PlanAnswerKind) -> String? {
        if kind == .maybe { return Copy.plansPageMaybe }
        guard model.isPast else { return Copy.plansPageGoing }
        #if DEBUG
        return BlockedCopy.plansPageWent
        #else
        return nil
        #endif
    }

    /// C-20 label (`sectionLabel`, no number) with the chevron when the list continues in the sheet, then
    /// `size.global.sectionHeaderToContent` below the C-23 stack (`size.global.avatarSmall`, oldest answer first) and the
    /// first names joined by the platform list formatter (`listSubtitle`, grey). One button → the people sheet.
    private func listBlock(_ kind: PlanAnswerKind, width: CGFloat) -> some View {
        let people = model.people(kind)
        let names = PlanFormats.names(people.map(\.firstName))
        let stackWidth = width - 2 * Tokens.Sizes.globalScreenMargin
        let visible = AvatarStackLayout.visibleCount(
            count: people.count, maxWidth: stackWidth, diameter: Tokens.Sizes.globalAvatarSmall, overlap: Tokens.Sizes.globalAvatarStackOverlap
        )
        let continues = visible < people.count || !model.people(.cantGo).isEmpty
        let label = listLabel(kind)
        return Button {
            peopleOpen = true
        } label: {
            VStack(alignment: .leading, spacing: Tokens.Sizes.globalSectionHeaderToContent) {
                if let label {
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text(label)
                            .dsTextStyle(TextRole.sectionLabel)
                            .foregroundStyle(Tokens.Colors.globalTextPrimary)
                        Spacer(minLength: 0)
                        if continues {
                            Glyph(Tokens.Icons.globalChevron, relativeTo: TextRole.sectionLabel.relativeTo)
                                .foregroundStyle(Tokens.Colors.globalTextSecondary)
                        }
                    }
                }
                AvatarStack(paths: people.map(\.avatarPath), maxWidth: stackWidth)
                Text(names)
                    .dsTextStyle(TextRole.listSubtitle)
                    .foregroundStyle(Tokens.Colors.globalTextSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text([label, names].compactMap { $0 }.joined(separator: ": "))) // provenance-ok: joins copy and data ("Going: Ana, Ben, and Chloe")
        .accessibilityAddTraits(.isButton)
        .dsAnimation(ComponentMotion.fade, value: people.map(\.id))
        .accessibilityIdentifier("plans.page.\(kind.rawValue)")
    }

    // MARK: Album

    /// After the plan's day: C-20 label "Photos" over the first rows of a C-21 3-column grid (at most 3 rows); a cell
    /// opens photo.viewer in album order. The label's target (`albums.view`) needs an album row the server does not
    /// make (MERGE "Problems found"), so it carries no chevron.
    private var album: some View {
        let photos = model.albumPhotos
        return VStack(alignment: .leading, spacing: Tokens.Sizes.globalSectionHeaderToContent) {
            SectionHeader(title: Copy.plansPageAlbum)
            GroupPhotoGrid(
                cells: photos.map { GroupPhotoCell(id: $0.id.rawValue, post: $0, label: "") },
                columns: PlanPageModel.albumColumns,
                onSelect: { cell in
                    guard let post = cell.post else { return }
                    viewerContext = PhotoViewerContext(postIDs: model.photos.map(\.id), start: post.id, groupID: post.post.groupID)
                }
            ) { _ in
                EmptyView()
            }
        }
        .accessibilityIdentifier("plans.page.album")
    }
}

/// The who's coming sheet (C-29 page sheet, `plans.page.people.title`): C-14 sections Going, Maybe and — for its own
/// member and the maker only, as RLS returns them — Can't go, of C-16 rows (avatar `size.global.avatarPicker`, first
/// name `listTitle`), not tappable. No counts in the headers.
struct PlanPeopleSheet: View {
    let model: PlanPageModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: Copy.plansPagePeopleTitle, closeAccessibilityLabel: Copy.plansCreateCloseAccessibilityLabel) {
                dismiss()
            }
            SettingsList {
                section(.going, header: Copy.plansPageGoing)
                section(.maybe, header: Copy.plansPageMaybe)
                section(.cantGo, header: Copy.plansPagePeopleCantGo)
            }
        }
        .background(Tokens.Colors.globalBackground.ignoresSafeArea())
        .presentationDetents([.large])
        .dsSheetBackground()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plans.people")
    }

    @ViewBuilder
    private func section(_ kind: PlanAnswerKind, header: String) -> some View {
        let people = model.people(kind)
        if !people.isEmpty {
            SettingsGroup(header: header, rows: people.map { person in
                SettingsCustomRow {
                    HStack {
                        AvatarView(path: person.avatarPath, diameter: Tokens.Sizes.globalAvatarPicker)
                        Text(person.firstName)
                            .dsTextStyle(TextRole.listTitle)
                            .foregroundStyle(Tokens.Colors.globalTextPrimary)
                        Spacer(minLength: 0)
                    }
                }
                .accessibilityElement(children: .combine)
                .asSettingsRow()
            })
        }
    }
}

/// What a sheet presented from a plan screen gets: the account dependencies, the storage URL resolver and the toast host.
struct PlanPresentedContent: ViewModifier {
    let dependencies: AccountDependencies?

    func body(content: Content) -> some View {
        if let dependencies {
            content
                .environment(dependencies)
                .environment(\.storageURLResolver, dependencies.storageURLResolver)
                .toastHost(dependencies.toasts)
        } else {
            content
        }
    }
}
