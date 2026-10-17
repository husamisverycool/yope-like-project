// Shared component — C-25 chips and small pills (design/components.md): the video duration pill (and its tile marker,
// `layout.global.videoMarker`) and the premium pill.
// The fill pill ('Create') is C-06 `.fill`, the position pill C-22 (`PositionPill`), the relative-week pill C-03.
// Evidence: PAY ((945–955, 1480–1495), col x=960 y1450–1525; the "1:00" pill x 718–930, y 455–538 on the card x 232–974,
// top 410); RV §3.1, §3.3, §4 #8; references/auto/platform/android-photopicker-unselected-f150.png (top-trailing marker).
import DesignSystem
import SwiftUI
import UIKit

/// Video duration ('1:00'): capsule `color.global.surfaceLight`, `size.global.videoPillHeight` tall,
/// `size.global.videoPillPadding` each side; `icon.global.video` (`size.global.iconSmall`), `size.global.videoPillGap`, then
/// monospaced digits in text role `pillSmall`, `color.global.onSurfaceLight` (PAY: 71 × 28 pt). `duration` nil: the glyph
/// alone (a tile too narrow for the digits, `layout.global.videoMarker`). Accessibility: read by the owner element
/// (`chat.thread.a11y.video`).
struct VideoDurationPill: View {
    let duration: String?

    var body: some View {
        HStack(spacing: Tokens.Sizes.globalVideoPillGap) {
            Glyph(Tokens.Icons.globalVideo, size: Tokens.Sizes.globalIconSmall, relativeTo: TextRole.pillSmall.relativeTo)
            if let duration {
                Text(duration)
                    .dsTextStyle(TextRole.pillSmall)
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .foregroundStyle(Tokens.Colors.globalOnSurfaceLight)
        .padding(.horizontal, Tokens.Sizes.globalVideoPillPadding)
        .frame(height: Tokens.Sizes.globalVideoPillHeight)
        .background(Tokens.Colors.globalSurfaceLight, in: Capsule())
        .fixedSize()
        .accessibilityHidden(true)
    }

    /// '0:10' in `chat.voice.layout.durationFormat` (whole seconds).
    static func text(milliseconds: Int) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = Tokens.Layouts.ChatVoiceLayoutDurationFormat.pattern
        return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(max(0, milliseconds) / 1000))) // provenance-ok: ms → whole seconds
    }
}

/// `layout.global.videoMarker`: the video pill at a photo's or tile's top-trailing corner, `size.global.videoPillInset`
/// from both edges; where the duration does not fit inside the tile less both insets, the glyph alone. Place it as an
/// overlay aligned `.topTrailing`.
struct VideoTileMarker: View {
    let durationMs: Int

    var body: some View {
        ViewThatFits(in: .horizontal) {
            VideoDurationPill(duration: VideoDurationPill.text(milliseconds: durationMs))
            VideoDurationPill(duration: nil)
        }
        .padding(Tokens.Sizes.globalVideoPillInset)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// `layout.global.batchMarker`: a photo that leads photos posted together (Instagram's carousel icon in the top right)
/// carries the video pill's form without digits — capsule `color.global.surfaceLight`, `size.global.videoPillHeight` tall,
/// `size.global.videoPillPadding` each side, `icon.global.batch` (`size.global.iconSmall`) in `color.global.onSurfaceLight` —
/// at the top-trailing corner, `size.global.videoPillInset` from both edges; under the video marker
/// (`size.global.pillGap` below it) when the photo is also a video. Never a number. Place it as an overlay aligned
/// `.topTrailing`. Accessibility: hidden; the owner's label adds `chat.thread.a11y.batch`.
struct BatchTileMarker: View {
    /// The photo also carries the video marker: this one sits under it.
    var belowVideoMarker: Bool = false

    var body: some View {
        Glyph(Tokens.Icons.globalBatch, size: Tokens.Sizes.globalIconSmall, relativeTo: TextRole.pillSmall.relativeTo)
            .foregroundStyle(Tokens.Colors.globalOnSurfaceLight)
            .padding(.horizontal, Tokens.Sizes.globalVideoPillPadding)
            .frame(height: Tokens.Sizes.globalVideoPillHeight)
            .background(Tokens.Colors.globalSurfaceLight, in: Capsule())
            .fixedSize()
            .padding(.top, belowVideoMarker ? Tokens.Sizes.globalVideoPillHeight + Tokens.Sizes.globalPillGap : 0)
            .padding(Tokens.Sizes.globalVideoPillInset)
            .allowsHitTesting(false)
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
