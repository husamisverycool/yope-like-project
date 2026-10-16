// Surface: daily.capture — visual reference Retro (composed only from Retro components: C-29 header, C-17/C-18 photo
// container, C-35 control row, C-11 glass circle, C-09 pill, C-05 capsule, C-27 / C-28), mechanics BeReal.
// Reference images: references/auto/retro/store/retro-store-03.png (ST-03: header geometry, 20-pt circle → photo gap,
// pill on a photo, bottom capsule), references/auto/retro/press/tc-2025-12-rewind-device-a.png and …-device-b.jpg (RWA /
// RWB: control row, glass circle over a photo), references/auto/retro/store/retro-store-01.png (ST-01: 12-pt overlay
// inset on a photo card), references/auto/bereal/frames/appstore-preview-2026_t3.50s_capture.png,
// references/auto/bereal/frames/tiktok-bereal-7339559678604627233_capture-seq_f540-f681.jpg,
// …_t17.63s_black-spinner-prompt.png, …_t21.30s_preview-keep-smiling.png (mechanics)
// (design/surfaces/daily.capture.md; RC-12, RC-13).
import AppServices
import DesignSystem
import SwiftUI
import UIKit

/// Full-screen cover on the black media surface: the C-29 header (countdown or group name, close circle), the 3:4
/// viewfinder in Retro's photo container, and the C-35 row (flash · shutter · flip); after the shutter the progress line,
/// then the dual-image preview with the glass retake circle, the audience pill and the white "Send" capsule.
struct DailyCaptureView: View {
    @Bindable var model: DailyCaptureModel
    let sendCenter: CaptureSendCenter

