// Surface: week.edit — Retro's composer sheet "Add to Your Week" (native toolbar Cancel / title / Update, the chosen
// photos as a strip on top, a grey header line, a 4-column grid), its "Add a Message" modal, and its "New Album" sheet;
// reorder by touch and hold + drag (Apple Photos / Google Photos). Spec: design/surfaces/week.edit.md (RS-22).
// References: references/auto/retro/video/ig-DDbA_F7x-j7-composer-f130-147-f188-197.png (primary),
// references/auto/retro/video/retro-motion-measurements.txt §C–D, references/auto/retro/press/tc-2023-12-retro3.png
// phones 2–3 ("Add Message" pill, "Add a Message" modal), references/auto/apple-photos/apple-support/page-filter-sort-albums.png.
import AppData
import AppModels
import DesignSystem
import SwiftUI

struct WeekEditView: View {
    @State private var model: WeekEditModel
    let toasts: ToastCenter
    @State private var messageOpen = false
    @State private var confirmingDiscard = false
    @State private var showsSaveError = false
    @State private var alignTick = 0
    @State private var dragged: PostID?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.layoutDirection) private var layoutDirection

    init(groupID: GroupID, mode: WeekEditModel.Mode, toasts: ToastCenter) {
        self.init(model: WeekEditModel(groupID: groupID, mode: mode, data: SocialServices.shared.data), toasts: toasts)
    }

    init(model: WeekEditModel, toasts: ToastCenter) {
        _model = State(initialValue: model)
        self.toasts = toasts
    }

    var body: some View {
        Group {
            if model.isAlbumOnly {
                albumSheet(closesEditor: true)
            } else {
                editor
            }
        }
        .task { if model.phase == .loading { await model.load() } }
        .onChange(of: model.isFinished) { _, finished in if finished { dismiss() } }
        .onChange(of: model.saveError) { _, error in if error != nil { showsSaveError = true } }
        .socialFeedback(model.signals.feedback)
        .socialNotices(model.signals.notice, toasts: toasts)
        .accessibilityIdentifier("week.edit") // provenance-ok: accessibility identifier for UI tests
    }

    // MARK: Editor (`week.edit.layout.composition`)

    private var editor: some View {
        NavigationStack {
            content
                .background(Tokens.Colors.globalBackground.ignoresSafeArea())
                .navigationTitle(Copy.weekEditTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(Copy.weekEditCancel) {
                            if model.hasChanges { confirmingDiscard = true } else { dismiss() }
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        // Saving: "Update" gives way to the platform activity indicator (C-05 busy rule, toolbar).
                        if model.isSaving {
                            ProgressView()
                        } else {
                            Button(Copy.weekEditSave) { Task { await model.save() } }
                                .disabled(model.phase != .ready)
                        }
                    }
                }
                .tint(Tokens.Colors.globalSelection)
        }
        .presentationDetents([.large])
        .interactiveDismissDisabled(model.hasChanges)
        .dsSheetBackground()
        .alert(Copy.weekEditLostChangesTitle, isPresented: $confirmingDiscard) {
            Button(Copy.weekEditLostChangesConfirm, role: .destructive) { dismiss() }
            Button(Copy.photoViewerDeleteCancel, role: .cancel) {}
        } message: {
            Text(Copy.weekEditLostChangesMessage)
        }
        .alert(model.saveError == .notReady ? Copy.weekEditErrorNotReady : Copy.weekEditErrorSave, isPresented: $showsSaveError) {}
        .sheet(isPresented: $messageOpen) {
            WeekEditMessageSheet(text: $model.text)
        }
        .sheet(isPresented: $model.isAlbumSheetPresented) {
            albumSheet(closesEditor: false)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .loading:
            ScrollView {
                MetricStack {
                    WeekStrip(tiles: WeekStripLayout.placeholders(count: Int(Tokens.Counts.weekEditCountGridColumns)), accessibilityLabel: { _ in "" })
                    grid(placeholders: Int(Tokens.Counts.weekEditCountGridColumns) * 2) // provenance-ok: two rows of placeholder cells (loading)
                        .metricGap(Tokens.Sizes.globalSectionGap, from: .bottom, to: .top)
                }
            }
            .accessibilityLabel(Text(Copy.weekHistoryA11yLoading))
        case .notReady:
            EmptyStateView(title: Copy.weekEditErrorNotReady)
                .frame(maxHeight: .infinity)
        case .failed:
            SocialErrorLine(text: Copy.weekEditErrorSave) { Task { await model.load() } }
                .frame(maxHeight: .infinity, alignment: .top)
        case .offline:
            EmptyStateView(title: Copy.chatThreadOfflineTitle, detail: Copy.chatThreadOfflineDetail)
                .frame(maxHeight: .infinity)
        case .ready:
            ScrollView {
                MetricStack {
                    strip
                    actions
                        .metricGap(Tokens.Sizes.globalSectionGap, from: .bottom, to: .top)
                    if let number = model.weekNumber {
                        Text(Copy.weekEditHeader(weekNumber: String(number)))
                            .dsTextRole(TextRole.listSubtitle)
                            .foregroundStyle(Tokens.Colors.globalTextSecondary)
                            .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
                            .metricGap(Tokens.Sizes.globalSectionGap, from: .bottom, to: .capTop)
                        grid(placeholders: 0)
                            .metricGap(Tokens.Sizes.globalSectionHeaderToContent, from: .lastBaseline, to: .top)
                    }
                }
                .padding(.bottom, Tokens.Sizes.globalSectionGap)
            }
        }
    }

    // MARK: Strip (C-17, `week.edit.layout.reorder`)

    /// The chosen photos in recap order: C-17 photo tiles, outer corners `radius.global.card`, scrolling sideways. Touch
    /// and hold a tile, drag it to a new place, release; the others shift with `duration.global.stripInsert`; each slot
    /// change plays `week.edit.haptic.dragAlign` (iOS: `sensoryFeedback(.alignment)`), the lift the system's own
    /// feedback (`week.edit.haptic.dragStart`). VoiceOver: drag and drop points on every tile, and the actions "Move photo
    /// left" / "Move photo right" (`week.edit.a11y.moveLeft` / `.moveRight`, Chrome's tab reorder actions) where the
    /// tile has a neighbour on that side — in a right-to-left layout "left" is later in the recap. (The shared
    /// `WeekStrip` has no reorder — reported as a component gap — so the strip draws `DayTile`s itself.)
    private var strip: some View {
        let posts = model.chosenPosts
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Tokens.Sizes.globalStripGap) {
                if posts.isEmpty {
                    DayTile(tile: WeekStripTile(id: "empty", kind: .placeholder, date: nil))
                        .accessibilityHidden(true)
                }
                ForEach(posts) { post in
                    let label = SocialA11y.tile(date: post.post.visibleAt, name: model.profiles[post.post.authorID]?.socialFirstName ?? "", timeZone: .current)
                    DayTile(tile: WeekStripTile(id: post.id.rawValue, kind: .photo(SocialImages.source(post.media?.gridPath)), date: post.post.visibleAt))
                        .contentShape(Rectangle())
                        .draggable(post.id.rawValue) {
                            DayTile(tile: WeekStripTile(id: post.id.rawValue, kind: .photo(SocialImages.source(post.media?.gridPath)), date: post.post.visibleAt))
                                .onAppear { dragged = post.id }
                        }
                        .dropDestination(for: String.self) { items, _ in
                            guard let id = items.first else { return false }
                            return withDSAnimation(ComponentMotion.stripInsert) { model.move(PostID(id), to: post.id) }
                        } isTargeted: { targeted in
                            if targeted, dragged != post.id { alignTick += 1 }
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text(label))
                        .accessibilityDragPoint(.center, description: Text(label))
                        .accessibilityDropPoint(.leading, description: Text(label))
                        .accessibilityActions {
                            let left = WeekEditModel.screenStep(.left, rightToLeft: layoutDirection == .rightToLeft)
                            let right = WeekEditModel.screenStep(.right, rightToLeft: layoutDirection == .rightToLeft)
                            if model.canMove(post.id, by: left) {
                                Button(Copy.weekEditA11yMoveLeft) { _ = withDSAnimation(ComponentMotion.stripInsert) { model.move(post.id, by: left) } }
                            }
                            if model.canMove(post.id, by: right) {
                                Button(Copy.weekEditA11yMoveRight) { _ = withDSAnimation(ComponentMotion.stripInsert) { model.move(post.id, by: right) } }
                            }
                        }
                        .transition(.opacity)
                }
            }
            .clipShape(DSShape.rounded(Tokens.Radii.globalCard))
            .padding(.leading, Tokens.Sizes.globalScreenMargin)
            .dsAnimation(ComponentMotion.stripInsert, value: model.chosen)
        }
        .sensoryFeedback(.alignment, trigger: alignTick)
    }

    // MARK: Action row (C-06)

    /// Equal widths, `size.global.pillGap` apart: outline capsule with `icon.global.edit` + "Add a message" ("Edit
    /// message" once there is text; C-07 anatomy) → the message sheet; outline capsule "Save as Album" → the album sheet.
    private var actions: some View {
        CapsuleRow {
            Button { messageOpen = true } label: {
                IconCapsuleLabel(
                    title: model.text.isEmpty ? Copy.weekEditMessageAdd : Copy.weekEditMessageEdit,
                    icon: Tokens.Icons.globalEdit
                )
                .dsAnimation(ComponentMotion.crossfade, value: model.text.isEmpty)
            }
            .buttonStyle(.plain)
            CapsuleButton(Copy.weekEditSaveAsAlbum, fillsWidth: true) { model.isAlbumSheetPresented = true }
        }
        .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
    }

    // MARK: Grid (C-21 composer grid)

    /// Every visible post of the week in time order: `week.edit.count.gridColumns` square cells, `size.global.stripGap`
    /// gaps, full width inside the margins; a tap toggles in / out (`haptic.global.select`); the in / out mark is
    /// `week.edit.layout.selectionMark` (`SelectionMarkCell`). (The shared `PhotoGrid` has no selection state or value —
    /// reported as a component gap.)
    private func grid(placeholders: Int) -> some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: Tokens.Sizes.globalStripGap), count: Int(Tokens.Counts.weekEditCountGridColumns)),
            spacing: Tokens.Sizes.globalStripGap
        ) {
            if placeholders > 0 {
                ForEach(0..<placeholders, id: \.self) { _ in
                    Tokens.Colors.globalControl
                        .aspectRatio(1, contentMode: .fit) // provenance-ok: square cells (C-21 composer grid)
                        .accessibilityHidden(true)
                }
            } else {
                ForEach(model.gridPosts) { post in
                    let checked = model.isChecked(post.id)
                    Button { model.toggle(post.id) } label: {
                        SelectionMarkedCell(source: SocialImages.source(post.media?.gridPath), checked: checked)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(SocialA11y.tile(date: post.post.visibleAt, name: model.profiles[post.post.authorID]?.socialFirstName ?? "", timeZone: .current)))
                    .accessibilityValue(Text(checked ? Copy.weekEditA11yInRecap : Copy.weekEditA11yNotInRecap))
                    .accessibilityAddTraits(.isToggle)
                }
            }
        }
        .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
    }

    // MARK: Album sheet

    private func albumSheet(closesEditor: Bool) -> some View {
        SocialNameSheet(
            title: Copy.weekEditAlbumTitle,
            placeholder: Copy.weekEditAlbumNamePlaceholder,
            buttonTitle: Copy.weekEditAlbumCreate,
            name: $model.albumName,
            isEnabled: model.canSaveAlbum,
            isBusy: model.isSavingAlbum,
            showsMissingName: model.albumNameMissing,
            closeAccessibilityLabel: Copy.photoViewerA11yClose,
            onNameChange: { model.albumNameChanged() },
            onSave: { Task { await model.saveAlbum() } },
            onClose: { if closesEditor { dismiss() } else { model.isAlbumSheetPresented = false } }
        )
        .alert(Copy.weekEditErrorSave, isPresented: Binding(get: { model.albumError != nil }, set: { if !$0 { model.dismissAlbumError() } })) {}
    }
}

