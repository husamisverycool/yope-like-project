// Surfaces: camera.capture, camera.sendto, daily.capture, collage.view (design/surfaces/<id>.md).
// Reference images: references/auto/retro/store/retro-store-03.png (ST-03: header, circles, pill on a photo),
// references/auto/retro/press/tc-2025-12-rewind-device-a.png (RWA: 64-pt circles beside a central control),
// references/auto/locket/store/locket-store-07.png (AS-7: shutter mechanics).
// Pieces the capture screens compose from the Pass 3 components (ios/App/Sources/Components) where a component has
// no variant for them: the media appearance rule, the shutter (a mechanic Retro lacks — RC-3), the 64-pt C-11 circle
// on media (no `CircleButtonStyle` case — component gap reported), the C-29 header of the black composer at its
// measured geometry (`camera.sendto.layout.header`), and the C-28 progress line on media.
import AppServices
import DesignSystem
import SwiftUI

// MARK: - Media appearance

extension View {
    /// Media surfaces stay black in both appearances (`layout.global.appearance.media`, RC-1): the subtree resolves the
    /// `{light, dark}` tokens to their dark values (separator #4D4D4D, disabled capsule #4D4D4D with a black label,
    /// inactive page dot #808080, the C-27 / C-06 / C-11 `.page` colours as their on-media equivalents). Attach
    /// sheets, alerts and covers outside this modifier: sheets over media follow the system appearance.
    func captureMediaAppearance() -> some View {
        environment(\.colorScheme, .dark)
    }
}

// MARK: - Shutter (mechanics: Locket AS-7; colours Retro's — RC-3)

/// The shutter: outer `camera.capture.size.shutterOuter` (86) with a `camera.capture.size.shutterRing` (4.5) ring in
/// `color.global.surfaceLight`, the gap in `color.global.backgroundDeep`, and the `camera.capture.size.shutterDisc` (70)
/// disc in `color.global.surfaceLight`. The four measured values do not sum (86 − 2 × 4.5 − 70 = 7, not 2 × 3): outer,
/// ring and disc are drawn exactly, so the gap (`camera.capture.size.shutterGap` 3) shows 3.5. No custom press state
/// (RC-3: the platform default; Retro's press was not recorded). Decorative: the caller makes it a control.
struct CaptureShutter: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Tokens.Colors.globalBackgroundDeep)
            Circle()
                .strokeBorder(Tokens.Colors.globalSurfaceLight, lineWidth: Tokens.Sizes.cameraCaptureSizeShutterRing)
            Circle()
                .fill(Tokens.Colors.globalSurfaceLight)
                .frame(width: Tokens.Sizes.cameraCaptureSizeShutterDisc, height: Tokens.Sizes.cameraCaptureSizeShutterDisc)
        }
        .frame(width: Tokens.Sizes.cameraCaptureSizeShutterOuter, height: Tokens.Sizes.cameraCaptureSizeShutterOuter)
        .accessibilityHidden(true)
    }
}

// MARK: - Control row (C-35 rule)

/// The control row of `camera.capture.layout.controlRow`: the central control (the shutter) horizontally centred and
/// each side control centred in the free space between the screen edge and the central control's outer edge (Retro's
/// Rewind rule, RWA / RWB: 76.8 pt from the edge on a 393-pt screen). The row is as tall as its tallest child.
struct CaptureControlRow<Leading: View, Centre: View, Trailing: View>: View {
    @ViewBuilder let leading: () -> Leading
    @ViewBuilder let centre: () -> Centre
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        // Each slot is one subview even when its content is hidden (a ZStack with no children has zero size).
        CaptureControlRowLayout(centreWidth: Tokens.Sizes.cameraCaptureSizeShutterOuter) {
            ZStack { leading() }
            ZStack { centre() }
            ZStack { trailing() }
        }
    }
}

/// Places three children: leading, centre, trailing (see `CaptureControlRow`).
private struct CaptureControlRowLayout: Layout {
    let centreWidth: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        // At least the central control's height, so the row keeps its place when the shutter is hidden (denied).
        let height = max(centreWidth, subviews.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0)
        return CGSize(width: proposal.width ?? centreWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 3 else { return }
        let centreX = bounds.midX
        // Free space on each side: from the screen edge to the central control's outer edge; side controls sit at its middle.
        let sideCentre = (bounds.width / 2 - centreWidth / 2) / 2
        let xs = [bounds.minX + sideCentre, centreX, bounds.maxX - sideCentre]
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: xs[index], y: bounds.midY), anchor: .center, proposal: .unspecified)
        }
    }
}

// MARK: - Large circle on media (C-11, 64 pt)

