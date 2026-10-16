// Shared component — C-25 chips and small pills (design/components.md): the video duration pill and the premium pill.
// The fill pill ('Create') is C-06 `.fill`, the position pill C-22 (`PositionPill`), the relative-week pill C-03.
// Evidence: PAY ((945–955, 1480–1495), col x=960 y1450–1525); RV §3.1, §3.3, §4 #8.
import DesignSystem
import SwiftUI
import UIKit

/// Video duration ('1:00'): capsule `color.global.surfaceLight` with `icon.global.video` and monospaced digits in text
/// role `pillSmall`, `color.global.onSurfaceLight`. Retro's pill measures 71 × 24 pt; height 24 is read from
/// `size.global.badgeHeight` (the same measured capsule height; no token of its own — Gap), width hugs the content with
/// the platform's padding. Accessibility: read by the owner element (the duration in words from copy).
struct VideoDurationPill: View {
    let duration: String

    var body: some View {
        HStack {
            Glyph(Tokens.Icons.globalVideo, size: Tokens.Sizes.globalIconSmall, relativeTo: TextRole.pillSmall.relativeTo)
            Text(duration)
                .dsTextStyle(TextRole.pillSmall)
                .monospacedDigit()
                .lineLimit(1)
        }
        .foregroundStyle(Tokens.Colors.globalOnSurfaceLight)
        .padding(.horizontal)
        .frame(minHeight: Tokens.Sizes.globalBadgeHeight)
        .background(Tokens.Colors.globalSurfaceLight, in: Capsule())
        .accessibilityHidden(true)
    }
}

/// Premium pill ('FREE') — paywall only, the owner decides whether the premium accent is used: a capsule filled with
/// `layout.global.premiumGradient` (top → bottom; `color.global.premium` is its flat value), label text role
/// `pillSmall` (caps from copy) in `color.global.onBadge`. Retro's 51 × 26 pt size and its coloured shadow were not
/// tokenised (Gap): the pill hugs its label with the platform's padding, takes the small-capsule height
/// `size.global.badgeHeight` (24; 26 measured here) and has no shadow.
struct PremiumPill: View {
    let label: String

    var body: some View {
        Text(label)
            .dsTextStyle(TextRole.pillSmall)
            .foregroundStyle(Tokens.Colors.globalOnBadge)
            .lineLimit(1)
            .padding(.horizontal)
            .frame(minHeight: Tokens.Sizes.globalBadgeHeight)
            .background(PremiumGradient.fill, in: Capsule())
    }
}

/// `layout.global.premiumGradient` as a SwiftUI gradient (its hex values are token strings).
enum PremiumGradient {
    static var fill: LinearGradient {
        let top = color(hex: Tokens.Layouts.GlobalPremiumGradient.top) ?? Tokens.Colors.globalPremium
        let bottom = color(hex: Tokens.Layouts.GlobalPremiumGradient.bottom) ?? Tokens.Colors.globalPremium
        return LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
    }

    /// '#RRGGBB' → colour; nil when the string is not of that form.
    static func color(hex: String) -> Color? {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil } // provenance-ok: RRGGBB length
        let red = CGFloat((value >> 16) & 0xFF) / 255 // provenance-ok: 8-bit channel decoding of a token value
        let green = CGFloat((value >> 8) & 0xFF) / 255 // provenance-ok: 8-bit channel decoding of a token value
        let blue = CGFloat(value & 0xFF) / 255 // provenance-ok: 8-bit channel decoding of a token value
        return Color(uiColor: UIColor(red: red, green: green, blue: blue, alpha: 1)) // provenance-ok: token hex parsed
    }
}
