// Surface: auth.phone — landing (A) and phone number entry (B). Visual reference: Retro sign-up landing
// (references/auto/retro/lazyweb/retro-lazyweb-20251119-social.png, LAND: RAW iOS dark, 3.000 px/pt) and Retro's
// wordmark size (references/auto/retro/web/retro.app-5bff8a0be69f7ec7.css `.page_largeRetroWordmark`); B is the
// onboarding form composition (PhoneForm.swift). design/surfaces/auth.phone.md.
import AppData
import AppModels
import DesignSystem
import Observation
import SwiftUI
import UIKit

/// auth.phone: the landing on a cold launch without a session (and after sign-out), the phone form after "Get started"
/// or "already have an account?" (one-time-code sign-in serves new and returning accounts). A ↔ B: the onboarding page
/// transition (`duration.global.pageTransition`, `easing.global.standard`).
struct PhoneScreen: View {
    @State private var model: PhoneModel
    @State private var showsForm: Bool
    @Environment(AccountDependencies.self) private var dependencies

    /// - Parameter showsForm: start on B (tests, a return from auth.code); the landing otherwise.
    init(model: PhoneModel, showsForm: Bool = false) {
        _model = State(initialValue: model)
        _showsForm = State(initialValue: showsForm)
    }

    private static let pageTransition = DSAnimation.timing(duration: Tokens.Durations.globalPageTransition, easing: Tokens.Easings.globalStandard)

    var body: some View {
        ZStack {
            if showsForm {
                PhoneForm(
                    model: model,
                    network: dependencies.network,
                    onBack: { withDSAnimation(Self.pageTransition) { showsForm = false } },
                    onSent: { number in dependencies.session.codeSent(phone: number) }
                )
                .transition(.opacity)
            } else {
                PhoneLanding(
                    appName: dependencies.configuration.displayName,
                    legal: PhoneModel.legalText(termsURL: dependencies.configuration.termsURL, privacyURL: dependencies.configuration.privacyURL),
                    onStart: { withDSAnimation(Self.pageTransition) { showsForm = true } }
                )
                .transition(.opacity)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("auth.phone")
    }
}

/// auth.phone A — the landing (C-33 anatomy with LAND's measured gaps): the wordmark (the app's name from
/// config/app.json `displayName`, owner — omitted while it is not set) over the tagline, the block centred at
/// `auth.phone.layout.landingBlock.centreY` of the screen height; "Get started" (C-05) at `size.global.buttonMarginH`;
/// "already have an account?" (C-08 link) `auth.phone.size.capsuleToLink` under it; the fine print (text role `caption`,
/// underlined links) `auth.phone.size.linkToLegal` under the link and `auth.phone.size.legalToBottom` above the screen
/// bottom. Both buttons open the phone form. Page `color.global.background`, following the appearance (LAND is dark;
/// the light landing reuses its geometry, MERGE RA-3).
struct PhoneLanding: View {
    let appName: String?
    let legal: AttributedString
    let onStart: () -> Void

    /// The wordmark: the app's name in the display serif at `auth.phone.fontSize.wordmark`, at the display role's weight
    /// (`fontWeight.global.headerTitle`, regular), Dynamic Type `largeTitle`.
    private static let wordmark = DSTextStyle(
        family: Tokens.Fonts.globalDisplay,
        size: Tokens.FontSizes.authPhoneFontSizeWordmark,
        weight: Tokens.FontWeights.fontWeightGlobalHeaderTitle,
        relativeTo: .largeTitle
    )

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                wordmarkBlock
                    .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
                    .position(x: proxy.size.width / 2, y: proxy.size.height * Tokens.Layouts.AuthPhoneLayoutLandingBlock.centreY)
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    actions
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .ignoresSafeArea(.container, edges: [.top, .bottom])
        .background(Tokens.Colors.globalBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .opensLinksInAppBrowser()
    }

    /// Wordmark (header trait, read as the app's name) and the tagline `auth.phone.size.wordmarkToTagline` below its
    /// baseline (to the tagline's cap top), centred.
    private var wordmarkBlock: some View {
        MetricStack(alignment: .center) {
            if let appName {
                Text(appName)
                    .dsTextRole(Self.wordmark)
                    .foregroundStyle(Tokens.Colors.globalTextPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }
            Text(Copy.authPhoneTagline)
                .dsTextRole(TextRole.onboardingTitle)
                .foregroundStyle(Tokens.Colors.globalTextSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .metricGap(appName == nil ? 0 : Tokens.Sizes.authPhoneSizeWordmarkToTagline, from: .lastBaseline, to: .capTop)
        }
    }

    private var actions: some View {
        MetricStack(alignment: .center) {
            PrimaryButton(Copy.authPhoneGetStarted, action: onStart)
                .padding(.horizontal, Tokens.Sizes.globalButtonMarginH)
                .accessibilityIdentifier("auth.phone.getStarted")
            // C-08 secondary link; its 44-pt hit area centres the text, so it is placed by the text's cap top.
            TextButton(Copy.authPhoneSignIn, style: .link, action: onStart)
                .capHeight(of: TextRole.listTitle)
                .accessibilityIdentifier("auth.phone.signIn")
                .metricGap(Tokens.Sizes.authPhoneSizeCapsuleToLink, from: .bottom, to: .capTop)
            Text(legal)
                .dsTextRole(TextRole.caption)
                .foregroundStyle(Tokens.Colors.globalTextSecondary)
                .tint(Tokens.Colors.globalTextSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
                .metricGap(Tokens.Sizes.authPhoneSizeLinkToLegal, from: .lastBaseline, to: .capTop)
        }
        .padding(.bottom, Tokens.Sizes.authPhoneSizeLegalToBottom)
    }
}
