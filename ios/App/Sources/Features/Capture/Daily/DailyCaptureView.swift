// Surface: daily.capture — reference app: BeReal.
// Reference images: references/auto/bereal/frames/appstore-preview-2026_t3.50s_capture.png (live layout),
// tiktok-bereal-7339559678604627233_shutter-press_f518-f546.jpg, …_capture-seq_f540-f681.jpg,
// …_t17.63s_black-spinner-prompt.png, …_t21.30s_preview-keep-smiling.png,
// references/auto/bereal/help/help-21083708285725_bts-post-preview-2x.png (design/surfaces/daily.capture.md).
import AppServices
import DesignSystem
import SwiftUI
import UIKit

/// Full-screen cover: chevron, countdown, 3:4 viewfinder, flash / shutter / flip; after the shutter
/// the dual-image preview with retake, the audience chip and SEND.
struct DailyCaptureView: View {
    @Bindable var model: DailyCaptureModel
    let sendCenter: CaptureSendCenter

    private typealias Viewfinder = Tokens.Layouts.DailyCaptureLayoutViewfinder
    private typealias Shutter = Tokens.Layouts.DailyCaptureLayoutShutter
    private typealias Sequence = Tokens.Layouts.DailyCaptureLayoutCaptureSequence

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let viewfinderWidth = width - Viewfinder.sideMargin * 2
            let viewfinderHeight = viewfinderWidth / Viewfinder.aspect
            ZStack(alignment: .topLeading) {
                Tokens.Colors.globalBackgroundDeep
                viewfinderArea(width: viewfinderWidth, height: viewfinderHeight)
                    .frame(width: viewfinderWidth, height: viewfinderHeight)
                    .offset(x: Viewfinder.sideMargin, y: Viewfinder.top)
                    .accessibilitySortPriority(4)
                countdown(width: width)
                dismissButton
                    .position(x: Tokens.Layouts.DailyCaptureLayoutDismiss.centerFromLeading, y: Tokens.Layouts.DailyCaptureLayoutDismiss.centerFromTop)
                if model.phase == .preview {
                    sendRow(width: width, imageBottom: Viewfinder.top + viewfinderHeight)
                } else if model.phase != .denied && model.phase != .unavailable {
                    controls(width: width)
                        .frame(width: width, height: Shutter.outer)
                        .offset(y: proxy.size.height - Shutter.centerFromBottom - Shutter.outer / 2)
                }
            }
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
        .accessibilityIdentifier("daily.capture")
        .task { await model.appear() }
        .onDisappear { Task { await model.disappear() } }
        .captureSendStatus(sendCenter)
    }

    // MARK: Top

    private var dismissButton: some View {
        Button {
            model.dismiss()
        } label: {
            Image(systemName: Tokens.Icons.globalChevronDown)
                .foregroundStyle(Tokens.Colors.dailyCaptureColorText)
                .frame(width: Tokens.Sizes.globalMinTouchTargetIos, height: Tokens.Sizes.globalMinTouchTargetIos)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Copy.dailyCaptureA11yDismiss)
        .accessibilitySortPriority(6)
        .accessibilityIdentifier("daily.capture.dismiss")
    }

    /// Centred; the digits' baseline sits `gapAboveViewfinder` above the viewfinder.
    private func countdown(width: CGFloat) -> some View {
        let baseline = Viewfinder.top - Tokens.Layouts.DailyCaptureLayoutCountdown.gapAboveViewfinder
        return ZStack(alignment: .top) {
            DailyCountdownView(closesAt: model.invitation?.closesAt, opensAt: model.invitation?.firesAt, clock: model.clock)
                .alignmentGuide(.top) { dimensions in dimensions[.firstTextBaseline] }
        }
        .frame(width: width)
        .offset(y: baseline)
        .accessibilitySortPriority(5)
    }

    // MARK: Viewfinder

    @ViewBuilder
    private func viewfinderArea(width: CGFloat, height: CGFloat) -> some View {
        switch model.phase {
        case .starting, .live, .capturing:
            ZStack {
                Tokens.Colors.globalBackgroundDeep
                model.camera.preview(position: model.mainPosition)
                    .id(model.mainPosition)
                    .accessibilityHidden(true)
                // The viewfinder fades to black when the shutter is pressed.
                Tokens.Colors.globalBackgroundDeep
                    .opacity(model.phase == .capturing ? 1 : 0)
                    .dsAnimation(.measured(milliseconds: Sequence.viewfinderFadeOut), value: model.phase)
                if model.phase == .capturing {
                    capturingIndicator
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Viewfinder.cornerRadius, style: .continuous))
        case .preview:
            if let answer = model.answer {
                DualImageView(main: answer.main.image, inset: answer.inset?.image, accessibilityLabel: model.dualImageLabel)
                    .frame(width: width, height: height)
                    .overlay(alignment: .topTrailing) { retakeButton }
                    .overlay(alignment: .bottom) { audienceChip }
                    .accessibilityIdentifier("daily.capture.preview")
            }
        case .denied:
            CaptureEmptyState(
                title: Copy.cameraCaptureDeniedTitle,
                detail: Copy.cameraCaptureDeniedDetail,
                buttonTitle: Copy.cameraCaptureDeniedButton,
                action: { model.openSettings() }
            )
            .frame(width: width, height: height)
            .accessibilityIdentifier("daily.capture.denied")
        case .unavailable:
            CaptureEmptyState(
                title: Copy.cameraCaptureUnavailableTitle,
                detail: Copy.cameraCaptureUnavailableDetail,
                buttonTitle: Copy.cameraCaptureUnavailableButton,
                action: { Task { await model.retry() } }
            )
            .frame(width: width, height: height)
            .accessibilityIdentifier("daily.capture.unavailable")
        }
    }

    /// Platform progress indicator with one centred line under it.
    private var capturingIndicator: some View {
        VStack(spacing: Tokens.Layouts.DailyCaptureLayoutPrompt.gapBelowSpinner) {
            ProgressView()
                .controlSize(.large)
                .tint(Tokens.Colors.dailyCaptureColorText)
                .frame(width: Tokens.Sizes.dailyCaptureSizeProgress, height: Tokens.Sizes.dailyCaptureSizeProgress)
            Text(Copy.dailyCapturePrompt)
                .dsTextStyle(CaptureType.prompt)
                .foregroundStyle(Tokens.Colors.dailyCaptureColorText)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("daily.capture.capturing")
    }

    // MARK: Preview controls

    /// Retake ✕. Its circle fill `daily.capture.color.overlayControl` is BLOCKED and not drawn.
    private var retakeButton: some View {
        let retake = Tokens.Layouts.DailyCaptureLayoutRetake.self
        return Button {
            Task { await model.retake() }
        } label: {
            Image(systemName: Tokens.Icons.globalClose)
                .resizable()
                .scaledToFit()
                .frame(width: retake.glyph, height: retake.glyph)
                .foregroundStyle(Tokens.Colors.dailyCaptureColorText)
                .frame(width: retake.diameter, height: retake.diameter)
                .contentShape(Circle())
                .captureMinimumHitArea { Task { await model.retake() } }
        }
        .buttonStyle(.plain)
        .padding(.top, retake.inset)
        .padding(.trailing, retake.inset)
        .accessibilityLabel(Copy.dailyCaptureA11yRetake)
        .accessibilityIdentifier("daily.capture.retake")
    }

    /// Not interactive: the answer goes to the invitation's group. Its fill
    /// `daily.capture.color.overlayControl` is BLOCKED and not drawn.
    private var audienceChip: some View {
        let chip = Tokens.Layouts.DailyCaptureLayoutAudienceChip.self
        return HStack(spacing: chip.glyphToText) {
            Image(systemName: Tokens.Icons.globalGroup)
                .accessibilityHidden(true)
            Text(Copy.dailyCaptureAudience(group: model.groupName))
        }
        .dsTextStyle(CaptureType.chip)
        .foregroundStyle(Tokens.Colors.dailyCaptureColorText)
        .padding(.leading, chip.paddingLeading)
        .padding(.trailing, chip.paddingTrailing)
        .frame(height: chip.height)
        .padding(.bottom, chip.bottomInset)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("daily.capture.audience")
    }

    /// SEND ▶, centred, cap top `capTopBelowImage` under the image.
    private func sendRow(width: CGFloat, imageBottom: CGFloat) -> some View {
        let send = Tokens.Layouts.DailyCaptureLayoutSend.self
        let baseline = imageBottom + send.capTopBelowImage + CaptureMetrics.capHeight(of: CaptureType.send)
        return ZStack(alignment: .top) {
            Button {
                model.send()
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: send.glyphGap) {
                    Text(Copy.dailyCaptureSend)
                        .dsTextStyle(CaptureType.send)
                    Image(systemName: Tokens.Icons.globalPlay)
                        .resizable()
                        .scaledToFit()
                        .frame(width: send.glyph, height: send.glyph)
                }
                .foregroundStyle(Tokens.Colors.dailyCaptureColorText)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Copy.dailyCaptureA11ySend)
            .accessibilityIdentifier("daily.capture.send")
            .alignmentGuide(.top) { dimensions in dimensions[.firstTextBaseline] }
        }
        .frame(width: width)
        .offset(y: baseline)
    }

    // MARK: Live controls

    private func controls(width: CGFloat) -> some View {
        let side = Tokens.Layouts.DailyCaptureLayoutSideControls.self
        let capturing = model.phase == .capturing
        let controlsOut = DSAnimation.measured(milliseconds: Sequence.controlsOut)
        return ZStack {
            if model.isFlashAvailable {
                Button {
                    model.toggleFlash()
                } label: {
                    Image(systemName: model.isFlashOn ? Tokens.Icons.globalFlashOn : Tokens.Icons.globalFlashOff)
                        .foregroundStyle(Tokens.Colors.dailyCaptureColorText)
                        .frame(width: Tokens.Sizes.globalMinTouchTargetIos, height: Tokens.Sizes.globalMinTouchTargetIos)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Copy.dailyCaptureA11yFlash)
                .accessibilityValue(model.isFlashOn ? Copy.dailyCaptureA11yFlashOn : Copy.dailyCaptureA11yFlashOff)
                .accessibilitySortPriority(3)
                .accessibilityIdentifier("daily.capture.flash")
                .dsMotion(controlsOut, opacity: capturing ? 0 : 1)
                .position(x: side.flashCenterFromLeading, y: Shutter.outer / 2)
            }
            Button {
                Task { await model.shutter() }
            } label: {
                CaptureShutterGraphic(
                    outer: Shutter.outer,
                    ring: Shutter.ring,
                    disc: Shutter.disc,
                    ringColor: Tokens.Colors.globalSurfaceLight,
                    gapColor: Tokens.Colors.globalBackgroundDeep,
                    discColor: Tokens.Colors.globalSurfaceLight
                )
            }
            .buttonStyle(DailyShutterStyle(isCapturing: capturing))
            .disabled(model.phase != .live)
            .accessibilityLabel(Copy.dailyCaptureA11yShutter)
            .accessibilitySortPriority(2)
            .accessibilityIdentifier("daily.capture.shutter")
            .position(x: width / 2, y: Shutter.outer / 2)
            Button {
                model.flip()
            } label: {
                Image(systemName: Tokens.Icons.globalFlip)
                    .foregroundStyle(Tokens.Colors.dailyCaptureColorText)
                    .frame(width: Tokens.Sizes.globalMinTouchTargetIos, height: Tokens.Sizes.globalMinTouchTargetIos)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Copy.dailyCaptureA11yFlip)
            .accessibilitySortPriority(1)
            .accessibilityIdentifier("daily.capture.flip")
            .dsMotion(controlsOut, opacity: capturing ? 0 : 1)
            .position(x: width - side.flipCenterFromTrailing, y: Shutter.outer / 2)
        }
    }
}

