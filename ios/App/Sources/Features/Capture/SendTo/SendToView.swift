// Surface: camera.sendto — visual reference Retro's "Postcard" composer and its "Add a Message" sheet; mechanics Locket
// (send to many, save, send states).
// Reference images: references/auto/retro/store/retro-store-03.png (ST-03: header, photo frame, "Add a message" pill,
// labelled block, hairline, 60-pt white capsule), references/auto/retro/press/tc-2023-12-retro3.png phone 2 (disabled
// "Send Postcard" #4D4D4D, rows with a hairline) and phone 3 ("Add a Message" sheet: title, Done, counter '58/250'),
// references/auto/retro/video/ig-DDbA_F7x-j7-composer-f130-147-f188-197.png (sheet presentation),
// references/owner/locket-review-sendto.jpg, -review-sending.jpg, -review-sent.jpg (mechanics)
// (design/surfaces/camera.sendto.md; MERGE_DECISIONS RC-5 … RC-8).
import DesignSystem
import SwiftUI

/// The black composer: save · "Share Photo" · close; the photo with the message pill and the voice capsule; "Groups" and
/// one check row per group; the white "Send" capsule pinned at the bottom. Media surface in both appearances; the
/// "Add a Message" sheet, the alerts and groups.create follow the system appearance (`sheetAppearance`).
struct SendToView: View {
    @State var model: SendToModel
    /// The system appearance (read by the presenter outside the media override), for the sheets over the composer.
    var sheetAppearance: ColorScheme?

    @State private var isEditingMessage = false
    @State private var isConfirmingDiscard = false
    @State private var isCreatingGroup = false
    /// The finger's travel while holding the voice capsule (the slide-to-cancel hint follows it).
    @State private var voiceSlide: CGSize = .zero

    init(model: SendToModel, sheetAppearance: ColorScheme? = nil) {
        _model = State(initialValue: model)
        self.sheetAppearance = sheetAppearance
    }

    private typealias Preview = Tokens.Layouts.CameraSendtoLayoutPreview
    private typealias Field = Tokens.Layouts.CameraSendtoLayoutMessageField
    private typealias Row = Tokens.Layouts.CameraSendtoLayoutRecipientRow

    var body: some View {
        composer
            .captureMediaAppearance()
            // A full-screen cover over media: light status-bar content (the cover's own presentation only).
            .preferredColorScheme(.dark)
            .dsHaptic(Tokens.Haptics.globalSelect, trigger: model.selectionChanges)
            .task { await model.load() }
            .sheet(isPresented: $isEditingMessage) {
                SendToMessageSheet(model: model)
                    .preferredColorScheme(sheetAppearance)
            }
            // groups.create (account group) over send-to, so the capture is kept; the list reloads after.
            .sheet(isPresented: $isCreatingGroup, onDismiss: { Task { await model.reload() } }) {
                AccountModalDestination(modal: .groupCreate)
                    .preferredColorScheme(sheetAppearance)
            }
            .alert(Copy.cameraSendtoDiscardTitle, isPresented: $isConfirmingDiscard) {
                Button(Copy.cameraSendtoDiscardConfirm, role: .destructive) { model.close() }
                Button(Copy.cameraSendtoCancel, role: .cancel) {}
            } message: {
                Text(Copy.cameraSendtoDiscardMessage)
            }
            .alert(Copy.cameraSendtoErrorSendFailed, isPresented: failureBinding, presenting: model.sendFailure) { _ in
                Button(Copy.cameraSendtoErrorRetry) { Task { await model.retrySend() } }
                Button(Copy.cameraSendtoCancel, role: .cancel) { model.dismissSendFailure() }
            } message: { failure in
                Text(failure.message)
            }
    }

    private var failureBinding: Binding<Bool> {
        Binding(get: { model.sendFailure != nil }, set: { if !$0 { model.dismissSendFailure() } })
    }

