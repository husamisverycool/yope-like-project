// Shared component — Yope's segmented control ("pics | wall | recaps", the group-type picker).
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

/// Capsule track with a white pill on the selected segment.
///
/// Tokens: track `groups.screen.color.segmentTrack`, height `groups.screen.size.segmentHeight` (minimum; grows with
/// Dynamic Type), capsule (`radius.global.capsule`); selected pill `color.global.surfaceLight` inset
/// `groups.screen.size.segmentInset`, label `color.global.onSurfaceLight`; labels `groups.screen.fontSize.segmentLabel`
/// / `.fontWeight.segmentLabel` (Dynamic Type subheadline; labels wrap), unselected `color.global.textPrimary`.
/// The pill moves with `spring.global.platformDefault.ios`; under Reduce Motion it cross-fades. Selection plays
/// `haptic.global.select`. Accessibility: each segment is a button with the selected trait. The caller applies
/// the side margin (`groups.screen.size.segmentMarginH` on the profile page, `size.global.buttonMarginH` in forms).
struct SegmentedPills<Value: Hashable>: View {
    let options: [SegmentOption<Value>]
    @Binding var selection: Value

    @Namespace private var namespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var labelStyle: DSTextStyle {
        DSTextStyle(
            family: Tokens.Fonts.globalFamily,
            size: Tokens.FontSizes.groupsScreenFontSizeSegmentLabel,
            weight: Tokens.FontWeights.groupsScreenFontWeightSegmentLabel,
            relativeTo: .subheadline
        )
    }

    /// The selected pill's height: the track height minus the inset above and below.
    private var pillMinHeight: CGFloat {
        Tokens.Sizes.groupsScreenSizeSegmentHeight - Tokens.Sizes.groupsScreenSizeSegmentInset * 2
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options) { option in
                segment(option)
            }
        }
        .padding(Tokens.Sizes.groupsScreenSizeSegmentInset)
        .background(Tokens.Colors.groupsScreenColorSegmentTrack, in: Capsule())
        .dsHaptic(Tokens.Haptics.globalSelect, trigger: selection)
    }

    private func segment(_ option: SegmentOption<Value>) -> some View {
        let selected = option.value == selection
        return Button {
            guard option.value != selection else { return }
            withDSAnimation(.spring(Tokens.Springs.globalPlatformDefaultIos)) {
                selection = option.value
            }
        } label: {
            Text(option.title)
                .dsTextStyle(labelStyle)
                .multilineTextAlignment(.center)
                .foregroundStyle(selected ? Tokens.Colors.globalOnSurfaceLight : Tokens.Colors.globalTextPrimary)
                .frame(maxWidth: .infinity, minHeight: pillMinHeight)
                .background {
                    if selected {
                        if reduceMotion {
                            Capsule().fill(Tokens.Colors.globalSurfaceLight)
                        } else {
                            Capsule().fill(Tokens.Colors.globalSurfaceLight)
                                .matchedGeometryEffect(id: "selection", in: namespace) // provenance-ok: geometry-effect identifier
                        }
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
