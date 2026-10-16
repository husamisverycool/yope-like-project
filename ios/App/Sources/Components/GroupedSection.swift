// Shared component — C-14 grouped section and rows (settings) (design/components.md). Evidence: VID-SET frame 42
// (≈#F2F2F2, ≈12 corners); APK-X `pik` (12 dp shapes, 16 dp padding), vv3.l; RV §3.5, §4 #17; RP §3.5.
import DesignSystem
import SwiftUI

/// One row of a grouped section.
///
/// Title text role `body` in `color.global.textPrimary` (Title Case labels from copy), optional subtitle text role `meta`
/// in `color.global.textSecondary`; trailing `icon.global.chevron` in `color.global.textSecondary`, a native switch (tint
/// `color.global.selection`), or nothing. `role: .destructive` draws the title in `color.global.destructive` (C-10) with an
/// optional leading glyph. Row padding: Retro's Android rows pad 16 dp (APK, no token — Gap); iOS rows use the
/// platform's padding (16 pt). Row height was not measured (Gap) — at least `size.global.minTouchTarget.ios`.
/// Accessibility: a navigation / destructive row is one button; a switch row is the native toggle.
struct GroupedRow: View {
    enum Accessory {
        case chevron
        case toggle(Binding<Bool>)
        case none
    }

    enum Role {
        case normal
        case destructive
    }

    let title: String
    var subtitle: String?
    var icon: String?
    var accessory: Accessory = .chevron
    var role: Role = .normal
    var action: (() -> Void)?

    init(
        _ title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        accessory: Accessory = .chevron,
        role: Role = .normal,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.accessory = accessory
        self.role = role
        self.action = action
    }

    var body: some View {
        switch accessory {
        case let .toggle(isOn):
            Toggle(isOn: isOn) { labels }
                .tint(Tokens.Colors.globalSelection)
                .padding()
                .frame(minHeight: Tokens.Sizes.globalMinTouchTargetIos)
        case .chevron, .none:
            Button {
                action?()
            } label: {
                HStack {
                    labels
                    Spacer(minLength: 0)
                    if showsChevron {
                        Glyph(Tokens.Icons.globalChevron, relativeTo: TextRole.body.relativeTo)
                            .foregroundStyle(Tokens.Colors.globalTextSecondary)
                    }
                }
                .padding()
                .frame(minHeight: Tokens.Sizes.globalMinTouchTargetIos)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(action == nil)
        }
    }

    private var labels: some View {
        HStack {
            if let icon {
                Glyph(icon, relativeTo: TextRole.body.relativeTo)
                    .foregroundStyle(titleColor)
            }
            VStack(alignment: .leading) {
                Text(title)
                    .dsTextStyle(TextRole.body)
                    .foregroundStyle(titleColor)
                if let subtitle {
                    Text(subtitle)
                        .dsTextStyle(TextRole.meta)
                        .foregroundStyle(Tokens.Colors.globalTextSecondary)
                }
            }
            .multilineTextAlignment(.leading)
        }
    }

    private var showsChevron: Bool {
        if case .chevron = accessory { return true }
        return false
    }

    private var titleColor: Color {
        role == .destructive ? Tokens.Colors.globalDestructive : Tokens.Colors.globalTextPrimary
    }
}

/// C-14: an optional small section header (text role `meta`, `color.global.textSecondary`, a single Title Case word,
/// header trait), then the rows in one group: fill `color.global.control` (iOS), corners `radius.global.groupedRow`
/// (continuous) — the first row rounds its top corners, the last its bottom corners, a single row all four, middle rows
/// stay square — with a `size.global.hairline` divider in `color.global.separator` between rows. Inset
/// `size.global.screenMargin` from the screen edges (applied here). Header → group spacing was not measured (Gap) —
/// platform stack spacing; the header's leading inset follows the rows' padding.
struct GroupedSection: View {
    var header: String?
    let rows: [GroupedRow]

    init(header: String? = nil, rows: [GroupedRow]) {
        self.header = header
        self.rows = rows
    }

    var body: some View {
        VStack(alignment: .leading) {
            if let header {
                Text(header)
                    .dsTextStyle(TextRole.meta)
                    .foregroundStyle(Tokens.Colors.globalTextSecondary)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.horizontal)
            }
            VStack(spacing: 0) {
                ForEach(rows.indices, id: \.self) { index in
                    if index > 0 {
                        HairlineDivider()
                    }
                    rows[index]
                }
            }
            .background(Tokens.Colors.globalControl)
            .clipShape(DSShape.rounded(Tokens.Radii.globalGroupedRow))
        }
        .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
    }
}
