// Surface: camera.capture (+ camera.fromwidget) — visual reference Retro (composed only from Retro components: Retro has
// no camera), mechanics Locket.
// Reference images: references/auto/retro/lazyweb/retro-lazyweb-20251020-week43-dark.png (H43: C-01 serif title,
// bare trailing glyph, 16 margin, 18-pt photo-container corners), references/auto/retro/press/tc-2025-12-rewind-device-a.png
// and …-device-b.jpg (RWA / RWB: C-35 control row, 64-pt circles), references/auto/retro/store/retro-store-03.png (ST-03:
// C-09 pill on a photo), references/auto/locket/store/locket-store-07.png (AS-7: shutter, flash / flip row)
// (design/surfaces/camera.capture.md; MERGE_DECISIONS RC-1 … RC-4).
import AppServices
import DesignSystem
import SwiftUI

/// The camera the app opens to, on Retro's media surface (black in both appearances): the C-01 serif header
/// ("Week 42") with the flash as a bare header glyph, the 3:4 viewfinder in Retro's photo container, and the C-35 control
/// row (library · shutter · flip). The tab bar under it is the shell's (C-04 media variant). One tap captures; holding
/// records a video (premium).
struct CameraCaptureView: View {
    @Bindable var model: CameraCaptureModel
    /// Builds the send-to screen for a capture.
    let makeSendTo: (CapturedMedia) -> SendToModel
    let sendCenter: CaptureSendCenter

    /// The system appearance, read outside the media override: sheets over the composer follow it.
    @Environment(\.colorScheme) private var systemAppearance
    @State private var isPickerPresented = false
    /// Recording progress, 0 → 1 linearly over `camera.capture.duration.videoMax`.
    @State private var recordingProgress: CGFloat

    /// - Parameter recordingProgress: where the recording outline starts (snapshots of a recording).
    init(model: CameraCaptureModel, makeSendTo: @escaping (CapturedMedia) -> SendToModel, sendCenter: CaptureSendCenter, recordingProgress: CGFloat = 0) {
        self.model = model
        self.makeSendTo = makeSendTo
        self.sendCenter = sendCenter
        _recordingProgress = State(initialValue: recordingProgress)
    }

    var body: some View {
        page
            .captureMediaAppearance()
            .fullScreenCover(item: $model.captured) { media in
                SendToView(model: makeSendTo(media), sheetAppearance: systemAppearance)
            }
            .sheet(isPresented: $isPickerPresented) {
                CaptureLibraryPicker { media in
                    isPickerPresented = false
                    if let media { model.didPick(media) }
                }
                .ignoresSafeArea()
            }
            // camera.trim: the system trimmer for a library video over the limit (its own chrome, system appearance).
            .fullScreenCover(item: $model.trimming) { request in
                VideoTrimmer(request: request) { trimmed, failed in
                    Task { await model.didTrim(request, to: trimmed, failed: failed) }
                }
                .ignoresSafeArea()
                .preferredColorScheme(systemAppearance)
            }
            .alert(Copy.cameraCaptureVideoTooLongTitle, isPresented: $model.isVideoTooLong) {
                Button(Copy.cameraCaptureVideoTooLongDismiss, role: .cancel) {}
            } message: {
                Text(Copy.cameraCaptureVideoTooLongMessage(duration: CaptureVideoLimit.spoken))
            }
            // camera.overnight's destination sheet follows the system appearance (C-29).
            .sheet(isPresented: destinationBinding, onDismiss: { model.overnight?.destinationClosed() }) {
                if let overnight = model.overnight {
                    OvernightDestinationSheet(model: overnight, canCreateGroup: model.canCreateGroup)
                        .preferredColorScheme(systemAppearance)
                }
            }
            .task { await model.appear() }
            .onDisappear { Task { await model.disappear() } }
            .onChange(of: model.isRecording) { _, recording in
                recordingProgress = 0
                guard recording else { return }
                // A progress indicator, not decoration: linear, and unchanged under Reduce Motion (camera.capture Motion).
                let fill = DSAnimation.timing(duration: Tokens.Durations.cameraCaptureDurationVideoMax, easing: .linear) // provenance-ok: linear trim per camera.capture Motion ("recording outline: linear trim 0 → 1")
                withAnimation(fill.animation) {
                    recordingProgress = 1
                }
            }
    }