    var body: some View {
        page
            .captureMediaAppearance()
            // A full-screen cover over media: light status-bar content (this presentation only).
            .preferredColorScheme(.dark)
            .task { await model.appear() }
            .onDisappear { Task { await model.disappear() } }
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

    private var page: some View {
        GeometryReader { proxy in
            // `camera.sendto.size.sendButtonBottom` is measured from the screen bottom; the safe area holds part of it.
            let capsuleBottom = max(0, Tokens.Sizes.cameraSendtoSizeSendButtonBottom - proxy.safeAreaInsets.bottom)
            VStack(spacing: 0) {
                header
                GeometryReader { area in
                    let size = Self.viewfinderSize(in: area.size)
                    VStack(spacing: 0) {
                        viewfinderArea
                            .frame(width: size.width, height: size.height)
                            .padding(.top, Tokens.Layouts.CameraSendtoLayoutPreview.topBelowHeaderCircle)
                            .accessibilitySortPriority(4)
                        controls
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(width: area.size.width)
                }
            }
            .overlay(alignment: .bottom) {
                if model.phase == .preview {
                    PrimaryButton(Copy.dailyCaptureSend, surface: .media, isBusy: model.isSending) {
                        Task { await model.send() }
                    }
                    .padding(.horizontal, Tokens.Sizes.globalButtonMarginH)
                    .padding(.bottom, capsuleBottom)
                    .accessibilitySortPriority(1)
                    .accessibilityIdentifier("daily.capture.send")
                    .dsTransition(.opacity)
                }
            }
        }
        .dsAnimation(ComponentMotion.fade, value: model.phase)
        .background(Tokens.Colors.globalBackgroundDeep.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("daily.capture")
    }

    /// `daily.capture.layout.viewfinder`: 3:4, screen width − 2 × `size.global.screenMargin`, its top 20 pt below the close
    /// circle; shrinks (3:4 kept, centred) when the control row would get less than `size.global.screenMargin` above and
    /// below the shutter.
    static func viewfinderSize(in area: CGSize) -> CGSize {
        let aspect = Tokens.Layouts.DailyCaptureLayoutViewfinder.aspect
        let fullWidth = max(0, area.width - Tokens.Sizes.globalScreenMargin * 2)
        let reserved = Tokens.Layouts.CameraSendtoLayoutPreview.topBelowHeaderCircle
            + Tokens.Sizes.cameraCaptureSizeShutterOuter + Tokens.Sizes.globalScreenMargin * 2
        let height = max(0, min(fullWidth / aspect, area.height - reserved))
        return CGSize(width: height * aspect, height: height)
    }

    // MARK: Header (C-29 on media)

    private var header: some View {
        CaptureMediaHeader(
            trailing: HeaderAction(icon: Tokens.Icons.globalClose, accessibilityLabel: Copy.dailyCaptureA11yDismiss) {
                model.dismiss()
            }
        ) {
            DailyCaptureTitle(
                closesAt: model.invitation?.closesAt,
                opensAt: model.invitation?.firesAt,
                clock: model.clock,
                groupName: model.groupName
            )
            .accessibilitySortPriority(7)
        }
        .disabled(model.isSending)
        .accessibilitySortPriority(6)
        .accessibilityIdentifier("daily.capture.header")
    }

    // MARK: Viewfinder / preview

    @ViewBuilder
    private var viewfinderArea: some View {
        switch model.phase {
        case .starting, .live, .capturing:
            ZStack {
                Tokens.Colors.globalBackgroundDeep
                if model.phase != .starting {
                    model.camera.preview(position: model.mainPosition)
                        .id(model.mainPosition)
                        .accessibilityHidden(true)
                        .opacity(model.phase == .capturing ? 0 : 1)
                        .dsTransition(.opacity)
                }
                if model.phase == .capturing {
                    CaptureMediaProgress(text: Copy.dailyCapturePrompt)
                        .dsTransition(.opacity)
                        .accessibilityIdentifier("daily.capture.capturing")
                }
            }
            .clipShape(DSShape.rounded(Tokens.Radii.globalViewfinder))
        case .preview:
            DualImageView(
                main: model.mainImage,
                inset: model.insetImage,
                accessibilityLabel: model.dualImageLabel,
                corners: .host(Tokens.Radii.globalViewfinder)
            )
            .accessibilitySortPriority(4)
            .overlay(alignment: .topTrailing) { retakeButton }
            .overlay(alignment: .bottom) { audiencePill }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("daily.capture.preview")
        case .denied:
            EmptyStateView(
                icon: Tokens.Icons.globalCamera,
                title: Copy.cameraCaptureDeniedTitle,
                detail: Copy.cameraCaptureDeniedDetail,
                action: EmptyStateView.Action(Copy.cameraCaptureDeniedButton) { model.openSettings() }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("daily.capture.denied")
        case .unavailable:
            EmptyStateView(
                icon: Tokens.Icons.globalCamera,
                title: Copy.cameraCaptureUnavailableTitle,
                detail: Copy.cameraCaptureUnavailableDetail,
                action: EmptyStateView.Action(Copy.cameraCaptureUnavailableButton) { Task { await model.retry() } }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("daily.capture.unavailable")
        }
    }

    /// C-11 glass circle over the photo (`size.global.circleButtonPhoto` 40, `color.global.glass`, `icon.global.close`),
    /// `size.global.badgeInset` (12) from the image's top and trailing edges. Unlimited retakes, no count.
    private var retakeButton: some View {
        CircleButton(icon: Tokens.Icons.globalClose, accessibilityLabel: Copy.dailyCaptureA11yRetake, style: .glass) {
            Task { await model.retake() }
        }
        .disabled(model.isSending)
        .padding(.top, Tokens.Sizes.globalBadgeInset)
        .padding(.trailing, Tokens.Sizes.globalBadgeInset)
        .accessibilitySortPriority(3)
        .accessibilityIdentifier("daily.capture.retake")
    }

    /// C-09 on media (`icon.global.group` + "{group} only"), centred 20.5 pt above the image's bottom; not interactive —
    /// the answer goes to the invitation's group.
    private var audiencePill: some View {
        LightPillLabel(Copy.dailyCaptureAudience(group: model.groupName), icon: Tokens.Icons.globalGroup, style: .dark)
            .padding(.bottom, Tokens.Layouts.CameraSendtoLayoutMessageField.bottomInset)
            .accessibilityElement(children: .combine)
            .accessibilitySortPriority(2)
            .accessibilityIdentifier("daily.capture.audience")
    }

    // MARK: Control row (C-35) — fades out while capturing

    @ViewBuilder
    private var controls: some View {
        let live = model.phase == .live || model.phase == .starting
        if model.phase != .denied && model.phase != .unavailable && model.phase != .preview {
            CaptureControlRow {
                if model.isFlashAvailable {
                    CaptureLargeCircleButton(
                        icon: model.isFlashOn ? Tokens.Icons.globalFlashOn : Tokens.Icons.globalFlashOff,
                        accessibilityLabel: Copy.dailyCaptureA11yFlash,
                        accessibilityValue: model.isFlashOn ? Copy.dailyCaptureA11yFlashOn : Copy.dailyCaptureA11yFlashOff
                    ) {
                        model.toggleFlash()
                    }
                    .dsAnimation(ComponentMotion.crossfade, value: model.isFlashOn)
                    .accessibilitySortPriority(3)
                    .accessibilityIdentifier("daily.capture.flash")
                }
            } centre: {
                Button {
                    Task { await model.shutter() }
                } label: {
                    CaptureShutter()
                }
                .buttonStyle(.plain)
                .disabled(model.phase != .live)
                .accessibilityLabel(Text(Copy.dailyCaptureA11yShutter))
                .accessibilitySortPriority(2)
                .accessibilityIdentifier("daily.capture.shutter")
            } trailing: {
                CaptureLargeCircleButton(icon: Tokens.Icons.globalFlip, accessibilityLabel: Copy.dailyCaptureA11yFlip) {
                    model.flip()
                }
                .accessibilitySortPriority(1)
                .accessibilityIdentifier("daily.capture.flip")
            }
            .opacity(live ? 1 : 0)
            .allowsHitTesting(live)
            .accessibilityHidden(!live)
            .dsTransition(.opacity)
        }
    }
}