    private var composer: some View {
        GeometryReader { proxy in
            // `camera.sendto.size.sendButtonBottom` is measured from the screen bottom; the safe area already holds part of it.
            let capsuleBottom = max(0, Tokens.Sizes.cameraSendtoSizeSendButtonBottom - proxy.safeAreaInsets.bottom)
            VStack(spacing: 0) {
                header
                ScrollView {
                    content
                }
                .scrollIndicators(.hidden)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                sendCapsule
                    .padding(.horizontal, Tokens.Sizes.globalButtonMarginH)
                    .padding(.top, Row.padding)
                    .padding(.bottom, capsuleBottom)
                    .background(Tokens.Colors.globalBackgroundDeep)
            }
        }
        .background(Tokens.Colors.globalBackgroundDeep.ignoresSafeArea())
        .ignoresSafeArea(.keyboard)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("camera.sendto")
    }

    // MARK: Header (C-29 on media)

    private var header: some View {
        CaptureMediaHeader(
            leading: HeaderAction(icon: Tokens.Icons.globalDownload, accessibilityLabel: Copy.cameraSendtoA11ySave) {
                Task { await model.save() }
            },
            trailing: HeaderAction(icon: Tokens.Icons.globalClose, accessibilityLabel: Copy.cameraSendtoA11yClose) {
                if model.needsDiscardConfirmation {
                    isConfirmingDiscard = true
                } else {
                    model.close()
                }
            },
            leadingIdentifier: "camera.sendto.save",
            trailingIdentifier: "camera.sendto.close"
        ) {
            CaptureMediaHeaderTitle(text: model.isSending ? Copy.cameraSendtoSending : Copy.cameraSendtoTitle)
                .accessibilitySortPriority(9)
        }
        .disabled(model.isSending)
        .accessibilitySortPriority(10)
    }

    // MARK: Photo, groups label and rows

    private var content: some View {
        MetricStack(alignment: .center) {
            preview
                .metricGap(Preview.topBelowHeaderCircle, from: .top, to: .top)
            Text(Copy.cameraSendtoGroupsLabel)
                .dsTextRole(TextRole.meta)
                .foregroundStyle(Tokens.Colors.globalTextSecondary)
                .accessibilityAddTraits(.isHeader)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
                .accessibilitySortPriority(5)
                .capHeight(of: TextRole.meta)
                // Photo bottom → label cap top: ST-03 measures 35.2 pt (a prose-only value of
                // `camera.sendto.layout.recipientRow`); the token geometry is Retro's section gap (strip bottom → next
                // section header cap top), `size.global.sectionGap`.
                .metricGap(Tokens.Sizes.globalSectionGap, from: .bottom, to: .capTop)
            groups
                .frame(maxWidth: .infinity)
                .accessibilitySortPriority(4)
        }
    }

    /// `camera.sendto.layout.preview`: 297.6 pt wide, native aspect (camera photos 3:4 → 396.8 pt), at most 422.8 tall,
    /// aspect-fill, corners 8.5 (continuous); the message pill and voice capsule centred 20.5 pt above its bottom.
    private var preview: some View {
        let aspect = model.media.still.map { CGFloat($0.pixelWidth) / CGFloat(max($0.pixelHeight, 1)) }
            ?? Tokens.Layouts.CameraCaptureLayoutViewfinder.aspect
        let height = min(Preview.width / max(aspect, .leastNonzeroMagnitude), Preview.maxHeight)
        return ZStack {
            Tokens.Colors.globalBackgroundDeep
            CapturePreviewMedia(media: model.media, still: model.previewImage)
                .frame(width: Preview.width, height: height)
                .clipped()
                .accessibilityHidden(true)
        }
        .frame(width: Preview.width, height: height)
        .clipShape(DSShape.rounded(Preview.cornerRadius))
        .overlay(alignment: .bottom) {
            pillRow
                .padding(.bottom, Field.bottomInset)
        }
    }

