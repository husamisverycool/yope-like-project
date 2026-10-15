// Surfaces: widget.home.small / .large / .xl, widget.lock.rect / .circular / .inline, daily.liveactivity.
// Every BLOCKED value the widget extension depends on, in one place (design/BLOCKED.md). While a value
// is BLOCKED its accessor returns nil and the element is not drawn (the generated `BlockedTokens`
// accessors trap). When `node tools/designgen.mjs` moves an unblocked token into `Tokens`, the
// accessor switches to it in one line (given in each comment). Also compiled into AppTests.
import DesignSystem
import SwiftUI

enum WidgetBlocked {
    /// `widget.home.small.color.emptyLabel` — the 'No pics yet' / 'Tap to set up' label under the
    /// empty stack. Unblocked: `Tokens.Colors.widgetHomeSmallColorEmptyLabel`
    static var emptyLabelColor: Color? { nil }

    /// `daily.capture.fontWeight.countdown` on the Lock Screen Live Activity; until then
    /// `daily.liveactivity.fontWeight.min`. Unblocked: `Tokens.FontWeights.dailyCaptureFontWeightCountdown`
    static var countdownWeight: Font.Weight? { nil }

    /// `widget.lock.rect.layout.content` — what the Lock Screen widgets show for a photo without a
    /// caption (rectangular, inline) and for a collage (all three). While BLOCKED: the avatar alone /
    /// nothing. Unblocked: wire the token's layout into WidgetSlots.swift (its shape is not decided).
    static var lockScreenContentDecided: Bool { false }
}
