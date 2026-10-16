// Surface: week.recap — Retro's recaps: "Create Recap" (close circle, title, month cards → our week cards) and the
// recap preview (blurred photo page, close circle, the recap card / full-bleed cover in a pager, page dots, the
// select-photos thumbnail and a white pill). Spec: design/surfaces/week.recap.md (RS-17 … RS-19).
// References: references/auto/retro/press/tc-2023-12-recaps.png (list cards, card and full-bleed styles),
// references/auto/retro/store/retro-store-04.png (2026 preview chrome, select-photos thumbnail),
// references/auto/retro/press/tc-2023-12-retro-header.png (card footer), references/auto/retro/web/retro.app-42b38811bebcd07d.css
// (note box). The preview is one definition in the product: capture's `RecapPreviewScreen` (chrome, RC-15) with
// memory's `RecapCard` / `RecapFooter` (pages, RM-8, L-4).
import AppData
import AppModels
import DesignSystem
import SwiftUI

// MARK: - Recap list (`week.recap.layout.list`)

/// Page sheet over the group (`SocialModal.recaps`): the leading close circle and the centred title "Recaps"; week
/// cards newest first, full width inside `size.global.screenMargin`, `size.global.cardGap` apart, starting
/// `size.global.titleToContent` below the header.
struct WeekRecapListScreen: View {
    @State private var model: WeekRecapListModel
    @State private var preview: RecapPreviewTarget?
    @Environment(\.dismiss) private var dismiss

    init(groupID: String) {
        self.init(model: WeekRecapListModel(groupID: GroupID(groupID), data: SocialServices.shared.data))
    }

    init(model: WeekRecapListModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        VStack(spacing: 0) {
            LeadingCloseSheetHeader(title: Copy.weekRecapListTitle, closeAccessibilityLabel: Copy.weekRecapA11yClose) { dismiss() }
                .padding(.top, Tokens.Sizes.globalScreenMargin)
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Tokens.Colors.globalBackground.ignoresSafeArea())
        .presentationDragIndicator(.visible)
        .dsSheetBackground()
        .socialAnnouncesLoading(model.showsLoading)
        .task {
            if model.phase == .loading { await model.load() }
            await model.run()
        }
        .fullScreenCover(item: $preview) { target in
            WeekRecapPreviewScreen(groupID: model.groupID.rawValue, recapID: target.recapID.rawValue, isPresentedModally: true)
        }
        .accessibilityIdentifier("week.recap.list") // provenance-ok: accessibility identifier for UI tests
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .loading:
            if model.showsLoading {
                cards {
                    ForEach(0..<2, id: \.self) { _ in // provenance-ok: week.recap loading state "two placeholder cards"
                        WeekCardShape { Tokens.Colors.globalControl }
                    }
                }
            }
        case .empty:
            VStack {
                Spacer(minLength: 0)
                EmptyStateView(
                    icon: Tokens.Icons.globalRecap,
                    title: Copy.weekRecapEmptyTitle,
                    detail: Copy.weekRecapEmptyDetail,
                    action: .init(Copy.weekRecapEmptyAction, icon: Tokens.Icons.globalAdd) {
                        dismiss()
                        SocialNav.openCamera(groupID: model.groupID.rawValue)
                    }
                )
                Spacer(minLength: 0)
            }
        case .failed, .offline:
            SocialErrorLine(text: Copy.weekRecapErrorTitle) { Task { await model.retry() } }
                .padding(.top, Tokens.Sizes.globalTitleToContent)
            if model.phase == .offline {
                Text(Copy.chatThreadOfflineDetail)
                    .dsTextStyle(TextRole.body)
                    .foregroundStyle(Tokens.Colors.globalTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
            }
            Spacer(minLength: 0)
        case .ready:
            cards {
                ForEach(model.recaps) { recap in
                    if recap.status == .ready {
                        Button { preview = RecapPreviewTarget(recapID: recap.id) } label: {
                            WeekCard(
                                cover: SocialImages.source(model.cover(of: recap)?.media?.displayImagePath),
                                weekNumber: model.weekNumber(of: recap),
                                range: SocialFormat.weekRange(recap.weekStart, timeZone: model.timeZone)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text(Copy.weekRecapA11yCard(
                            weekNumber: String(model.weekNumber(of: recap)),
                            dateRange: SocialFormat.spokenWeekRange(recap.weekStart, timeZone: model.timeZone)
                        )))
                        .accessibilityAddTraits(.isButton)
                    } else {
                        PendingWeekCard()
                    }
                }
            }
        }
    }

    private func cards<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ScrollView {
            LazyVStack(spacing: Tokens.Sizes.globalCardGap) {
                content()
            }
            .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
            .padding(.vertical, Tokens.Sizes.globalTitleToContent)
        }
    }
}

