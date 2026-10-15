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

/// auth.phone screen: title, italic subtitle, phone field, lime "continue", legal footer; HUD while sending.
struct PhoneScreen: View {
    @State private var model: PhoneModel
    @Environment(AccountDependencies.self) private var dependencies
    @FocusState private var fieldFocused: Bool
    @State private var choosingCountry = false

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
        .formErrorAlert(model.failure?.message, trigger: model.errorCount)
        .onAppear { fieldFocused = true }
        .sheet(isPresented: $choosingCountry) {
            CountryCodeList(selected: model.flagRegion) { region in
                model.selectCountry(region)
                fieldFocused = true
            }
        }
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
                    contentType: .telephoneNumber,
                    trailingInset: CountryFlagButton.Layout.flagLeading
                ) {
                    CountryFlagButton(region: model.flagRegion) { choosingCountry = true }
                }
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
