// Shared component — Yope's inline permission card ("can’t see your friends?" / "enable contacts" / "enable" / ✕),
// used for the permission-denied states of onboarding.permission.camera (inside camera.capture) and
// onboarding.permission.photos (where a save was attempted, photo.viewer).
import DesignSystem
import SwiftUI

/// Inline permission card (`onboarding.permission.contacts.layout.card`).
///
/// Tokens: fill `onboarding.permission.contacts.color.card`, height `onboarding.permission.contacts.size.cardHeight`
/// (minimum; grows with Dynamic Type), corners `radius.global.card`; the caller places it with side margin
/// `onboarding.permission.contacts.size.cardMarginH`. Text block left-aligned, `groups.list.size.avatarInset` from the
/// leading edge: title `onboarding.permission.contacts.fontSize.cardTitle` / `.fontWeight.cardTitle` in
/// `color.global.textPrimary` (max 2 lines; Dynamic Type headline), detail `.fontSize.cardDetail` in
/// `color.global.textSecondary` (subheadline). White "enable" pill (`LightPill`, `.card` metrics) vertically centred,
/// `groups.list.size.avatarInset` from the trailing edge. Optional dismiss ✕ (`icon.global.close`,
/// `color.global.textPrimary`) at the top-trailing corner with a `size.global.minTouchTarget.ios` hit area.
/// Accessibility: title + detail read as one element, then the pill, then ✕.
struct PermissionCard: View {
    let title: String
    let detail: String
    let buttonTitle: String
    let onEnable: () -> Void
    /// Nil: the card cannot be dismissed (the camera cannot work without its permission).
    var onDismiss: (() -> Void)?

    private static let titleStyle = DSTextStyle(
        family: Tokens.Fonts.globalFamily,
        size: Tokens.FontSizes.onboardingPermissionContactsFontSizeCardTitle,
        weight: Tokens.FontWeights.onboardingPermissionContactsFontWeightCardTitle,
        relativeTo: .headline
    )
    private static let detailStyle = DSTextStyle(
        family: Tokens.Fonts.globalFamily,
        size: Tokens.FontSizes.onboardingPermissionContactsFontSizeCardDetail,
        weight: Font.Weight.regular,
        relativeTo: .subheadline
    )

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(title)
                    .dsTextStyle(Self.titleStyle)
                    .foregroundStyle(Tokens.Colors.globalTextPrimary)
                    .lineLimit(2)
                Text(detail)
                    .dsTextStyle(Self.detailStyle)
                    .foregroundStyle(Tokens.Colors.globalTextSecondary)
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 0)
            LightPill(buttonTitle, metrics: .card, action: onEnable)
        }
        .padding(.horizontal, Tokens.Sizes.groupsListSizeAvatarInset)
        .frame(maxWidth: .infinity, minHeight: Tokens.Sizes.onboardingPermissionContactsSizeCardHeight)
        .background(Tokens.Colors.onboardingPermissionContactsColorCard, in: RoundedRectangle(cornerRadius: Tokens.Radii.globalCard))
        .overlay(alignment: .topTrailing) {
            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: Tokens.Icons.globalClose)
                        .foregroundStyle(Tokens.Colors.globalTextPrimary)
                        .frame(width: Tokens.Sizes.globalMinTouchTargetIos, height: Tokens.Sizes.globalMinTouchTargetIos)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(Copy.onboardingPermissionContactsCardDismissAccessibilityLabel))
            }
        }
        .accessibilityElement(children: .contain)
    }
}

extension PermissionCard {
    /// `onboarding.permission.camera` denied / restricted: no ✕. `onEnable` should open the app's page in Settings
    /// (`UIApplication.openSettingsURLString`) and re-check authorization on return.
    static func cameraDenied(onEnable: @escaping () -> Void) -> PermissionCard {
        PermissionCard(
            title: Copy.onboardingPermissionCameraDeniedTitle,
            detail: Copy.onboardingPermissionCameraDeniedDetail,
            buttonTitle: Copy.onboardingPermissionCameraDeniedButton,
            onEnable: onEnable
        )
    }

    /// `onboarding.permission.photos` add-only access denied, shown where the save was attempted; ✕ hides it.
    static func photosDenied(onEnable: @escaping () -> Void, onDismiss: @escaping () -> Void) -> PermissionCard {
        PermissionCard(
            title: Copy.onboardingPermissionPhotosDeniedTitle,
            detail: Copy.onboardingPermissionPhotosDeniedDetail,
            buttonTitle: Copy.onboardingPermissionPhotosDeniedButton,
            onEnable: onEnable,
            onDismiss: onDismiss
        )
    }
}