struct RecapPreviewTarget: Identifiable, Hashable {
    let recapID: RecapID
    var id: String { recapID.rawValue }
}

/// The week card's shape: full width, `week.recap.aspectRatio.weekCard`, corners `week.recap.radius.card` (continuous).
struct WeekCardShape<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        Color.clear
            .aspectRatio(Tokens.AspectRatios.weekRecapAspectRatioWeekCard, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay { content() }
            .clipShape(DSShape.rounded(Tokens.Radii.weekRecapRadiusCard))
            .contentShape(DSShape.rounded(Tokens.Radii.weekRecapRadiusCard))
    }
}

/// A ready recap (Retro's month card as a week card): the cover = the recap's first item (aspect fill); on it,
/// `week.recap.dimension.weekCardTextInset` from the leading edge and its cap top `.weekCardTextTop` from the top,
/// "Week {n}" in the display serif (`displayMedium`, `color.global.textOnMedia`) and, `.weekCardLinePitch` below its
/// baseline, the range (`listSubtitle`, `color.global.textOnMedia`); `icon.global.chevron` at the trailing top on the
/// serif line's cap middle. No scrim (Retro draws none on month cards).
struct WeekCard: View {
    let cover: PhotoSource?
    let weekNumber: Int
    let range: String

    var body: some View {
        WeekCardShape {
            ZStack(alignment: .topLeading) {
                PhotoView(source: cover)
                MetricStack {
                    HStack(alignment: .capMiddle) {
                        Text(Copy.photoViewerHeaderWeek(weekNumber: String(weekNumber)))
                            .dsTextRole(TextRole.displayMedium)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Glyph(Tokens.Icons.globalChevron)
                    }
                    .capMiddleRow(TextRole.displayMedium)
                    .metricGap(Tokens.Sizes.weekRecapDimensionWeekCardTextTop, from: .top, to: .capTop)
                    Text(range)
                        .dsTextStyle(TextRole.listSubtitle)
                        .lineLimit(1)
                        .metricGap(Tokens.Sizes.weekRecapDimensionWeekCardLinePitch, from: .firstBaseline, to: .firstBaseline)
                }
                .foregroundStyle(Tokens.Colors.globalTextOnMedia)
                .padding(.horizontal, Tokens.Sizes.weekRecapDimensionWeekCardTextInset)
            }
        }
    }
}

