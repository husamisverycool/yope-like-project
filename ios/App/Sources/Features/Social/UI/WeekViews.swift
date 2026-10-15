// Surfaces: week.recap (Yope recaps by week), week.edit (built from Yope components, S-13), week.history (Retro).
// Specs: design/surfaces/week.recap.md, week.edit.md, week.history.md.
// References: references/owner/yope-week-recap.jpg (recap card, pics grid, "recap | pics" capsule — primary);
// references/auto/yope/frames/a-chuongxetank-7694968408424582452-t6.73-sendto-voice-tooltip.png and
// a-itsmthuyope-7644974799302823175-t45.23-new-group-empty.png (edit sheet, name sheet);
// references/auto/retro/store/retro-store-02.png (history: week header, strip, tile labels).
import AppData
import AppModels
import DesignSystem
import SwiftUI
import UIKit

// MARK: - Shared header

/// ‹ (or ✕) circle · centred title · optional trailing circle, circles at `size.global.headerInset`.
struct SocialCenteredHeader<Trailing: View>: View {
    let title: String
    var titleStyle: DSTextStyle = SocialText.recapTitle
    var leadingIcon: String = Tokens.Icons.globalBack
    var leadingLabel: String = Copy.chatThreadA11yBack
    let leadingAction: () -> Void
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack {
            HeaderCircleButton(icon: leadingIcon, accessibilityLabel: leadingLabel, fill: .onDeep, action: leadingAction)
            Spacer(minLength: 0)
            trailing()
        }
        .padding(.horizontal, Tokens.Sizes.globalHeaderInset)
        .overlay {
            Text(title)
                .dsTextStyle(titleStyle)
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, Tokens.Sizes.globalHeaderInset + Tokens.Sizes.globalHeaderButton + Tokens.Sizes.globalHeaderGap)
                .accessibilityAddTraits(.isHeader)
        }
    }
}

/// The week pics grid (O3 C2): `week.recap.count.picsColumns` columns, gaps `week.recap.dimension.picsGap`, tiles
/// `week.recap.aspectRatio.picsTile`, full width, square corners, aspect fill.
struct WeekPicsGrid<Overlay: View>: View {
    let posts: [PostWithMedia]
    var reorder: WeekPicsReorder?
    /// Each tile's VoiceOver label (`photo.viewer.a11y.photo`) and value (`week.edit.a11y.inRecap` / `.notInRecap`).
    let label: (PostWithMedia) -> String
    var value: (PostWithMedia) -> String = { _ in "" }
    let open: (PostWithMedia) -> Void
    @ViewBuilder var overlay: (PostWithMedia) -> Overlay

    @State private var width: CGFloat = 0
    @State private var alignTick = 0
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        let gap = Tokens.Sizes.weekRecapDimensionPicsGap
        let columns = Array(repeating: GridItem(.flexible(), spacing: gap), count: Int(Tokens.Counts.weekRecapCountPicsColumns))
        LazyVGrid(columns: columns, spacing: gap) {
            ForEach(posts) { post in
                Button { open(post) } label: {
                    PhotoGridTile(path: post.media?.gridPath, aspectRatio: Tokens.AspectRatios.weekRecapAspectRatioPicsTile, maxPixel: maxPixel)
                        .overlay(alignment: .topTrailing) { overlay(post) }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(label(post)))
                .accessibilityValue(Text(value(post)))
                .modifier(ReorderableTile(postID: post.id, reorder: reorder, alignTick: $alignTick))
            }
        }
        .socialReadsWidth($width)
        .sensoryFeedback(.alignment, trigger: alignTick)
    }

    private var maxPixel: Int? {
        guard width > 0 else { return nil }
        let tile = SocialGrid.tileWidth(container: width, columns: Tokens.Counts.weekRecapCountPicsColumns, inset: 0, gap: Tokens.Sizes.weekRecapDimensionPicsGap)
        return SocialGrid.maxPixel(width: tile, aspectRatio: Tokens.AspectRatios.weekRecapAspectRatioPicsTile, scale: displayScale)
    }
}

extension WeekPicsGrid where Overlay == EmptyView {
    init(posts: [PostWithMedia], label: @escaping (PostWithMedia) -> String, open: @escaping (PostWithMedia) -> Void) {
        self.init(posts: posts, reorder: nil, label: label, open: open, overlay: { _ in EmptyView() })
    }
}

