// Shared component — C-32 divider (design/components.md). Evidence: TC-1B, JED, ST-03, TC-2B; APK-X vv3.h/.j; RV §4 #22.
import DesignSystem
import SwiftUI

/// A hairline: `size.global.hairline` (1 device pixel) in `color.global.separator` (#CCCCCC / #4D4D4D), full width of
/// its container (the caller insets it inside the margins). Used sparingly: between the viewer footer and comments
/// (there in the separator's dark value, `Color.darkAppearanceValue`), above 'Total', between grouped rows.
/// Decorative (hidden from assistive technology).
struct HairlineDivider: View {
    var color: Color = Tokens.Colors.globalSeparator

    @Environment(\.displayScale) private var displayScale

    var body: some View {
        let hairline = 1 / max(displayScale, 1) // provenance-ok: size.global.hairline = 1 device pixel (1 / displayScale pt)
        color
            .frame(height: hairline)
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
    }
}