/// Shutter press (scale to `pressScale` over `press`), then while capturing the shutter shrinks
/// to nothing over `controlsOut`. Reduce Motion: no scale; the shutter fades instead.
private struct DailyShutterStyle: ButtonStyle {
    let isCapturing: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private typealias Sequence = Tokens.Layouts.DailyCaptureLayoutCaptureSequence

    func makeBody(configuration: Configuration) -> some View {
        let scale: CGFloat = isCapturing ? 0 : (configuration.isPressed ? Sequence.pressScale : 1)
        let animation = DSAnimation.measured(milliseconds: isCapturing ? Sequence.controlsOut : Sequence.press)
        configuration.label
            .dsMotion(animation, opacity: isCapturing && reduceMotion ? 0 : 1, scale: scale)
    }
}

/// Font metrics for placing text by its cap height (positions measured to a cap top).
enum CaptureMetrics {
    static func capHeight(of style: DSTextStyle) -> CGFloat {
        let size = DSDynamicType.scaled(style.size, relativeTo: style.relativeTo)
        return UIFont.systemFont(ofSize: size, weight: uiWeight(style.weight)).capHeight
    }

    private static func uiWeight(_ weight: Font.Weight) -> UIFont.Weight {
        switch weight {
        case .ultraLight: return .ultraLight
        case .thin: return .thin
        case .light: return .light
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        default: return .regular
        }
    }
}
