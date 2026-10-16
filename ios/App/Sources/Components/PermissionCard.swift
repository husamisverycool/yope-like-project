// Shared component — the permission-denied state (C-27 variant, design/components.md: "Permission-denied uses the same
// block with the pre-prompt copy"), replacing Yope's inline permission card. Used for onboarding.permission.camera
// (inside camera.capture) and onboarding.permission.photos (where a save was attempted, photo.viewer).
import DesignSystem
import SwiftUI

/// The C-27 block with the pre-prompt copy: title, detail, and an outline capsule (C-06) that opens Settings; an
/// optional close circle (C-11 `.page`, `icon.global.close`) at the top-trailing corner hides it (Yope's dismiss ✕; Retro's
/// pre-prompts were not captured as images — the circle is the C-11 close used on light sheets). The name and
/// signature are kept from the Yope card so screens compile; Pass 4 places it as its surface spec says.
/// Accessibility: title (header) and detail, then the action, then close.
struct PermissionCard: View {
    let title: String
    let detail: String
    let buttonTitle: String
    let onEnable: () -> Void
    /// Nil: it cannot be dismissed (the camera cannot work without its permission).
    var onDismiss: (() -> Void)?

    var body: some View {
        EmptyStateView(title: title, detail: detail, action: EmptyStateView.Action(buttonTitle, handler: onEnable))
            .frame(maxWidth: .infinity)
            .overlay(alignment: .topTrailing) {
                if let onDismiss {
                    CircleButton(
                        icon: Tokens.Icons.globalClose,
                        accessibilityLabel: Copy.onboardingPermissionContactsCardDismissAccessibilityLabel,
                        style: .page,
                        action: onDismiss
                    )
                    .padding(.trailing, Tokens.Sizes.globalScreenMargin)
                }
            }
            .accessibilityElement(children: .contain)
    }
}

extension PermissionCard {
    /// `onboarding.permission.camera` denied / restricted: no close. `onEnable` should open the app's page in Settings
    /// (`UIApplication.openSettingsURLString`) and re-check authorization on return.
    static func cameraDenied(onEnable: @escaping () -> Void) -> PermissionCard {
        PermissionCard(
            title: Copy.onboardingPermissionCameraDeniedTitle,
            detail: Copy.onboardingPermissionCameraDeniedDetail,
            buttonTitle: Copy.onboardingPermissionCameraDeniedButton,
            onEnable: onEnable
        )
    }

    /// `onboarding.permission.photos` add-only access denied, shown where the save was attempted; close hides it.
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
