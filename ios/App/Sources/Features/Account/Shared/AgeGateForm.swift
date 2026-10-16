// Surface: auth.agegate — birthday / age gate at sign-up (also the App Clip's age step, invite.appclip). Visual
// reference: Retro sign-up (references/auto/retro/lazyweb/retro-lazyweb-20251119-social.png, LAND) and Retro's
// grouped row with a switch (references/auto/retro/video/ig-DJXvmqRv2_N-referrals-sheet-f042-059.png, VID-SET); a neutral
// age screen (FTC COPPA, docs/PLATFORM_CONSTRAINTS.md §9) drawn as the onboarding form composition of C-02, C-12, C-14,
// C-05 (design/surfaces/auth.agegate.md; MERGE RA-4).
import AppData
import AppModels
import DesignSystem
import Observation
import SwiftUI

/// auth.agegate: no back (the account exists after auth.code) · "When's your birthday?" · explanation · the birthday field
/// (the locale's numeric date order as its placeholder, no default) · the opt-in row (C-14 single row, switch off) ·
/// "Next". Not configured / offline: the C-27 block replaces the field, the row and the capsule.
struct AgeGateForm: View {
    @Bindable var model: AgeGateModel
    let network: NetworkMonitor
    /// The age was confirmed (and the birthday stored when opted in).
    let onConfirmed: () -> Void
    /// `under_minimum_age`: the session signs out and the refusal is shown.
    let onUnderAge: (Int?) async -> Void

    @FocusState private var fieldFocused: Bool

    private static let stateFade = DSAnimation.timing(duration: Tokens.Durations.globalCrossfade, easing: Tokens.Easings.globalStandard)

    var body: some View {
        SignUpLayout(
            title: Copy.authAgegateTitle,
            explanation: Copy.authAgegateSubtitle,
            replacement: replacement
        ) {
            MetricStack {
                FormField(
                    model.placeholder,
                    text: Binding(get: { model.text }, set: { model.setText($0) }),
                    accessibilityLabel: Copy.authAgegateFieldAccessibilityLabel,
                    keyboard: .numberPad
                )
                .accessibilityHint(Text(model.entry.placeholderFormat))
                .focused($fieldFocused)
                .disabled(model.isChecking)
                .accessibilityIdentifier("auth.agegate.field")
                .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
                SettingsGroup(rows: [
                    SettingsRow(
                        Copy.authAgegateOptInLabel,
                        subtitle: Copy.authAgegateOptInDetail,
                        kind: .toggle($model.optIn),
                        isEnabled: !model.isChecking
                    )
                    .accessibilityLabel(Text(Copy.authAgegateOptInAccessibilityLabel))
                    .accessibilityHint(Text(Copy.authAgegateOptInDetail))
                    .accessibilityIdentifier("auth.agegate.optIn")
                    .asSettingsRow(),
                ])
                .metricGap(Tokens.Sizes.globalTitleToContent, from: .bottom, to: .top)
            }
        } bottom: {
            PrimaryButton(Copy.authAgegateContinue, isEnabled: model.entry.isComplete(model.text), isBusy: model.isChecking) {
                Task { await confirm() }
            }
            .accessibilityIdentifier("auth.agegate.continue")
        }
        .dsAnimation(Self.stateFade, value: model.phase)
        .dsHaptic(Tokens.Haptics.globalSuccess, trigger: model.successCount)
        .dsHaptic(Tokens.Haptics.globalError, trigger: model.errorCount)
        .formErrorAlert(model.invalidDate ? Copy.authAgegateErrorInvalidDate : nil, trigger: model.errorCount)
        .onAppear { fieldFocused = true }
        .accessibilityIdentifier("auth.agegate")
    }

    /// Not configured (`age_gate_not_configured`): "Sign-up isn't open yet" with "Try again"; offline: the sign-up
    /// offline block.
    private var replacement: EmptyStateView? {
        if network.isOffline || model.phase == .offline {
            return .signUpOffline { model.retry() }
        }
        if model.phase == .notConfigured {
            return EmptyStateView(
                title: Copy.authAgegateNotConfiguredTitle,
                detail: Copy.authAgegateNotConfiguredDetail,
                action: EmptyStateView.Action(Copy.authAgegateNotConfiguredRetry) { model.retry() }
            )
        }
        return nil
    }

    private func confirm() async {
        switch await model.confirm() {
        case .confirmed:
            onConfirmed()
        case let .underAge(minAge):
            await onUnderAge(minAge)
        case .stay:
            break
        }
    }
}

/// auth.agegate "under age": the C-27 block without an action, centred on the page; the session is signed out and the
/// refusal is remembered on the device. `{min_age}` comes from `public_app_config.min_age_years` (the cutoff is shown
/// only after the person submitted).
struct AgeGateRefusedScreen: View {
    let minAge: Int?

    var body: some View {
        // Without a readable `min_age_years` the sentence cannot be completed: the explanation stands alone.
        SignUpStateView(
            title: minAge.map { Copy.authAgegateUnderAgeTitle(minAge: String($0)) },
            detail: Copy.authAgegateUnderAgeDetail
        )
        .accessibilityIdentifier("auth.agegate.refused")
    }
}
