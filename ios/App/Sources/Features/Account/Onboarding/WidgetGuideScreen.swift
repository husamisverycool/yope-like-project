// Surface: onboarding.widget — guided add-the-widget step. Reference app: Locket (design/surfaces/onboarding.widget.md;
// layout from the welcome screen of the same Locket onboarding flow, an approximation noted in its Gaps). Reference
// images: references/auto/locket/lazyweb/locket-lazyweb-20260821-cap-welcome.png (LW),
// references/owner/locket-add-widget-steps.jpg (LT), locket-lazyweb-20260821-cap-personalization-3.png (LP3).
import DesignSystem
import SwiftUI

/// Static steps and a "Continue" capsule that always moves on (no check, no gate, no "did you add it?").
struct WidgetGuideScreen: View {
    let onContinue: () -> Void

    /// The iOS steps (`onboarding.widget.step.ios.1` … `.5`), then `onboarding.widget.done`. Step 4 names the app
    /// (`{app_name}`, BLOCKED): release builds omit it, so numbering follows the steps shown.
    static var steps: [String] {
        [
            Copy.onboardingWidgetStepIos1,
            Copy.onboardingWidgetStepIos2,
            Copy.onboardingWidgetStepIos3,
            AccountBlockedCopy.widgetStepIOS4,
            Copy.onboardingWidgetStepIos5,
        ].compactMap { $0 }
    }

    /// "1. …": numeral + period before the step's text (reference LT).
    static func numbered(_ number: Int, _ text: String) -> String {
        String(number) + ". " + text
    }

    private static let titleStyle = DSTextStyle(
        family: Tokens.Fonts.globalFamily,
        size: Tokens.FontSizes.onboardingWidgetFontSizeTitle,
        weight: Tokens.FontWeights.onboardingWidgetFontWeightTitle,
        relativeTo: .largeTitle
    )
    private static let stepStyle = DSTextStyle(
        family: Tokens.Fonts.globalFamily,
        size: Tokens.FontSizes.onboardingWidgetFontSizeStep,
        weight: Tokens.FontWeights.onboardingWidgetFontWeightStep,
        relativeTo: .title2,
        lineHeight: Tokens.LineHeights.onboardingWidgetLineHeightStep
    )
    /// CTA label: `onboarding.widget.fontSize.ctaLabel`, bold per the spec (no weight token), Dynamic Type headline.
    private static let ctaStyle = DSTextStyle(
        family: Tokens.Fonts.globalFamily,
        size: Tokens.FontSizes.onboardingWidgetFontSizeCtaLabel,
        weight: Font.Weight.bold,
        relativeTo: .headline
    )

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    Text(Copy.onboardingWidgetTitle)
                        .dsTextStyle(Self.titleStyle)
                        .foregroundStyle(Tokens.Colors.onboardingWidgetColorTitle)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.top, Tokens.Sizes.groupsCreateSizeSheetTopToTitle)
                    VStack(spacing: Tokens.LineHeights.onboardingWidgetLineHeightStep) {
                        ForEach(Array(Self.steps.enumerated()), id: \.offset) { index, step in
                            Text(Self.numbered(index + 1, step))
                                .accessibilityLabel(Text(Copy.onboardingWidgetStepNumberAccessibilityLabel(number: String(index + 1))))
                                .accessibilityValue(Text(step))
                        }
                        Text(Copy.onboardingWidgetDone)
                    }
                    .dsTextStyle(Self.stepStyle)
                    .foregroundStyle(Tokens.Colors.onboardingWidgetColorStep)
                    .padding(.top, Tokens.Sizes.groupsCreateSizeTitleToContent)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Tokens.Sizes.paywallSizePerkMarginH)
            }
            .scrollBounceBehavior(.basedOnSize)
            cta
                .padding(.bottom, Tokens.Sizes.groupsCreateSizeFieldToButton)
        }
        .background(
            LinearGradient(
                colors: [Tokens.Colors.onboardingWidgetColorBackgroundTop, Tokens.Colors.onboardingWidgetColorBackgroundBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .accessibilityIdentifier("onboarding.widget")
    }

    /// Content-width capsule: label + trailing arrow (decorative), `onboarding.widget.size.ctaPaddingH` each side.
    private var cta: some View {
        Button(action: onContinue) {
            HStack(spacing: Tokens.Sizes.onboardingWidgetSizeCtaArrowGap) {
                Text(Copy.onboardingWidgetContinue)
                    .dsTextStyle(Self.ctaStyle)
                Image(systemName: Tokens.Icons.onboardingWidgetIconCtaArrow)
                    .resizable()
                    .scaledToFit()
                    .frame(width: Tokens.Sizes.onboardingWidgetSizeCtaArrow)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(Tokens.Colors.onboardingWidgetColorCtaLabel)
            .padding(.horizontal, Tokens.Sizes.onboardingWidgetSizeCtaPaddingH)
            .frame(minHeight: Tokens.Sizes.onboardingWidgetSizeCtaHeight)
            .background(Tokens.Colors.onboardingWidgetColorCta, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("onboarding.widget.continue")
    }
}
