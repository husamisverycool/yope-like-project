// Surface: birthday.contribute — Retro's "Add to Your Week" composer sheet, the dark postcard composer and the "Add a
// Message" modal, in Tribute / VidDay's order (choose a photo → write a line → send) (design/surfaces/birthday.contribute.md,
// MERGE RM-11). Reference images: references/auto/retro/video/ig-DDbA_F7x-j7-composer-f130-147-f188-197.png (VID-COMP),
// references/auto/retro/store/retro-store-03.png (ST-03, postcard composer), references/auto/retro/press/tc-2023-12-retro3.png
// phone 3 ('Add a Message' modal and counter). Components: C-29 (sheet, toolbar), C-21 (composer grid), C-11, C-09, C-05,
// C-08, C-27, C-26.
import AppData
import DesignSystem
import SwiftUI

/// The contribution flow in a page sheet with its own navigation stack: step 1 chooses a photo you posted or are in;
/// step 2 (dark in both appearances) shows it with the "Add a message" pill and "Add to video"; the pill opens the
/// "Add a Message" modal (step 2a, follows the appearance). Sending closes the sheet ("Added to video!" is announced).
///
/// - Parameter onOpenGroup: the empty state's "View {group}": the presenter closes too and shows the group.
@MainActor
struct BirthdayContributeScreen: View {
    let requestID: String
    @State private var model: BirthdayContributeModel
    private let onOpenGroup: ((String) -> Void)?
    @Environment(\.dismiss) private var dismiss
    /// The sheet's own appearance (the system's): step 2a follows it although step 2 renders dark.
    @Environment(\.colorScheme) private var systemScheme

    init(requestID: String, model: BirthdayContributeModel? = nil, onOpenGroup: ((String) -> Void)? = nil) {
        self.requestID = requestID
        _model = State(initialValue: model ?? BirthdayContributeModel(requestID: TributeRequestID(requestID), dependencies: .current))
        self.onOpenGroup = onOpenGroup
    }

    var body: some View {
        NavigationStack(path: $model.path) {
            BirthdayContributePicker(model: model)
                .navigationDestination(for: BirthdayContributeModel.Step.self) { _ in
                    BirthdayContributeComposer(model: model, modalScheme: systemScheme)
                }
        }
        .dsSheetBackground()
        .interactiveDismissDisabled(model.isSending)
        .task { await model.loadIfNeeded() }
        .onDisappear { model.stopListening() }
        .onChange(of: model.isFinished) { _, finished in
            guard finished else { return }
            if model.openGroupRequested, let group = model.groupID {
                onOpenGroup?(group.rawValue)
            }
            dismiss()
        }
        .accessibilityIdentifier("birthday.contribute")
    }
}

// MARK: - Step 1 — Choose a Photo

/// Native toolbar "Cancel / Choose a Photo / Next" (C-29, system tint), the grey line (text role `body`,
/// `color.global.textSecondary`, at `size.global.screenMargin`), then the composer grid (C-21: Retro's composer columns —
/// `week.edit.count.gridColumns`, the same "Add to Your Week" grid — square cells, `size.global.stripGap` gaps,
/// `radius.global.photo`, full width). One photo at a time: the selected cell shows the check (`icon.global.check`,
/// `color.global.selection`, `size.global.checkCircle`, inset `size.global.badgeInset` from its top-right corner; the
/// platform picker's filled check, PLATFORM), fading in over `duration.global.fade`.
struct BirthdayContributePicker: View {
    @Bindable var model: BirthdayContributeModel