/// A C-06 outline capsule with C-07's anatomy (`size.global.pillPaddingLeading` → glyph `size.global.iconSmall` →
/// `size.global.pillIconGap` → label `pill` → `size.global.pillPaddingTrailing`) that fills its share of an action row.
/// (The shared `CapsuleLabel` has no glyph + label form and `OutlineCTA` hugs its label — reported as a component gap.)
struct IconCapsuleLabel: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: Tokens.Sizes.globalPillIconGap) {
            Glyph(icon, size: Tokens.Sizes.globalIconSmall, relativeTo: TextRole.pill.relativeTo)
            Text(title)
                .dsTextStyle(TextRole.pill)
                .lineLimit(1)
        }
        .foregroundStyle(Tokens.Colors.globalTextPrimary)
        .padding(.leading, Tokens.Sizes.globalPillPaddingLeading)
        .padding(.trailing, Tokens.Sizes.globalPillPaddingTrailing)
        .frame(maxWidth: .infinity, minHeight: Tokens.Sizes.globalPillHeight)
        .overlay { Capsule().strokeBorder(Tokens.Colors.globalTextPrimary) }
        .contentShape(Capsule())
    }
}

/// "Add a Message" (`week.edit.layout.message`): the centred title (`sheetTitle`) with "Done" trailing (C-08, `textButton`,
/// `color.global.textPrimary`); the text from `size.global.screenMargin` (text role `placeholder`; placeholder
/// "Add a message…" in `color.global.textSecondary`), keyboard up; the counter "58/2000" (`body`, monospaced digits,
/// `color.global.textSecondary`) at the trailing margin above the keyboard. Limit `week.edit.layout.message.limit`.
struct WeekEditMessageSheet: View {
    @Binding var text: String
    @State private var draft = ""
    @FocusState private var focused: Bool
    @Environment(\.dismiss) private var dismiss

