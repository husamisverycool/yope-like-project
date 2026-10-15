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
        .formErrorAlert(model.failure?.message, trigger: model.errorCount)
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
