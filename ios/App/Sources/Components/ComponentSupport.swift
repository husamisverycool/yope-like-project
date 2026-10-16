// Shared component support — the primitives every Retro component uses (design/components.md, "Rules every component
// follows"): photos, glyphs, the continuous corner, minimum hit areas, the photo scrim, token motion, and a vertical
// stack that spaces views by their text metrics (baselines, cap tops) the way Retro's measurements are given.
// Nothing here chooses a value: every number is a token or arithmetic on tokens.
import DesignSystem
import SwiftUI
import UIKit

// MARK: - Photos

/// Where a component's photo comes from: a storage path (signed URL through `StorageImage`), a plain URL (`URLImage`),
/// or an image already in memory (just picked, previews, snapshots).
enum PhotoSource: Hashable {
    case storage(String)
    case url(URL)
    case image(UIImage)
}

/// A photo filling the frame its caller gives it (aspect-fill unless `contentMode` says otherwise), drawn in
/// `color.global.control` until it has loaded (C-17 placeholder tile, C-28).
struct PhotoView: View {
    let source: PhotoSource?
    var contentMode: ContentMode = .fill

    var body: some View {
        switch source {
        case let .storage(path)?:
            StorageImage(path: path, contentMode: contentMode) { placeholder }
        case let .url(url)?:
            URLImage(url: url, contentMode: contentMode) { placeholder }
        case let .image(image)?:
            GeometryReader { proxy in
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
            }
        case nil:
            placeholder
        }
    }

    private var placeholder: some View {
        Tokens.Colors.globalControl
    }
}

// MARK: - Glyphs

/// An SF Symbol in Retro's icon style (`layout.global.iconStyle`: outline variant, weight regular) filling a square
/// glyph box of a token size (`size.global.icon` 24 unless the component names another). Retro's glyph sizes are
/// measured as ink boxes, so the symbol is scaled to fit the box. With `relativeTo` the box scales with Dynamic Type
/// (glyphs next to text). Decorative: the control that contains it carries the label.
struct Glyph: View {
    let name: String
    let size: CGFloat
    private let scales: Bool
    @ScaledMetric private var scaledSize: CGFloat

    init(_ name: String, size: CGFloat = Tokens.Sizes.globalIcon, relativeTo textStyle: Font.TextStyle? = nil) {
        self.name = name
        self.size = size
        scales = textStyle != nil
        _scaledSize = ScaledMetric(wrappedValue: size, relativeTo: textStyle ?? .body)
    }

    var body: some View {
        let side = scales ? scaledSize : size
        Image(systemName: name)
            .resizable()
            .scaledToFit()
            .fontWeight(Font.Weight.regular)
            .frame(width: side, height: side)
            .accessibilityHidden(true)
    }
}

// MARK: - Shape

enum DSShape {
    /// A rounded rectangle with Retro's corner curve (`layout.global.cornerStyle`: continuous on iOS).
    static func rounded(_ radius: CGFloat) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }
}

// MARK: - Hit areas

extension View {
    /// Grows the hit area to at least `size.global.minTouchTarget.ios` around a control drawn at `drawn` points,
    /// without changing its layout (header glyphs, 32–36 pt circles, badges in rows).
    func minimumHitArea(drawn: CGSize) -> some View {
        let target = Tokens.Sizes.globalMinTouchTargetIos
        let grow = max(0, (target - drawn.width) / 2, (target - drawn.height) / 2)
        return contentShape(Rectangle().inset(by: -grow))
    }
}

// MARK: - Colour

extension Color {
    /// This token's dark-appearance value, in both appearances. Media surfaces are black in both appearances
    /// (`layout.global.appearance.media`), so a `{light, dark}` token drawn on them reads its dark value
    /// (C-22: the divider is `color.global.separator` dark #4D4D4D).
    var darkAppearanceValue: Color {
        let resolved = UIColor(self).resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
        return Color(uiColor: resolved) // provenance-ok: a token's own dark value, resolved
    }
}

// MARK: - Photo scrim