    private static let limit = Int(SocialTokenNumbers.first(in: Tokens.Layouts.WeekEditLayoutMessage.limit) ?? 0)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                Text(Copy.weekEditMessageTitle)
                    .dsTextStyle(TextRole.sheetTitle)
                    .foregroundStyle(Tokens.Colors.globalTextPrimary)
                    .accessibilityAddTraits(.isHeader)
                HStack {
                    Spacer(minLength: 0)
                    TextButton(Copy.weekEditMessageDone) {
                        text = draft
                        dismiss()
                    }
                }
            }
            .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
            .padding(.top, Tokens.Sizes.globalScreenMargin)
            TextField(
                text: $draft,
                prompt: Text(Copy.weekEditTextPlaceholder).foregroundStyle(Tokens.Colors.globalTextSecondary),
                axis: .vertical
            ) {
                Text(Copy.weekEditMessageTitle)
            }
            .dsTextStyle(TextRole.placeholder)
            .foregroundStyle(Tokens.Colors.globalTextPrimary)
            .focused($focused)
            .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
            .padding(.top, Tokens.Sizes.globalTitleToContent)
            .onChange(of: draft) { _, value in
                if Self.limit > 0, value.count > Self.limit { draft = String(value.prefix(Self.limit)) }
            }
            Spacer(minLength: 0)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Text(Copy.weekEditMessageCounter(used: String(draft.count), max: String(Self.limit)))
                .dsTextStyle(TextRole.body)
                .monospacedDigit()
                .foregroundStyle(Tokens.Colors.globalTextSecondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
                .padding(.bottom, Tokens.Sizes.globalSectionHeaderToContent)
        }
        .background(Tokens.Colors.globalBackground.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .dsSheetBackground()
        .onAppear {
            draft = text
            focused = true
        }
    }
}

