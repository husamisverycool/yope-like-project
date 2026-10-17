// Surfaces: widget.styles (Photo · Date · Frame), on every home-screen photo widget (widget.home.small / .medium / .large
// / .xl, widget.friend, widget.memories) — design/surfaces/widget.styles.md.
// Reference images: references/auto/retro/store/retro-store-04.png and references/auto/retro/play/retro-play-04.png
// (Retro's instant-print recap: the Frame style), references/auto/retro/press/tc-2025-12-rewind-device-a.png and
// references/auto/retro/store/retro-store-05.png (Rewind's serif date: the Date style),
// references/auto/locket/mobbin/locket-mobbin-gold-flow-2.png (Locket Gold "Widget frames": premium widget decoration),
// references/auto/retro/apk/widget_preview_journals.webp (the Photo style, Retro's widget).
// Pure SwiftUI on `GroupWidgetContent` (no timeline types), linked into AppTests (ios/AppTests/Capture/Linked) for the
// snapshots of every style and size.
import AppModels
import DesignSystem
import SwiftUI
import UIKit
import WidgetKit

/// What one home-screen photo widget draws: the content (photo, names, state), the style it draws, and the kind's own
/// words where they differ from the group widget's (the friend and memories widgets' state lines and labels).
struct WidgetPresentation {
    var content: GroupWidgetContent
    /// The style drawn (a locked premium style is already `.photo` here — `WidgetPhotoStyle.drawn(isPremium:)`).
    var style: WidgetPhotoStyle = .photo
    /// Replaces the group widget's state line (`widget.home.small.empty.*`) for the kind's own empty / not-set-up words.
    var stateLine: String?
    /// Replaces the group widget's accessibility label when the item has one of its own (a memory).
    var accessibilityLabel: String?

    var resolvedStateLine: String? { stateLine ?? content.stateLine }

    var resolvedAccessibilityLabel: String {
        if let accessibilityLabel, content.state == .photo || content.state == .collage { return accessibilityLabel }
        switch content.state {
        case .empty, .notSetUp, .signedOut: return resolvedStateLine ?? ""
        default: return content.accessibilityLabel
        }
    }

    var showsItem: Bool { content.state == .photo || content.state == .collage }

    /// {date} of the Date style and of the memory label: `layout.onthisday.dateFormat` ("Jul 22, 2022").
    var dateText: String {
        content.postedAt.map { $0.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted)) } ?? ""
    }
}

// MARK: - Container background (removable: StandBy / tinted)

/// Photo and Date: the photo under the bottom scrim (`WidgetContainerBackground`). Frame: the blurred backdrop with
/// the print and its photo (`widget.styles.layout.frame`). Every non-item state: `color.global.backgroundDeep`.
struct StyledWidgetBackground: View {
    let presentation: WidgetPresentation

    var body: some View {
        switch presentation.style {
        case .frame where presentation.showsItem && presentation.content.photo != nil:
            WidgetPrintBackground(photo: presentation.content.photo!)
        default:
            WidgetContainerBackground(content: presentation.content)
        }
    }
}

/// `widget.styles.layout.frame`: C-34 backdrop — the photo aspect-filling the widget, Gaussian σ
/// `size.global.backdropBlur`, under `color.global.backdropDim` — and the instant print centred on it: the largest of
/// aspect 1 ÷ `aspect` inside `fit` × the widget, paper `widget.styles.color.frame`, a square window `sideBorder` in from
/// the sides and `topBorder` from the top, the photo aspect-filling it.
struct WidgetPrintBackground: View {
    let photo: UIImage

    private typealias Frame = Tokens.Layouts.WidgetStylesLayoutFrame

    static func printSize(in size: CGSize) -> CGSize {
        let maxWidth = size.width * Frame.fit
        let maxHeight = size.height * Frame.fit
        let width = min(maxWidth, maxHeight / Frame.aspect)
        return CGSize(width: width, height: width * Frame.aspect)
    }

