// Surfaces: camera.capture, camera.sendto, daily.capture, collage.view, collage.share.
// Reference images: listed in each design/surfaces/<id>.md. Building blocks shared by the capture
// screens (no shared component exists in ios/App/Sources/Components yet, so they live here).
import AppServices
import DesignSystem
import SwiftUI

/// A circle icon button of a header (`size.global.headerButton`, glyph `color.global.textPrimary`).
struct CaptureHeaderCircle: View {
    let icon: String
    let label: String
    let fill: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
                .frame(width: Tokens.Sizes.globalHeaderButton, height: Tokens.Sizes.globalHeaderButton)
                .background(fill, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// Yope's empty-state layout (`yope.voice.empty-state`): title, detail, light pill.
struct CaptureEmptyState: View {
    let title: String
    var detail: String?
    var buttonTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack {
            Text(title)
                .dsTextStyle(CaptureType.emptyTitle)
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
                .multilineTextAlignment(.center)
            if let detail {
                Text(detail)
                    .italic()
                    .dsTextStyle(CaptureType.emptyDetail)
                    .foregroundStyle(Tokens.Colors.globalTextSecondary)
                    .multilineTextAlignment(.center)
            }
            if let buttonTitle, let action {
                CaptureLightPill(title: buttonTitle, action: action)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

/// The white secondary pill (`color.global.surfaceLight`, `radius.global.capsule`, height
/// `camera.capture.size.permissionButtonHeight`, text role `button`). The label sits between the
/// capsule's end caps (horizontal inset = height / 2, the capsule radius).
struct CaptureLightPill: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .dsTextStyle(CaptureType.button)
                .foregroundStyle(Tokens.Colors.globalOnSurfaceLight)
                .padding(.horizontal, Tokens.Sizes.cameraCaptureSizePermissionButtonHeight / 2)
                .frame(minHeight: Tokens.Sizes.cameraCaptureSizePermissionButtonHeight)
                .background(Tokens.Colors.globalSurfaceLight, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// Selection circle of a picker row (`icon.global.check` / `.uncheck`, `size.global.checkCircle`).
struct CaptureCheckCircle: View {
    let isSelected: Bool

    var body: some View {
        Image(systemName: isSelected ? Tokens.Icons.globalCheck : Tokens.Icons.globalUncheck)
            .resizable()
            .scaledToFit()
            .frame(width: Tokens.Sizes.globalCheckCircle, height: Tokens.Sizes.globalCheckCircle)
            .foregroundStyle(isSelected ? Tokens.Colors.globalSelection : Tokens.Colors.globalTextSecondary)
    }
}

/// Yope's first-use coach tooltip (`camera.capture.layout.coach`): lime body with an optional
/// leading glyph at the text size, the text and ✕, and a pointer whose apex points down at the
/// control it explains.
struct CaptureCoachTooltip: View {
    var glyph: String?
    let text: String
    /// Wraps the text within this width (send-to voice coach); one line otherwise.
    var maxTextWidth: CGFloat?
    let onClose: () -> Void

    private typealias Coach = Tokens.Layouts.CameraCaptureLayoutCoach

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                label
                    .dsTextStyle(CaptureType.coach)
                    .lineLimit(maxTextWidth == nil ? 1 : nil)
                    .fixedSize(horizontal: maxTextWidth == nil, vertical: true)
                    .frame(maxWidth: maxTextWidth, alignment: .leading)
                Image(systemName: Tokens.Icons.globalClose)
                    .resizable()
                    .scaledToFit()
                    .frame(width: Coach.closeGlyph, height: Coach.closeGlyph)
                    .padding(.leading, Coach.textToCloseGap)
                    .overlay {
                        Color.clear
                            .frame(width: Tokens.Sizes.globalMinTouchTargetIos, height: Tokens.Sizes.globalMinTouchTargetIos)
                            .contentShape(Rectangle())
                            .onTapGesture(perform: onClose)
                    }
                    .accessibilityElement()
                    .accessibilityLabel(Copy.cameraCaptureA11yClose)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction(onClose)
                    .accessibilitySortPriority(1)
            }
            .padding(.horizontal, Coach.paddingHorizontal)
            .frame(minHeight: Coach.height)
            .background(Tokens.Colors.globalAccent, in: RoundedRectangle(cornerRadius: Coach.cornerRadius, style: .continuous))
            CoachPointer()
                .fill(Tokens.Colors.globalAccent)
                .frame(width: Coach.pointerWidth, height: Coach.pointerHeight)
                .accessibilityHidden(true)
        }
        .foregroundStyle(Tokens.Colors.globalOnAccent)
        .accessibilityElement(children: .contain)
    }

    private var label: Text {
        guard let glyph else { return Text(text) }
        return Text(Image(systemName: glyph)) + Text(verbatim: " ") + Text(text)
    }
}

/// Downward triangle under the coach body.
struct CoachPointer: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// A shutter drawn from its tokens: ring, gap fill, disc.
struct CaptureShutterGraphic: View {
    let outer: CGFloat
    let ring: CGFloat
    let disc: CGFloat
    let ringColor: Color
    let gapColor: Color
    let discColor: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(gapColor)
                .frame(width: outer, height: outer)
            Circle()
                .strokeBorder(ringColor, lineWidth: ring)
                .frame(width: outer, height: outer)
            Circle()
                .fill(discColor)
                .frame(width: disc, height: disc)
        }
    }
}

extension View {
    /// A hit area of at least `size.global.minTouchTarget.ios` around a smaller control, without
    /// changing its layout.
    func captureMinimumHitArea(action: @escaping () -> Void) -> some View {
        overlay {
            Color.clear
                .frame(width: Tokens.Sizes.globalMinTouchTargetIos, height: Tokens.Sizes.globalMinTouchTargetIos)
                .contentShape(Rectangle())
                .onTapGesture(perform: action)
        }
    }
}

extension CameraPosition {
    var flipped: CameraPosition { self == .back ? .front : .back }
}
