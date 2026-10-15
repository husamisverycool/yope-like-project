// Shared component — the Yope lime toast ("posted in the wall"; `safety.block.layout.toast`).
import DesignSystem
import Observation
import SwiftUI
import UIKit

/// Shows one toast at a time. Inject one per window (`.toastHost(center)`) and call `show(_:)`.
///
/// The dwell time (`safety.block.duration.toast`) is BLOCKED, so release builds never draw the toast: the message
/// is still posted as a VoiceOver announcement. DEBUG builds keep it on screen until it is tapped, so the layout
/// can be reviewed and snapshot.
@MainActor
@Observable
final class ToastCenter {
    private(set) var message: String?

    init(message: String? = nil) {
        self.message = message
    }

    func show(_ message: String) {
        UIAccessibility.post(notification: .announcement, argument: message)
        #if DEBUG
        self.message = message
        #endif
    }

    func dismiss() {
        message = nil
    }
}

/// The toast itself. Tokens: fill `color.global.accent`; `icon.global.checkmark` + label in `color.global.onAccent`,
/// text role `button`; shape `radius.global.capsule`; full width minus `size.global.screenMargin` each side; top,
/// under the status bar. Height, glyph size and insets: the same Yope toast as measured by the capture pass
/// (`camera.sendto.layout.toast`: height, glyph, glyphInset, glyphToText).
struct ToastView: View {
    let message: String

    var body: some View {
        HStack(spacing: Tokens.Layouts.CameraSendtoLayoutToast.glyphToText) {
            Image(systemName: Tokens.Icons.globalCheckmark)
                .resizable()
                .scaledToFit()
                .frame(width: Tokens.Layouts.CameraSendtoLayoutToast.glyph, height: Tokens.Layouts.CameraSendtoLayoutToast.glyph)
                .accessibilityHidden(true)
            Text(message)
                .dsTextStyle(TextRole.button)
            Spacer(minLength: 0)
        }
        .foregroundStyle(Tokens.Colors.globalOnAccent)
        .padding(.horizontal, Tokens.Layouts.CameraSendtoLayoutToast.glyphInset)
        .frame(maxWidth: .infinity, minHeight: Tokens.Layouts.CameraSendtoLayoutToast.height)
        .background(Tokens.Colors.globalAccent, in: Capsule())
        .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
    }
}

extension View {
    /// Hosts `center`'s toast at the top of this view. Enters with `spring.global.platformDefault.ios`; under
    /// Reduce Motion it cross-fades (`layout.global.reduceMotion`).
    func toastHost(_ center: ToastCenter) -> some View {
        modifier(ToastHostModifier(center: center))
    }
}

private struct ToastHostModifier: ViewModifier {
    let center: ToastCenter

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let message = center.message {
                ToastView(message: message)
                    .onTapGesture { center.dismiss() }
                    .dsTransition(.move(edge: .top).combined(with: .opacity))
                    .accessibilityAddTraits(.isStaticText)
            }
        }
        .dsAnimation(.spring(Tokens.Springs.globalPlatformDefaultIos), value: center.message)
    }
}
