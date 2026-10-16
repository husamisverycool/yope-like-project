// Surface: auth.code — SMS code entry (also the App Clip's code step, invite.appclip). Visual reference: Retro's
// AUTH_CODE sign-up step, not captured as an image — the onboarding form composition of C-02, C-12, C-05, C-08
// (design/surfaces/auth.code.md; page and capsule from references/auto/retro/lazyweb/retro-lazyweb-20251119-social.png,
// LAND; copy from references/auto/retro/apk/retro-android-2026.10.1150-strings.txt).
import AppData
import AppModels
import DesignSystem
import Observation
import SwiftUI
import UIKit

/// auth.code: back · "Enter your code" · "We texted a code to {phone}." · code field · helper · "Didn't receive a code?
/// Send again" · "Next". `onVerified` decides where the person goes next; `onBack` returns to auth.phone (number kept).
struct CodeScreen: View {
    @State private var model: CodeModel
    let network: NetworkMonitor
    let toasts: ToastCenter
    let onVerified: (UserID) async -> Void
    let onBack: () -> Void

    @FocusState private var fieldFocused: Bool
    @State private var shownFailure: AuthFailure?

    init(model: CodeModel, network: NetworkMonitor, toasts: ToastCenter, onVerified: @escaping (UserID) async -> Void, onBack: @escaping () -> Void) {
        _model = State(initialValue: model)
        self.network = network
        self.toasts = toasts
        self.onVerified = onVerified
        self.onBack = onBack
    }

    var body: some View {
        SignUpLayout(
            back: FormBackButton(accessibilityLabel: Copy.authCodeBackAccessibilityLabel, identifier: "auth.code.back", action: onBack),
            title: Copy.authCodeTitle,
            explanation: Copy.authCodeSubtitle(phone: model.phone),
            replacement: network.isOffline || model.failedOffline ? .signUpOffline { model.retryAfterOffline() } : nil
        ) {
            fields
        } bottom: {
            PrimaryButton(Copy.authCodeContinue, isEnabled: !model.code.isEmpty, isBusy: model.isVerifying) {
                Task { await model.verify(onVerified: onVerified) }
            }
            .accessibilityIdentifier("auth.code.continue")
        }
        .dsHaptic(Tokens.Haptics.globalSuccess, trigger: model.successCount)
        .dsHaptic(Tokens.Haptics.globalError, trigger: model.errorCount)
        .onChange(of: model.errorCount) { _, _ in shownFailure = model.failure }
        .alert(
            Text(shownFailure?.title ?? ""),
            isPresented: Binding(get: { shownFailure != nil }, set: { if !$0 { shownFailure = nil } }),
            presenting: shownFailure
        ) { failure in
            if failure.offersRecovery {
                Button(Copy.authCodeErrorEditCode, role: .cancel) { fieldFocused = true }
                Button(Copy.authCodeErrorSendNew) { Task { await resend() } }
            } else {
                Button(Copy.authPhoneErrorDismiss, role: .cancel) {}
            }
        } message: { failure in
            Text(failure.message)
        }
        .onAppear {
            model.startResendLock()
            fieldFocused = true
        }
        .accessibilityIdentifier("auth.code")
    }

    /// Field, then the helper and the resend line, each `size.global.sectionHeaderToContent` under the previous one
    /// (cap top; the C-20 header → content gap reused, auth.code Gaps).
    private var fields: some View {
        MetricStack {
            FormField(
                Copy.authCodeFieldPlaceholder,
                text: Binding(get: { model.code }, set: { model.setCode($0) }),
                accessibilityLabel: Copy.authCodeFieldAccessibilityLabel,
                keyboard: .numberPad,
                contentType: .oneTimeCode
            )
            .focused($fieldFocused)
            .disabled(model.isVerifying)
            .accessibilityIdentifier("auth.code.field")
            Text(Copy.authCodeHelper)
                .dsTextRole(TextRole.caption)
                .foregroundStyle(Tokens.Colors.globalTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .metricGap(Tokens.Sizes.globalSectionHeaderToContent, from: .bottom, to: .capTop)
            resendLine
                .metricGap(Tokens.Sizes.globalSectionHeaderToContent, from: .lastBaseline, to: .capTop)
        }
        .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
    }

    /// `auth.code.resend.prefix` (caption, grey) + "Send again" (C-08 link: text role `listTitle`, grey; dimmed to
    /// `color.global.textTertiary` and inactive for `auth.code.duration.resendLock` after each request, no countdown),
    /// on one baseline; the state change cross-fades (`duration.global.crossfade`).
    private var resendLine: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(Copy.authCodeResendPrefix)
                .dsTextStyle(TextRole.caption)
                .foregroundStyle(Tokens.Colors.globalTextSecondary)
            Button {
                Task { await resend() }
            } label: {
                Text(Copy.authCodeResend)
                    .dsTextStyle(TextRole.listTitle)
                    .foregroundStyle(model.isResendLocked ? Tokens.Colors.globalTextTertiary : Tokens.Colors.globalTextSecondary)
                    .frame(minHeight: Tokens.Sizes.globalMinTouchTargetIos)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(model.isResendLocked)
            .dsAnimation(ComponentMotion.crossfade, value: model.isResendLocked)
            .accessibilityIdentifier("auth.code.resend")
        }
        .capHeight(of: TextRole.caption)
    }

    private func resend() async {
        if await model.resend() { toasts.show(Copy.authCodeToastResent) }
    }
}