/// Moving checked tiles in `week.edit` (`week.edit.layout.reorder`).
struct WeekPicsReorder {
    let canMove: (PostID) -> Bool
    let move: (PostID, PostID) -> Bool
}

/// `week.edit.layout.reorder` (Apple Photos / Google Photos, G-16): touch and hold a checked tile, then drag it into a
/// new position among the checked tiles; the platform drag-and-drop shows the drop position. The pick-up plays the
/// system's own feedback (`week.edit.haptic.dragStart` iOS: system); each slot the drag enters plays
/// `week.edit.haptic.dragAlign` (iOS: `sensoryFeedback(.alignment)`). The drag tracks the finger (Reduce Motion too).
/// The "move earlier / later" accessibility actions of the spec have no copy yet (not built).
struct ReorderableTile: ViewModifier {
    let postID: PostID
    let reorder: WeekPicsReorder?
    @Binding var alignTick: Int

    private var enabled: Bool { reorder?.canMove(postID) ?? false }

    func body(content: Content) -> some View {
        if enabled, let reorder {
            content
                .draggable(postID.rawValue)
                .dropDestination(for: String.self) { items, _ in
                    guard let dragged = items.first else { return false }
                    return reorder.move(PostID(dragged), postID)
                } isTargeted: { targeted in
                    if targeted { alignTick += 1 }
                }
        } else {
            content
        }
    }
}

// MARK: - week.recap

struct WeekRecapView: View {
    @State private var model: WeekRecapModel
    @State private var viewer: PhotoViewerContext?
    @State private var editing = false
    @State private var toasts = ToastCenter()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Part: Hashable {
        case recap
        case pics
    }

    init(groupID: String, recapID: String) {
        self.init(model: WeekRecapModel(groupID: GroupID(groupID), recapID: RecapID(recapID), data: SocialServices.shared.data))
    }

    init(model: WeekRecapModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        ZStack {
            Tokens.Colors.globalBackground.ignoresSafeArea()
            content
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            SocialCenteredHeader(title: title, leadingAction: { dismiss() }) {
                if model.canEdit {
                    HeaderCircleButton(icon: Tokens.Icons.globalEdit, accessibilityLabel: Copy.weekRecapA11yEdit, fill: .onDeep) {
                        editing = true
                    }
                }
            }
        }
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
        .accessibilityIdentifier("week.recap") // provenance-ok: accessibility identifier for UI tests
    }

