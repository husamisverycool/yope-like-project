// Shared component — C-26 toasts and confirmations (design/components.md), replacing Yope's lime toast.
// Retro's iOS toast was not captured (Gap — one screenshot after 'Copy Link' in the iOS app closes it), so iOS draws no
// custom toast: the confirmation is the state change itself plus an accessibility announcement
// (`AccessibilityNotification.Announcement`, PLATFORM). Android uses the platform Toast (LENGTH_SHORT) with Retro's copy.
// Evidence: APK-X 'TOASTS'; RP §3.9, §4.2; RV §6.
import DesignSystem
import Observation
import SwiftUI

/// Confirmations ('Saved!', 'Copied!', 'Invite link copied to clipboard'). `show(_:)` posts the message as a VoiceOver
/// announcement and records it as `message` (the last confirmation, for the screen's own state and for tests) until
/// `dismiss()` or the next `show`. Nothing is drawn (C-26 iOS).
@MainActor
@Observable
final class ToastCenter {
    private(set) var message: String?

    init(message: String? = nil) {
        self.message = message
    }

    func show(_ message: String) {
        AccessibilityNotification.Announcement(message).post()
        self.message = message
    }

    func dismiss() {
        message = nil
    }
}

extension View {
    /// Kept so screens keep their wiring: iOS draws no toast (C-26), so this adds nothing.
    func toastHost(_ center: ToastCenter) -> some View {
        self
    }
}
