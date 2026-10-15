// Surface: auth.agegate — birthday / age gate at sign-up. Reference app: Yope onboarding (Yope's birthday screen was not
// found; Yope form field + FTC neutral-screen rules, design/surfaces/auth.agegate.md). Reference images: as auth.phone
// (S24, S26, C24, BI, NG, HUD) plus references/auto/yope/frames/a-itsmthuyope-7644974799302823175-t49.23-new-group-selected-create.png
// (check circles of the opt-in row).
import AppData
import AppModels
import DesignSystem
import Observation
import SwiftUI
import UIKit

@MainActor
@Observable
final class AgeGateModel {
    enum Phase: Equatable {
        case form
        /// `age_gate_not_configured`: sign-up is not open yet (min_age_years null).
        case notConfigured
        case offline
    }

    let entry: BirthdayEntry
    private(set) var text = ""
    var optIn = false
    private(set) var phase: Phase = .form
    private(set) var isChecking = false
    /// "invalid date" (presentation BLOCKED; announced to VoiceOver).
    private(set) var invalidDate = false
    private(set) var successCount = 0
    private(set) var errorCount = 0

    private let data: AccountDataSource

    init(data: AccountDataSource, entry: BirthdayEntry = BirthdayEntry()) {
        self.data = data
        self.entry = entry
    }

    /// `auth.agegate.field.placeholder` with the locale's pattern ({date_format}).
    var placeholder: String { Copy.authAgegateFieldPlaceholder(dateFormat: entry.placeholderFormat) }

    var canContinue: Bool { entry.isComplete(text) && !isChecking }

    func setText(_ newValue: String) {
        text = entry.edit(from: text, to: newValue)
    }

    enum Outcome: Equatable {
        case confirmed
        /// `under_minimum_age`; carries `public_app_config.min_age_years` for `{min_age}`.
        case underAge(minAge: Int?)
        case stay
    }

    /// `confirm_age(p_birthdate)`, then `set_birthday(p_birthday, true)` when opted in.
    func confirm() async -> Outcome {
        guard canContinue else { return .stay }
        invalidDate = false
        guard let birthdate = entry.date(from: text) else {
            failInvalid()
            return .stay
        }
        isChecking = true
        defer { isChecking = false }
        do {
            try await data.confirmAge(birthdate: birthdate)
            if optIn {
                try await data.setBirthday(birthdate, optIn: true)
            }
            successCount += 1
            return .confirmed
        } catch {
            switch DataError.from(error) {
            case .api(.ageGateNotConfigured, _):
                phase = .notConfigured
                errorCount += 1
            case .api(.underMinimumAge, _):
                errorCount += 1
                let minAge = try? await data.publicConfig().minAgeYears
                return .underAge(minAge: minAge)
            case .api(.invalidBirthdate, _), .api(.invalidBirthday, _):
                failInvalid()
            case .offline:
                phase = .offline
            default:
                // Not in the spec's States table (e.g. set_birthday failed after the age was confirmed): the person
                // stays on the step and can try again (confirm_age keeps the first confirmation).
                errorCount += 1
            }
            return .stay
        }
    }

    private func failInvalid() {
        invalidDate = true
        errorCount += 1
        UIAccessibility.post(notification: .announcement, argument: Copy.authAgegateErrorInvalidDate)
    }

    /// Retry pill of the not-open / offline states.
    func retry() {
        phase = .form
    }
}

/// auth.agegate screen: no back (the account exists after auth.code).
struct AgeGateScreen: View {
    @State private var model: AgeGateModel
    @Environment(AccountDependencies.self) private var dependencies
    @FocusState private var fieldFocused: Bool

    init(model: AgeGateModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        Group {
            if dependencies.network.isOffline || model.phase == .offline {
                SignUpStateView(
                    title: Copy.authPhoneOfflineTitle,
                    detail: Copy.authAgegateOfflineDetail,
                    retry: EmptyStateView.Action(Copy.authPhoneOfflineRetry) { model.retry() }
                )
            } else if model.phase == .notConfigured {
                SignUpStateView(
                    title: Copy.authAgegateNotConfiguredTitle,
                    detail: Copy.authAgegateNotConfiguredDetail,
                    retry: EmptyStateView.Action(Copy.authAgegateNotConfiguredRetry) { model.retry() }
                )
            } else {
                form
            }
        }
        .loadingHUD(model.isChecking)
        .dsHaptic(Tokens.Haptics.globalSuccess, trigger: model.successCount)
        .dsHaptic(Tokens.Haptics.globalError, trigger: model.errorCount)
        .navigationBarBackButtonHidden(true)
        .onAppear { fieldFocused = true }
        .accessibilityIdentifier("auth.agegate")
    }

    private var form: some View {
        SignUpLayout {
            VStack(spacing: 0) {
                OnboardingTitleBlock(title: Copy.authAgegateTitle, subtitle: Copy.authAgegateSubtitle)
                    .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
                FormField(
                    model.placeholder,
                    text: Binding(get: { model.text }, set: { model.setText($0) }),
                    accessibilityLabel: Copy.authAgegateFieldAccessibilityLabel,
                    keyboard: .numberPad
                )
                .accessibilityHint(Text(model.entry.placeholderFormat))
                .focused($fieldFocused)
                .accessibilityIdentifier("auth.agegate.field")
                .padding(.top, Tokens.Sizes.groupsCreateSizeTitleToContent)
                CheckRow(
                    label: Copy.authAgegateOptInLabel,
                    detail: Copy.authAgegateOptInDetail,
                    accessibilityLabel: Copy.authAgegateOptInAccessibilityLabel,
                    isOn: $model.optIn
                )
                .accessibilityIdentifier("auth.agegate.optIn")
                .padding(.top, Tokens.Sizes.groupsCreateSizeFieldToButton)
                PrimaryButton(Copy.authAgegateContinue, isEnabled: model.canContinue) {
                    Task { await confirm() }
                }
                .accessibilityIdentifier("auth.agegate.continue")
                .padding(.top, Tokens.Sizes.groupsCreateSizeFieldToButton)
            }
            .padding(.horizontal, Tokens.Sizes.globalButtonMarginH)
        }
    }

    private func confirm() async {
        switch await model.confirm() {
        case .confirmed:
            dependencies.session.ageConfirmed()
        case let .underAge(minAge):
            await dependencies.session.refuseUnderAge(minAge: minAge)
        case .stay:
            break
        }
    }
}

/// auth.agegate "under age": the empty-state layout without a button; the session is signed out and the refusal is
/// remembered on the device. The title (`auth.agegate.underAge.title`) uses `{app_name}`: BLOCKED, omitted in release.
struct AgeGateRefusedScreen: View {
    let minAge: Int?

    var body: some View {
        SignUpStateView(title: AccountBlockedCopy.ageGateUnderAgeTitle(minAge: minAge), detail: Copy.authAgegateUnderAgeDetail)
            .accessibilityIdentifier("auth.agegate.refused")
    }
}
