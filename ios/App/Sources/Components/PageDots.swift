// Shared component — C-31 page dots (design/components.md). Evidence: TC-REC phone 2 (dots x1360–1417), TC-1B (light);
// RV §4 #21.
import DesignSystem
import SwiftUI

/// `count` dots of `size.global.pageDot`, centres `size.global.pageDotPitch` apart, centred; the active one
/// `color.global.textPrimary` (on media `color.global.textOnMedia`), the others `color.global.pageDotInactive` — on media
/// its dark value in both appearances (C-31 on media: media surfaces stay dark), as Android's `Tokens.ColorsDark`.
/// Accessibility: one adjustable element whose value is "page N of M" from copy (`accessibilityValue`); swiping up / down
/// calls `onSelect` when given (platform page-control semantics). Contrast: inactive on white 1.36:1 FAIL (failure 9),
/// reported, not changed.
struct PageDots: View {
    let count: Int
    let index: Int
    var onMedia: Bool = false
    let accessibilityValue: String
    var onSelect: ((Int) -> Void)?
    @Environment(\.colorScheme) private var colorScheme

    init(count: Int, index: Int, onMedia: Bool = false, accessibilityValue: String, onSelect: ((Int) -> Void)? = nil) {
        self.count = count
        self.index = index
        self.onMedia = onMedia
        self.accessibilityValue = accessibilityValue
        self.onSelect = onSelect
    }

    var body: some View {
        HStack(spacing: Tokens.Sizes.globalPageDotPitch - Tokens.Sizes.globalPageDot) {
            ForEach(0..<max(0, count), id: \.self) { dot in
                Circle()
                    .fill(dot == index ? activeColor : Tokens.Colors.globalPageDotInactive)
                    .frame(width: Tokens.Sizes.globalPageDot, height: Tokens.Sizes.globalPageDot)
            }
        }
        .environment(\.colorScheme, onMedia ? .dark : colorScheme)
        .dsAnimation(ComponentMotion.crossfade, value: index)
        .accessibilityElement(children: .ignore)
        .accessibilityValue(Text(accessibilityValue))
        .accessibilityAdjustableAction { direction in
            guard let onSelect else { return }
            switch direction {
            case .increment: if index + 1 < count { onSelect(index + 1) }
            case .decrement: if index > 0 { onSelect(index - 1) }
            @unknown default: break
            }
        }
    }

    private var activeColor: Color {
        onMedia ? Tokens.Colors.globalTextOnMedia : Tokens.Colors.globalTextPrimary
    }
}