/// C-11 circle beside a central control on a media surface (`camera.capture` library / flip, `daily.capture` flash /
/// flip): `size.global.circleButtonLarge` (64), fill `color.global.controlOnDeep`, glyph in a `size.global.icon` box in
/// `color.global.textOnMedia`. `CircleButtonStyle` has `.glassLarge` (64, glass) and `.media` (36, #262626) but no 64-pt
/// media circle, so it is composed here from the same face rules (component gap reported). Pressed: platform default.
struct CaptureLargeCircleButton: View {
    let icon: String
    let accessibilityLabel: String
    var accessibilityValue: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Glyph(icon)
                .foregroundStyle(Tokens.Colors.globalTextOnMedia)
                .frame(width: Tokens.Sizes.globalCircleButtonLarge, height: Tokens.Sizes.globalCircleButtonLarge)
                .background(Tokens.Colors.globalControlOnDeep, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(accessibilityLabel))
        .accessibilityValue(Text(accessibilityValue ?? ""))
    }
}

// MARK: - Header of the black composer (C-29 on media)

/// The header of the postcard-style composer (`camera.sendto.layout.header`, ST-03), shared by `camera.sendto` and
/// `daily.capture`: the title centred with its cap middle on the circles' centre line, which lies
/// `centreBelowSafeArea` (25.8) below the safe-area top; a trailing close circle (C-11 `.media`: 36, #262626, glyph
/// `size.global.iconSmall`) centred
/// 37.7 pt from the trailing edge; optionally a leading circle mirrored (send-to's save). The title keeps clear of both
/// circles. Place it at the top of the safe area.
struct CaptureMediaHeader<Title: View>: View {
    var leading: HeaderAction?
    let trailing: HeaderAction
    /// UI-test identifiers of the circles.
    var leadingIdentifier = ""
    var trailingIdentifier = ""
    @ViewBuilder let title: () -> Title

    /// From the screen edge to a circle's centre. `camera.sendto.layout.header` states it in words ("centre 37.7 pt
    /// from the trailing edge", ST-03); the number is `collage.view.layout.screen` closeCentreFromTrailing — the same
    /// Retro close circle, measured 37.7 pt on ST-04.
    static var measuredCentreInset: CGFloat { Tokens.Layouts.CollageViewLayoutScreen.closeCentreFromTrailing }

    var body: some View {
        let edgeToCircle = Self.measuredCentreInset - Tokens.Sizes.globalCircleButton / 2
        HStack(spacing: 0) {
            if let leading {
                circle(leading)
                    .accessibilityIdentifier(leadingIdentifier)
                    .accessibilitySortPriority(2)
            }
            Spacer(minLength: 0)
            circle(trailing)
                .accessibilityIdentifier(trailingIdentifier)
        }
        .padding(.horizontal, edgeToCircle)
        .frame(height: Tokens.Sizes.globalCircleButton)
        .overlay(alignment: Alignment(horizontal: .center, vertical: .capMiddle)) {
            title()
                .padding(.horizontal, Self.measuredCentreInset + Tokens.Sizes.globalCircleButton / 2)
        }
        .padding(.top, Tokens.Layouts.CameraSendtoLayoutHeader.centreBelowSafeArea - Tokens.Sizes.globalCircleButton / 2)
        .frame(maxWidth: .infinity, alignment: .top)
    }

    /// C-11 media circles: the glyph ink is the circle's measured default (`size.global.circleCloseGlyph` for the '×',
    /// `size.global.circleGlyph` for the save arrow; ST-03 / ST-04).
    private func circle(_ item: HeaderAction) -> some View {
        CircleButton(icon: item.icon, accessibilityLabel: item.accessibilityLabel, style: .media, action: item.action)
    }
}

extension CaptureMediaHeader where Title == CaptureMediaHeaderTitle {
    /// A text title (text role `sheetTitle`, `color.global.textOnMedia`, header trait).
    init(title: String, leading: HeaderAction? = nil, trailing: HeaderAction) {
        self.init(leading: leading, trailing: trailing, title: { CaptureMediaHeaderTitle(text: title) })
    }
}

/// The header's text title: text role `sheetTitle` in `color.global.textOnMedia`, one line, header trait; changes of
/// the text cross-fade (`duration.global.crossfade` — "Share Photo" ↔ "Sending…").
struct CaptureMediaHeaderTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .dsTextRole(TextRole.sheetTitle)
            .foregroundStyle(Tokens.Colors.globalTextOnMedia)
            .lineLimit(1)
            .contentTransition(.opacity)
            .dsAnimation(ComponentMotion.crossfade, value: text)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Progress on media (C-28 + C-27 title role)

/// The platform activity indicator in `color.global.textOnMedia`, then — its top `size.global.emptyIconToTitle` below
/// the indicator — one centred line in text role `emptyTitle`, `color.global.textOnMedia` (daily.capture "capturing",
/// collage.view "loading"). Read as one element that updates frequently.
struct CaptureMediaProgress: View {
    let text: String

    var body: some View {
        MetricStack(alignment: .center) {
            ProgressView()
                .tint(Tokens.Colors.globalTextOnMedia)
            Text(text)
                .dsTextRole(TextRole.emptyTitle)
                .foregroundStyle(Tokens.Colors.globalTextOnMedia)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .metricGap(Tokens.Sizes.globalEmptyIconToTitle, from: .bottom, to: .capTop)
        }
        .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
    }
}

// MARK: - Helpers

extension CameraPosition {
    var flipped: CameraPosition { self == .back ? .front : .back }
}