/// The bottom gradient on photos under white text (`layout.global.photoScrim`): black from transparent at `startAt`
/// of the height to `color.global.scrim` (black 60 %) at the bottom edge. Decorative; never takes touches.
struct PhotoScrim: View {
    var body: some View {
        let scrim = Tokens.Layouts.GlobalPhotoScrim.self
        // The scrim colour carries the end opacity; the start colour is the same black at the start opacity.
        let start = Tokens.Colors.globalScrim.opacity(scrim.startOpacity / max(scrim.endOpacity, .leastNonzeroMagnitude))
        LinearGradient(
            stops: [
                Gradient.Stop(color: start, location: 0),
                Gradient.Stop(color: start, location: scrim.startAt),
                Gradient.Stop(color: Tokens.Colors.globalScrim, location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Motion

/// Token animations the components share (design/components.md "Motion"). Apply with `.dsAnimation` /
/// `withDSAnimation` / `.dsTransition`, which honour Reduce Motion (`layout.global.reduceMotion`).
enum ComponentMotion {
    /// Appear / disappear: `duration.global.fade` with `easing.global.standard`.
    static let fade = DSAnimation.timing(duration: Tokens.Durations.globalFade, easing: Tokens.Easings.globalStandard)
    /// A state change of one element: `duration.global.crossfade` with `easing.global.standard`.
    static let crossfade = DSAnimation.timing(duration: Tokens.Durations.globalCrossfade, easing: Tokens.Easings.globalStandard)
    /// A strip tile shifting one slot: `duration.global.stripInsert` with `easing.global.standard`.
    static let stripInsert = DSAnimation.timing(duration: Tokens.Durations.globalStripInsert, easing: Tokens.Easings.globalStandard)
    /// Opening a photo from a card / tile into the viewer: `duration.global.photoOpen` with `easing.global.standard`.
    static let photoOpen = DSAnimation.timing(duration: Tokens.Durations.globalPhotoOpen, easing: Tokens.Easings.globalStandard)
}

// MARK: - Text metrics

extension VerticalAlignment {
    private enum CapMiddle: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat {
            context[VerticalAlignment.center]
        }
    }

    /// The middle of the capital letters of a text's first line (set by `.dsTextRole`); views without text use their
    /// centre. Retro centres header glyphs on the title's cap middle (C-01, C-02, C-20).
    static var capMiddle: VerticalAlignment { VerticalAlignment(CapMiddle.self) }
}

/// Font metrics of a text role at a (Dynamic Type scaled) size, for placing views by baseline and cap height.
struct TextMetrics {
    /// Height of the capital letters.
    let capHeight: CGFloat
    /// From the top of a one-line text's frame to its baseline.
    let ascender: CGFloat
    /// From the last baseline to the bottom of the text's frame (descender plus the font's leading).
    let belowBaseline: CGFloat

    init(style: DSTextStyle, size: CGFloat) {
        let font = Self.font(family: style.family, size: size, weight: style.weight)
        capHeight = font.capHeight
        ascender = font.ascender
        belowBaseline = font.lineHeight - font.ascender
    }

    /// From the top of a one-line text's frame to the top of its capitals.
    var capTopOffset: CGFloat { max(0, ascender - capHeight) }

    static func font(family: DSFontFamily, size: CGFloat, weight: Font.Weight) -> UIFont {
        let uiWeight = Self.uiWeight(weight)
        switch family {
        case .system:
            return UIFont.systemFont(ofSize: size, weight: uiWeight)
        case .systemSerif:
            let base = UIFont.systemFont(ofSize: size, weight: uiWeight)
            guard let serif = base.fontDescriptor.withDesign(.serif) else { return base }
            return UIFont(descriptor: serif, size: size)
        case let .custom(name):
            return UIFont(name: name, size: size) ?? UIFont.systemFont(ofSize: size, weight: uiWeight)
        }
    }

    static func uiWeight(_ weight: Font.Weight) -> UIFont.Weight {
        let pairs: [(Font.Weight, UIFont.Weight)] = [
            (.ultraLight, .ultraLight), (.thin, .thin), (.light, .light), (.regular, .regular),
            (.medium, .medium), (.semibold, .semibold), (.bold, .bold), (.heavy, .heavy), (.black, .black),
        ]
        return pairs.first { $0.0 == weight }?.1 ?? .regular
    }
}

/// The cap height a `MetricStack` child publishes for `.capTop` gaps.
private struct CapHeightKey: LayoutValueKey {
    static let defaultValue: CGFloat? = nil
}

/// The gap a `MetricStack` child keeps from the view before it.
private struct MetricGapKey: LayoutValueKey {
    static let defaultValue: MetricGap? = nil
}

/// A vertical distance between two text-metric lines, as Retro's spacings are measured (e.g. "title baseline → strip
/// top 30", "glyph bottom → title cap top 26").
struct MetricGap: Hashable, Sendable {
    enum Line: Hashable, Sendable {
        case top
        /// First baseline minus the published cap height (`.dsTextRole` / `.capHeight(of:)`); `top` without one.
        case capTop
        case firstBaseline
        case lastBaseline
        case bottom
    }

    /// The line of the previous view (the stack's top edge for the first view).
    var from: Line
    /// The line of this view.
    var to: Line
    var length: CGFloat
}

/// Applies a text role and publishes its metrics: the `.capMiddle` guide (cap middle of the first line) and the cap
/// height `MetricStack` uses for cap-top gaps.
private struct TextRoleModifier: ViewModifier {
    let style: DSTextStyle
    @ScaledMetric private var size: CGFloat

    init(style: DSTextStyle) {
        self.style = style
        _size = ScaledMetric(wrappedValue: style.size, relativeTo: style.relativeTo)
    }

    func body(content: Content) -> some View {
        let metrics = TextMetrics(style: style, size: size)
        return content
            .dsTextStyle(style)
            .alignmentGuide(.capMiddle) { dimensions in dimensions[.firstTextBaseline] - metrics.capHeight / 2 }
            .layoutValue(key: CapHeightKey.self, value: metrics.capHeight)
    }
}

/// For a one-line row whose children align on `.capMiddle` around a text of `style`: the row's first and last text
/// baselines become that text's baseline, and the row publishes the text's cap height.
private struct CapMiddleRowModifier: ViewModifier {
    let style: DSTextStyle
    @ScaledMetric private var size: CGFloat

    init(style: DSTextStyle) {
        self.style = style
        _size = ScaledMetric(wrappedValue: style.size, relativeTo: style.relativeTo)
    }

    func body(content: Content) -> some View {
        let half = TextMetrics(style: style, size: size).capHeight / 2
        return content
            .alignmentGuide(.firstTextBaseline) { dimensions in dimensions[.capMiddle] + half }
            .alignmentGuide(.lastTextBaseline) { dimensions in dimensions[.capMiddle] + half }
            .layoutValue(key: CapHeightKey.self, value: half * 2)
    }
}

/// For a container whose first line is a text of `style`: the `.capMiddle` guide from the container's first baseline.
private struct CapMiddleFromBaselineModifier: ViewModifier {
    let style: DSTextStyle
    @ScaledMetric private var size: CGFloat

    init(style: DSTextStyle) {
        self.style = style
        _size = ScaledMetric(wrappedValue: style.size, relativeTo: style.relativeTo)
    }

    func body(content: Content) -> some View {
        let half = TextMetrics(style: style, size: size).capHeight / 2
        return content.alignmentGuide(.capMiddle) { dimensions in dimensions[.firstTextBaseline] - half }
    }
}

/// Publishes the cap height of `style` (scaled) for a container whose first line is set in that role.
private struct CapHeightModifier: ViewModifier {
    let style: DSTextStyle
    @ScaledMetric private var size: CGFloat

    init(style: DSTextStyle) {
        self.style = style
        _size = ScaledMetric(wrappedValue: style.size, relativeTo: style.relativeTo)
    }

    func body(content: Content) -> some View {
        content.layoutValue(key: CapHeightKey.self, value: TextMetrics(style: style, size: size).capHeight)
    }
}

extension View {
    /// `.dsTextStyle(style)` plus the role's metrics (`.capMiddle` guide, cap height for `MetricStack`).
    func dsTextRole(_ style: DSTextStyle) -> some View {
        modifier(TextRoleModifier(style: style))
    }

    /// For a one-line row aligned on `.capMiddle` around a text of `style`: baselines from the cap middle.
    func capMiddleRow(_ style: DSTextStyle) -> some View {
        modifier(CapMiddleRowModifier(style: style))
    }

    /// For a container whose first line is a text of `style` (a row of text runs on one baseline): the `.capMiddle`
    /// guide from the container's first baseline.
    func capMiddleFromBaseline(_ style: DSTextStyle) -> some View {
        modifier(CapMiddleFromBaselineModifier(style: style))
    }

    /// Publishes the cap height of `style` for a container (e.g. a title + detail block) in a `MetricStack`.
    func capHeight(of style: DSTextStyle) -> some View {
        modifier(CapHeightModifier(style: style))
    }

    /// In a `MetricStack`: places this view so that its `to` line is `length` below the previous view's `from` line
    /// (the stack's top edge for the first view). Apply it last, on the stack's direct child.
    func metricGap(_ length: CGFloat, from: MetricGap.Line, to: MetricGap.Line) -> some View {
        layoutValue(key: MetricGapKey.self, value: MetricGap(from: from, to: to, length: length))
    }
}

/// A vertical stack that spaces its children by text metrics (`.metricGap`); a child without a gap sits directly below
/// the previous one. Children are aligned horizontally by `alignment` and offered the stack's width.
struct MetricStackLayout: Layout {
    var alignment: HorizontalAlignment = .leading

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let arrangement = arrange(width: bounds.width, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            let frame = arrangement.frames[index]
            let x: CGFloat
            if alignment == .center {
                x = bounds.minX + (bounds.width - frame.width) / 2
            } else if alignment == .trailing {
                x = bounds.maxX - frame.width
            } else {
                x = bounds.minX
            }
            subview.place(
                at: CGPoint(x: x, y: bounds.minY + frame.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: frame.width, height: frame.height)
            )
        }
    }

    /// The stack's first baseline is its first child's, its last baseline its last child's (so a `MetricStack` inside
    /// another one, or in a baseline-aligned row, is placed by its text).
    func explicitAlignment(
        of guide: VerticalAlignment,
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGFloat? {
        guard !subviews.isEmpty, guide == .firstTextBaseline || guide == .lastTextBaseline else { return nil }
        let arrangement = arrange(width: bounds.width, subviews: subviews)
        let index = guide == .firstTextBaseline ? 0 : subviews.count - 1
        let frame = arrangement.frames[index]
        let dimensions = subviews[index].dimensions(in: ProposedViewSize(width: frame.width, height: frame.height))
        return bounds.minY + frame.minY + dimensions[guide]
    }

    private func arrange(width: CGFloat?, subviews: Subviews) -> (frames: [CGRect], size: CGSize) {
        let finiteWidth = width.flatMap { $0.isFinite ? $0 : nil }
        let childProposal = ProposedViewSize(width: finiteWidth, height: nil)
        var frames: [CGRect] = []
        var previous: (y: CGFloat, dimensions: ViewDimensions, capHeight: CGFloat?)?
        for subview in subviews {
            let dimensions = subview.dimensions(in: childProposal)
            let capHeight = subview[CapHeightKey.self]
            var y: CGFloat = 0
            if let gap = subview[MetricGapKey.self] {
                let anchor = previous.map { $0.y + Self.offset(of: gap.from, $0.dimensions, $0.capHeight) } ?? 0
                y = anchor + gap.length - Self.offset(of: gap.to, dimensions, capHeight)
            } else if let previous {
                y = previous.y + previous.dimensions.height
            }
            frames.append(CGRect(x: 0, y: y, width: dimensions.width, height: dimensions.height))
            previous = (y, dimensions, capHeight)
        }
        // A view placed above the top (its line sits higher than the gap allows) moves everything down.
        let shift = min(0, frames.map(\.minY).min() ?? 0)
        frames = frames.map { $0.offsetBy(dx: 0, dy: -shift) }
        let contentWidth = frames.map(\.width).max() ?? 0
        let height = frames.map(\.maxY).max() ?? 0
        return (frames, CGSize(width: finiteWidth ?? contentWidth, height: height))
    }

    /// The line's distance from the view's top edge.
    private static func offset(of line: MetricGap.Line, _ dimensions: ViewDimensions, _ capHeight: CGFloat?) -> CGFloat {
        switch line {
        case .top:
            return 0
        case .capTop:
            guard let capHeight else { return 0 }
            return dimensions[.firstTextBaseline] - capHeight
        case .firstBaseline:
            return dimensions[.firstTextBaseline]
        case .lastBaseline:
            return dimensions[.lastTextBaseline]
        case .bottom:
            return dimensions.height
        }
    }
}

/// `MetricStackLayout` as a view with a content builder.
struct MetricStack<Content: View>: View {
    var alignment: HorizontalAlignment = .leading
    @ViewBuilder let content: Content

    var body: some View {
        MetricStackLayout(alignment: alignment).callAsFunction { content }
    }
}
