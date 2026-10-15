// Surface: auth.code — SMS code entry. Reference app: Yope onboarding (screen not found; built from documented
// Yope parts, design/surfaces/auth.code.md). Reference images: references/auto/yope/frames/
// a-yrrah-7454430216123862280-t6.73-signup-2024.png (S24), a-virgi-7686278541255642390-t31.23-signup-es.png (S26),
// a-yrrah-7452976839846382855-t3.73-create-new-group-empty-2024.png (C24), a-itsmthuyope-…-t50.60-loading-hud.png (HUD).
// Also the code step of the App Clip join flow (invite.appclip).
import AppData
import AppModels
import DesignSystem
import Observation
import SwiftUI
import UIKit

/// State of the code step.
@MainActor
@Observable
final class CodeModel {
    /// The normalised (E.164) number the code was sent to.
    let phone: String
    /// Typed code, digits only (the screen filters input through `setCode`).
    var code = ""
    private(set) var isVerifying = false
    /// The last failure (presentation BLOCKED; announced to VoiceOver).
    private(set) var failure: AuthFailure?
    /// A request failed for lack of connection (offline state until retry).
    private(set) var failedOffline = false
    /// "send new code" is disabled for `auth.code.duration.resendLock` after each request (no countdown shown).
    private(set) var isResendLocked = true
    /// Haptic triggers: `haptic.global.success` / `haptic.global.error`.
    private(set) var successCount = 0
    private(set) var errorCount = 0

    private let data: AccountDataSource
    private let displayName: String?
    @ObservationIgnored private var codeSentAt: Date
    private let now: () -> Date
    private let sleep: (TimeInterval) async -> Void
    @ObservationIgnored private var unlockTask: Task<Void, Never>?

    /// - Parameters:
    ///   - codeSentAt: when the code was requested (auth.phone just sent it).
    ///   - displayName: the App Clip join sheet's name, re-sent with "send new code".
    init(
        phone: String,
        data: AccountDataSource,
        displayName: String? = nil,
        codeSentAt: Date = Date(),
        now: @escaping () -> Date = Date.init,
        sleep: @escaping (TimeInterval) async -> Void = { try? await Task.sleep(for: .seconds($0)) }
    ) {
        self.phone = phone
        self.data = data
        self.displayName = displayName
        self.codeSentAt = codeSentAt
        self.now = now
        self.sleep = sleep
    }

    var canContinue: Bool { !code.isEmpty && !isVerifying }

    /// Keeps digits only (AutoFill and paste may bring spaces).
    func setCode(_ text: String) {
        code = PhoneNumberInput.digits(of: text)
    }

    /// Starts the resend lock for the code just sent (call when the screen appears).
    func startResendLock() {
        lockResend(from: codeSentAt)
    }

    private func lockResend(from start: Date) {
        unlockTask?.cancel()
        let remaining = Tokens.Durations.authCodeDurationResendLock - now().timeIntervalSince(start)
        guard remaining > 0 else {
            isResendLocked = false
            return
        }
        isResendLocked = true
        let sleep = self.sleep
        unlockTask = Task { [weak self] in
            await sleep(remaining)
            guard !Task.isCancelled else { return }
            self?.isResendLocked = false
        }
    }

    /// `verifyOTP`. On success `onVerified` runs (the session decides the next step) while the HUD stays up.
    func verify(onVerified: (UserID) async -> Void) async {
        guard canContinue else { return }
        isVerifying = true
        failure = nil
        defer { isVerifying = false }
        do {
            let userID = try await data.verifyCode(phone: phone, code: code)
            successCount += 1
            await onVerified(userID)
        } catch {
            guard let failure = AuthFailure.verifying(error, codeAge: now().timeIntervalSince(codeSentAt)) else {
                failedOffline = true
                return
            }
            self.failure = failure
            errorCount += 1
            code = ""
            UIAccessibility.post(notification: .announcement, argument: failure.message)
        }
    }

