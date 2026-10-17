// Account group — PhoneModel: state and actions of the phone form (auth.phone B; PhoneForm.swift), shared with the App Clip.
import AppData
import AppModels
import DesignSystem
import Observation
import SwiftUI
import UIKit

@MainActor
@Observable
final class PhoneModel {
    /// Pre-filled with "+" and the device region's calling code; edited as text (the calling code inline with the
    /// number, `auth.phone.layout.countryCode`).
    var phone: String
    /// The country chosen in the list behind the flag; its flag wins while its calling code is typed.
    private(set) var pickedRegion: String?
    private(set) var isSending = false
    /// Last failure, shown as the form error alert (`auth.phone.layout.inlineError`).
    private(set) var failure: AuthFailure?
    private(set) var failedOffline = false
    private(set) var successCount = 0
    private(set) var errorCount = 0

    private let data: AccountDataSource
    private let deviceRegion: String?

    init(data: AccountDataSource, phone: String? = nil, deviceRegion: String? = Locale.current.region?.identifier) {
        self.data = data
        self.deviceRegion = deviceRegion
        self.phone = PhoneNumberFormatting.formatted(phone ?? PhoneNumberInput.initialText(region: deviceRegion))
    }

    /// The field's binding: every edit is formatted as typed (`PhoneNumberFormatting.edit`); `phone` keeps the shown
    /// text and `send()` submits its E.164 form.
    var phoneText: String {
        get { phone }
        set { phone = PhoneNumberFormatting.edit(from: phone, to: newValue) }
    }

    /// The region whose flag shows at the field's leading edge; nil while no calling code is typed.
    var flagRegion: String? {
        PhoneNumberInput.region(of: phone, preferring: [pickedRegion, deviceRegion])
    }

    /// A country chosen in the list: its calling code replaces the typed one.
    func selectCountry(_ region: String) {
        guard let code = CallingCodes.byRegion[region.uppercased()] else { return }
        pickedRegion = region.uppercased()
        phone = PhoneNumberFormatting.formatted(PhoneNumberInput.replacingCallingCode(in: phone, with: code))
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
    }

    func retryAfterOffline() {
        failedOffline = false
    }

    /// `auth.phone.legal.text` with `auth.phone.legal.terms` / `.privacy` underlined, in the same grey (LAND, C-33);
    /// each is a link when config/app.json has its URL (`legal.termsUrl` / `.privacyUrl`, owner), opened in the in-app
    /// browser.
    static func legalText(termsURL: URL?, privacyURL: URL?) -> AttributedString {
        var text = AttributedString(Copy.authPhoneLegalText)
        for (phrase, url) in [(Copy.authPhoneLegalTerms, termsURL), (Copy.authPhoneLegalPrivacy, privacyURL)] {
            guard let range = text.range(of: phrase) else { continue }
            text[range].swiftUI.underlineStyle = Text.LineStyle.single
            if let url { text[range].link = url }
        }
        return text
    }
}
