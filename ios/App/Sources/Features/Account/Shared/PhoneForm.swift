// Surface: auth.phone — state B, the phone form (also the App Clip's first sign-in step, invite.appclip). Visual
// reference: Retro sign-up landing (references/auto/retro/lazyweb/retro-lazyweb-20251119-social.png, LAND) and Retro's
// sign-up order; the form screens were not captured, so this is the onboarding form composition of C-02, C-12, C-05
// (design/surfaces/auth.phone.md B; MERGE RA-2). Country-code mechanics: Locket
// (references/auto/locket/apk/locket-1.243.0-hermes-excerpts.txt).
import AppData
import AppModels
import DesignSystem
import Observation
import SwiftUI
import UIKit

/// auth.phone B: back (to the landing; none in the App Clip) · "What's your phone number?" · explanation · the phone
/// field with the country flag · "Next" above the keyboard. Sending: "Next" busy, field and back disabled. Errors:
/// message-only alert (`auth.phone.layout.inlineError`). Offline: the C-27 block replaces the field and the capsule.
struct PhoneForm: View {
    @Bindable var model: PhoneModel
    let network: NetworkMonitor
    /// Back to the landing (state A); nil hides the chevron (App Clip).
    var onBack: (() -> Void)?
    /// The code went to this (E.164) number: push auth.code.
    let onSent: (String) -> Void

    @FocusState private var fieldFocused: Bool
    @State private var choosingCountry = false

    var body: some View {
        SignUpLayout(
            back: onBack.map { back in
                FormBackButton(accessibilityLabel: Copy.authCodeBackAccessibilityLabel, action: back)
            },
            title: Copy.authPhoneTitle,
            explanation: Copy.authPhoneSubtitle,
            replacement: network.isOffline || model.failedOffline ? .signUpOffline { model.retryAfterOffline() } : nil
        ) {
            FormField(
                Copy.authPhoneFieldPlaceholder,
                text: $model.phone,
                accessibilityLabel: Copy.authPhoneFieldAccessibilityLabel,
                keyboard: .phonePad,
                contentType: .telephoneNumber,
                trailingInset: CountryFlagButton.Layout.flagLeading
            ) {
                CountryFlagButton(region: model.flagRegion) { choosingCountry = true }
            }
            .focused($fieldFocused)
            .disabled(model.isSending)
            .accessibilityIdentifier("auth.phone.field")
        } bottom: {
            PrimaryButton(
                Copy.authPhoneContinue,
                isEnabled: PhoneNumberInput.hasSubscriberDigits(model.phone),
                isBusy: model.isSending
            ) {
                Task { await send() }
            }
            .accessibilityIdentifier("auth.phone.continue")
        }
        .disabled(model.isSending)
        .dsHaptic(Tokens.Haptics.globalError, trigger: model.errorCount)
        .formErrorAlert(model.failure?.message, trigger: model.errorCount)
        .onAppear { fieldFocused = true }
        .sheet(isPresented: $choosingCountry) {
            CountryCodeList(selected: model.flagRegion) { region in
                model.selectCountry(region)
                fieldFocused = true
            }
        }
        .accessibilityIdentifier("auth.phone.form")
    }

    private func send() async {
        guard let number = await model.send() else { return }
        onSent(number)
    }
}

/// The flag at the phone field's leading edge (`auth.phone.layout.countryCode`): the regional-indicator emoji of the
/// typed calling code's country in a `flagWidth` × `flagHeight` slot, `flagLeading` from the field's edge and
/// `flagToText` before the text; a tap opens the country list. The hit area is the inset, slot and gap, the field's
/// full height. While no calling code is typed the slot stays empty (the layout does not move).
struct CountryFlagButton: View {
    typealias Layout = Tokens.Layouts.AuthPhoneLayoutCountryCode

    let region: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(region.map { PhoneNumberInput.flag(for: $0) } ?? "")
                // The emoji is sized to the slot height and scaled down to fit its width.
                .font(.system(size: Layout.flagHeight)) // provenance-ok: emoji sized to the token slot (auth.phone.layout.countryCode flagHeight)
                .minimumScaleFactor(0.5)
                .frame(width: Layout.flagWidth, height: Layout.flagHeight)
                .padding(.leading, Layout.flagLeading)
                .padding(.trailing, Layout.flagToText)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(region.flatMap { Locale.current.localizedString(forRegionCode: $0) } ?? ""))
        .accessibilityHidden(region == nil)
    }
}

/// The country list behind the flag (`auth.phone.layout.countryCode` flagTap: the platform picker in a sheet): every
/// region with a calling code by its localised name, its flag and code, searchable; choosing one replaces the calling
/// code and closes the sheet. System list styling (system surface).
struct CountryCodeList: View {
    let selected: String?
    let onSelect: (String) -> Void
    @State private var query = ""
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    private var countries: [PhoneNumberInput.Country] {
        let all = PhoneNumberInput.countries(locale: locale)
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return all }
        let digits = PhoneNumberInput.digits(of: trimmed)
        return all.filter { $0.name.localizedCaseInsensitiveContains(trimmed) || (!digits.isEmpty && $0.callingCode.hasPrefix(digits)) }
    }

    var body: some View {
        NavigationStack {
            List(countries) { country in
                Button {
                    onSelect(country.region)
                    dismiss()
                } label: {
                    HStack {
                        Text(country.flag)
                        Text(country.name)
                            .foregroundStyle(.primary) // provenance-ok: system list label colour (color.global.system.ios)
                        Spacer(minLength: 0)
                        Text("+" + country.callingCode) // provenance-ok: E.164 prefix before the calling code
                            .foregroundStyle(.secondary) // provenance-ok: system secondary label colour (color.global.system.ios)
                    }
                }
                .accessibilityAddTraits(country.region == selected ? .isSelected : [])
            }
            .listStyle(.plain)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("auth.phone.countries")
    }
}
