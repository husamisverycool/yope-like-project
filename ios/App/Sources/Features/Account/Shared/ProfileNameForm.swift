// Surface: auth.profile — step 1, the name (also the App Clip's last sign-in step, invite.appclip). Visual reference:
// Retro's FULL_NAME sign-up step (strings: references/auto/retro/apk/retro-android-2026.10.1150-strings.txt
// `onboarding_form_input_hint_full_name`, `error_full_name_too_long`), not captured as an image — the onboarding form
// composition of C-02, C-12, C-05 (design/surfaces/auth.profile.md step 1; MERGE RA-24).
import AppData
import AppModels
import DesignSystem
import Observation
import SwiftUI

/// auth.profile step 1: no back (the account exists) · "What's your name?" · explanation · the name field (inline "Name
/// too long" past 80 characters, Next disabled) · the note `sectionHeaderToContent` under it · "Next".
struct ProfileNameForm: View {
    @Bindable var model: ProfileModel
    let network: NetworkMonitor
    /// The name was saved. "Next" stays busy while it runs (the App Clip joins the group here, invite.appclip 4).
    let onSaved: () async -> Void

    @FocusState private var fieldFocused: Bool
    @State private var finishing = false

    var body: some View {
        SignUpLayout(
            title: Copy.authProfileTitle,
            explanation: Copy.authProfileSubtitle,
            replacement: network.isOffline || model.phase == .offline ? .signUpOffline { model.retry() } : nil
        ) {
            MetricStack {
                FormField(
                    Copy.authProfileFieldPlaceholder,
                    text: Binding(get: { model.name }, set: { model.setName($0) }),
                    accessibilityLabel: Copy.authProfileFieldAccessibilityLabel,
                    contentType: .name,
                    submitLabel: .next,
                    errorMessage: model.isNameTooLong ? Copy.authProfileErrorTooLong : nil,
                    onSubmit: { Task { await save() } }
                )
                .focused($fieldFocused)
                .disabled(model.isSaving || finishing)
                .accessibilityIdentifier("auth.profile.field")
                Text(Copy.authProfileFieldNote)
                    .dsTextRole(TextRole.caption)
                    .foregroundStyle(Tokens.Colors.globalTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .metricGap(Tokens.Sizes.globalSectionHeaderToContent, from: .bottom, to: .capTop)
            }
            .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
        } bottom: {
            PrimaryButton(Copy.authProfileContinue, isEnabled: !model.trimmedName.isEmpty && !model.isNameTooLong, isBusy: model.isSaving || finishing) {
                Task { await save() }
            }
            .accessibilityIdentifier("auth.profile.continue")
        }
        .dsHaptic(Tokens.Haptics.globalSuccess, trigger: model.successCount)
        .dsHaptic(Tokens.Haptics.globalError, trigger: model.errorCount)
        .formErrorAlert(model.failureMessage, trigger: model.errorCount)
        .onAppear { fieldFocused = true }
        .accessibilityIdentifier("auth.profile")
    }

    private func save() async {
        guard !finishing, await model.saveName() else { return }
        finishing = true
        await onSaved()
        finishing = false
    }
}
