// Shared component — C-33 onboarding / landing hero and the onboarding title block (design/components.md), replacing
// Yope's heavy sign-up titles and two-tone title. Evidence: LAND ('F' y1235–1298; capsule y2032–2211; link y2260–2320;
// legal y2385–2435, baselines 2429 → 2494); RV §3.3, §3.4; RP §6.3, §3.7. Sign-up form screens, onboarding pages and
// permission pre-prompts were not captured as images (Gap) — they compose C-05, C-12, C-27 in the APK's order.
import DesignSystem
import SwiftUI

/// The sign-up landing (LAND): the owner's mark area at the top (`mark`; Retro's wordmark is not copied), a large grey
/// line (text role `onboardingTitle`, `color.global.textSecondary`, centred), the primary capsule (C-05) at
/// `size.global.buttonMarginH`, an optional grey secondary link under it (C-08 `.link`, lower case from copy), and fine
/// print (text role `caption` with `lineHeight.global.caption`, `color.global.textSecondary`, centred; its links
/// underlined and tinted the same grey). Page `color.global.background` (LAND is the dark appearance; the light landing
/// was not captured — Gap). Vertical spacing between the parts was not tokenised (Gap) — the mark area takes the free
/// space, the rest stacks at the bottom with platform spacing.
/// Accessibility: links are buttons with their own labels; the large line is not a header (the mark is the page's
/// identity). Contrast: grey on black 7.37:1 passes; in light it would fail (failure 1), reported.
struct OnboardingHero<Mark: View>: View {
    @ViewBuilder let mark: () -> Mark
    let line: String
    let primaryTitle: String
    let onPrimary: () -> Void
    var secondaryTitle: String?
    var onSecondary: (() -> Void)?
    var finePrint: AttributedString?

    init(
        line: String,
        primaryTitle: String,
        onPrimary: @escaping () -> Void,
        secondaryTitle: String? = nil,
        onSecondary: (() -> Void)? = nil,
        finePrint: AttributedString? = nil,
        @ViewBuilder mark: @escaping () -> Mark
    ) {
        self.line = line
        self.primaryTitle = primaryTitle
        self.onPrimary = onPrimary
        self.secondaryTitle = secondaryTitle
        self.onSecondary = onSecondary
        self.finePrint = finePrint
        self.mark = mark
    }

    var body: some View {
        VStack {
            VStack {
                mark()
                Text(line)
                    .dsTextStyle(TextRole.onboardingTitle)
                    .foregroundStyle(Tokens.Colors.globalTextSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxHeight: .infinity)
            PrimaryButton(primaryTitle, action: onPrimary)
                .padding(.horizontal, Tokens.Sizes.globalButtonMarginH)
            if let secondaryTitle, let onSecondary {
                TextButton(secondaryTitle, style: .link, action: onSecondary)
            }
            if let finePrint {
                Text(Self.underliningLinks(finePrint))
                    .dsTextStyle(TextRole.caption)
                    .foregroundStyle(Tokens.Colors.globalTextSecondary)
                    .tint(Tokens.Colors.globalTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Tokens.Colors.globalBackground.ignoresSafeArea())
    }

    /// The fine print with its link runs underlined (LAND).
    static func underliningLinks(_ text: AttributedString) -> AttributedString {
        var result = text
        for run in result.runs where run.link != nil {
            result[run.range].swiftUI.underlineStyle = Text.LineStyle.single
        }
        return result
    }
}

/// A title (and optional line under it) at the top of a sign-up / onboarding step: the title in the display serif (text
/// role `displayMedium`, `color.global.textPrimary` — Retro's Android onboarding headlines are display serif), the line
/// in the empty-state explanation style (text role `emptyDetail`, `color.global.textSecondary` — composition of C-27).
/// Both centred; the spacing between them is the platform's (not measured). Accessibility: the title is a header.
struct OnboardingTitleBlock: View {
    let title: String
    var subtitle: String?

    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack {
            Text(title)
                .dsTextStyle(TextRole.displayMedium)
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle)
                    .dsTextStyle(TextRole.emptyDetail)
                    .foregroundStyle(Tokens.Colors.globalTextSecondary)
            }
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Yope's two-tone title (second part in the lime accent). Retro has no accent colour in chrome: both parts are drawn as
/// one display serif title (`displayMedium`, `color.global.textPrimary`). Kept so screens compile until Pass 4.
@available(*, deprecated, message: "Retro has no two-tone title: use OnboardingTitleBlock (C-33)")
struct TwoToneTitle: View {
    let text: String
    var accent: String?

    var body: some View {
        let parts = Self.split(text, accent: accent)
        VStack(spacing: 0) {
            if !parts.first.isEmpty {
                Text(parts.first)
            }
            if !parts.second.isEmpty {
                Text(parts.second)
            }
        }
        .dsTextStyle(TextRole.displayMedium)
        .foregroundStyle(Tokens.Colors.globalTextPrimary)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(text))
        .accessibilityAddTraits(.isHeader)
    }

    /// Splits `text` into (first line, accent line).
    static func split(_ text: String, accent: String?) -> (first: String, second: String) {
        if let accent, !accent.isEmpty, let range = text.range(of: accent, options: .backwards) {
            let before = String(text[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            let after = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            let first = after.isEmpty ? before : [before, after].filter { !$0.isEmpty }.joined(separator: " ")
            return (first, accent)
        }
        let words = text.split(separator: " ").map { String($0) }
        guard words.count > 1 else { return ("", text) }
        let half = words.count / 2
        return (words[..<half].joined(separator: " "), words[half...].joined(separator: " "))
    }
}