/// A recap still being made (`status = pending`): the card shape in `color.global.control` (C-17 placeholder fill) with
/// `week.recap.pending` centred (`body`, `color.global.textSecondary`).
struct PendingWeekCard: View {
    var body: some View {
        WeekCardShape {
            ZStack {
                Tokens.Colors.globalControl
                Text(Copy.weekRecapPending)
                    .dsTextStyle(TextRole.body)
                    .foregroundStyle(Tokens.Colors.globalTextSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Recap preview (`week.recap.layout.preview`)

/// One recap, full screen and dark in both appearances: capture's recap-preview chrome (`RecapPreviewScreen`,
/// `collage.view.layout.screen`) holding, on the blurred cover (C-34 `BlurredBackdrop`, L-5), memory's recap card
/// (page 1, with the note) and the full-bleed cover (page 2) in a pager; the close circle on the page; the dots below
/// it; bottom row: the select-photos thumbnail (→ `week.edit`) and the "Save as Album" pill (→ the album sheet with the
/// recap's photos).
struct WeekRecapPreviewScreen: View {
    @State private var model: WeekRecapModel
    /// True when presented as a full-screen cover (from the recap list): the cover then asks for light status-bar
    /// content (`.preferredColorScheme(.dark)`), as capture's `CollageView`.
    let isPresentedModally: Bool
    @State private var page = 0
    @State private var viewer: PhotoViewerContext?
    @State private var editing = false
    @State private var savingAlbum = false
    @State private var toasts = ToastCenter()
    @Environment(\.dismiss) private var dismiss

    init(groupID: String, recapID: String, isPresentedModally: Bool = false) {
        self.init(
            model: WeekRecapModel(groupID: GroupID(groupID), recapID: RecapID(recapID), data: SocialServices.shared.data),
            isPresentedModally: isPresentedModally
        )
    }

    init(model: WeekRecapModel, isPresentedModally: Bool = false) {
        _model = State(initialValue: model)
        self.isPresentedModally = isPresentedModally
    }

    private enum Page: Equatable {
        case card([PostWithMedia])
        case cover
    }

    /// Page 1 (the card) only when its grid fill is known (`week.recap.layout.gridFill`, BLOCKED); page 2 always.
    private var pages: [Page] {
        guard model.phase == .ready else { return [] }
        let card = SocialBlocked.recapCardItems(
            model.cardPosts,
            columns: Int(Tokens.Layouts.YearStoryRecapCard.columns),
            maxRows: Int(Tokens.Layouts.YearStoryRecapCard.maxRows)
        )
        return (card.map { [Page.card($0)] } ?? []) + [.cover]
    }

    var body: some View {
        let pages = pages
        RecapPreviewScreen(
            dots: pages.count > 1 ? RecapPreviewDots(
                count: pages.count,
                index: min(page, pages.count - 1),
                accessibilityValue: Copy.globalA11yPagePosition(position: String(min(page, pages.count - 1) + 1), count: String(pages.count))
            ) : nil,
            onSelectPage: { page = $0 }
        ) { _ in
            mediaPage(pages)
                .accessibilitySortPriority(3)
        } overlay: { geometry in
            RecapPreviewClose(geometry: geometry, accessibilityLabel: Copy.weekRecapA11yClose) { dismiss() }
                .accessibilitySortPriority(4)
                .accessibilityIdentifier("week.recap.close") // provenance-ok: accessibility identifier for UI tests
        } leading: {
            selectThumbnail
                .accessibilitySortPriority(2)
        } trailing: {
            if model.phase == .ready {
                RecapPill(Copy.weekRecapSaveAsAlbum, textRole: TextRole.pill) { savingAlbum = true }
                    .accessibilitySortPriority(1)
            }
        }
        .preferredColorScheme(isPresentedModally ? .dark : nil)
        .socialHidesNavigationBar()
        .task {
            if model.phase == .loading { await model.load() }
            await model.run()
        }
        .socialFeedback(model.signals.feedback)
        .toastHost(toasts)
        .socialPhotoViewer($viewer)
        .sheet(isPresented: $editing, onDismiss: { Task { await model.load() } }) {
            WeekEditView(
                model: WeekEditModel(groupID: model.groupID, mode: .recap(model.recapID), data: SocialServices.shared.data, seed: model.editSeed),
                toasts: toasts
            )
        }
        .sheet(isPresented: $savingAlbum) {
            WeekEditView(
                model: WeekEditModel(groupID: model.groupID, mode: .recapAlbum(model.recapID), data: SocialServices.shared.data, seed: model.editSeed),
                toasts: toasts
            )
        }
        .accessibilityIdentifier("week.recap") // provenance-ok: accessibility identifier for UI tests
    }

    // MARK: Pages

    /// The media page: the blurred cover (C-34 backdrop: σ `size.global.backdropBlur` under `color.global.backdropDim`)
    /// under the swiped pages once ready (native pager, its own dots hidden — the chrome draws C-31); the state centred
    /// in the frame otherwise.
    private func mediaPage(_ pages: [Page]) -> some View {
        ZStack {
            BlurredBackdrop(source: SocialImages.source(model.cover?.media?.displayImagePath))
            switch model.phase {
            case .loading:
                if model.showsLoading {
                    LoadingHUD()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            case .pending:
                centredLine(Copy.weekRecapPending)
            case .failed, .offline, .empty:
                Button { Task { await model.retry() } } label: { centredLine(Copy.weekRecapErrorTitle) }
                    .buttonStyle(.plain)
            case .ready:
                if pages.count > 1 {
                    TabView(selection: $page) {
                        ForEach(pages.indices, id: \.self) { index in
                            pageView(pages[index])
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .accessibilityIdentifier("week.recap.pages") // provenance-ok: accessibility identifier for UI tests
                } else if let only = pages.first {
                    pageView(only)
                        .accessibilityIdentifier("week.recap.pages") // provenance-ok: accessibility identifier for UI tests
                }
            }
        }
    }

    @ViewBuilder
    private func pageView(_ page: Page) -> some View {
        switch page {
        case let .card(items):
            cardPage(items)
        case .cover:
            coverPage
        }
    }

    private func centredLine(_ text: String) -> some View {
        Text(text)
            .dsTextStyle(TextRole.body)
            .foregroundStyle(Tokens.Colors.globalTextSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var weekTitle: String { Copy.photoViewerHeaderWeek(weekNumber: String(model.weekNumber ?? 0)) }

    private var range: String {
        model.recap.map { SocialFormat.weekRange($0.weekStart, timeZone: model.timeZone) } ?? ""
    }

    /// Page 1: memory's recap card (white in both appearances, L-4) — footer "Week {n}" with the group name over the
    /// range — and, when the recap has text, the note `week.recap.dimension.noteGap` under it; card and note centred
    /// together in the frame.
    private func cardPage(_ items: [PostWithMedia]) -> some View {
        GeometryReader { proxy in
            VStack(spacing: Tokens.Sizes.weekRecapDimensionNoteGap) {
                RecapCard(
                    photos: items.map { post in
                        RecapCardPhoto(
                            id: post.id.rawValue,
                            source: SocialImages.source(post.media?.gridPath),
                            accessibilityLabel: SocialA11y.photo(post, author: model.profiles[post.post.authorID], me: model.me)
                        )
                    },
                    title: weekTitle,
                    name: model.group?.name,
                    detail: range,
                    frameWidth: proxy.size.width
                ) { photo in
                    viewer = PhotoViewerContext(postIDs: model.cardPosts.map(\.id), start: PostID(photo.id), groupID: model.groupID)
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel(Text(Copy.weekRecapA11yCard(
                    weekNumber: String(model.weekNumber ?? 0),
                    dateRange: model.recap.map { SocialFormat.spokenWeekRange($0.weekStart, timeZone: model.timeZone) } ?? ""
                )))
                if let note = model.note {
                    RecapNote(text: note.text, editor: note.editor)
                        .frame(width: RecapCard.width(frameWidth: proxy.size.width))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    /// Page 2: the cover fills the frame (aspect fill) under `layout.global.photoScrim`; "Week {n}" (serif `headerTitle`)
    /// and the group name over the range at `dimension.year.story.frame.padding`, baseline
    /// `dimension.year.story.footer.baseline` above the frame bottom (memory's `RecapFooter`).
    private var coverPage: some View {
        ZStack {
            PhotoView(source: SocialImages.source(model.cover?.media?.displayImagePath))
            PhotoScrim()
            RecapFooter {
                Text(weekTitle)
                    .dsTextStyle(TextRole.headerTitle)
                    .lineLimit(1)
            } trailing: {
                VStack(alignment: .trailing, spacing: 0) {
                    if let name = model.group?.name {
                        Text(name).dsTextStyle(TextRole.listTitle)
                    }
                    Text(range).dsTextStyle(TextRole.meta)
                }
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
            }
            .foregroundStyle(Tokens.Colors.globalTextOnMedia)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Bottom row

    /// The select-photos thumbnail: `week.recap.dimension.selectThumb` square, corners `week.recap.radius.selectThumb`,
    /// a `week.recap.dimension.selectThumbBorder` border in `color.global.surfaceLight`, the recap's first item; no count
    /// badge. → `week.edit` (ready recaps only). The chrome places it at `size.global.buttonMarginH`.
    @ViewBuilder
    private var selectThumbnail: some View {
        if model.canEdit {
            Button { editing = true } label: {
                PhotoView(source: SocialImages.source(model.cover?.media?.gridPath))
                    .frame(width: Tokens.Sizes.weekRecapDimensionSelectThumb, height: Tokens.Sizes.weekRecapDimensionSelectThumb)
                    .clipShape(DSShape.rounded(Tokens.Radii.weekRecapRadiusSelectThumb))
                    .overlay {
                        DSShape.rounded(Tokens.Radii.weekRecapRadiusSelectThumb)
                            .strokeBorder(Tokens.Colors.globalSurfaceLight, lineWidth: Tokens.Sizes.weekRecapDimensionSelectThumbBorder)
                    }
                    .minimumHitArea(drawn: CGSize(width: Tokens.Sizes.weekRecapDimensionSelectThumb, height: Tokens.Sizes.weekRecapDimensionSelectThumb))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(Copy.weekRecapA11yEdit))
        }
    }
}

/// The recap text as Retro's journal note (`week.recap.layout.note`): a box the card's width, corners
/// `week.recap.radius.note`, padding `week.recap.dimension.notePaddingV` / `.notePaddingH`, fill
/// `color.global.controlOnDeep`; the last editor's avatar (`size.global.avatarComment`) and name (`listTitle`) lead the
/// first line, then the text (`body`, `color.global.textOnMedia`).
struct RecapNote: View {
    let text: String
    let editor: Profile?

    var body: some View {
        HStack(alignment: .top, spacing: Tokens.Sizes.chatThreadDimensionRowAvatarToText) {
            if let editor {
                AvatarView(source: SocialImages.source(editor.avatarPath), diameter: Tokens.Sizes.globalAvatarComment)
            }
            noteText
                .foregroundStyle(Tokens.Colors.globalTextOnMedia)
        }
        .dsTextStyle(TextRole.body)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Tokens.Sizes.weekRecapDimensionNotePaddingV)
        .padding(.horizontal, Tokens.Sizes.weekRecapDimensionNotePaddingH)
        .background(Tokens.Colors.globalControlOnDeep, in: DSShape.rounded(Tokens.Radii.weekRecapRadiusNote))
        .accessibilityElement(children: .combine)
    }

    /// The editor's first name in the `listTitle` weight, a space, then the text.
    private var noteText: Text {
        guard let editor else { return Text(verbatim: text) }
        let name = Text(verbatim: editor.socialFirstName).fontWeight(Tokens.FontWeights.fontWeightGlobalListTitle)
        return Text("\(name) \(Text(verbatim: text))") // provenance-ok: name and note text (data) joined by a space
    }
}
