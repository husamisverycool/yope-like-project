// Shared component — C-01 screen header (root: serif title + trailing glyph buttons), C-02 screen header (pushed:
// back + serif title), and the bare header glyph button / menu (C-11 "bare header glyph") (design/components.md).
// Evidence: H43, H22 (title baseline 64 below the safe area; glyphs centred on the title's cap middle, 48 apart, last
// ink on the 16 margin), ED-W3 (pushed: chevron ink 21.1 from the edge, title 14.6 after it).
import DesignSystem
import SwiftUI

/// A trailing header glyph button: an icon and its label from copy (C-01 trailing glyphs).
struct HeaderAction {
    let icon: String
    let accessibilityLabel: String
    let action: () -> Void

    init(icon: String, accessibilityLabel: String, action: @escaping () -> Void) {
        self.icon = icon
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }
}

/// C-11 bare header glyph: `icon` in the `size.global.icon` box, no visible circle, hit area `size.global.headerButton`
/// (PLATFORM). `color` is `color.global.textPrimary` on pages, `color.global.textOnMedia` on media surfaces.
struct HeaderIconButton: View {
    let icon: String
    let accessibilityLabel: String
    var color: Color = Tokens.Colors.globalTextPrimary
    let action: () -> Void

    init(icon: String, accessibilityLabel: String, color: Color = Tokens.Colors.globalTextPrimary, action: @escaping () -> Void) {
        self.icon = icon
        self.accessibilityLabel = accessibilityLabel
        self.color = color
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HeaderGlyphFace(icon: icon, color: color)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(accessibilityLabel))
    }
}

/// A bare header glyph that opens a native menu (C-29: `Menu`; destructive items use `Button(role: .destructive)`).
struct HeaderIconMenu<Content: View>: View {
    let icon: String
    let accessibilityLabel: String
    var color: Color = Tokens.Colors.globalTextPrimary
    @ViewBuilder let content: () -> Content

    init(icon: String, accessibilityLabel: String, color: Color = Tokens.Colors.globalTextPrimary, @ViewBuilder content: @escaping () -> Content) {
        self.icon = icon
        self.accessibilityLabel = accessibilityLabel
        self.color = color
        self.content = content
    }

    var body: some View {
        Menu(content: content) {
            HeaderGlyphFace(icon: icon, color: color)
        }
        .accessibilityLabel(Text(accessibilityLabel))
    }
}

/// The glyph in its `size.global.headerButton` hit area.
private struct HeaderGlyphFace: View {
    let icon: String
    let color: Color

    var body: some View {
        Glyph(icon)
            .foregroundStyle(color)
            .frame(width: Tokens.Sizes.globalHeaderButton, height: Tokens.Sizes.globalHeaderButton)
            .contentShape(Rectangle())
    }
}

/// The trailing glyph row of C-01 / C-02: hit areas `size.global.headerButton` whose centres are
/// `size.global.headerIconPitch` apart; the last glyph's box sits `size.global.headerInset` from the screen edge.
private struct HeaderActionRow: View {
    let actions: [HeaderAction]
    let color: Color

    /// Hit area beyond the glyph box on each side.
    private static var hitOverhang: CGFloat { (Tokens.Sizes.globalHeaderButton - Tokens.Sizes.globalIcon) / 2 }

    /// Width the row takes from the trailing edge (the title keeps clear of it).
    static func width(count: Int) -> CGFloat {
        guard count > 0 else { return 0 }
        let pitchGap = Tokens.Sizes.globalHeaderIconPitch - Tokens.Sizes.globalHeaderButton
        return CGFloat(count) * Tokens.Sizes.globalHeaderButton + CGFloat(count - 1) * pitchGap + trailingPadding
    }

    static var trailingPadding: CGFloat { max(0, Tokens.Sizes.globalHeaderInset - hitOverhang) }

    var body: some View {
        HStack(spacing: Tokens.Sizes.globalHeaderIconPitch - Tokens.Sizes.globalHeaderButton) {
            ForEach(actions.indices, id: \.self) { index in
                let item = actions[index]
                HeaderIconButton(icon: item.icon, accessibilityLabel: item.accessibilityLabel, color: color, action: item.action)
            }
        }
        .padding(.trailing, Self.trailingPadding)
    }
}

/// C-01 screen header (root). The display serif title (text role `headerTitle`, `font.global.display`) at the leading
/// `size.global.screenMargin`, its first baseline `size.global.titleTop` below the top of the safe area; an optional
/// accessory after the title (C-03 relative-week pill) and up to two trailing glyph buttons, both centred on the
/// title's cap middle. No bar background, no hairline. The header's bottom edge is `size.global.titleToContent` below
/// the title's last baseline, where the content starts. Title and accessory read as one header element ("Week 19,
/// Last Week"); each glyph has its label from copy. On media surfaces pass `onMedia` (`color.global.textOnMedia`).
///
/// Scrolled state: Retro's collapsed title was not captured (Gap) — the header scrolls with the content.
struct ScreenHeader<Accessory: View>: View {
    let title: String
    var actions: [HeaderAction]
    var onMedia: Bool
    @ViewBuilder let accessory: () -> Accessory

    @ScaledMetric private var titleSize: CGFloat