    /// The message pill (C-09 on media: `icon.global.edit` + "Add a message" / "Edit message") then, `size.global.pillGap`
    /// after it, the voice capsule. While a voice note records (or a draft is paused) the recording capsule takes the
    /// pill's place (chat.voice).
    private var pillRow: some View {
        HStack(spacing: Tokens.Sizes.globalPillGap) {
            ZStack {
                if model.voicePhase == .idle {
                    LightPill(model.hasMessage ? Copy.cameraSendtoMessageEdit : Copy.cameraSendtoMessageAdd, icon: Tokens.Icons.globalEdit, style: .dark) {
                        isEditingMessage = true
                    }
                    .contentTransition(.opacity)
                    .dsAnimation(ComponentMotion.crossfade, value: model.hasMessage)
                    .disabled(model.isSending)
                    .accessibilitySortPriority(7)
                    .accessibilityIdentifier("camera.sendto.message")
                    .dsTransition(.opacity)
                } else {
                    SendToRecordingCapsule(model: model, slide: voiceSlide)
                        .dsTransition(.opacity)
                }
            }
            .dsAnimation(ComponentMotion.fade, value: model.voicePhase == .idle)
            // The recording capsule can take the photo's width less the voice capsule and the gap; sliding left past
            // half of it cancels (chat.voice "slide left past the hint").
            SendToVoiceCapsule(
                model: model,
                rowWidth: Preview.width - Tokens.Sizes.globalIconPillWidth - Tokens.Sizes.globalPillGap,
                slide: $voiceSlide
            )
            .accessibilitySortPriority(6)
        }
    }

    @ViewBuilder
    private var groups: some View {
        switch model.listState {
        case .idle:
            Color.clear.frame(height: 0)
        case .loading:
            // C-28: the platform activity indicator (`color.global.textSecondary`) in the rows area.
            LoadingHUD()
                .padding(.vertical, Row.padding)
                .accessibilityIdentifier("camera.sendto.loading")
        case .empty:
            EmptyStateView(
                icon: Tokens.Icons.globalGroup,
                title: Copy.cameraSendtoEmptyTitle,
                detail: Copy.cameraSendtoEmptyDetail,
                action: model.canCreateGroup ? EmptyStateView.Action(Copy.cameraSendtoEmptyButton) { isCreatingGroup = true } : nil
            )
            .padding(.vertical, Row.padding)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("camera.sendto.empty")
        case .offline:
            EmptyStateView(
                title: nil,
                detail: Copy.cameraSendtoErrorOffline,
                action: EmptyStateView.Action(Copy.cameraSendtoErrorRetry) { Task { await model.reload() } }
            )
            .padding(.vertical, Row.padding)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("camera.sendto.offline")
        case .failed:
            EmptyStateView(
                title: nil,
                detail: Copy.cameraSendtoErrorGeneric,
                action: EmptyStateView.Action(Copy.cameraSendtoErrorRetry) { Task { await model.reload() } }
            )
            .padding(.vertical, Row.padding)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("camera.sendto.failed")
        case .loaded:
            VStack(spacing: 0) {
                ForEach(Array(model.groups.enumerated()), id: \.element.id) { index, group in
                    if index > 0 {
                        // C-32 between rows, inside the margins; the separator's dark value on media (#4D4D4D).
                        HairlineDivider()
                            .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
                    }
                    SendToGroupRow(
                        group: group,
                        cover: model.covers[group.id],
                        isSelected: model.isSelected(group.id)
                    ) {
                        model.toggle(group.id)
                    }
                    .disabled(model.isSending)
                }
            }
        }
    }

    // MARK: Send (C-05 on media)

    private var sendCapsule: some View {
        PrimaryButton(Copy.cameraSendtoSend, surface: .media, isEnabled: model.canSend, isBusy: model.isSending) {
            Task { await model.send() }
        }
        .accessibilitySortPriority(3)
        .accessibilityIdentifier("camera.sendto.send")
    }
}

