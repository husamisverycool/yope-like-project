// Shared component — C-30 segmented control (design/components.md), replacing Yope's capsule track with a white pill.
// Retro uses the system control ('Create Recap': Yearly / Monthly / Weekly / All Posts; TC-REC row y=446), drawn by
// iOS in the current appearance — PLATFORM. Evidence: TC-REC phone 1; RV §3.2, §4 #20.
import DesignSystem
import SwiftUI

/// One segment of `SegmentedPills`.
struct SegmentOption<Value: Hashable>: Identifiable {
    let value: Value
    let title: String
    var id: Value { value }

    init(_ value: Value, title: String) {
        self.value = value
        self.title = title
    }
}

/// The native segmented control (`Picker` with `.segmented` style): track, selection and labels are the system's; a
/// change plays `haptic.global.select`. The name is kept from the Yope component so screens keep compiling.
/// Accessibility: the system control's own semantics; `accessibilityLabel` (copy) names the control.
struct SegmentedPills<Value: Hashable>: View {
    let options: [SegmentOption<Value>]
    @Binding var selection: Value
    var accessibilityLabel: String?

    init(options: [SegmentOption<Value>], selection: Binding<Value>, accessibilityLabel: String? = nil) {
        self.options = options
        _selection = selection
        self.accessibilityLabel = accessibilityLabel
    }

    var body: some View {
        Picker(selection: $selection) {
            ForEach(options) { option in
                Text(option.title).tag(option.value)
            }
        } label: {
            Text(accessibilityLabel ?? "")
        }
        .pickerStyle(.segmented)
        .dsHaptic(Tokens.Haptics.globalSelect, trigger: selection)
    }
}