    /// "send new code": `signInWithOTP` again (Twilio Verify returns the same code within its lifetime).
    /// Returns true when the code was sent (the screen shows the toast `auth.code.toast.resent`).
    func resend() async -> Bool {
        guard !isResendLocked else { return false }
        failure = nil
        let requestedAt = now()
        lockResend(from: requestedAt)
        do {
            try await data.sendCode(phone: phone, displayName: displayName)
            codeSentAt = requestedAt
            successCount += 1
            return true
        } catch {
            guard let failure = AuthFailure.sending(error) else {
                failedOffline = true
                return false
            }
            self.failure = failure
            errorCount += 1
            UIAccessibility.post(notification: .announcement, argument: failure.message)
            return false
        }
    }

    /// Offline state's "try again".
    func retryAfterOffline() {
        failedOffline = false
    }
}

/// auth.code screen. `onVerified` decides where the person goes next; `onBack` returns to auth.phone (number kept).
struct CodeScreen: View {
    @State private var model: CodeModel
    let network: NetworkMonitor
    let toasts: ToastCenter
    let onVerified: (UserID) async -> Void
    let onBack: () -> Void

    @FocusState private var fieldFocused: Bool

    init(model: CodeModel, network: NetworkMonitor, toasts: ToastCenter, onVerified: @escaping (UserID) async -> Void, onBack: @escaping () -> Void) {
        _model = State(initialValue: model)
        self.network = network
        self.toasts = toasts
        self.onVerified = onVerified
        self.onBack = onBack
    }

    var body: some View {
        Group {
            if network.isOffline || model.failedOffline {
                SignUpStateView(
                    title: Copy.authPhoneOfflineTitle,
                    detail: Copy.authCodeOfflineDetail,
                    retry: EmptyStateView.Action(Copy.authPhoneOfflineRetry) { model.retryAfterOffline() }
                )
                .overlay(alignment: .topLeading) { backButton.padding(.leading, Tokens.Sizes.globalHeaderInset) }
            } else {
                form
            }
        }
        .loadingHUD(model.isVerifying)
        .dsHaptic(Tokens.Haptics.globalSuccess, trigger: model.successCount)
        .dsHaptic(Tokens.Haptics.globalError, trigger: model.errorCount)
        .onAppear {
            model.startResendLock()
            fieldFocused = true
        }
        .accessibilityIdentifier("auth.code")
    }

    private var backButton: some View {
        HeaderCircleButton(icon: Tokens.Icons.globalBack, accessibilityLabel: Copy.authCodeBackAccessibilityLabel, fill: .onDeep, action: onBack)
            .accessibilityIdentifier("auth.code.back")
    }

    private var form: some View {
        SignUpLayout {
            backButton
        } content: {
            VStack(spacing: 0) {
                OnboardingTitleBlock(title: Copy.authCodeTitle, subtitle: Copy.authCodeSubtitle(phone: model.phone))
                    .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
                FormField(
                    Copy.authCodeFieldPlaceholder,
                    text: Binding(get: { model.code }, set: { model.setCode($0) }),
                    accessibilityLabel: Copy.authCodeFieldAccessibilityLabel,
                    keyboard: .numberPad,
                    contentType: .oneTimeCode
                )
                .focused($fieldFocused)
                .accessibilityIdentifier("auth.code.field")
                .padding(.top, Tokens.Sizes.groupsCreateSizeTitleToContent)
                PrimaryButton(Copy.authCodeContinue, isEnabled: model.canContinue) {
                    Task { await model.verify(onVerified: onVerified) }
                }
                .accessibilityIdentifier("auth.code.continue")
                .padding(.top, Tokens.Sizes.groupsCreateSizeFieldToButton)
                Button {
                    Task {
                        if await model.resend() { toasts.show(Copy.authCodeToastResent) }
                    }
                } label: {
                    Text(Copy.authCodeResend)
                        .dsTextStyle(TextRole.textLink)
                        .foregroundStyle(model.isResendLocked ? Tokens.Colors.globalTextSecondary : Tokens.Colors.globalAccent)
                        .frame(minHeight: Tokens.Sizes.globalMinTouchTargetIos)
                }
                .buttonStyle(.plain)
                .disabled(model.isResendLocked)
                .accessibilityIdentifier("auth.code.resend")
                .padding(.top, Tokens.Sizes.groupsCreateSizeFieldToButton)
            }
            .padding(.horizontal, Tokens.Sizes.globalButtonMarginH)
        } footer: {
            EmptyView()
        }
    }
}