    private var title: String {
        model.recap.map { SocialFormat.weekTitle($0.weekStart, timeZone: model.timeZone) } ?? ""
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .loading:
            if model.showsLoading { LoadingHUD() }
        case .pending:
            Text(Copy.weekRecapPending)
                .dsTextStyle(TextRole.emptyTitle)
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
                .multilineTextAlignment(.center)
        case .empty:
            EmptyStateView(
                title: Copy.weekRecapEmptyTitle,
                detail: Copy.weekRecapEmptyDetail,
                action: .init(Copy.weekRecapEmptyAction, icon: Tokens.Icons.globalCamera) {
                    SocialNav.openCamera(groupID: model.groupID.rawValue)
                }
            )
        case .failed:
            EmptyStateView(
                title: Copy.weekRecapErrorTitle,
                detail: Copy.chatThreadErrorDetail,
                action: .init(Copy.chatThreadErrorRetry) { Task { await model.retry() } }
            )
        case .offline:
            EmptyStateView(title: Copy.chatThreadOfflineTitle, detail: Copy.chatThreadOfflineDetail)
        case .ready:
            ready
        }
    }

    private var ready: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    card
                        .id(Part.recap)
                    // Page dots: hidden while the card has one page (`week.recap.layout.page2` BLOCKED); their place
                    // is kept so a second page adds no jump.
                    Color.clear.frame(height: Tokens.Sizes.weekRecapDimensionCardToDots + Tokens.Sizes.weekRecapDimensionPageDot + Tokens.Sizes.weekRecapDimensionDotsToPics)
                    WeekPicsGrid(
                        posts: model.weekPosts,
                        label: { SocialA11y.photo($0, author: model.profiles[$0.post.authorID], me: model.me) },
                        open: { post in
                            viewer = PhotoViewerContext(postIDs: model.weekPosts.map(\.id), start: post.id, groupID: model.groupID)
                        }
                    )
                    .id(Part.pics)
                    .background {
                        GeometryReader { geometry in
                            Color.clear.preference(key: RecapPicsTopKey.self, value: geometry.frame(in: .named(Part.recap)).minY)
                        }
                    }
                }
                .padding(.bottom, Tokens.Sizes.weekRecapDimensionSegmentedBottom + Tokens.Sizes.weekRecapDimensionSegmentedHeight)
            }
            .coordinateSpace(.named(Part.recap))
            .onPreferenceChange(RecapPicsTopKey.self) { [model] top in
                // Scrolling updates the selection (approximation, spec Gaps): "pics" once the grid reaches the middle.
                Task { @MainActor in
                    model.setSegment(top < UIScreenHeight.half ? .pics : .recap, fromScroll: true)
                }
            }
            .overlay(alignment: .bottom) {
                RecapSegmentedControl(selection: model.segment) { segment in
                    model.setSegment(segment)
                    if reduceMotion {
                        proxy.scrollTo(segment == .recap ? Part.recap : Part.pics, anchor: .top)
                    } else {
                        withAnimation { proxy.scrollTo(segment == .recap ? Part.recap : Part.pics, anchor: .top) }
                    }
                }
                .padding(.bottom, Tokens.Sizes.weekRecapDimensionSegmentedBottom)
                .ignoresSafeArea(edges: .bottom)
            }
        }
    }

    /// The recap card: `week.recap.dimension.cardWidth`, corners `week.recap.radius.card`; full rows of
    /// `week.recap.count.gridColumns` tiles (`week.recap.aspectRatio.gridTile`, gap `week.recap.dimension.gridGap`).
    /// The row holding the leftover 1–2 photos (first, full width) is BLOCKED (`week.recap.layout.shortRowSplit`,
    /// `.dimension.shortRowHeight`): those photos stay in the pics grid below. The week label (uppercase) sits
    /// `week.recap.dimension.labelInsetLeading` from the left, baseline `.labelBaselineBottom` above the bottom (its
    /// scrim is BLOCKED).
    private var card: some View {
        let columns = Int(Tokens.Counts.weekRecapCountGridColumns)
        let items = model.cardPosts
        let leftover = SocialBlocked.recapShortRowHeight == nil ? items.count % columns : 0
        let full = Array(items.dropFirst(leftover))
        let tileWidth = Tokens.Sizes.weekRecapDimensionCardWidth / CGFloat(columns)
        let gap = Tokens.Sizes.weekRecapDimensionGridGap
        let label = model.recap.map { SocialFormat.weekLabel($0.weekStart, timeZone: model.timeZone) } ?? ""
        return VStack(spacing: gap) {
            ForEach(Array(stride(from: 0, to: full.count, by: columns)), id: \.self) { start in
                HStack(spacing: gap) {
                    ForEach(full[start..<min(start + columns, full.count)]) { post in
                        Button {
                            viewer = PhotoViewerContext(postIDs: items.map(\.id), start: post.id, groupID: model.groupID)
                        } label: {
                            SocialPhoto(path: post.media?.gridPath)
                                .frame(width: tileWidth, height: tileWidth / Tokens.AspectRatios.weekRecapAspectRatioGridTile)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(SocialA11y.photo(post, author: model.profiles[post.post.authorID], me: model.me)))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: Tokens.Sizes.weekRecapDimensionCardWidth, alignment: .top)
        .frame(minHeight: tileWidth / Tokens.AspectRatios.weekRecapAspectRatioGridTile)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radii.weekRecapRadiusCard))
        .overlay(alignment: .bottomLeading) {
            Text(label)
                .dsTextStyle(SocialText.recapLabel)
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(.leastNonzeroMagnitude)
                .padding(.leading, Tokens.Sizes.weekRecapDimensionLabelInsetLeading)
                .alignmentGuide(.bottom) { $0[.firstTextBaseline] + Tokens.Sizes.weekRecapDimensionLabelBaselineBottom }
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(Copy.weekRecapA11yCard(weekLabel: title)))
    }
}

