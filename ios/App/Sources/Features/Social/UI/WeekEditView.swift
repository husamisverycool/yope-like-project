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
    /// feedback (`week.edit.haptic.dragStart`). VoiceOver: drag and drop points on every tile. (The shared `WeekStrip`
    /// has no reorder — reported as a component gap — so the strip draws `DayTile`s itself.)
    private var strip: some View {
        let posts = model.chosenPosts
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Tokens.Sizes.globalStripGap) {
                if posts.isEmpty {
                    DayTile(tile: WeekStripTile(id: "empty", kind: .placeholder, date: nil))
                        .accessibilityHidden(true)
                }
                ForEach(posts) { post in
                    let label = SocialA11y.tile(date: post.post.createdAt, name: model.profiles[post.post.authorID]?.socialFirstName ?? "", timeZone: .current)
                    DayTile(tile: WeekStripTile(id: post.id.rawValue, kind: .photo(SocialImages.source(post.media?.gridPath)), date: post.post.createdAt))
                        .contentShape(Rectangle())
                        .draggable(post.id.rawValue) {
                            DayTile(tile: WeekStripTile(id: post.id.rawValue, kind: .photo(SocialImages.source(post.media?.gridPath)), date: post.post.createdAt))
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
    /// `week.edit.layout.selectionMark` (BLOCKED: DEBUG approximation only). (The shared `PhotoGrid` has no selection
    /// state or value — reported as a component gap.)
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
                        PhotoView(source: SocialImages.source(post.media?.gridPath))
                            .aspectRatio(1, contentMode: .fit) // provenance-ok: square cells (C-21 composer grid)
                            .clipShape(Rectangle())
                            .overlay(alignment: .topTrailing) { selectionMark(checked) }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(SocialA11y.tile(date: post.post.createdAt, name: model.profiles[post.post.authorID]?.socialFirstName ?? "", timeZone: .current)))
                    .accessibilityValue(Text(checked ? Copy.weekEditA11yInRecap : Copy.weekEditA11yNotInRecap))
                    .accessibilityAddTraits(.isToggle)
                }
            }
        }
        .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
    }

    @ViewBuilder
    private func selectionMark(_ checked: Bool) -> some View {
        if SocialBlocked.showsSelectionMark {
            Glyph(checked ? Tokens.Icons.globalCheck : Tokens.Icons.globalUncheck, size: Tokens.Sizes.globalCheckCircle)
                .foregroundStyle(Tokens.Colors.globalTextOnMedia)
                .padding(SocialBlocked.selectionMarkInset)
                .accessibilityHidden(true)
        }
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
