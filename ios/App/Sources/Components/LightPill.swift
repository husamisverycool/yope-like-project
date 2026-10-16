// Shared component — C-09 light pill on media (design/components.md), replacing Yope's white secondary pill.
// Evidence: TC-REC, ST-04 ('Share', row y=2420 x882–1026), ST-03 ('Add a message' 463–819, 1743–1830); RV §4 #6, §3.7.
//
// The role narrowed in the redesign (design/tokens/README.md "Redesign renames": `color.global.surfaceLight`): this
// pill is drawn over a photo or a black media surface only. On a page, use C-06 (`CapsuleButton`) or C-07
// (`OutlineCTA`).
import DesignSystem
import SwiftUI

/// The pill's look without the button (for a pill inside a larger tappable element).
///
/// - `.light` ('Share' on the recap preview, 'Send Postcard'-style actions on black): fill `color.global.surfaceLight`,
///   label `color.global.onSurfaceLight`.
/// - `.dark` ('Add a message' on the postcard photo): fill `color.global.controlOnDeep` (reads opaque in ST-03), glyph
///   and label `color.global.textOnMedia`.
///
/// Label text role `pill`; width hugs the label. Height: not isolated for 'Share' (Gap) — `size.global.pillHeight`
/// (the 37 pt measured for 'Add a message'), a minimum so the label can grow with Dynamic Type. With a glyph the
/// spacing is C-07's measured capsule anatomy (`size.global.pillPaddingLeading`, `.pillIconGap`,
/// `.pillPaddingTrailing`, glyph `size.global.iconSmall`); text-only side padding was not measured (Gap) — platform.
struct LightPillLabel: View {
    enum Style {
        case light
        case dark
    }

    let title: String
    var icon: String?
    var style: Style = .light

    init(_ title: String, icon: String? = nil, style: Style = .light) {
        self.title = title
        self.icon = icon
        self.style = style
    }

    var body: some View {
        content
            .foregroundStyle(style == .light ? Tokens.Colors.globalOnSurfaceLight : Tokens.Colors.globalTextOnMedia)
            .frame(minHeight: Tokens.Sizes.globalPillHeight)
            .background(style == .light ? Tokens.Colors.globalSurfaceLight : Tokens.Colors.globalControlOnDeep, in: Capsule())
            .contentShape(Capsule())
    }

    @ViewBuilder
    private var content: some View {
        if let icon {
            HStack(spacing: Tokens.Sizes.globalPillIconGap) {
                Glyph(icon, size: Tokens.Sizes.globalIconSmall, relativeTo: TextRole.pill.relativeTo)
                Text(title).dsTextStyle(TextRole.pill)
            }
            .padding(.leading, Tokens.Sizes.globalPillPaddingLeading)
            .padding(.trailing, Tokens.Sizes.globalPillPaddingTrailing)
        } else {
            Text(title)
                .dsTextStyle(TextRole.pill)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
}

/// C-09 light pill button. Pressed: platform default. Accessibility: button labelled with the visible text.
struct LightPill: View {
    let title: String
    var icon: String?
    var style: LightPillLabel.Style = .light
    var isEnabled: Bool = true
    let action: () -> Void

    init(_ title: String, icon: String? = nil, style: LightPillLabel.Style = .light, isEnabled: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.style = style
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            LightPillLabel(title, icon: icon, style: style)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(Text(title))
    }
}

// MARK: - Yope-era signatures (Pass 4 replaces the call sites)

extension LightPill {
    /// Yope's pill metrics (`groups.screen.size.lightPillHeight`, the permission card's fixed button). Retro has one
    /// pill (C-09); both cases draw it.
    enum Metrics {
        case standard
        case card
    }

    @available(*, deprecated, message: "Yope metrics are gone: on media use LightPill(_:icon:style:); on a page use CapsuleButton (C-06) / OutlineCTA (C-07)")
    init(_ title: String, icon: String? = nil, metrics: Metrics, isEnabled: Bool = true, action: @escaping () -> Void) {
        self.init(title, icon: icon, isEnabled: isEnabled, action: action)
    }
}

extension LightPillLabel {
    @available(*, deprecated, message: "Yope metrics are gone: on media use LightPillLabel(_:icon:style:); on a page use CapsuleLabel (C-06) / OutlineCTALabel (C-07)")
    init(_ title: String, icon: String? = nil, metrics: LightPill.Metrics) {
        self.init(title, icon: icon)
    }
}
