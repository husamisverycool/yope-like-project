// Shared component — sign-up / onboarding titles and Yope's two-tone title.
import DesignSystem
import SwiftUI

/// Title + italic subtitle at the top of a sign-up / onboarding step.
///
/// Tokens: title text role `onboardingTitle` (`fontSize.global.onboardingTitle`, `fontWeight.global.onboardingTitle`,
/// Dynamic Type largeTitle) in `color.global.textPrimary`; subtitle `auth.phone.fontSize.subtitle` with
/// `auth.phone.layout.subtitle` (italic, regular, `color.global.textPrimary`, centred; Dynamic Type subheadline).
/// Both centred; the title–subtitle gap is the platform's leading (not measured, auth.phone Gaps).
/// The caller places the block `groups.create.size.sheetTopToTitle` below the safe-area top.
struct OnboardingTitleBlock: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .dsTextStyle(TextRole.onboardingTitle)
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle)
                    .italic()
                    .dsTextStyle(TextRole.signUpSubtitle)
                    .foregroundStyle(Tokens.Colors.globalTextPrimary)
            }
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Two-tone title (`groups.create.layout.titleAccent`): the first part in `color.global.textPrimary`, the second
/// part on its own line in `color.global.accent`; text role `onboardingTitle`, centred.
///
/// `accent` names the second part when the copy marks it with a placeholder (`groups.invite.title.*`: the group
/// name). Without it the second half of the words is the accent (`groups.list.empty.title`: "create your" /
/// "first group", as its copy note states).
struct TwoToneTitle: View {
    let text: String
    var accent: String?

    var body: some View {
        let parts = Self.split(text, accent: accent)
        VStack(spacing: 0) {
            if !parts.first.isEmpty {
                Text(parts.first).foregroundStyle(Tokens.Colors.globalTextPrimary)
            }
            if !parts.second.isEmpty {
                Text(parts.second).foregroundStyle(Tokens.Colors.globalAccent)
            }
        }
        .dsTextStyle(TextRole.onboardingTitle)
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
        let words = text.split(separator: " ").map(String.init)
        guard words.count > 1 else { return ("", text) }
        let half = words.count / 2
        return (words[..<half].joined(separator: " "), words[half...].joined(separator: " "))
    }
}
