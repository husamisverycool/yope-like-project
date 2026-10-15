// Account group — the invite page's theme and title auto-fit, rendered natively (invite.appclip "Preview": the
// invite.web anatomy, tokens and copy). Ported from the web service (web/src/theme.ts, web/src/titleFit.ts), whose
// numbers all come from the `invite.web.*` tokens.
import DesignSystem
import SwiftUI
import UIKit

/// The invite's theme: page colour from `preview.json` (mean colour of the cover; `invite.web.layout.theme`) and the
/// text colour set it was computed with (`invite.web.layout.themeTextColour`).
struct InviteTheme: Equatable {
    let background: Color
    /// "dark" scheme: white text (`invite.web.color.text.dark`); "light": black (`invite.web.color.text.light`).
    let isDark: Bool

    /// No cover, and every non-ideal state: `invite.web.color.theme.default` with white text.
    static let standard = InviteTheme(background: Tokens.Colors.inviteWebColorThemeDefault, isDark: true)

    init(background: Color, isDark: Bool) {
        self.background = background
        self.isDark = isDark
    }

    init(_ theme: WebInvitePreview.Theme?) {
        guard let theme, let color = Self.color(hex: theme.background) else {
            self = .standard
            return
        }
        self.init(background: color, isDark: theme.scheme == "dark")
    }

    var text: Color { isDark ? Tokens.Colors.inviteWebColorTextDark : Tokens.Colors.inviteWebColorTextLight }
    var buttonFill: Color { isDark ? Tokens.Colors.inviteWebColorButtonFilledFillDark : Tokens.Colors.inviteWebColorButtonFilledFillLight }
    var buttonLabel: Color { isDark ? Tokens.Colors.inviteWebColorButtonFilledLabelDark : Tokens.Colors.inviteWebColorButtonFilledLabelLight }
    /// Members-only card: `invite.web.color.gateCard.light` / `.dark` at `invite.web.opacity.gateCard.*`.
    var gateCard: Color {
        isDark
            ? Tokens.Colors.inviteWebColorGateCardDark.opacity(Tokens.Opacities.inviteWebOpacityGateCardDark)
            : Tokens.Colors.inviteWebColorGateCardLight.opacity(Tokens.Opacities.inviteWebOpacityGateCardLight)
    }
    var outlinedBorderOpacity: Double {
        isDark ? Tokens.Opacities.inviteWebOpacityButtonOutlinedBorderDark : Tokens.Opacities.inviteWebOpacityButtonOutlinedBorderLight
    }
    var initialsFillOpacity: Double {
        isDark ? Tokens.Opacities.inviteWebOpacityAvatarMinimalFillDark : Tokens.Opacities.inviteWebOpacityAvatarMinimalFillLight
    }
    var placeholderOpacity: Double {
        isDark ? Tokens.Opacities.inviteAppclipOpacitySheetPlaceholderDark : Tokens.Opacities.inviteAppclipOpacitySheetPlaceholderLight
    }
    var helperOpacity: Double {
        isDark ? Tokens.Opacities.inviteAppclipOpacitySheetHelperDark : Tokens.Opacities.inviteAppclipOpacitySheetHelperLight
    }

    /// "#RRGGBB" from preview.json (data computed by the web service, not a design value).
    static func color(hex: String) -> Color? {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        return Color(uiColor: UIColor(red: red, green: green, blue: blue, alpha: 1)) // provenance-ok: theme colour is data from preview.json
    }
}

/// Partiful's title auto-fit (`invite.web.layout.title.fit`, web/src/titleFit.ts): the largest size that wraps to
/// `invite.web.count.title.maxLines` lines (or one line), between `invite.web.fontSize.title.min` and `.base` /
/// `.singleLineMax`, then shrunk until the widest word fits.
enum InviteTitleFit {
    private typealias Fit = Tokens.Layouts.InviteWebLayoutTitleFit

    private static let thin = Set(Fit.thinCharacters.utf16)
    private static let normal = Set(Fit.normalCharacters.utf16)

    /// Estimated rendered width of `text` at `size` (UTF-16 units, as the reference).
    static func estimateWidth(_ text: String, size: CGFloat) -> CGFloat {
        var thinCount: CGFloat = 0
        var wideCount: CGFloat = 0
        let units = Array(text.utf16)
        for unit in units {
            if thin.contains(unit) {
                thinCount += 1
            } else if !normal.contains(unit) {
                wideCount += 1
            }
        }
        let normalCount = CGFloat(units.count) - wideCount - thinCount
        return size * (Fit.widthWide * wideCount + normalCount * Fit.widthNormal + Fit.widthThin * thinCount)
    }

    private static func lineCount(size: CGFloat, width: CGFloat, words: [String], spaceWidth: CGFloat) -> Int {
        var lines = 0
        var remaining = width
        for word in words {
            let wordWidth = estimateWidth(word, size: size)
            if wordWidth + spaceWidth > remaining {
                lines += 1
                remaining = width - wordWidth
            } else {
                remaining -= wordWidth + spaceWidth
            }
        }
        return lines + (remaining < width ? 1 : 0)
    }

    /// Integer binary search returning the lower bound.
    private static func search(_ low: CGFloat, _ high: CGFloat, tooBig: (CGFloat) -> Bool) -> CGFloat {
        var low = low
        var high = high
        while true {
            let mid = ((high + low) / 2).rounded(.down)
            if mid - low < 1 { return low }
            if tooBig(mid) { high = mid } else { low = mid }
        }
    }

    /// Title size for a column `width`.
    static func size(for title: String, width: CGFloat) -> CGFloat {
        let minimum = Tokens.FontSizes.inviteWebFontSizeTitleMin
        let base = Tokens.FontSizes.inviteWebFontSizeTitleBase
        let words = title.split(whereSeparator: { $0.isWhitespace }).map { String($0) }
        guard !words.isEmpty else { return minimum }
        let overflows = estimateWidth(title, size: base) > width
        let maxLines = overflows ? Int(Tokens.Counts.inviteWebCountTitleMaxLines) : 1
        let upper = overflows ? base : Tokens.FontSizes.inviteWebFontSizeTitleSingleLineMax
        let size = search(minimum, upper) { candidate in
            lineCount(size: candidate, width: width, words: words, spaceWidth: estimateWidth(" ", size: candidate)) > maxLines
        }.rounded(.down)
        if size <= minimum { return minimum }
        var widest: CGFloat = 0
        var widestWord = words[0]
        for word in words {
            let wordWidth = estimateWidth(word, size: size)
            if wordWidth > widest {
                widest = wordWidth
                widestWord = word
            }
        }
        if widest <= width { return size }
        return search(minimum, size) { estimateWidth(widestWord, size: $0) > width }.rounded(.down)
    }
}