/// One group (C-16 row on media, `camera.sendto.layout.recipientRow`): the cover in a `size.global.avatarPicker` circle
/// (no cover: `icon.global.group` on `color.global.controlOnDeep`), the name (text role `listTitle`,
/// `color.global.textOnMedia`) starting `size.global.cardNameGap` after it, and the trailing check
/// (`size.global.checkCircle`: `icon.global.check` in `color.global.selection` / `icon.global.uncheck` in
/// `color.global.textSecondary`) with its ink on the margin; `padding` (16) above and below the avatar (69-pt row).
/// `PeopleRow` (C-16) has no avatar → name gap token and no check slot, so the row is composed here (gap reported).
/// Tap toggles (multi-select, `haptic.global.select`); accessibility: the name, selected trait.
struct SendToGroupRow: View {
    let group: CaptureGroup
    let cover: UIImage?
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 0) {
                AvatarView(source: cover.map { PhotoSource.image($0) }, diameter: Tokens.Sizes.globalAvatarPicker, placeholderIcon: Tokens.Icons.globalGroup)
                Text(group.name)
                    .dsTextStyle(TextRole.listTitle)
                    .foregroundStyle(Tokens.Colors.globalTextOnMedia)
                    .lineLimit(1)
                    .padding(.leading, Tokens.Sizes.globalCardNameGap)
                Spacer(minLength: Tokens.Sizes.globalCardNameGap)
                Image(systemName: isSelected ? Tokens.Icons.globalCheck : Tokens.Icons.globalUncheck)
                    .resizable()
                    .scaledToFit()
                    .frame(width: Tokens.Sizes.globalCheckCircle, height: Tokens.Sizes.globalCheckCircle)
                    .foregroundStyle(isSelected ? Tokens.Colors.globalSelection : Tokens.Colors.globalTextSecondary)
                    .contentTransition(.opacity)
                    .dsAnimation(ComponentMotion.crossfade, value: isSelected)
            }
            .padding(.vertical, Tokens.Layouts.CameraSendtoLayoutRecipientRow.padding)
            .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(group.name))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("camera.sendto.row.\(group.id)")
    }
}

/// The "Add a Message" sheet (`camera.sendto.layout.messageSheet`; TC-R3 phone 3): a native page sheet that follows the
/// appearance (page `color.global.background`), its toolbar with the centred title (text role `sheetTitle`) and the
/// trailing "Done" (C-08, text role `textButton`, `color.global.textPrimary`); the multi-line field from
/// `textInset` (22), text role `placeholder` (17), typed text `color.global.textPrimary`, placeholder
/// `camera.sendto.caption.placeholder` in `color.global.textSecondary`; the counter '58/250'
/// (`camera.sendto.fontSize.counter`, monospaced digits, `color.global.textSecondary`) trailing `counterTrailingInset`
/// (20.7) from the edge and `counterAboveKeyboard` (22) above the keyboard. Input stops at 250 characters; "Done" or a
/// swipe down keeps the text; an empty field clears the message.
struct SendToMessageSheet: View {
    @Bindable var model: SendToModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool

    private typealias Sheet = Tokens.Layouts.CameraSendtoLayoutMessageSheet

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                TextField(
                    text: $model.caption,
                    prompt: Text(Copy.cameraSendtoCaptionPlaceholder).foregroundStyle(Tokens.Colors.globalTextSecondary),
                    axis: .vertical
                ) {
                    Text(Copy.cameraSendtoMessageTitle)
                }
                .dsTextStyle(TextRole.placeholder)
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
                .tint(Tokens.Colors.globalSelection)
                .focused($isFocused)
                .onChange(of: model.caption) { _, _ in model.clampCaption() }
                .padding(.horizontal, Sheet.textInset)
                .padding(.top)
                .accessibilityIdentifier("camera.sendto.message.field")
                Spacer(minLength: 0)
                Text(CaptureFormat.messageCounter(count: model.caption.count, max: SendToModel.captionMaxLength))
                    .dsTextStyle(CaptureType.counter)
                    .fontDesign(.monospaced)
                    .monospacedDigit()
                    .foregroundStyle(Tokens.Colors.globalTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, Sheet.counterTrailingInset)
                    .padding(.bottom, Sheet.counterAboveKeyboard)
                    .accessibilityLabel(Text(Copy.globalA11yPagePosition(position: String(model.caption.count), count: String(SendToModel.captionMaxLength))))
                    .accessibilityIdentifier("camera.sendto.message.counter")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Tokens.Colors.globalBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(Copy.cameraSendtoMessageTitle)
                        .dsTextStyle(TextRole.sheetTitle)
                        .foregroundStyle(Tokens.Colors.globalTextPrimary)
                        .accessibilityAddTraits(.isHeader)
                }
                ToolbarItem(placement: .confirmationAction) {
                    TextButton(Copy.cameraSendtoMessageDone) { dismiss() }
                        .accessibilityIdentifier("camera.sendto.message.done")
                }
            }
        }
        .dsSheetBackground()
        .presentationDragIndicator(.visible)
        .onAppear { isFocused = true }
    }
}
