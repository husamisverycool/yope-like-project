// Shared component — the Yope Loading HUD (reference: V-mthu t50.60 "Loading").
import DesignSystem
import SwiftUI

/// Square HUD with the system activity indicator and the label `groups.create.hud.loading`.
///
/// Tokens: side `groups.create.size.hud` (minimum; grows with Dynamic Type), fill `groups.create.color.hud`,
/// label `groups.create.fontSize.hudLabel` in `color.global.textPrimary`, spinner = platform activity indicator
/// (`easing.global.native.activityIndicator`), corners `chat.thread.radius.loadingHud`. Spinner–label gap: platform stack
/// spacing (not measured).
struct LoadingHUD: View {
    var body: some View {
        VStack {
            ProgressView()
            Text(Copy.groupsCreateHudLoading)
                .dsTextStyle(TextRole.hudLabel)
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
        }
        .frame(minWidth: Tokens.Sizes.groupsCreateSizeHud, minHeight: Tokens.Sizes.groupsCreateSizeHud)
        .background(Tokens.Colors.groupsCreateColorHud, in: RoundedRectangle(cornerRadius: Tokens.Radii.chatThreadRadiusLoadingHud))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
    }
}

extension View {
    /// Centres `LoadingHUD` over the view while `isPresented`, blocking input underneath.
    func loadingHUD(_ isPresented: Bool) -> some View {
        overlay {
            if isPresented {
                ZStack {
                    Color.clear.contentShape(Rectangle())
                    LoadingHUD()
                }
                .ignoresSafeArea()
            }
        }
    }
}