private struct RecapPicsTopKey: PreferenceKey {
    static let defaultValue: CGFloat = .greatestFiniteMagnitude
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

/// Half the screen height (where the pics grid's top switches the capsule to "pics").
@MainActor
enum UIScreenHeight {
    static var half: CGFloat {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return (scenes.first?.screen.bounds.height ?? 0) / 2
    }
}

/// The floating "recap | pics" capsule: track `week.recap.dimension.segmentedWidth` × `.segmentedHeight` in
/// `color.global.control`, white pill `.segmentedPillWidth` × `.segmentedPillHeight` inset `.segmentedInset`, labels
/// `week.recap.fontSize.segmented` / `.fontWeight.segmented` (selected `color.global.onSurfaceLight`, others
/// `color.global.textPrimary`). The pill moves with `spring.global.platformDefault.ios`; under Reduce Motion it jumps.
struct RecapSegmentedControl: View {
    let selection: WeekRecapModel.Segment
    let select: (WeekRecapModel.Segment) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let inset = Tokens.Sizes.weekRecapDimensionSegmentedInset
        ZStack(alignment: selection == .recap ? .leading : .trailing) {
            Capsule()
                .fill(Tokens.Colors.globalSurfaceLight)
                .frame(width: Tokens.Sizes.weekRecapDimensionSegmentedPillWidth, height: Tokens.Sizes.weekRecapDimensionSegmentedPillHeight)
                .padding(inset)
            HStack(spacing: 0) {
                segment(.recap, Copy.weekRecapSegmentRecap)
                segment(.pics, Copy.weekRecapSegmentPics)
            }
            .padding(inset)
        }
        .frame(width: Tokens.Sizes.weekRecapDimensionSegmentedWidth, height: Tokens.Sizes.weekRecapDimensionSegmentedHeight)
        .background(Tokens.Colors.globalControl, in: Capsule())
        .animation(reduceMotion ? nil : DSAnimation.spring(Tokens.Springs.globalPlatformDefaultIos).animation, value: selection)
    }

