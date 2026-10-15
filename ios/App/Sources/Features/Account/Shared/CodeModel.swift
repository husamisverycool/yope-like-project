// Account group — CodeModel: state and actions of the screen in CodeScreen.swift.
import AppData
import AppModels
import DesignSystem
import Observation
import SwiftUI
import UIKit

@MainActor
@Observable
final class CodeModel {
    /// The normalised (E.164) number the code was sent to.
    let phone: String
    /// Typed code, digits only (the screen filters input through `setCode`).
    var code = ""
    private(set) var isVerifying = false
    /// The last failure, shown as the form error alert (`auth.phone.layout.inlineError`).
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
            return false
        }
    }

    /// Offline state's "try again".
    func retryAfterOffline() {
        failedOffline = false
    }
}
