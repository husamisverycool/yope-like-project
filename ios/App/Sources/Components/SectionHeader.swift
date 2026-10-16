// Shared component — C-20 section header ('Week 27  Jul 3 - 9') and the week section it heads (C-20 + C-17), stacked
// in the profile / history week list (C-21) (design/components.md). Evidence: ST-02 ('W' cap y1289–1313; baseline
// 1313 → strip 1341; strip 1608 → header 1695), TC-J1; RV §4 #3, #24; design/research/retro-timehop.md
// "Measured values — week.history".
import DesignSystem
import SwiftUI

/// Two runs on one baseline one space apart — the week (text role `sectionLabel`, `color.global.textPrimary`) and the
/// range (text role `listSubtitle`, `color.global.textSecondary`; omitted for the current week without photos) — then
/// '•••' (`icon.global.more`, `color.global.textPrimary`) with its glyph box on the right margin, centred on the text's
/// cap middle, opening a native menu (C-29; Retro's week menu contents were not captured — Gap). The dated variant
/// (album grid, 'January 25, 2024') is a title without a range. Inset `size.global.screenMargin`. The header's frame is
/// its text (the menu's hit area overhangs it), so `WeekSection` / `WeekSectionList` space by its baseline and cap top.
/// Accessibility: header trait, read as one element (`accessibilityLabel` from copy: "Week 27, July 3 to 9"); the
/// menu is a separate labelled button. Contrast: the range on white 2.85:1 FAIL (failure 1), reported, not changed.
struct SectionHeader<MenuContent: View>: View {
    let title: String
    var detail: String?
    var accessibilityLabel: String?
    var moreAccessibilityLabel: String?
    @ViewBuilder let menu: () -> MenuContent

    init(
        title: String,
        detail: String? = nil,
        accessibilityLabel: String? = nil,
        moreAccessibilityLabel: String?,
        @ViewBuilder menu: @escaping () -> MenuContent
    ) {
        self.title = title
        self.detail = detail
        self.accessibilityLabel = accessibilityLabel
        self.moreAccessibilityLabel = moreAccessibilityLabel
        self.menu = menu
    }

    /// The menu's hit area beyond its glyph box on each side; the glyph box sits on the margin.
    private var hitOverhang: CGFloat { (Tokens.Sizes.globalHeaderButton - Tokens.Sizes.globalIcon) / 2 }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(title)
                .dsTextStyle(TextRole.sectionLabel)
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
            if let detail {
                Text(" " + detail)
                    .dsTextStyle(TextRole.listSubtitle)
                    .foregroundStyle(Tokens.Colors.globalTextSecondary)
            }
        }
        .lineLimit(1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityLabel ?? [title, detail].compactMap { $0 }.joined(separator: " ")))
        .accessibilityAddTraits(.isHeader)
        .capMiddleFromBaseline(TextRole.sectionLabel)
        .padding(.leading, Tokens.Sizes.globalScreenMargin)
        .padding(.trailing, Tokens.Sizes.globalScreenMargin + (moreAccessibilityLabel == nil ? 0 : Tokens.Sizes.globalIcon))
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: Alignment(horizontal: .trailing, vertical: .capMiddle)) {
            if let moreAccessibilityLabel {
                HeaderIconMenu(icon: Tokens.Icons.globalMore, accessibilityLabel: moreAccessibilityLabel, content: menu)
                    .padding(.trailing, max(0, Tokens.Sizes.globalScreenMargin - hitOverhang))
            }
        }
        .capHeight(of: TextRole.sectionLabel)
    }
}

extension SectionHeader where MenuContent == EmptyView {
    /// A header without the '•••' menu.
    init(title: String, detail: String? = nil, accessibilityLabel: String? = nil) {
        self.init(title: title, detail: detail, accessibilityLabel: accessibilityLabel, moreAccessibilityLabel: nil) { EmptyView() }
    }
}

/// A week section (C-21 profile / history list): the C-20 header, then its content (the C-17 strip) with its top
/// `size.global.sectionHeaderToContent` below the header's baseline.
struct WeekSection<Header: View, Content: View>: View {
    @ViewBuilder let header: () -> Header
    @ViewBuilder let content: () -> Content

    init(@ViewBuilder header: @escaping () -> Header, @ViewBuilder content: @escaping () -> Content) {
        self.header = header
        self.content = content
    }

    var body: some View {
        MetricStack {
            header()
            content()
                .metricGap(Tokens.Sizes.globalSectionHeaderToContent, from: .lastBaseline, to: .top)
        }
    }
}

/// Week sections, newest first, in a lazy stack: each header's cap top `size.global.sectionGap` below the previous
/// section's bottom. Assumes C-20 headers (their frame starts at the text's top, in text role `sectionLabel`), so the
/// spacing is `sectionGap` minus the distance from the text's top to its cap top at the current Dynamic Type size.
struct WeekSectionList<Content: View>: View {
    @ViewBuilder let content: Content

    @ScaledMetric private var labelSize: CGFloat

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
        _labelSize = ScaledMetric(wrappedValue: TextRole.sectionLabel.size, relativeTo: TextRole.sectionLabel.relativeTo)
    }

    var body: some View {
        let capTop = TextMetrics(style: TextRole.sectionLabel, size: labelSize).capTopOffset
        LazyVStack(alignment: .leading, spacing: max(0, Tokens.Sizes.globalSectionGap - capTop)) {
            content
        }
    }
}
