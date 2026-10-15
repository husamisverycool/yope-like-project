// Account group — PhoneModel: state and actions of the screen in PhoneScreen.swift.
import AppData
import AppModels
import DesignSystem
import Observation
import SwiftUI
import UIKit

@MainActor
@Observable
final class PhoneModel {
    /// Pre-filled with "+" and the device region's calling code; edited as text.
    var phone: String
    private(set) var isSending = false
    /// Last failure (presentation BLOCKED: `auth.phone.layout.inlineError`; announced to VoiceOver).
    private(set) var failure: AuthFailure?
    private(set) var failedOffline = false
    private(set) var successCount = 0
    private(set) var errorCount = 0

    private let data: AccountDataSource

    init(data: AccountDataSource, phone: String = PhoneNumberInput.initialText()) {
        self.data = data
        self.phone = phone
    }

    /// "continue" is enabled once digits follow the calling code.
    var canContinue: Bool { PhoneNumberInput.hasSubscriberDigits(phone) && !isSending }

    /// Normalises to E.164 and sends the code. Returns the number the code went to.
    func send() async -> String? {
        guard canContinue else { return nil }
        failure = nil
        guard let number = PhoneNumberInput.normalized(phone) else {
            fail(.invalidNumber)
            return nil
        }
        isSending = true
        defer { isSending = false }
        do {
            try await data.sendCode(phone: number, displayName: nil)
            successCount += 1
            return number
        } catch {
            guard let failure = AuthFailure.sending(error) else {
                failedOffline = true
                return nil
            }
            fail(failure)
            return nil
        }
    }

    private func fail(_ failure: AuthFailure) {
        self.failure = failure
        errorCount += 1
        UIAccessibility.post(notification: .announcement, argument: failure.message)
    }

    func retryAfterOffline() {
        failedOffline = false
    }

    /// `auth.phone.legal.text` with `auth.phone.legal.terms` / `.privacy` as bold link ranges
    /// (`auth.phone.layout.legalFooter`); without a configured URL (config/app.json legal.* null) the phrase is bold only.
    static func legalText(termsURL: URL?, privacyURL: URL?) -> AttributedString {
        var text = AttributedString(Copy.authPhoneLegalText)
        for (phrase, url) in [(Copy.authPhoneLegalTerms, termsURL), (Copy.authPhoneLegalPrivacy, privacyURL)] {
            guard let range = text.range(of: phrase) else { continue }
            text[range].inlinePresentationIntent = .stronglyEmphasized
            if let url { text[range].link = url }
        }
        return text
    }
}