    var body: some View {
        GeometryReader { proxy in
            let print = Self.printSize(in: proxy.size)
            let window = print.width * (1 - 2 * Frame.sideBorder)
            ZStack {
                Tokens.Colors.globalBackgroundDeep
                WidgetPhotoImage(image: photo)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .blur(radius: Tokens.Sizes.globalBackdropBlur, opaque: true)
                Tokens.Colors.globalBackdropDim
                ZStack(alignment: .top) {
                    Tokens.Colors.widgetStylesColorFrame
                    WidgetPhotoImage(image: photo)
                        .frame(width: window, height: window)
                        .clipped()
                        .padding(.top, print.width * Frame.topBorder)
                }
                .frame(width: print.width, height: print.height)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Overlay

/// Photo: the name stack (`WidgetTextStack`). Date: the same, and the item's date top-leading
/// (`widget.styles.layout.date`). Frame: no text over the print. States: the state column with the kind's line.
/// One accessibility element with the button trait (the tap).
struct StyledWidgetOverlay: View {
    let presentation: WidgetPresentation

    var body: some View {
        ZStack {
            switch presentation.content.state {
            case .photo, .collage:
                if presentation.style != .frame { WidgetTextStack(lines: stackLines) }
                if presentation.style == .date { WidgetDateTitle(text: presentation.dateText) }
            case .empty, .notSetUp, .signedOut:
                WidgetStateColumn(line: presentation.resolvedStateLine)
            case .loading:
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(presentation.resolvedAccessibilityLabel))
        .accessibilityAddTraits(.isButton)
    }

    /// Line 1 the poster's first name, line 2 the group (a collage: the group alone) — `widget.home.small.layout.overlay`.
    private var stackLines: [String] {
        let content = presentation.content
        return content.state == .collage ? [content.groupName ?? ""] : [content.firstName, content.groupName ?? ""]
    }
}

/// `widget.styles.layout.date`: the date in `font.global.display`, text role `displaySmall`, `color.global.textOnMedia`,
/// one line; leading inset and cap top `size.global.screenMargin` (the cap height scales with the text, title2).
struct WidgetDateTitle: View {
    let text: String

    @ScaledMetric private var capHeight: CGFloat

    init(text: String) {
        self.text = text
        let style = WidgetType.displaySmall
        _capHeight = ScaledMetric(wrappedValue: WidgetDateTitle.defaultCapHeight(style), relativeTo: style.relativeTo)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            Text(text)
                .dsTextStyle(WidgetType.displaySmall)
                .foregroundStyle(Tokens.Colors.globalTextOnMedia)
                .lineLimit(1)
                .truncationMode(.tail)
                // The cap top sits `screenMargin` below the edge: the first baseline is the margin plus the cap height.
                .alignmentGuide(.top) { dimensions in dimensions[.firstTextBaseline] - capHeight }
                .padding(.top, Tokens.Sizes.globalScreenMargin)
                .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
        }
    }

    /// The display face's cap height at the role's default size (the bundled font registers on first use).
    static func defaultCapHeight(_ style: DSTextStyle) -> CGFloat {
        DSBundledFonts.registerOnce()
        guard case let .custom(name) = style.family, let font = UIFont(name: name, size: style.size) else {
            return UIFont.systemFont(ofSize: style.size).capHeight
        }
        return font.capHeight
    }
}

extension WidgetType {
    /// Text role `displaySmall` (25.8, Dynamic Type `layout.global.textStyleMap.displaySmall` — title2) in
    /// `font.global.display`: the Date style's title (`widget.styles.layout.date`).
    static var displaySmall: DSTextStyle {
        DSTextStyle(
            family: Tokens.Fonts.globalDisplay,
            size: Tokens.FontSizes.globalDisplaySmall,
            weight: Tokens.FontWeights.fontWeightGlobalDisplaySmall,
            relativeTo: WidgetTextStyleName.resolve(Tokens.Layouts.GlobalTextStyleMap.displaySmall)
        )
    }
}