    private var destinationBinding: Binding<Bool> {
        Binding(
            get: { model.overnight?.isDestinationOpen ?? false },
            set: { open in
                if open { model.overnight?.isDestinationOpen = true } else { model.overnight?.destinationClosed() }
            }
        )
    }

    /// 9 AM mode (camera.overnight): no library, no hold-to-record, no coach; the destination pill in the coach's slot.
    private var isLater: Bool { model.overnight?.isLater ?? false }

    private var page: some View {
        VStack(spacing: 0) {
            CameraHeader(title: model.title, flash: flashControl)
                .accessibilitySortPriority(6)
            if let overnight = model.overnight {
                // `camera.overnight.layout.modeControl`: shown in both modes so the layout does not jump.
                OvernightModeControl(model: overnight)
                    // Not while a video records (the mode changes what the shutter does).
                    .disabled(model.isRecording)
                    .padding(.bottom, Tokens.Sizes.globalSectionHeaderToContent)
                    .accessibilitySortPriority(5.5)
            }
            GeometryReader { area in
                let size = Self.viewfinderSize(in: area.size)
                VStack(spacing: 0) {
                    viewfinder
                        .frame(width: size.width, height: size.height)
                        .accessibilitySortPriority(4)
                    controls
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(width: area.size.width)
            }
        }
        .background(Tokens.Colors.globalBackgroundDeep.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("camera.capture")
    }

    /// `camera.capture.layout.viewfinder`: 3:4, screen width − 2 × `size.global.screenMargin`; if the control row would get
    /// less than `size.global.screenMargin` above and below the shutter, the viewfinder shrinks (3:4 kept, centred).
    static func viewfinderSize(in area: CGSize) -> CGSize {
        let aspect = Tokens.Layouts.CameraCaptureLayoutViewfinder.aspect
        let fullWidth = max(0, area.width - Tokens.Sizes.globalScreenMargin * 2)
        let rowMinimum = Tokens.Sizes.cameraCaptureSizeShutterOuter + Tokens.Sizes.globalScreenMargin * 2
        let height = max(0, min(fullWidth / aspect, area.height - rowMinimum))
        return CGSize(width: height * aspect, height: height)
    }

    private var flashControl: CameraHeader.Flash? {
        guard model.isFlashAvailable else { return nil }
        return CameraHeader.Flash(isOn: model.isFlashOn) { model.toggleFlash() }
    }

    // MARK: Viewfinder

    private var viewfinder: some View {
        ZStack {
            Tokens.Colors.globalBackgroundDeep
            switch model.phase {
            case .starting, .live:
                if model.phase == .live || model.hasBeenLive {
                    model.camera.preview(position: nil)
                        .accessibilityHidden(true)
                        .dsTransition(.opacity)
                }
            case .denied:
                EmptyStateView(
                    icon: Tokens.Icons.globalCamera,
                    title: Copy.cameraCaptureDeniedTitle,
                    detail: Copy.cameraCaptureDeniedDetail,
                    action: EmptyStateView.Action(Copy.cameraCaptureDeniedButton) { model.openSettings() }
                )
                .dsTransition(.opacity)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("camera.capture.denied")
            case .unavailable:
                EmptyStateView(
                    icon: Tokens.Icons.globalCamera,
                    title: Copy.cameraCaptureUnavailableTitle,
                    detail: Copy.cameraCaptureUnavailableDetail,
                    action: EmptyStateView.Action(Copy.cameraCaptureUnavailableButton) { Task { await model.retry() } }
                )
                .dsTransition(.opacity)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("camera.capture.unavailable")
            }
        }
        .dsAnimation(ComponentMotion.fade, value: model.phase)
        .clipShape(DSShape.rounded(Tokens.Radii.globalViewfinder))
        .overlay {
            if model.isRecording {
                recordingOutline
            }
        }
        .overlay(alignment: .bottom) {
            GeometryReader { proxy in
                ZStack(alignment: .bottom) {
                    viewfinderPill(width: proxy.size.width)
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
            }
            .dsAnimation(ComponentMotion.fade, value: model.showsCoach)
            .dsAnimation(ComponentMotion.fade, value: isLater)
        }
        .overlay(alignment: .bottom) {
            // question.weekly B: the week's question in the coach pill's slot while answering (the coach keeps the slot
            // while it shows; 9 AM mode drops the question — Features/Question/QuestionCamera.swift).
            QuestionCameraPill(
                groupID: model.contextGroupID,
                isHidden: (model.showsCoach && model.phase == .live && !model.isRecording) || model.overnight?.isLater == true
                    || !(model.phase == .live || model.phase == .starting)
            )
            .onChange(of: model.overnight?.isLater == true) { _, later in
                if later { QuestionCameraContext.shared.drop() }
            }
        }
    }

    /// The pill slot at the viewfinder's bottom (`camera.sendto.layout.messageField` bottomInset): camera.overnight's
    /// destination pill in 9 AM mode (the video coach is never shown then), otherwise the first-use coach.
    @ViewBuilder
    private func viewfinderPill(width: CGFloat) -> some View {
        if let overnight = model.overnight, overnight.isLater, model.phase == .live || model.phase == .starting {
            OvernightDestinationPill(model: overnight, viewfinderWidth: width)
                .accessibilitySortPriority(5)
                .dsTransition(.opacity)
        } else if model.showsCoach && model.phase == .live && !model.isRecording {
            coach
                .dsTransition(.opacity)
        }
    }

    /// While a video records: `camera.capture.size.recordingOutline` in `color.global.surfaceLight` traced along the
    /// viewfinder's rounded outline from empty to full over the maximum video length (Locket's progress outline).
    private var recordingOutline: some View {
        let width = Tokens.Sizes.cameraCaptureSizeRecordingOutline
        return DSShape.rounded(Tokens.Radii.globalViewfinder)
            .inset(by: width / 2)
            .trim(from: 0, to: recordingProgress)
            .stroke(Tokens.Colors.globalSurfaceLight, style: StrokeStyle(lineWidth: width, lineCap: .butt))
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }

    /// First use, members who can record video: C-09 pill on media centred, its bottom 20.5 pt above the viewfinder's
    /// bottom (`camera.sendto.layout.messageField.bottomInset`, Retro's pill-on-photo inset). Tapping dismisses it for good.
    private var coach: some View {
        LightPill(Copy.cameraCaptureCoachHoldToRecord, icon: Tokens.Icons.globalVideo, style: .dark) {
            model.dismissCoach()
        }
        .padding(.bottom, Tokens.Layouts.CameraSendtoLayoutMessageField.bottomInset)
        .accessibilitySortPriority(5)
        .accessibilityIdentifier("camera.capture.coach")
    }

    // MARK: Control row (C-35)

    private var controls: some View {
        CaptureControlRow {
            // 9 AM mode: the leading slot stays empty (the developing stack is BLOCKED, ON-8; a picked photo was
            // already seen).
            if !isLater {
                CaptureLargeCircleButton(icon: Tokens.Icons.globalGallery, accessibilityLabel: Copy.cameraCaptureA11yLibrary) {
                    isPickerPresented = true
                }
                .accessibilitySortPriority(3)
                .accessibilityIdentifier("camera.capture.library")
                .dsTransition(.opacity)
            }
        } centre: {
            if model.phase != .denied {
                shutter
            }
        } trailing: {
            if model.phase != .denied {
                CaptureLargeCircleButton(icon: Tokens.Icons.globalFlip, accessibilityLabel: Copy.cameraCaptureA11yFlip) {
                    Task { await model.flip() }
                }
                .accessibilitySortPriority(1)
                .accessibilityIdentifier("camera.capture.flip")
            }
        }
        .dsAnimation(ComponentMotion.fade, value: isLater)
    }

    /// Tap = photo; hold = video (premium; a free member's first hold opens the paywall once per session). No haptic
    /// (`haptic.global.shutter`: none) and no custom press state (RC-3).
    private var shutter: some View {
        CaptureShutter()
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in model.shutterTouchDown() }
                    .onEnded { _ in model.shutterTouchUp() }
            )
            .accessibilityElement()
            .accessibilityLabel(Text(Copy.cameraCaptureA11yShutter))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { Task { await model.takePhoto() } }
            .accessibilityActions {
                if model.isVideoAvailable && !isLater {
                    Button(Copy.cameraCaptureA11yRecordVideo) {
                        Task { await model.toggleRecordingFromAccessibility() }
                    }
                }
            }
            .accessibilitySortPriority(2)
            .accessibilityIdentifier("camera.capture.shutter")
    }
}

/// C-01 root header on media: the serif title (`headerTitle`, `color.global.textOnMedia`) and the flash as the trailing
/// bare header glyph (`icon.global.flashOff` / `.flashOn`, `size.global.icon`, hit area `size.global.headerButton`),
/// centred on the title's cap middle with its ink `size.global.headerInset` from the trailing edge — `ScreenHeader`'s
/// own trailing-glyph geometry. The glyph is placed here rather than as a `HeaderAction` because the flash needs an
/// accessibility value (On / Off), which `HeaderAction` cannot carry (component gap reported).
private struct CameraHeader: View {
    struct Flash {
        let isOn: Bool
        let toggle: () -> Void
    }

