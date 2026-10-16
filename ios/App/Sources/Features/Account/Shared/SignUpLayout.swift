// Account group — the onboarding form composition every sign-up step uses (auth.phone B, auth.code, auth.agegate,
// auth.profile, the onboarding pages; MERGE RA-2): composition of C-02 (back chevron, no title in the row), a display
// title (text role `displayMedium`) at C-01's `size.global.titleTop`, the explanation under it as C-19 sets the real
// name under the serif name, the content `size.global.titleToContent` below, and C-05 at the bottom margin, above the
// keyboard. Shared with the App Clip (invite.appclip runs the same screens). The page follows the system appearance
// (`layout.global.appearance`): nothing here forces a colour scheme.
import DesignSystem
import SwiftUI

/// The back chevron of a sign-up step (C-02 without a title): `icon.global.back` at the `size.global.icon` symbol size in
/// `color.global.textPrimary`, its ink `size.global.backInset` from the screen edge, vertically centred in a
/// `size.global.headerButton` row at the top of the safe area (where the system draws a navigation bar's back button);
/// hit area at least `size.global.minTouchTarget.ios`.
struct FormBackButton: View {
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: Tokens.Icons.globalBack)
                .font(Tokens.Fonts.globalFamily.font(size: Tokens.Sizes.globalIcon, weight: Font.Weight.regular))
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
                .frame(height: Tokens.Sizes.globalHeaderButton)
                .minimumHitArea(drawn: CGSize(width: Tokens.Sizes.globalIcon, height: Tokens.Sizes.globalIcon))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(accessibilityLabel))
        .padding(.leading, Tokens.Sizes.globalBackInset)
    }
}

/// The title block of a sign-up step or onboarding page: the title in the display serif (text role `displayMedium`,
/// `color.global.textPrimary`, header trait) and the explanation directly under it (text role `body`,
/// `color.global.textSecondary`), leading-aligned. The spacing between the two lines is the platform stack spacing, as
/// C-19 stacks the real name under the serif name (not measured).
struct OnboardingHeading: View {
    let title: String
    var explanation: String?

    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .dsTextStyle(TextRole.displayMedium)
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
                .accessibilityAddTraits(.isHeader)
            if let explanation {
                Text(explanation)
                    .dsTextStyle(TextRole.body)
                    .foregroundStyle(Tokens.Colors.globalTextSecondary)
            }
        }
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .capHeight(of: TextRole.displayMedium)
    }
}

/// One sign-up step on `color.global.background`:
///
/// - `back`: the C-02 chevron in a `size.global.headerButton` row at the safe-area top (nil: no back — steps after the
///   code cannot go back).
/// - the heading (`OnboardingHeading`) at `size.global.screenMargin`, the title's first baseline
///   `size.global.titleTop` below the safe-area top (C-01 metric);
/// - `content` (fields, rows) `size.global.titleToContent` below the explanation's last baseline, inside
///   `size.global.screenMargin`;
/// - `bottom` (the C-05 capsule, a C-08 link) pinned `size.global.buttonMarginH` above the keyboard or the bottom safe
///   area, `size.global.buttonMarginH` from the sides; the stack scrolls when it no longer fits (large Dynamic Type).
/// - `replacement` (offline, not configured): the C-27 block replaces the content and the bottom, centred in the space
///   under the heading.
struct SignUpLayout<Content: View, Bottom: View>: View {
    var back: FormBackButton?
    let title: String
    var explanation: String?
    var replacement: EmptyStateView?
    @ViewBuilder var content: () -> Content
    @ViewBuilder var bottom: () -> Bottom

    init(
        back: FormBackButton? = nil,
        title: String,
        explanation: String? = nil,
        replacement: EmptyStateView? = nil,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder bottom: @escaping () -> Bottom
    ) {
        self.back = back
        self.title = title
        self.explanation = explanation
        self.replacement = replacement
        self.content = content
        self.bottom = bottom
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    MetricStack {
                        OnboardingHeading(title: title, explanation: explanation)
                            .metricGap(Tokens.Sizes.globalTitleTop, from: .top, to: .firstBaseline)
                        if replacement == nil {
                            content()
                                .metricGap(Tokens.Sizes.globalTitleToContent, from: .lastBaseline, to: .top)
                        }
                    }
                    .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
                    if let replacement {
                        Spacer(minLength: 0)
                        replacement
                        Spacer(minLength: 0)
                    } else {
                        // The capsule keeps its own margin (`size.global.buttonMarginH`) from the content above it.
                        Spacer(minLength: Tokens.Sizes.globalButtonMarginH)
                        bottom()
                            .padding(.horizontal, Tokens.Sizes.globalButtonMarginH)
                            .padding(.bottom, Tokens.Sizes.globalButtonMarginH)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .top)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.never)
        }
        .overlay(alignment: .topLeading) {
            if let back { back }
        }
        .background(Tokens.Colors.globalBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
    }
}

extension SignUpLayout where Bottom == EmptyView {
    init(
        back: FormBackButton? = nil,
        title: String,
        explanation: String? = nil,
        replacement: EmptyStateView? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(back: back, title: title, explanation: explanation, replacement: replacement, content: content) { EmptyView() }
    }
}

/// A sign-up state with no form (resolving the next step, its failure, the under-age refusal): the C-27 block (no glyph)
/// centred on the page, or the platform activity indicator (C-28) while `title` is nil.
struct SignUpStateView: View {
    let title: String?
    let detail: String?
    var retry: EmptyStateView.Action?

    var body: some View {
        Group {
            if title == nil, detail == nil {
                LoadingHUD()
            } else {
                EmptyStateView(title: title, detail: detail, action: retry)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Tokens.Colors.globalBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }
}

extension EmptyStateView {
    /// The sign-up offline block (`auth.phone.offline.*`, C-27 error / offline variant, no glyph).
    static func signUpOffline(retry: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            title: Copy.authPhoneOfflineTitle,
            detail: Copy.authPhoneOfflineDetail,
            action: EmptyStateView.Action(Copy.authPhoneOfflineRetry, handler: retry)
        )
    }
}