    private func segment(_ value: WeekRecapModel.Segment, _ title: String) -> some View {
        Button { select(value) } label: {
            Text(title)
                .dsTextStyle(SocialText.recapSegment)
                .foregroundStyle(value == selection ? Tokens.Colors.globalOnSurfaceLight : Tokens.Colors.globalTextPrimary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(value == selection ? [.isSelected, .isButton] : .isButton)
    }
}

// MARK: - week.edit

/// Sheet over `week.recap` (or straight on the album sheet from `week.history`): the week's photos with check
/// circles, the recap text, "save". Reorder is BLOCKED (`week.edit.layout.reorder`): DEBUG builds drag checked tiles.
struct WeekEditView: View {
    @State private var model: WeekEditModel
    let toasts: ToastCenter
    @Environment(\.dismiss) private var dismiss

    init(groupID: GroupID, mode: WeekEditModel.Mode, toasts: ToastCenter) {
        self.init(model: WeekEditModel(groupID: groupID, mode: mode, data: SocialServices.shared.data), toasts: toasts)
    }

    init(model: WeekEditModel, toasts: ToastCenter) {
        _model = State(initialValue: model)
        self.toasts = toasts
    }

    var body: some View {
        VStack(spacing: 0) {
            SocialCenteredHeader(
                title: Copy.weekEditTitle,
                titleStyle: TextRole.sheetTitle,
                leadingIcon: Tokens.Icons.globalClose,
                leadingLabel: Copy.weekEditA11yClose,
                leadingAction: { dismiss() }
            ) { EmptyView() }
            content
        }
        .background(Tokens.Colors.globalBackgroundDeep.ignoresSafeArea())
        .loadingHUD(model.phase == .loading || model.isSaving || model.isSavingAlbum)
        .presentationDetents([.large])
        .task { if model.phase == .loading { await model.load() } }
        .onChange(of: model.isFinished) { _, finished in if finished { dismiss() } }
        .socialFeedback(model.signals.feedback)
        .socialNotices(model.signals.notice, toasts: toasts)
        .sheet(isPresented: $model.isAlbumSheetPresented) {
            AlbumNameSheet(
                title: Copy.weekEditAlbumTitle,
                name: $model.albumName,
                isEnabled: model.canSaveAlbum,
                showsMissingName: model.albumNameMissing,
                failed: model.albumError != nil,
                onNameChange: { model.albumNameChanged() },
                onSave: { Task { await model.saveAlbum() } }
            )
        }
        .accessibilityIdentifier("week.edit") // provenance-ok: accessibility identifier for UI tests
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .loading:
            Spacer()
        case .notReady:
            Spacer()
            EmptyStateView(title: Copy.weekEditErrorNotReady)
            Spacer()
        case .failed:
            Spacer()
            EmptyStateView(
                title: Copy.weekEditErrorSave,
                action: .init(Copy.chatThreadErrorRetry) { Task { await model.load() } }
            )
            Spacer()
        case .offline:
            Spacer()
            EmptyStateView(title: Copy.chatThreadOfflineTitle, detail: Copy.chatThreadOfflineDetail)
            Spacer()
        case .ready:
            ScrollView {
                VStack(spacing: Tokens.Sizes.globalListGap) {
                    grid
                    if case .recap = model.mode { recapText }
                }
            }
            footer
        }
    }

    private var grid: some View {
        WeekPicsGrid(
            posts: model.gridPosts,
            reorder: WeekPicsReorder(canMove: { model.isChecked($0) }, move: { model.move($0, to: $1) }),
            label: { SocialA11y.photo($0, author: model.profiles[$0.post.authorID], me: model.me) },
            value: { model.isChecked($0.id) ? Copy.weekEditA11yInRecap : Copy.weekEditA11yNotInRecap },
            open: { post in model.toggle(post.id) }
        ) { post in
            let checked = model.isChecked(post.id)
            Image(systemName: checked ? Tokens.Icons.globalCheck : Tokens.Icons.globalUncheck)
                .resizable()
                .scaledToFit()
                .frame(width: Tokens.Sizes.globalCheckCircle, height: Tokens.Sizes.globalCheckCircle)
                .foregroundStyle(checked ? Tokens.Colors.globalSelection : Tokens.Colors.globalTextPrimary)
                .padding(Tokens.Sizes.globalListGap)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .contain)
    }

    /// Position BLOCKED (`week.edit.layout.recapText`): the spec's approximation under the grid — multi-line field
    /// `groups.create.color.field`, `radius.global.field`, min height `size.global.fieldHeight`, side margin
    /// `size.global.buttonMarginH`, text role `body`, placeholder `week.edit.textPlaceholder`.
    private var recapText: some View {
        TextField(
            text: $model.text,
            prompt: Text(Copy.weekEditTextPlaceholder).foregroundStyle(Tokens.Colors.globalTextSecondary),
            axis: .vertical
        ) {
            Text(Copy.weekEditTextPlaceholder)
        }
        .dsTextStyle(TextRole.body)
        .foregroundStyle(Tokens.Colors.globalTextPrimary)
        .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
        .padding(.vertical, SocialMetrics.singleLineInset(height: Tokens.Sizes.globalFieldHeight, style: TextRole.body))
        .frame(maxWidth: .infinity, minHeight: Tokens.Sizes.globalFieldHeight, alignment: .leading)
        .background(Tokens.Colors.groupsCreateColorField, in: RoundedRectangle(cornerRadius: Tokens.Radii.globalField))
        .padding(.horizontal, Tokens.Sizes.globalButtonMarginH)
    }

    /// Pinned "save" (lime, `size.global.buttonHeightSheet`, margins `size.global.buttonMarginHSheet`). The dark
    /// "save as album" button beside it has no tokens (`SocialBlocked.hasSaveAsAlbumButton`).
    private var footer: some View {
        VStack(spacing: Tokens.Sizes.globalListGap) {
            if let error = model.saveError {
                Text(error == .notReady ? Copy.weekEditErrorNotReady : Copy.weekEditErrorSave)
                    .dsTextStyle(TextRole.listSubtitle)
                    .foregroundStyle(Tokens.Colors.globalTextSecondary)
                    .multilineTextAlignment(.center)
            }
            if case .recap = model.mode {
                PrimaryButton(Copy.weekEditSave, height: .sheet, isEnabled: !model.isSaving) {
                    Task { await model.save() }
                }
            }
        }
        .padding(.horizontal, Tokens.Sizes.globalButtonMarginHSheet)
    }
}

/// The album name sheet ("new group" form, S-13): ✕ circle + title (`groups.create.fontSize.title` /
/// `.fontWeight.title`), the name field (shared `FormField`), the lime "save" (`size.global.buttonHeight`,
/// `size.global.buttonMarginH`), disabled until a photo is checked and a name is typed; spacing
/// `groups.create.size.titleToContent` and `.fieldToButton`.
struct AlbumNameSheet: View {
    let title: String
    @Binding var name: String
    let isEnabled: Bool
    let showsMissingName: Bool
    var failed = false
    let onNameChange: () -> Void
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            SocialCenteredHeader(
                title: title,
                titleStyle: SocialText.albumSheetTitle,
                leadingIcon: Tokens.Icons.globalClose,
                leadingLabel: Copy.weekEditA11yClose,
                leadingAction: { dismiss() }
            ) { EmptyView() }
            FormField(Copy.weekEditAlbumNamePlaceholder, text: $name, accessibilityLabel: Copy.weekEditAlbumNamePlaceholder, submitLabel: .done, onSubmit: onSave)
                .padding(.top, Tokens.Sizes.groupsCreateSizeTitleToContent)
                .padding(.horizontal, Tokens.Sizes.globalButtonMarginH)
                .onChange(of: name) { _, _ in onNameChange() }
            if showsMissingName || failed {
                Text(showsMissingName ? Copy.weekEditErrorAlbumName : Copy.weekEditErrorSave)
                    .dsTextStyle(TextRole.listSubtitle)
                    .foregroundStyle(Tokens.Colors.globalTextSecondary)
                    .padding(.horizontal, Tokens.Sizes.globalButtonMarginH)
            }
            PrimaryButton(Copy.weekEditSave, height: .form, isEnabled: isEnabled, action: onSave)
                .padding(.top, Tokens.Sizes.groupsCreateSizeFieldToButton)
                .padding(.horizontal, Tokens.Sizes.globalButtonMarginH)
            Spacer(minLength: 0)
        }
        .background(Tokens.Colors.globalBackgroundDeep.ignoresSafeArea())
        .presentationDetents([.large])
    }
}

