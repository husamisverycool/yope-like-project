// Shared component — C-35 full-bleed media page (Rewind-style) (design/components.md). Evidence: RWA, RWB
// (`press/tc-2025-12-rewind-device-b.jpg`), TC-RWP, ST-05; RV §4 #19; RP §3.8.
import DesignSystem
import SwiftUI

/// A glass circle action beside the central control (C-11 `.glassLarge`: `icon.global.share`, `icon.global.random`).
struct MediaCircleAction {
    let icon: String
    let accessibilityLabel: String
    let action: () -> Void

    init(icon: String, accessibilityLabel: String, action: @escaping () -> Void) {
        self.icon = icon
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }
}

/// A full-bleed photo on `color.global.backgroundDeep` (black in both appearances) with the bottom
/// `layout.global.photoScrim`; the display date title (C-01 metrics, text role `headerTitle`, `color.global.textOnMedia`)
/// with an optional `icon.global.chevronDown` after it (tapping the title opens the date picker — mechanics); the
/// subtitle ('On this week', text role `textButton` in `color.global.textOnMedia` — Retro draws it at a reduced opacity
/// that is not measurable over a photo, Gap, so it is not reduced); a glass '•••' (C-11 `.glass`) at the right margin
/// opening a native menu; and at the bottom the central `control` (the dial — mechanics; it plays `haptic.global.select`
/// once per step) flanked by large glass circles. The tab bar (C-04 `.overPhoto`) sits on the scrim — the shell's.
/// Spacing of the bottom row and the subtitle was not tokenised (Gap) — platform spacing.
/// Accessibility: the photo is labelled from copy; title, subtitle and controls read in order.
struct FullBleedMediaPage<Control: View, MenuContent: View>: View {
    let photo: PhotoSource?
    let photoAccessibilityLabel: String
    let title: String
    var subtitle: String?
    var onTitle: (() -> Void)?
    var moreAccessibilityLabel: String?
    var leading: MediaCircleAction?
    var trailing: MediaCircleAction?
    @ViewBuilder let menu: () -> MenuContent
    @ViewBuilder let control: () -> Control

    init(
        photo: PhotoSource?,
        photoAccessibilityLabel: String,
        title: String,
        subtitle: String? = nil,
        onTitle: (() -> Void)? = nil,
        moreAccessibilityLabel: String? = nil,
        leading: MediaCircleAction? = nil,
        trailing: MediaCircleAction? = nil,
        @ViewBuilder menu: @escaping () -> MenuContent,
        @ViewBuilder control: @escaping () -> Control
    ) {
        self.photo = photo
        self.photoAccessibilityLabel = photoAccessibilityLabel
        self.title = title
        self.subtitle = subtitle
        self.onTitle = onTitle
        self.moreAccessibilityLabel = moreAccessibilityLabel
        self.leading = leading
        self.trailing = trailing
        self.menu = menu
        self.control = control
    }

    var body: some View {
        ZStack {
            Tokens.Colors.globalBackgroundDeep.ignoresSafeArea()
            PhotoView(source: photo)
                .ignoresSafeArea()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(photoAccessibilityLabel))
                .accessibilityAddTraits(.isImage)
            PhotoScrim()
                .ignoresSafeArea()
            VStack(alignment: .leading) {
                header
                if let subtitle {
                    Text(subtitle)
                        .dsTextStyle(TextRole.textButton)
                        .foregroundStyle(Tokens.Colors.globalTextOnMedia)
                        .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
                }
                Spacer(minLength: 0)
                HStack {
                    circle(leading)
                    Spacer(minLength: 0)
                    control()
                    Spacer(minLength: 0)
                    circle(trailing)
                }
                .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
            }
        }
    }

    /// C-01 metrics on media: the title's first baseline `size.global.titleTop` below the safe area; the chevron and the
    /// '•••' circle centred on its cap middle (RWA: the circle spans the cap middle), the circle's ink on the margin.
    private var header: some View {
        MetricStack {
            HStack(alignment: .capMiddle) {
                Text(title)
                    .dsTextRole(TextRole.headerTitle)
                    .foregroundStyle(Tokens.Colors.globalTextOnMedia)
                if onTitle != nil {
                    Glyph(Tokens.Icons.globalChevronDown)
                        .foregroundStyle(Tokens.Colors.globalTextOnMedia)
                }
            }
            .capMiddleRow(TextRole.headerTitle)
            .contentShape(Rectangle())
            .onTapGesture { onTitle?() }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(onTitle != nil ? [.isHeader, .isButton] : .isHeader)
            .padding(.leading, Tokens.Sizes.globalScreenMargin)
            .padding(.trailing, Tokens.Sizes.globalScreenMargin + Tokens.Sizes.globalCircleButtonPhoto)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: Alignment(horizontal: .trailing, vertical: .capMiddle)) {
                if let moreAccessibilityLabel {
                    CircleMenu(icon: Tokens.Icons.globalMore, accessibilityLabel: moreAccessibilityLabel, style: .glass, content: menu)
                        .padding(.trailing, Tokens.Sizes.globalScreenMargin)
                }
            }
            .metricGap(Tokens.Sizes.globalTitleTop, from: .top, to: .firstBaseline)
        }
    }

    @ViewBuilder
    private func circle(_ item: MediaCircleAction?) -> some View {
        if let item {
            CircleButton(icon: item.icon, accessibilityLabel: item.accessibilityLabel, style: .glassLarge, action: item.action)
        }
    }
}

extension FullBleedMediaPage where MenuContent == EmptyView {
    init(
        photo: PhotoSource?,
        photoAccessibilityLabel: String,
        title: String,
        subtitle: String? = nil,
        onTitle: (() -> Void)? = nil,
        leading: MediaCircleAction? = nil,
        trailing: MediaCircleAction? = nil,
        @ViewBuilder control: @escaping () -> Control
    ) {
        self.init(
            photo: photo, photoAccessibilityLabel: photoAccessibilityLabel, title: title, subtitle: subtitle,
            onTitle: onTitle, moreAccessibilityLabel: nil, leading: leading, trailing: trailing,
            menu: { EmptyView() }, control: control
        )
    }
}
