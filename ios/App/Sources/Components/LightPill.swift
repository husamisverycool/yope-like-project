// Shared component — the white secondary pill (Yope "invite more friends", "try again", "enable").
import DesignSystem
import SwiftUI

/// White pill button with an optional leading SF Symbol.
///
/// Tokens: fill `color.global.surfaceLight`, label and glyph `color.global.onSurfaceLight` in text role `button`.
/// - `.standard` (empty states, invite share): height `groups.screen.size.lightPillHeight`, corners
///   `groups.screen.radius.lightPill` (account surfaces' own measurement, MERGE account A-7); the width hugs the
///   content with `groups.list.size.avatarInset` on each side — **approximation**: Yope's inner padding was not
///   measured (the reference pill is 205 pt wide for "invite more friends" + link glyph).
/// - `.card` (the inline permission card's "enable"): fixed `onboarding.permission.contacts.size.cardButtonWidth` ×
///   `.cardButtonHeight`, shape `radius.global.capsule`.
/// The height is a minimum so the label can grow with Dynamic Type.
struct LightPill: View {
    enum Metrics {
        case standard
        case card
    }

    let title: String
    var icon: String?
    var metrics: Metrics = .standard
    var isEnabled: Bool = true
    let action: () -> Void

    init(_ title: String, icon: String? = nil, metrics: Metrics = .standard, isEnabled: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.metrics = metrics
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            LightPillLabel(title, icon: icon, metrics: metrics)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

/// The light pill's look without the button, for a pill inside a larger tappable row (the year-story entry's
/// "let's go" on groups.screen). Same tokens as `LightPill`.
struct LightPillLabel: View {
    let title: String
    var icon: String?
    var metrics: LightPill.Metrics = .standard

    init(_ title: String, icon: String? = nil, metrics: LightPill.Metrics = .standard) {
        self.title = title
        self.icon = icon
        self.metrics = metrics
    }

    var body: some View {
        label
            .foregroundStyle(Tokens.Colors.globalOnSurfaceLight)
            .background(Tokens.Colors.globalSurfaceLight, in: shape)
            .contentShape(shape)
    }

    @ViewBuilder
    private var label: some View {
        switch metrics {
        case .standard:
            content
                .padding(.horizontal, Tokens.Sizes.groupsListSizeAvatarInset)
                .frame(minHeight: Tokens.Sizes.groupsScreenSizeLightPillHeight)
        case .card:
            content
                .frame(minWidth: Tokens.Sizes.onboardingPermissionContactsSizeCardButtonWidth,
                       minHeight: Tokens.Sizes.onboardingPermissionContactsSizeCardButtonHeight)
        }
    }

    private var content: some View {
        HStack {
            if let icon {
                Image(systemName: icon)
                    .accessibilityHidden(true)
            }
            Text(title)
                .dsTextStyle(TextRole.button)
                .multilineTextAlignment(.center)
        }
    }

    private var shape: AnyShape {
        switch metrics {
        case .standard: return AnyShape(RoundedRectangle(cornerRadius: Tokens.Radii.groupsScreenRadiusLightPill))
        case .card: return AnyShape(Capsule())
        }
    }
}
