// Surface: camera.capture (+ camera.fromwidget) — reference app: Yope + Locket.
// Reference images: references/auto/yope/frames/a-jacob-7691153057177931039-t3.73-camera-hold-to-record.png,
// a-alexaa-7684388619099933966-t5.23-camera-hold-to-record-tabbar.png, a-chuongxetank-7694968408424582452-t4.73-camera.png,
// a-virgi-7686278541255642390-t36.23-camera-first-open-es.png, references/auto/locket/frames/
// locket-tt-7069892557970345259-03.367s-shutter-pressed-2022.jpg (design/surfaces/camera.capture.md).
import AppServices
import DesignSystem
import SwiftUI

/// The camera the app opens to: full-width viewfinder with the hour overlay and flash, then the
/// library thumbnail, the shutter and flip. One tap captures; holding records (premium).
struct CameraCaptureView: View {
    @Bindable var model: CameraCaptureModel
    /// Builds the send-to screen for a capture.
    let makeSendTo: (CapturedMedia) -> SendToModel
    let sendCenter: CaptureSendCenter

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

    private typealias Viewfinder = Tokens.Layouts.CameraCaptureLayoutViewfinder

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let viewfinderHeight = width * Viewfinder.heightOverWidth
            let shutterCenterY = Viewfinder.top + viewfinderHeight + Tokens.Sizes.cameraCaptureSizeShutterTopGap
                + Tokens.Sizes.cameraCaptureSizeShutterOuter / 2
            ZStack(alignment: .topLeading) {
                Tokens.Colors.globalBackgroundDeep
                viewfinder(width: width, height: viewfinderHeight)
                    .frame(width: width, height: viewfinderHeight)
                    .clipShape(RoundedRectangle(cornerRadius: Tokens.Radii.globalViewfinder, style: .continuous))
                    .overlay {
                        if model.isRecording {
                            recordingOutline
                        }
                    }
                    .offset(y: Viewfinder.top)
                controls(width: width)
                    .frame(width: width, height: Tokens.Sizes.cameraCaptureSizeShutterOuter)
                    .offset(y: shutterCenterY - Tokens.Sizes.cameraCaptureSizeShutterOuter / 2)
            }
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("camera.capture")
        .fullScreenCover(item: $model.captured) { media in
            SendToView(model: makeSendTo(media))
        }
        .sheet(isPresented: $isPickerPresented) {
            CaptureLibraryPicker { media in
                isPickerPresented = false
                if let media { model.didPick(media) }
            }
            .ignoresSafeArea()
        }
        .task { await model.appear() }
        .onDisappear { Task { await model.disappear() } }
        .onChange(of: model.isRecording) { _, recording in
            recordingProgress = 0
            guard recording else { return }
            withDSAnimation(.timing(duration: Tokens.Durations.cameraCaptureDurationVideoMax, easing: .linear)) { // provenance-ok: linear fill per camera.capture.size.recordingOutline notes (Locket)
                recordingProgress = 1
            }
        }
        .captureSendStatus(sendCenter)
    }

    /// While a video records, the viewfinder's outline (`camera.capture.size.recordingOutline`,
    /// `color.global.accent`) is traced from empty to full, linearly, over the maximum video length
    /// (Locket's progress stroke).
    private var recordingOutline: some View {
        let width = Tokens.Sizes.cameraCaptureSizeRecordingOutline
        return RoundedRectangle(cornerRadius: Tokens.Radii.globalViewfinder, style: .continuous)
            .inset(by: width / 2)
            .trim(from: 0, to: recordingProgress)
            .stroke(Tokens.Colors.globalAccent, style: StrokeStyle(lineWidth: width, lineCap: .butt))
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }

    // MARK: Viewfinder

    @ViewBuilder
    private func viewfinder(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            Tokens.Colors.globalBackgroundDeep
            switch model.phase {
            case .starting, .live:
                model.camera.preview(position: nil)
                    .accessibilityHidden(true)
                hourOverlay
                flashToggle
                    .position(
                        x: Tokens.Layouts.CameraCaptureLayoutFlashGlyph.centerFromLeading,
                        y: height - Tokens.Layouts.CameraCaptureLayoutFlashGlyph.centerFromBottom
                    )
            case .denied:
                CaptureEmptyState(
                    title: Copy.cameraCaptureDeniedTitle,
                    detail: Copy.cameraCaptureDeniedDetail,
                    buttonTitle: Copy.cameraCaptureDeniedButton,
                    action: { model.openSettings() }
                )
                .accessibilityIdentifier("camera.capture.denied")
            case .unavailable:
                CaptureEmptyState(
                    title: Copy.cameraCaptureUnavailableTitle,
                    detail: Copy.cameraCaptureUnavailableDetail,
                    buttonTitle: Copy.cameraCaptureUnavailableButton,
                    action: { Task { await model.retry() } }
                )
                .accessibilityIdentifier("camera.capture.unavailable")
            }
        }
    }

    /// The hour slot the photo will be filed under; updates on the hour.
    private var hourOverlay: some View {
        TimelineView(.everyMinute) { context in
            Text(CaptureFormat.hourOverlay(at: context.date))
                .dsTextStyle(CaptureType.overlayTimeCamera)
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
        }
        .accessibilitySortPriority(5)
    }

    @ViewBuilder
    private var flashToggle: some View {
        if model.isFlashAvailable {
            Button {
                model.toggleFlash()
            } label: {
                Image(systemName: model.isFlashOn ? Tokens.Icons.globalFlashOn : Tokens.Icons.globalFlashOff)
                    .resizable()
                    .scaledToFit()
                    .frame(height: Tokens.Layouts.CameraCaptureLayoutFlashGlyph.glyphHeight)
                    .foregroundStyle(Tokens.Colors.globalTextPrimary)
                    .frame(minWidth: Tokens.Sizes.globalMinTouchTargetIos, minHeight: Tokens.Sizes.globalMinTouchTargetIos)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Copy.cameraCaptureA11yFlash)
            .accessibilityValue(model.isFlashOn ? Copy.cameraCaptureA11yFlashOn : Copy.cameraCaptureA11yFlashOff)
            .accessibilitySortPriority(4)
            .accessibilityIdentifier("camera.capture.flash")
        }
    }

    // MARK: Control row

    private func controls(width: CGFloat) -> some View {
        let center = width / 2
        let offset = Tokens.Sizes.cameraCaptureSizeSideControlOffset
        let rowHeight = Tokens.Sizes.cameraCaptureSizeShutterOuter
        return ZStack {
            libraryThumbnail
                .position(x: center - offset, y: rowHeight / 2)
            if model.phase != .denied {
                shutter
                    .position(x: center, y: rowHeight / 2)
                flipButton
                    .position(x: center + offset, y: rowHeight / 2)
            }
            if model.showsCoach && model.phase == .live {
                // Centred on the shutter; the pointer's apex sits `pointerToTarget` above the ring.
                coach
                    .frame(width: width, height: 0, alignment: .bottom)
                    .position(x: center, y: -Tokens.Layouts.CameraCaptureLayoutCoach.pointerToTarget)
            }
        }
    }

    private var coach: some View {
        CaptureCoachTooltip(
            glyph: Tokens.Icons.cameraCaptureIconRecordHint,
            text: Copy.cameraCaptureCoachHoldToRecord,
            onClose: { model.dismissCoach() }
        )
        .fixedSize()
        .accessibilitySortPriority(6)
        .accessibilityIdentifier("camera.capture.coach")
    }

    private var libraryThumbnail: some View {
        Button {
            isPickerPresented = true
        } label: {
            ZStack {
                if let image = model.libraryThumbnail {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: Tokens.Icons.globalGallery)
                        .foregroundStyle(Tokens.Colors.globalTextPrimary)
                }
            }
            .frame(width: Tokens.Sizes.cameraCaptureSizeLibraryThumb, height: Tokens.Sizes.cameraCaptureSizeLibraryThumb)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radii.cameraCaptureRadiusLibraryThumb, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Tokens.Radii.cameraCaptureRadiusLibraryThumb, style: .continuous)
                    .strokeBorder(Tokens.Colors.globalTextPrimary, lineWidth: Tokens.Sizes.cameraCaptureSizeLibraryThumbBorder)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Copy.cameraCaptureA11yLibrary)
        .accessibilitySortPriority(2)
        .accessibilityIdentifier("camera.capture.library")
    }

    private var shutter: some View {
        CaptureShutterGraphic(
            outer: Tokens.Sizes.cameraCaptureSizeShutterOuter,
            ring: Tokens.Sizes.cameraCaptureSizeShutterRing,
            disc: Tokens.Sizes.cameraCaptureSizeShutterDisc,
            ringColor: Tokens.Colors.globalAccent,
            gapColor: Tokens.Colors.globalBackgroundDeep,
            discColor: model.isShutterPressed ? Tokens.Colors.cameraCaptureColorShutterDiscPressed : Tokens.Colors.globalSurfaceLight
        )
        .dsMotion(
            .spring(Tokens.Springs.cameraCaptureSpringShutterPress),
            opacity: 1,
            scale: model.isShutterPressed ? Tokens.Layouts.CameraCaptureLayoutShutterPress.scale : 1
        )
        .dsAnimation(.spring(Tokens.Springs.cameraCaptureSpringShutterPress), value: model.isShutterPressed)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in model.shutterTouchDown() }
                .onEnded { _ in model.shutterTouchUp() }
        )
        .accessibilityElement()
        .accessibilityLabel(Copy.cameraCaptureA11yShutter)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { Task { await model.takePhoto() } }
        .accessibilityActions {
            if model.isVideoAvailable {
                Button(Copy.cameraCaptureA11yRecordVideo) {
                    Task { await model.toggleRecordingFromAccessibility() }
                }
            }
        }
        .accessibilitySortPriority(3)
        .accessibilityIdentifier("camera.capture.shutter")
    }

    private var flipButton: some View {
        Button {
            Task { await model.flip() }
        } label: {
            Image(systemName: Tokens.Icons.globalFlip)
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
                .frame(width: Tokens.Sizes.cameraCaptureSizeFlipButton, height: Tokens.Sizes.cameraCaptureSizeFlipButton)
                .background(Tokens.Colors.cameraCaptureColorFlipButton, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Copy.cameraCaptureA11yFlip)
        .accessibilitySortPriority(1)
        .accessibilityIdentifier("camera.capture.flip")
    }
}
