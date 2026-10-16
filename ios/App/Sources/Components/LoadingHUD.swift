// Shared component — C-28 loading states (design/components.md), replacing Yope's square Loading HUD. Retro shows no
// skeleton screens; its captured loading forms are placeholder tiles (C-17 `.placeholder`, `WeekStripLayout.placeholders`),
// progress text ('Updating…', copy `retro.voice.progress`) and the platform activity indicator. Retro's own spinner was
// not captured (Gap); its collage loader is a Rive file (not copied). Evidence: VID-COMP; RP §2.1, §3.9, §4.1 rule 3.
import DesignSystem
import SwiftUI

/// The platform activity indicator (`easing.global.native.activityIndicator`: `ProgressView`, PLATFORM) in
/// `color.global.textSecondary`, with an optional progress line under it in the platform's label style (copy:
/// 'Updating…'). Accessibility: announced as busy (updates frequently); the line is read when present.
struct LoadingHUD: View {
    var label: String?

    init(label: String? = nil) {
        self.label = label
    }

    var body: some View {
        Group {
            if let label {
                ProgressView {
                    Text(label)
                        .dsTextStyle(TextRole.body)
                        .foregroundStyle(Tokens.Colors.globalTextSecondary)
                }
            } else {
                ProgressView()
            }
        }
        .tint(Tokens.Colors.globalTextSecondary)
        .accessibilityAddTraits(.updatesFrequently)
    }
}

extension View {
    /// Shows `LoadingHUD` centred over the view while `isPresented`, blocking input underneath; it appears and leaves
    /// with `duration.global.fade` (`easing.global.standard`).
    func loadingHUD(_ isPresented: Bool, label: String? = nil) -> some View {
        overlay {
            ZStack {
                if isPresented {
                    ZStack {
                        Color.clear.contentShape(Rectangle())
                        LoadingHUD(label: label)
                    }
                    .ignoresSafeArea()
                    .dsTransition(.opacity)
                }
            }
            .dsAnimation(ComponentMotion.fade, value: isPresented)
        }
    }
}