    private var columns: Int { max(1, Int(Tokens.Counts.weekEditCountGridColumns)) }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Tokens.Colors.globalBackground.ignoresSafeArea())
            .sheetToolbar(
                title: Copy.birthdayContributePickerTitle,
                cancelTitle: Copy.birthdayContributePickerCancel,
                onCancel: { model.finish() },
                confirmTitle: Copy.birthdayContributePickerNext,
                isConfirmEnabled: model.canUsePhoto,
                onConfirm: { model.usePhoto() }
            )
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .idle, .loading:
            ScrollView {
                VStack(alignment: .leading) {
                    subtitle
                    placeholders
                }
            }
            .scrollDisabled(true)
            .onAppear { AccessibilityNotification.Announcement(Copy.birthdayContributeLoading).post() }
        case .loaded:
            ScrollView {
                VStack(alignment: .leading) {
                    subtitle
                    if model.inline == .notEligible {
                        Text(Copy.birthdayContributeNotEligible)
                            .dsTextStyle(TextRole.meta)
                            .foregroundStyle(Tokens.Colors.globalDestructive)
                            .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
                            .accessibilityIdentifier("birthday.contribute.notEligible")
                    }
                    grid
                }
            }
        case .empty:
            EmptyStateView(
                title: Copy.birthdayContributePickerEmptyTitle,
                detail: Copy.birthdayContributePickerEmptyDetail(group: model.groupName),
                action: EmptyStateView.Action(Copy.birthdayContributePickerEmptyAction(group: model.groupName)) { model.openGroup() }
            )
            .frame(maxHeight: .infinity)
            .accessibilityIdentifier("birthday.contribute.empty")
        case .closed:
            EmptyStateView(title: Copy.birthdayContributeClosed(name: model.honoreeName))
                .frame(maxHeight: .infinity)
                .accessibilityIdentifier("birthday.contribute.closed")
        case .error:
            EmptyStateView(
                title: Copy.birthdayContributeErrorTitle, detail: Copy.birthdayContributeErrorDetail,
                action: EmptyStateView.Action(Copy.birthdayContributeErrorRetry) { Task { await model.retry() } }
            )
            .frame(maxHeight: .infinity)
        case .offline:
            EmptyStateView(
                title: nil, detail: Copy.birthdayContributeOffline,
                action: EmptyStateView.Action(Copy.birthdayContributeErrorRetry) { Task { await model.retry() } }
            )
            .frame(maxHeight: .infinity)
        }
    }

    private var subtitle: some View {
        Text(Copy.birthdayContributePickerSubtitle)
            .dsTextStyle(TextRole.body)
            .foregroundStyle(Tokens.Colors.globalTextSecondary)
            .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
            .padding(.vertical)
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: Tokens.Sizes.globalStripGap), count: columns)
    }

    private var grid: some View {
        MemoryImageScope { images in
            LazyVGrid(columns: gridColumns, spacing: Tokens.Sizes.globalStripGap) {
                ForEach(Array(model.photos.enumerated()), id: \.element.id) { offset, photo in
                    cell(photo, source: images.source(photo.thumbURL), offset: offset)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func cell(_ photo: BirthdayContributeModel.EligiblePhoto, source: PhotoSource?, offset: Int) -> some View {
        let isSelected = model.selectedID == photo.id
        return Button {
            model.select(photo.id)
        } label: {
            PhotoView(source: source)
                .aspectRatio(1, contentMode: .fit) // provenance-ok: square cells (C-21)
                .clipShape(DSShape.rounded(Tokens.Radii.globalPhoto))
                .overlay(alignment: .topTrailing) {
                    if isSelected {
                        Image(systemName: Tokens.Icons.globalCheck)
                            .resizable()
                            .scaledToFit()
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(Tokens.Colors.globalTextOnMedia, Tokens.Colors.globalSelection)
                            .frame(width: Tokens.Sizes.globalCheckCircle, height: Tokens.Sizes.globalCheckCircle)
                            .padding(Tokens.Sizes.globalBadgeInset)
                            .dsTransition(.opacity)
                    }
                }
                .dsAnimation(ComponentMotion.fade, value: isSelected)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(Copy.birthdayContributeA11yPhoto(date: MemoryFormat.memoryDate(photo.createdAt, timeZone: .current))))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("birthday.contribute.photo." + String(offset)) // provenance-ok: accessibility identifier
    }

    /// Loading: C-17 placeholder tiles (`color.global.control`) in the grid's cells, filling the visible page.
    private var placeholders: some View {
        GeometryReader { proxy in
            let side = (proxy.size.width - CGFloat(columns - 1) * Tokens.Sizes.globalStripGap) / CGFloat(columns)
            let rows = side > 0 ? Int((proxy.size.height / (side + Tokens.Sizes.globalStripGap)).rounded(.up)) : 0
            LazyVGrid(columns: gridColumns, spacing: Tokens.Sizes.globalStripGap) {
                ForEach(0..<(rows * columns), id: \.self) { _ in
                    Tokens.Colors.globalControl
                        .aspectRatio(1, contentMode: .fit) // provenance-ok: square cells (C-21)
                }
            }
        }
        .containerRelativeFrame(.vertical)
        .accessibilityHidden(true)
    }
}

// MARK: - Step 2 — the composer (dark)

/// The postcard-style composer on `color.global.backgroundDeep` (dark in both appearances): the sheet header (C-29:
/// back, centred `birthday.contribute.composer.title` in text role `sheetTitle`, C-11 close on media); the photo fitted
/// (own aspect) in a `dimension.birthday.contribute.photoWidth` × `.photoMaxHeight` box, `dimension.birthday.contribute
/// .titleToPhoto` below the title's baseline, corners `radius.birthday.contribute.photo`; on it the C-09 dark pill
/// (`icon.global.edit` + "Add a message" / "Edit message") `dimension.birthday.contribute.pillBottom` above its bottom;
/// the line under it; pinned to the bottom the C-05 capsule on media "Add to video".
struct BirthdayContributeComposer: View {
    @Bindable var model: BirthdayContributeModel
    let modalScheme: ColorScheme

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                MetricStack(alignment: .center) {
                    header
                    if let photo = model.selectedPhoto {
                        photoBox(photo)
                            .metricGap(Tokens.Sizes.birthdayContributeTitleToPhoto, from: .lastBaseline, to: .top)
                    }
                    if !model.trimmedLine.isEmpty {
                        Text(model.line)
                            .dsTextStyle(TextRole.body)
                            .foregroundStyle(Tokens.Colors.globalTextOnMedia)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Tokens.Sizes.globalButtonMarginH)
                            .accessibilityIdentifier("birthday.contribute.line")
                            .metricGap(Tokens.Sizes.globalListGap, from: .bottom, to: .top)
                    }
                    inlineState
                        .metricGap(Tokens.Sizes.globalListGap, from: .bottom, to: .top)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            PrimaryButton(
                model.inline == .error ? Copy.birthdayContributeErrorRetry : Copy.birthdayContributeSubmit,
                surface: .media,
                isEnabled: model.canSubmit || model.isSending,
                isBusy: model.isSending
            ) {
                Task { await model.submit() }
            }
            .padding(.horizontal, Tokens.Sizes.globalButtonMarginH)
            .accessibilityIdentifier("birthday.contribute.submit")
        }
        .background(Tokens.Colors.globalBackgroundDeep.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
        .toolbar(.hidden, for: .navigationBar)
        .dsAnimation(ComponentMotion.crossfade, value: model.canSubmit)
        .sheet(isPresented: $model.showsMessage, onDismiss: { _ = model.normalizeLine() }) {
            BirthdayContributeMessage(model: model)
                .environment(\.colorScheme, modalScheme)
        }
    }

    /// The title's baselines are the row's; back and close are centred on its cap middle.
    private var header: some View {
        Text(Copy.birthdayContributeComposerTitle)
            .dsTextRole(TextRole.sheetTitle)
            .foregroundStyle(Tokens.Colors.globalTextOnMedia)
            .multilineTextAlignment(.center)
            .lineLimit(1)
            .padding(.horizontal, Tokens.Sizes.globalHeaderButton + Tokens.Sizes.globalScreenMargin)
            .frame(maxWidth: .infinity, minHeight: Tokens.Sizes.globalMinTouchTargetIos)
            .accessibilityAddTraits(.isHeader)
            .overlay(alignment: Alignment(horizontal: .leading, vertical: .capMiddle)) {
                HeaderIconButton(icon: Tokens.Icons.globalBack, accessibilityLabel: Copy.onthisdayA11yBack, color: Tokens.Colors.globalTextOnMedia) {
                    model.path = []
                }
                .accessibilityIdentifier("birthday.contribute.back")
            }
            .overlay(alignment: Alignment(horizontal: .trailing, vertical: .capMiddle)) {
                CircleButton(
                    icon: Tokens.Icons.globalClose, accessibilityLabel: Copy.birthdayContributeA11yClose, style: .media,
                    glyphSize: Tokens.Sizes.globalIconSmall
                ) {
                    model.finish()
                }
                .padding(.trailing, Tokens.Sizes.globalScreenMargin)
                .accessibilityIdentifier("birthday.contribute.close")
            }
            .padding(.top, Tokens.Sizes.globalScreenMargin)
    }

    private func photoBox(_ photo: BirthdayContributeModel.EligiblePhoto) -> some View {
        let box = CGSize(width: Tokens.Sizes.birthdayContributePhotoWidth, height: Tokens.Sizes.birthdayContributePhotoMaxHeight)
        let aspect = photo.aspectRatio ?? box.width / box.height
        let width = min(box.width, box.height * aspect)
        let height = width / aspect
        let hasLine = !model.trimmedLine.isEmpty
        return MemoryRemoteImage(url: photo.displayURL)
            .frame(width: width, height: height)
            .clipShape(DSShape.rounded(Tokens.Radii.birthdayContributePhoto))
            .accessibilityHidden(true)
            .overlay(alignment: .bottom) {
                LightPill(hasLine ? Copy.birthdayContributeMessageEdit : Copy.birthdayContributeMessageAdd, icon: Tokens.Icons.globalEdit, style: .dark) {
                    model.editMessage()
                }
                .dsAnimation(ComponentMotion.crossfade, value: hasLine)
                .padding(.bottom, Tokens.Sizes.birthdayContributePillBottom)
                .accessibilityIdentifier("birthday.contribute.pill")
            }
            .frame(width: box.width, height: height)
    }

    /// Offline: a C-12 inline line (text role `meta`, `color.global.textSecondary`); error: the C-27 error block (the
    /// capsule retries).
    @ViewBuilder
    private var inlineState: some View {
        switch model.inline {
        case .offline?:
            Text(Copy.birthdayContributeOffline)
                .dsTextStyle(TextRole.meta)
                .foregroundStyle(Tokens.Colors.globalTextSecondary)
                .padding(.horizontal, Tokens.Sizes.globalButtonMarginH)
                .accessibilityIdentifier("birthday.contribute.offline")
        case .error?:
            EmptyStateView(title: Copy.birthdayContributeErrorTitle, detail: Copy.birthdayContributeErrorDetail)
                .accessibilityIdentifier("birthday.contribute.error")
        case .notEligible?, nil:
            Color.clear.frame(height: 0)
        }
    }
}

// MARK: - Step 2a — "Add a Message"

/// The modal (C-29 page sheet, follows the appearance): centred title `birthday.contribute.message.title` (text role
/// `sheetTitle`) with the app-drawn "Done" (C-08, text role `textButton`, `color.global.textPrimary`) at
/// `dimension.birthday.contribute.counterInset` from the edge; the free text at `.messageInset` (text role
/// `placeholder`, no fill), keyboard up on open; the counter ("{count}/{max}", monospaced digits,
/// `color.global.textSecondary`) at the trailing `.counterInset`, its baseline `.counterAboveKeyboard` above the
/// keyboard. Input stops at `layout.birthday.contribute.lineMax`; a typed return is Done.
struct BirthdayContributeMessage: View {
    @Bindable var model: BirthdayContributeModel
    @FocusState private var focused: Bool

    init(model: BirthdayContributeModel) {
        _model = Bindable(model)
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(Copy.birthdayContributeMessageTitle)
                .dsTextStyle(TextRole.sheetTitle)
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
                .frame(maxWidth: .infinity, minHeight: Tokens.Sizes.globalMinTouchTargetIos)
                .overlay(alignment: .trailing) {
                    TextButton(Copy.birthdayContributeMessageDone) {
                        model.doneEditing()
                    }
                    .padding(.trailing, Tokens.Sizes.birthdayContributeCounterInset)
                    .accessibilityIdentifier("birthday.contribute.done")
                }
                .padding(.top, Tokens.Sizes.globalScreenMargin)
            TextField(
                text: $model.line,
                prompt: Text(Copy.birthdayContributeMessagePlaceholder).foregroundStyle(Tokens.Colors.globalTextSecondary),
                axis: .vertical
            ) {
                Text(Copy.birthdayContributeMessageTitle)
            }
            .dsTextStyle(TextRole.placeholder)
            .foregroundStyle(Tokens.Colors.globalTextPrimary)
            .focused($focused)
            .padding(.horizontal, Tokens.Sizes.birthdayContributeMessageInset)
            .padding(.top, Tokens.Sizes.globalScreenMargin)
            .accessibilityHint(Text(model.counter))
            .accessibilityIdentifier("birthday.contribute.field")
            .onChange(of: model.line) { _, _ in
                if model.normalizeLine() { model.doneEditing() }
            }
            Spacer(minLength: 0)
            MetricStack(alignment: .trailing) {
                Text(model.counter)
                    .dsTextRole(TextRole.placeholder)
                    .monospacedDigit()
                    .foregroundStyle(Tokens.Colors.globalTextSecondary)
                    .accessibilityHidden(true)
                Color.clear
                    .frame(height: 0)
                    .metricGap(Tokens.Sizes.birthdayContributeCounterAboveKeyboard, from: .lastBaseline, to: .top)
            }
            .padding(.trailing, Tokens.Sizes.birthdayContributeCounterInset)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .background(Tokens.Colors.globalBackground.ignoresSafeArea())
        .presentationDetents([.large])
        .onAppear { focused = true }
        .accessibilityIdentifier("birthday.contribute.message")
    }
}