// MARK: - week.history

struct WeekHistoryScreen: View {
    @State private var model: WeekHistoryModel
    @State private var viewer: PhotoViewerContext?
    @State private var albumWeek: LocalDate?
    @State private var toasts = ToastCenter()
    @Environment(\.dismiss) private var dismiss

    init(groupID: String) {
        self.init(model: WeekHistoryModel(groupID: GroupID(groupID), data: SocialServices.shared.data))
    }

    init(model: WeekHistoryModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                HeaderCircleButton(icon: Tokens.Icons.globalBack, accessibilityLabel: Copy.chatThreadA11yBack, fill: .onDeep) { dismiss() }
                    .padding(.leading, Tokens.Sizes.globalHeaderInset)
                Text(model.group?.name ?? "")
                    .dsTextStyle(SocialText.historyTitle)
                    .foregroundStyle(Tokens.Colors.globalTextPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.leading, Tokens.Sizes.weekHistoryDimensionTitleInset)
                    .accessibilityAddTraits(.isHeader)
                if model.line == .offline { line(Copy.weekHistoryOffline) }
                if model.isLoading {
                    if model.showsLoading { ProgressView().frame(maxWidth: .infinity) }
                } else {
                    ForEach(Array(model.weeks.enumerated()), id: \.element.id) { index, week in
                        WeekSection(model: model, week: week, open: open, saveAsAlbum: { albumWeek = week.weekStart })
                            .padding(.top, index == 0 ? Tokens.Sizes.weekHistoryDimensionTitleToStrip : Tokens.Sizes.weekHistoryDimensionSectionGap)
                            .onAppear {
                                if week.id == model.weeks.last?.id { Task { await model.loadMore() } }
                            }
                    }
                    if model.isLoadingMore { ProgressView().frame(maxWidth: .infinity) }
                    if model.line == .empty, let name = model.group?.name { line(Copy.weekHistoryEmpty(groupName: name)) }
                    if model.line == .error { line(Copy.weekHistoryError) }
                }
            }
        }
        .refreshable { await model.load() }
        .background(Tokens.Colors.globalBackgroundDeep.ignoresSafeArea())
        .socialHidesNavigationBar()
        .task {
            if model.isLoading { await model.load() }
            await model.run()
        }
        .toastHost(toasts)
        .socialPhotoViewer($viewer)
        .sheet(item: Binding(get: { albumWeek.map(AlbumWeek.init) }, set: { albumWeek = $0?.weekStart })) { item in
            WeekEditView(groupID: model.groupID, mode: .album(weekStart: item.weekStart), toasts: toasts)
        }
        .accessibilityIdentifier("week.history") // provenance-ok: accessibility identifier for UI tests
    }

    private func open(_ week: WeekHistoryModel.Week, _ postID: PostID) {
        viewer = PhotoViewerContext(postIDs: week.postIDs, start: postID, groupID: model.groupID)
    }

    /// The explanation line slot (`week.history` States): text role `listSubtitle`, `color.global.textSecondary`.
    private func line(_ text: String) -> some View {
        Text(text)
            .dsTextStyle(TextRole.listSubtitle)
            .foregroundStyle(Tokens.Colors.globalTextSecondary)
            .padding(.horizontal, Tokens.Sizes.weekHistoryDimensionInset)
            .padding(.top, Tokens.Sizes.weekHistoryDimensionHeaderToStrip)
    }
}

