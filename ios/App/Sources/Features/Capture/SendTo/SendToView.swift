// Surface: camera.sendto — reference app: Yope (+ Locket, C-5).
// Reference images: references/auto/yope/frames/a-chuongxetank-7694968408424582452-t6.73-sendto-voice-tooltip.png,
// a-savannahclooney-7683341732695592206-t5.73-sendto-caption-keyboard.png,
// a-jacob-7691153057177931039-t4.73-sendto-voice-tooltip.png, a-virgi-7686278541255642390-t56.23-sendto-three-selected-es.png,
// a-chuongxetank-7694968408424582452-t7.73-posted-toast-contacts-card.png (design/surfaces/camera.sendto.md).
import DesignSystem
import SwiftUI

/// 'send to...': header, preview card (hour overlay, caption, message field, mic), recipient rows
/// with check circles, and the lime 'send ⓝ' button.
struct SendToView: View {
    @State var model: SendToModel
    @FocusState private var isCaptionFocused: Bool
    @State private var isCreatingGroup = false
    /// The finger's travel while holding the mic (the slide-to-cancel hint follows it).
    @State private var voiceSlide: CGSize = .zero

    private typealias Preview = Tokens.Layouts.CameraSendtoLayoutPreview
    private typealias Field = Tokens.Layouts.CameraSendtoLayoutMessageField
    private typealias Row = Tokens.Layouts.CameraSendtoLayoutRecipientRow

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let previewBottom = Preview.top + Preview.height
            ZStack(alignment: .top) {
                Tokens.Colors.globalBackgroundDeep
                recipients(width: width)
                    .frame(width: width)
                    .padding(.top, previewBottom)
                header
                    .frame(width: width, height: Tokens.Sizes.globalHeaderButton)
                    .offset(y: Preview.top - Preview.gapBelowHeader - Tokens.Sizes.globalHeaderButton)
                previewCard
                    .frame(width: Preview.width, height: Preview.height)
                    .offset(y: Preview.top)
                if model.canSend {
                    sendButton
                        .frame(width: width - Tokens.Sizes.globalButtonMarginHSheet * 2)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, Tokens.Sizes.cameraSendtoSizeSendButtonBottom)
                }
            }
        }
        .ignoresSafeArea()
        .ignoresSafeArea(.keyboard)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("camera.sendto")
        .dsHaptic(Tokens.Haptics.globalSelect, trigger: model.selectionChanges)
        .captureSendStatus(model.statusCenter)
        .task { await model.load() }
        // groups.create (account group) over send-to, so the capture is kept; the list reloads after.
        .sheet(isPresented: $isCreatingGroup, onDismiss: { Task { await model.reload() } }) {
            AccountModalDestination(modal: .groupCreate)
        }
    }

    // MARK: Header

    private var header: some View {
        ZStack {
            Text(Copy.cameraSendtoTitle)
                .dsTextStyle(CaptureType.sheetTitle)
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
                .accessibilityAddTraits(.isHeader)
                .accessibilitySortPriority(9)
            HStack {
                HeaderCircleButton(icon: Tokens.Icons.globalClose, accessibilityLabel: Copy.cameraSendtoA11yClose, fill: .onDeep) {
                    model.close()
                }
                .accessibilitySortPriority(10)
                .accessibilityIdentifier("camera.sendto.close")
                Spacer()
                HeaderCircleButton(icon: Tokens.Icons.globalDownload, accessibilityLabel: Copy.cameraSendtoA11ySave, fill: .onDeep) {
                    Task { await model.save() }
                }
                .accessibilitySortPriority(8)
                .accessibilityIdentifier("camera.sendto.save")
            }
            .padding(.horizontal, Tokens.Sizes.globalHeaderInset)
        }
    }

    // MARK: Preview card

    private var previewCard: some View {
        ZStack {
            Tokens.Colors.globalBackgroundDeep
            CapturePreviewMedia(media: model.media, still: model.previewImage)
                .frame(width: Preview.width, height: Preview.height)
                .clipped()
                .accessibilityHidden(true)
            overlayAndCaption
            messageRow
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, Field.insetBottom)
            if model.showsVoiceCoach && !isCaptionFocused && model.voicePhase == .idle {
                voiceCoach
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radii.globalPhoto, style: .continuous))
    }

    /// Hour overlay centred; the caption's baseline sits `captionBaselineOffset` under the overlay's.
    private var overlayAndCaption: some View {
        Text(CaptureFormat.hourOverlay(at: model.media.capturedAt))
            .dsTextStyle(CaptureType.overlayTimeCamera)
            .foregroundStyle(Tokens.Colors.globalTextPrimary)
            .alignmentGuide(.captionBaseline) { dimensions in dimensions[.lastTextBaseline] }
            .overlay(alignment: Alignment(horizontal: .center, vertical: .captionBaseline)) {
                if !model.caption.isEmpty {
                    Text(model.caption)
                        .dsTextStyle(CaptureType.sendCaption)
                        .foregroundStyle(Tokens.Colors.globalTextPrimary)
                        .multilineTextAlignment(.center)
                        .frame(width: Preview.width)
                        .fixedSize(horizontal: false, vertical: true)
                        .alignmentGuide(.captionBaseline) { dimensions in
                            dimensions[.firstTextBaseline] - Tokens.Sizes.cameraSendtoSizeCaptionBaselineOffset
                        }
                        .accessibilityHidden(true)
                }
            }
            .accessibilitySortPriority(7)
    }

    /// Message field capsule + mic circle, both filled `camera.sendto.color.messageField` (the backdrop
    /// blur under it was not measured, so the tint is drawn alone). The field hides while the keyboard
    /// is up; while a voice note records (or one is attached) the recorder row takes its place.
    private var messageRow: some View {
        let fieldWidth = Preview.width - Field.insetLeading - Field.gapToMic - Field.micDiameter - Field.insetTrailing
        return HStack(spacing: Field.gapToMic) {
            ZStack {
                if model.showsVoiceRow {
                    SendToVoiceRow(model: model, slide: voiceSlide)
                } else {
                    captionField
                }
            }
            .frame(width: fieldWidth, height: Field.height)
            .background(Tokens.Colors.cameraSendtoColorMessageField, in: Capsule())
            .opacity(isCaptionFocused ? 0 : 1)
            SendToMicButton(model: model, fieldWidth: fieldWidth, slide: $voiceSlide)
                .accessibilitySortPriority(5)
        }
        .padding(.leading, Field.insetLeading)
        .padding(.trailing, Field.insetTrailing)
    }

    private var captionField: some View {
        TextField(text: $model.caption, prompt: Text(Copy.cameraSendtoCaptionPlaceholder).foregroundStyle(Tokens.Colors.globalTextPrimary)) {
            Text(Copy.cameraSendtoCaptionPlaceholder)
        }
        .dsTextStyle(CaptureType.messagePlaceholder)
        .foregroundStyle(Tokens.Colors.globalTextPrimary)
        .focused($isCaptionFocused)
        .submitLabel(.done)
        .onSubmit { isCaptionFocused = false }
        .onChange(of: model.caption) { _, _ in model.clampCaption() }
        .padding(.horizontal, Field.height / 2)
        .contentShape(Capsule())
        .accessibilitySortPriority(6)
        .accessibilityIdentifier("camera.sendto.caption")
    }

    /// The Yope coach pointing at the mic, wrapping within the card.
    private var voiceCoach: some View {
        let coachWidth = Preview.width - Field.insetLeading - Field.insetTrailing
        return CaptureCoachTooltip(
            text: Copy.cameraSendtoCoachVoice,
            maxTextWidth: coachWidth - Tokens.Layouts.CameraCaptureLayoutCoach.paddingHorizontal * 2
                - Tokens.Layouts.CameraCaptureLayoutCoach.textToCloseGap - Tokens.Layouts.CameraCaptureLayoutCoach.closeGlyph,
            onClose: { model.dismissVoiceCoach() }
        )
        .frame(width: coachWidth)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, Field.insetBottom + Field.micDiameter + Tokens.Layouts.CameraCaptureLayoutCoach.pointerToTarget)
        .accessibilityIdentifier("camera.sendto.coach")
    }

    // MARK: Recipients

    @ViewBuilder
    private func recipients(width: CGFloat) -> some View {
        switch model.listState {
        case .idle:
            Color.clear
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .empty:
            CaptureEmptyState(
                title: Copy.cameraSendtoEmptyTitle,
                detail: Copy.cameraSendtoEmptyDetail,
                buttonTitle: model.canCreateGroup ? Copy.cameraSendtoEmptyButton : nil,
                action: model.canCreateGroup ? { isCreatingGroup = true } : nil
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("camera.sendto.empty")
        case .offline:
            CaptureEmptyState(
                title: Copy.cameraSendtoErrorOffline,
                buttonTitle: Copy.cameraSendtoErrorRetry,
                action: { Task { await model.reload() } }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("camera.sendto.offline")
        case .failed:
            CaptureLightPill(title: Copy.cameraSendtoErrorRetry) {
                Task { await model.reload() }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("camera.sendto.failed")
        case .loaded:
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(model.groups) { group in
                        recipientRow(group)
                    }
                }
                .padding(.top, Row.firstRowCenterBelowPreview - Row.pitch / 2)
                .padding(.bottom, Tokens.Sizes.globalButtonHeightSheet + Tokens.Sizes.cameraSendtoSizeSendButtonBottom)
            }
            .scrollIndicators(.hidden)
            .accessibilitySortPriority(4)
        }
    }

    private func recipientRow(_ group: CaptureGroup) -> some View {
        let avatar = Tokens.Sizes.globalAvatarSmall
        let selected = model.isSelected(group.id)
        return Button {
            model.toggle(group.id)
        } label: {
            HStack(spacing: Row.nameInset - Row.avatarCenterInset - avatar / 2) {
                groupAvatar(group)
                    .frame(width: avatar, height: avatar)
                Text(group.name)
                    .dsTextStyle(CaptureType.headerTitle)
                    .foregroundStyle(Tokens.Colors.globalTextPrimary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                CaptureCheckCircle(isSelected: selected)
            }
            .padding(.leading, Row.avatarCenterInset - avatar / 2)
            .padding(.trailing, Row.checkTrailingInset)
            .frame(height: Row.pitch)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(group.name)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("camera.sendto.row.\(group.id)")
    }

    @ViewBuilder
    private func groupAvatar(_ group: CaptureGroup) -> some View {
        if let image = model.covers[group.id] {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .clipShape(Circle())
        } else {
            Image(systemName: Tokens.Icons.globalGroup)
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
        }
    }

    // MARK: Send

    private var sendButton: some View {
        Button {
            model.send()
        } label: {
            HStack(spacing: Tokens.Sizes.cameraSendtoSizeCountDiscGap) {
                Text(Copy.cameraSendtoSend)
                    .dsTextStyle(CaptureType.button)
                    .foregroundStyle(Tokens.Colors.globalOnAccent)
                Text(model.selection.count, format: .number)
                    .dsTextStyle(CaptureType.countNumber)
                    .foregroundStyle(Tokens.Colors.globalAccent)
                    .frame(width: Tokens.Sizes.cameraSendtoSizeCountDisc, height: Tokens.Sizes.cameraSendtoSizeCountDisc)
                    .background(Tokens.Colors.globalOnAccent, in: Circle())
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity)
            .frame(height: Tokens.Sizes.globalButtonHeightSheet)
            .background(Tokens.Colors.globalAccent, in: RoundedRectangle(cornerRadius: Tokens.Radii.globalButton, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Copy.cameraSendtoSend)
        .accessibilitySortPriority(3)
        .accessibilityIdentifier("camera.sendto.send")
    }
}

extension VerticalAlignment {
    private enum CaptionBaseline: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat { context[.lastTextBaseline] }
    }

    /// Aligns the send-to caption's first baseline to the hour overlay's last baseline (+ offset).
    static let captionBaseline = VerticalAlignment(CaptionBaseline.self)
}
