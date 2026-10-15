// Surface: auth.phone — phone number entry (sign up or log in). Reference app: Yope onboarding (the phone screen was
// not found; assembled from documented Yope parts, design/surfaces/auth.phone.md). Reference images:
// references/auto/yope/frames/a-yrrah-7454430216123862280-t6.73-signup-2024.png (S24),
// a-virgi-7686278541255642390-t31.23-signup-es.png (S26), a-yrrah-7452976839846382855-t3.73-create-new-group-empty-2024.png
// (C24), references/auto/yope/web/a-bi-2025-create-group-composite.jpg (BI),
// a-itsmthuyope-7644974799302823175-t49.23-new-group-selected-create.png (NG), …-t50.60-loading-hud.png (HUD).
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

/// auth.phone screen: title, italic subtitle, phone field, lime "continue", legal footer; HUD while sending.
struct PhoneScreen: View {
    @State private var model: PhoneModel
    @Environment(AccountDependencies.self) private var dependencies
    @FocusState private var fieldFocused: Bool

    init(model: PhoneModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        Group {
            if dependencies.network.isOffline || model.failedOffline {
                SignUpStateView(
                    title: Copy.authPhoneOfflineTitle,
                    detail: Copy.authPhoneOfflineDetail,
                    retry: EmptyStateView.Action(Copy.authPhoneOfflineRetry) { model.retryAfterOffline() }
                )
            } else {
                form
            }
        }
        .loadingHUD(model.isSending)
        .dsHaptic(Tokens.Haptics.globalSuccess, trigger: model.successCount)
        .dsHaptic(Tokens.Haptics.globalError, trigger: model.errorCount)
        .onAppear { fieldFocused = true }
        .accessibilityIdentifier("auth.phone")
    }

    private var form: some View {
        SignUpLayout {
            VStack(spacing: 0) {
                OnboardingTitleBlock(title: Copy.authPhoneTitle, subtitle: Copy.authPhoneSubtitle)
                    .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
                FormField(
                    Copy.authPhoneFieldPlaceholder,
                    text: $model.phone,
                    accessibilityLabel: Copy.authPhoneFieldAccessibilityLabel,
                    keyboard: .phonePad,
                    contentType: .telephoneNumber
                )
                .focused($fieldFocused)
                .accessibilityIdentifier("auth.phone.field")
                .padding(.top, Tokens.Sizes.groupsCreateSizeTitleToContent)
                PrimaryButton(Copy.authPhoneContinue, isEnabled: model.canContinue) {
                    Task { await send() }
                }
                .accessibilityIdentifier("auth.phone.continue")
                .padding(.top, Tokens.Sizes.groupsCreateSizeFieldToButton)
            }
            .padding(.horizontal, Tokens.Sizes.globalButtonMarginH)
        } footer: {
            Text(PhoneModel.legalText(termsURL: dependencies.configuration.termsURL, privacyURL: dependencies.configuration.privacyURL))
                .dsTextStyle(TextRole.caption)
                .foregroundStyle(Tokens.Colors.globalTextSecondary)
                .tint(Tokens.Colors.globalTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
                .opensLinksInAppBrowser()
        }
    }

    private func send() async {
        guard let number = await model.send() else { return }
        dependencies.toasts.show(Copy.authPhoneToastCodeSent)
        dependencies.session.codeSent(phone: number)
    }
}