    let title: String
    let flash: Flash?

    @ScaledMetric private var titleSize: CGFloat

    init(title: String, flash: Flash?) {
        self.title = title
        self.flash = flash
        _titleSize = ScaledMetric(wrappedValue: TextRole.headerTitle.size, relativeTo: TextRole.headerTitle.relativeTo)
    }

    /// The trailing glyph row of C-01 for one glyph: the hit area plus the padding that puts the glyph's ink on the margin.
    private static var trailingPadding: CGFloat {
        max(0, Tokens.Sizes.globalHeaderInset - (Tokens.Sizes.globalHeaderButton - Tokens.Sizes.globalIcon) / 2)
    }

    private static var glyphRowWidth: CGFloat { Tokens.Sizes.globalHeaderButton + trailingPadding }

    var body: some View {
        let capHeight = TextMetrics(style: TextRole.headerTitle, size: titleSize).capHeight
        let capMiddle = Tokens.Sizes.globalTitleTop - capHeight / 2
        ScreenHeader(title: title, onMedia: true)
            .padding(.trailing, flash == nil ? 0 : Self.glyphRowWidth)
            .overlay(alignment: .topTrailing) {
                if let flash {
                    HeaderIconButton(
                        icon: flash.isOn ? Tokens.Icons.globalFlashOn : Tokens.Icons.globalFlashOff,
                        accessibilityLabel: Copy.cameraCaptureA11yFlash,
                        color: Tokens.Colors.globalTextOnMedia,
                        action: flash.toggle
                    )
                    .accessibilityValue(Text(flash.isOn ? Copy.cameraCaptureA11yFlashOn : Copy.cameraCaptureA11yFlashOff))
                    .dsAnimation(ComponentMotion.crossfade, value: flash.isOn)
                    .padding(.top, capMiddle - Tokens.Sizes.globalHeaderButton / 2)
                    .padding(.trailing, Self.trailingPadding)
                    .accessibilityIdentifier("camera.capture.flash")
                }
            }
    }
}