/// `week.edit.layout.selectionMark` (the platform photo picker's mark, measured on Android's system picker): a square
/// cell (C-21 composer grid). Not in the recap, the photo fills it and carries no mark; in the recap, the cell fills with
/// `color.global.control`, the photo insets `selectedInsetRatio` × the cell width with corners `selectedCornerRatio` ×
/// the width, and the filled check circle (`icon.global.check` in the `size.global.checkCircle` box: the circle in
/// `color.global.selection`, the check in `color.global.textOnMedia`, on a white disc `markOutline` wider in radius)
/// sits centred `markCentreRatio` × the width from the top-leading corner. The change cross-fades
/// (`duration.global.crossfade`). Decorative: the cell's accessibility value carries the state.
struct SelectionMarkedCell: View {
    let source: PhotoSource?
    let checked: Bool

    private typealias Mark = Tokens.Layouts.WeekEditLayoutSelectionMark

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit) // provenance-ok: square cells (C-21 composer grid)
            .overlay {
                GeometryReader { proxy in
                    let cell = proxy.size.width
                    let inset = checked ? cell * Mark.selectedInsetRatio : 0
                    ZStack(alignment: .topLeading) {
                        Tokens.Colors.globalControl
                            .opacity(checked ? 1 : 0)
                        PhotoView(source: source)
                            .frame(width: max(0, cell - 2 * inset), height: max(0, cell - 2 * inset))
                            .clipShape(RoundedRectangle(cornerRadius: checked ? cell * Mark.selectedCornerRatio : 0))
                            .offset(x: inset, y: inset)
                        if checked {
                            mark
                                .offset(x: cell * Mark.markCentreRatio - Tokens.Sizes.globalCheckCircle / 2, y: cell * Mark.markCentreRatio - Tokens.Sizes.globalCheckCircle / 2)
                                .transition(.opacity)
                        }
                    }
                }
            }
            .clipShape(Rectangle())
            .dsAnimation(ComponentMotion.crossfade, value: checked)
    }

    /// The check circle on its white disc (the outline, and the check through the symbol's cut-out).
    private var mark: some View {
        let box = Tokens.Sizes.globalCheckCircle
        let disc = box * Self.glyphInk + 2 * Mark.markOutline
        return ZStack {
            Circle()
                .fill(Tokens.Colors.globalTextOnMedia)
                .frame(width: disc, height: disc)
            Glyph(Tokens.Icons.globalCheck, size: box)
                .foregroundStyle(Tokens.Colors.globalSelection)
        }
        .frame(width: box, height: box)
        .accessibilityHidden(true)
    }

    /// SF Symbols' `checkmark.circle.fill` circle fills ≈ 20 / 24 of its glyph box at the box size (the Material
    /// glyph's 20-unit ink in a 24-unit box on Android): the white disc sits just outside it.
    private static let glyphInk: CGFloat = 20.0 / 24.0 // provenance-ok: symbol glyph geometry (platform), not a design value
}