private struct AlbumWeek: Identifiable {
    let weekStart: LocalDate
    var id: LocalDate { weekStart }
}

/// One week: "Week {n}" + range + •••, then the strip of its photos (Retro R2).
struct WeekSection: View {
    let model: WeekHistoryModel
    let week: WeekHistoryModel.Week
    let open: (WeekHistoryModel.Week, PostID) -> Void
    let saveAsAlbum: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            strip
                .padding(.top, Tokens.Sizes.weekHistoryDimensionHeaderToStrip)
        }
        .accessibilityElement(children: .contain)
    }

    private var range: String? {
        week.isCurrent && week.postIDs.isEmpty ? nil : SocialFormat.weekRange(week.weekStart, timeZone: model.timeZone)
    }

    private var header: some View {
        let number = String(SocialCalendar.weekNumber(of: week.weekStart, in: model.timeZone))
        return HStack(alignment: .firstTextBaseline, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: Tokens.Sizes.weekHistoryDimensionRangeGap) {
                Text(Copy.weekHistoryHeaderTitle(weekNumber: number))
                    .dsTextStyle(SocialText.historyHeaderTitle)
                    .foregroundStyle(Tokens.Colors.globalTextPrimary)
                if let range {
                    Text(range)
                        .dsTextStyle(SocialText.historyHeaderRange)
                        .foregroundStyle(Tokens.Colors.globalTextSecondary)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text([Copy.weekHistoryHeaderTitle(weekNumber: number), range].compactMap { $0 }.joined(separator: ", ")))
            .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            menu
        }
        .padding(.leading, Tokens.Sizes.weekHistoryDimensionInset)
        .padding(.trailing, Tokens.Sizes.weekHistoryDimensionMoreTrailing - (Tokens.Sizes.globalMinTouchTargetIos - Tokens.Sizes.photoViewerDimensionMoreGlyphWidth) / 2)
    }

    /// Our two product items (Retro's own menu is BLOCKED, `week.history.layout.weekMenu`).
    private var menu: some View {
        Menu {
            if let recapID = model.readyRecaps[week.weekStart] {
                Button(Copy.weekHistoryMenuViewRecap) {
                    SocialNav.push(.recap(groupID: model.groupID.rawValue, recapID: recapID.rawValue))
                }
            }
            if !week.postIDs.isEmpty {
                Button(Copy.weekHistoryMenuSaveAsAlbum, action: saveAsAlbum)
            }
        } label: {
            Image(systemName: Tokens.Icons.globalMore)
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
                .frame(minWidth: Tokens.Sizes.globalMinTouchTargetIos, minHeight: Tokens.Sizes.globalMinTouchTargetIos)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(Text(Copy.weekHistoryA11yMore))
    }

    /// Tiles `week.history.dimension.tileWidth` × `.tileHeight`, gaps `.tileGap`, outer corners `week.history.radius.strip`,
    /// from `.inset`, scrolling horizontally; the weekday bottom-centred, baseline `.weekdayBaseline` above the bottom.
    /// The current week ends with the add tile and one empty-day tile per day without a photo
    /// (`week.history.color.emptyTile`; "+" in `color.global.textPrimary`, labels in `.emptyTileText`).
    private var strip: some View {
        let posts = week.postIDs.compactMap { model.posts[$0] }
        let emptyDays = model.emptyDays(of: week) ?? []
        let height = Tokens.Sizes.weekHistoryDimensionTileHeight
        let hasTiles = !posts.isEmpty || week.isCurrent
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Tokens.Sizes.weekHistoryDimensionTileGap) {
                ForEach(posts) { post in
                    Button { open(week, post.id) } label: {
                        SocialPhoto(path: post.media?.gridPath)
                            .frame(width: Tokens.Sizes.weekHistoryDimensionTileWidth, height: height)
                            .overlay(alignment: .bottom) {
                                Text(SocialFormat.weekday(post.post.createdAt, timeZone: model.timeZone))
                                    .dsTextStyle(SocialText.historyWeekday)
                                    .foregroundStyle(Tokens.Colors.globalTextPrimary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(.leastNonzeroMagnitude)
                                    .alignmentGuide(.bottom) { $0[.firstTextBaseline] + Tokens.Sizes.weekHistoryDimensionWeekdayBaseline }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(Copy.weekHistoryA11yTile(
                        weekday: SocialFormat.weekday(post.post.createdAt, timeZone: model.timeZone),
                        date: SocialFormat.spokenDate(post.post.createdAt, timeZone: model.timeZone),
                        name: model.profiles[post.post.authorID]?.socialFirstName ?? ""
                    )))
                }
                if week.isCurrent {
                    addTile
                    ForEach(emptyDays, id: \.self) { day in
                        EmptyDayTile(date: SocialCalendar.start(of: day, in: model.timeZone), timeZone: model.timeZone)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radii.weekHistoryRadiusStrip))
            .padding(.leading, Tokens.Sizes.weekHistoryDimensionInset)
        }
        .frame(height: hasTiles ? height : 0)
    }

    /// Opens the camera for this group (`week.history.a11y.add`).
    private var addTile: some View {
        Button {
            SocialNav.openCamera(groupID: model.groupID.rawValue)
        } label: {
            Image(systemName: Tokens.Icons.weekHistoryIconAdd)
                .resizable()
                .scaledToFit()
                .frame(width: Tokens.Sizes.weekHistoryDimensionAddGlyph, height: Tokens.Sizes.weekHistoryDimensionAddGlyph)
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
                .frame(width: Tokens.Sizes.weekHistoryDimensionTileWidth, height: Tokens.Sizes.weekHistoryDimensionTileHeight)
                .background(Tokens.Colors.weekHistoryColorEmptyTile)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(Copy.weekHistoryA11yAdd))
    }
}

/// A day of the current week without a photo: month (`MMM`), day number (bold), weekday (`EEE`), centred, in
/// `week.history.color.emptyTileText` on `week.history.color.emptyTile`. Not interactive.
struct EmptyDayTile: View {
    let date: Date
    let timeZone: TimeZone

    var body: some View {
        VStack(spacing: 0) {
            Text(SocialFormat.month(date, timeZone: timeZone))
                .dsTextStyle(SocialText.historyEmptyDayLabel)
            Text(SocialFormat.dayNumber(date, timeZone: timeZone))
                .dsTextStyle(SocialText.historyEmptyDay)
            Text(SocialFormat.weekday(date, timeZone: timeZone))
                .dsTextStyle(SocialText.historyEmptyDayLabel)
        }
        .lineLimit(1)
        .minimumScaleFactor(.leastNonzeroMagnitude)
        .foregroundStyle(Tokens.Colors.weekHistoryColorEmptyTileText)
        .frame(width: Tokens.Sizes.weekHistoryDimensionTileWidth, height: Tokens.Sizes.weekHistoryDimensionTileHeight)
        .background(Tokens.Colors.weekHistoryColorEmptyTile)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(Copy.weekHistoryA11yEmptyDay(
            weekday: SocialFormat.weekday(date, timeZone: timeZone),
            date: SocialFormat.spokenDate(date, timeZone: timeZone)
        )))
    }
}