    init(title: String, actions: [HeaderAction] = [], onMedia: Bool = false, @ViewBuilder accessory: @escaping () -> Accessory) {
        self.title = title
        self.actions = actions
        self.onMedia = onMedia
        self.accessory = accessory
        _titleSize = ScaledMetric(wrappedValue: TextRole.headerTitle.size, relativeTo: TextRole.headerTitle.relativeTo)
    }

    private var color: Color { onMedia ? Tokens.Colors.globalTextOnMedia : Tokens.Colors.globalTextPrimary }

    var body: some View {
        let metrics = TextMetrics(style: TextRole.headerTitle, size: titleSize)
        MetricStack {
            HStack(alignment: .capMiddle) {
                Text(title)
                    .dsTextRole(TextRole.headerTitle)
                    .foregroundStyle(color)
                accessory()
            }
            .capMiddleRow(TextRole.headerTitle)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            .padding(.leading, Tokens.Sizes.globalScreenMargin)
            .padding(.trailing, HeaderActionRow.width(count: actions.count))
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: Alignment(horizontal: .trailing, vertical: .capMiddle)) {
                HeaderActionRow(actions: actions, color: color)
            }
            .metricGap(Tokens.Sizes.globalTitleTop, from: .top, to: .firstBaseline)
            Color.clear
                .frame(height: 0)
                .metricGap(Tokens.Sizes.globalTitleToContent - metrics.belowBaseline, from: .bottom, to: .top)
        }
    }
}

extension ScreenHeader where Accessory == EmptyView {
    init(title: String, actions: [HeaderAction] = [], onMedia: Bool = false) {
        self.init(title: title, actions: actions, onMedia: onMedia) { EmptyView() }
    }
}

/// C-02 screen header (pushed): the back chevron (`icon.global.back`, `color.global.textPrimary`) with its ink
/// `size.global.backInset` from the screen edge, then the serif title `size.global.headerGap` after the chevron's ink,
/// on the same line (the chevron centred on the title's cap middle); trailing glyphs as C-01. The chevron is drawn at
/// the symbol size of the `size.global.icon` box (its ink then matches the measured 11.1 × 18.3 pt) and keeps a
/// `size.global.minTouchTarget.ios` hit area. Vertical metrics as C-01. Where the platform draws a native back button
/// (a visible navigation bar), use that instead.
struct PushedScreenHeader: View {
    let title: String
    let backAccessibilityLabel: String
    let onBack: () -> Void
    var actions: [HeaderAction] = []

    @ScaledMetric private var titleSize: CGFloat

    init(title: String, backAccessibilityLabel: String, actions: [HeaderAction] = [], onBack: @escaping () -> Void) {
        self.title = title
        self.backAccessibilityLabel = backAccessibilityLabel
        self.actions = actions
        self.onBack = onBack
        _titleSize = ScaledMetric(wrappedValue: TextRole.headerTitle.size, relativeTo: TextRole.headerTitle.relativeTo)
    }

    var body: some View {
        let metrics = TextMetrics(style: TextRole.headerTitle, size: titleSize)
        MetricStack {
            HStack(alignment: .capMiddle, spacing: Tokens.Sizes.globalHeaderGap) {
                Button(action: onBack) {
                    Image(systemName: Tokens.Icons.globalBack)
                        .font(Tokens.Fonts.globalFamily.font(size: Tokens.Sizes.globalIcon, weight: Font.Weight.regular))
                        .foregroundStyle(Tokens.Colors.globalTextPrimary)
                        .minimumHitArea(drawn: CGSize(width: Tokens.Sizes.globalIcon, height: Tokens.Sizes.globalIcon))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(backAccessibilityLabel))
                Text(title)
                    .dsTextRole(TextRole.headerTitle)
                    .foregroundStyle(Tokens.Colors.globalTextPrimary)
                    .accessibilityAddTraits(.isHeader)
            }
            .capMiddleRow(TextRole.headerTitle)
            .padding(.leading, Tokens.Sizes.globalBackInset)
            .padding(.trailing, HeaderActionRow.width(count: actions.count))
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: Alignment(horizontal: .trailing, vertical: .capMiddle)) {
                HeaderActionRow(actions: actions, color: Tokens.Colors.globalTextPrimary)
            }
            .metricGap(Tokens.Sizes.globalTitleTop, from: .top, to: .firstBaseline)
            Color.clear
                .frame(height: 0)
                .metricGap(Tokens.Sizes.globalTitleToContent - metrics.belowBaseline, from: .bottom, to: .top)
        }
    }
}

/// C-03 relative-week pill ('Last Week') after the title when the shown week is not the current one: capsule
/// `color.global.badgeMuted`, label text role `badge` in `color.global.onBadge`, height `size.global.badgeHeight`.
/// The label's side inset was not measured (Gap) — platform padding. Read as part of the title (C-01 combines them).
/// Contrast: white on #999999 2.85:1 FAIL (CONTRAST failure 7) — reported, not changed.
struct RelativeWeekPill: View {
    let label: String

    var body: some View {
        Text(label)
            .dsTextStyle(TextRole.badge)
            .foregroundStyle(Tokens.Colors.globalOnBadge)
            .lineLimit(1)
            .padding(.horizontal)
            .frame(minHeight: Tokens.Sizes.globalBadgeHeight)
            .background(Tokens.Colors.globalBadgeMuted, in: Capsule())
    }
}
