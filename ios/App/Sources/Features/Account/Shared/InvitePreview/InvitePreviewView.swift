// Surface: invite.appclip — the invite preview (the invite.web page anatomy rendered natively) and the Partiful-style
// state pages. Reference apps: Partiful (event invite page, App Clip card, RSVP sheet) + Apple HIG (App Clips);
// design/surfaces/invite.appclip.md and invite.web.md. Reference images:
// references/auto/partiful/web/pf-web-private-past-01.png … -03.png (P3), pf-web-public-light-01.png (P1),
// pf-web-public-dark-01.png (P2), pf-web-notfound-01.png (NF), pf-web-public-light-rsvp-sheet.png /
// pf-web-public-dark-rsvp-sheet.png (P4), references/auto/partiful/store/partiful-store-04.png (C1).
// Shared by the App Clip and the installed app (`InviteScreen`).
import DesignSystem
import SwiftUI

/// Text styles of the invite page (`invite.web.*`; px = pt). Dynamic Type follows the foundations' role mechanism:
/// each size scales with the nearest platform style (F-13 rule).
enum InviteStyle {
    private static func style(_ size: CGFloat, _ weight: Font.Weight, _ textStyle: Font.TextStyle, lineHeight: CGFloat? = nil) -> DSTextStyle {
        DSTextStyle(family: Tokens.Fonts.inviteWebFont, size: size, weight: weight, relativeTo: textStyle, lineHeight: lineHeight)
    }

    /// Body text: `invite.web.fontSize.body`, `invite.web.lineHeight.default` × size.
    static let body = style(Tokens.FontSizes.inviteWebFontSizeBody, Tokens.FontWeights.inviteWebFontWeightBody, .callout,
                            lineHeight: Tokens.FontSizes.inviteWebFontSizeBody * Tokens.LineHeights.inviteWebLineHeightDefault)
    static let bodyButton = style(Tokens.FontSizes.inviteWebFontSizeBody, Tokens.FontWeights.inviteWebFontWeightButton, .callout)
    static let userRowName = style(Tokens.FontSizes.inviteWebFontSizeBody, Tokens.FontWeights.inviteWebFontWeightUserRowName, .callout)
    static let sectionHeader = style(Tokens.FontSizes.inviteWebFontSizeSectionHeader, Tokens.FontWeights.inviteWebFontWeightSectionHeader, .headline)
    static let detail = style(Tokens.FontSizes.inviteWebFontSizeDetail, Tokens.FontWeights.inviteWebFontWeightBody, .subheadline,
                              lineHeight: Tokens.FontSizes.inviteWebFontSizeDetail * Tokens.LineHeights.inviteWebLineHeightDefault)
    static let buttonMedium = style(Tokens.FontSizes.inviteWebFontSizeButtonMedium, Tokens.FontWeights.inviteWebFontWeightButton, .subheadline)
    static let stateGlyph = style(Tokens.FontSizes.inviteWebFontSizeStateGlyph, Tokens.FontWeights.inviteWebFontWeightBody, .largeTitle,
                                  lineHeight: Tokens.FontSizes.inviteWebFontSizeStateGlyph * Tokens.LineHeights.inviteWebLineHeightDefault)
    static let stateTitle = style(Tokens.FontSizes.inviteWebFontSizeStateTitle, Tokens.FontWeights.inviteWebFontWeightStateTitle, .title2)

    /// The title at its auto-fitted size (`invite.web.lineHeight.title`, `invite.web.letterSpacing.title` em).
    static func title(size: CGFloat) -> DSTextStyle {
        style(size, Tokens.FontWeights.inviteWebFontWeightTitle, .largeTitle,
              lineHeight: size * Tokens.LineHeights.inviteWebLineHeightTitle)
    }
}

/// Partiful's button feedback: pressed opacity `invite.web.opacity.button.active`, animated over
/// `invite.web.duration.button.opacity` with `invite.web.easing.button`.
struct InvitePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? Tokens.Opacities.inviteWebOpacityButtonActive : 1)
            .dsAnimation(.timing(duration: Tokens.Durations.inviteWebDurationButtonOpacity, easing: Tokens.Easings.inviteWebEasingButton),
                         value: configuration.isPressed)
    }
}

/// The large filled button (`invite.web.dimension.button.large.*`, `invite.web.radius.button.large`,
/// `invite.web.color.button.filled.*`, body size at the button weight).
struct InviteFilledButton: View {
    let title: String
    let theme: InviteTheme
    var fullWidth = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .dsTextStyle(InviteStyle.bodyButton)
                .foregroundStyle(theme.buttonLabel)
                .padding(.horizontal, Tokens.Sizes.inviteWebDimensionButtonLargePaddingH)
                .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: Tokens.Sizes.inviteWebDimensionButtonLargeHeight)
                .background(theme.buttonFill, in: RoundedRectangle(cornerRadius: Tokens.Radii.inviteWebRadiusButtonLarge))
        }
        .buttonStyle(InvitePressStyle())
    }
}

/// The preview of a valid invite: title, cover, "Invited by", Member List, members-only card with "Join".
struct InvitePreviewContent: View {
    let preview: WebInvitePreview
    /// Hidden once the person has joined.
    var showsJoin = true
    let onJoin: () -> Void

    @State private var showsAllMembers = false

    private var theme: InviteTheme { InviteTheme(preview.theme) }

    var body: some View {
        GeometryReader { proxy in
            let column = min(proxy.size.width - Tokens.Sizes.inviteWebDimensionMargin * 2, Tokens.Sizes.inviteWebDimensionColumnMaxWidth)
            ScrollView {
                VStack(spacing: 0) {
                    title(column: column)
                    if let cover = preview.cover {
                        URLImage(url: cover.url) { theme.text.opacity(Tokens.Opacities.inviteWebOpacityButtonOutlinedFill) }
                            .aspectRatio(cover.width / max(cover.height, 1), contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radii.inviteWebRadiusCover))
                            .accessibilityLabel(Text(Copy.inviteWebCoverAlt(groupName: preview.groupName)))
                            .padding(.top, Tokens.Sizes.inviteWebDimensionTitleToCover)
                    }
                    VStack(alignment: .leading, spacing: Tokens.Sizes.inviteWebDimensionSectionGap) {
                        if let inviter = preview.inviterFirstName {
                            Text(Copy.inviteWebInvitedBy(firstName: inviter))
                                .dsTextStyle(InviteStyle.body)
                                .foregroundStyle(theme.text.opacity(Tokens.Opacities.inviteWebOpacityTextBody))
                                .padding(.vertical, Tokens.Sizes.inviteWebDimensionFieldRowPaddingV)
                        }
                        memberList
                        if showsJoin { gateCard }
                    }
                    .padding(.top, preview.cover == nil ? Tokens.Sizes.inviteWebDimensionTitleToCover : Tokens.Sizes.inviteWebDimensionCoverToNext)
                }
                .frame(width: max(column, 0))
                .frame(maxWidth: .infinity)
                .padding(.top, Tokens.Sizes.inviteWebDimensionTitleTop)
                .padding(.bottom, Tokens.Sizes.inviteWebDimensionSectionGap)
            }
        }
        .background(theme.background.ignoresSafeArea())
        .accessibilityIdentifier("invite.preview")
    }

    private func title(column: CGFloat) -> some View {
        let size = InviteTitleFit.size(for: preview.groupName, width: column)
        return Text(preview.groupName)
            .dsTextStyle(InviteStyle.title(size: size))
            .tracking(size * Tokens.Tracking.inviteWebLetterSpacingTitle)
            .foregroundStyle(theme.text)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: Member List

    private var memberList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(Copy.inviteWebMembersTitle)
                    .dsTextStyle(InviteStyle.sectionHeader)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                Button {
                    showsAllMembers.toggle()
                } label: {
                    Text(Copy.inviteWebMembersViewAll)
                        .dsTextStyle(InviteStyle.buttonMedium)
                        .padding(.horizontal, Tokens.Sizes.inviteWebDimensionButtonMediumPaddingH)
                        .frame(minHeight: Tokens.Sizes.inviteWebDimensionButtonMediumHeight)
                        .background(theme.text.opacity(Tokens.Opacities.inviteWebOpacityButtonOutlinedFill), in: Capsule())
                        .overlay(Capsule().strokeBorder(theme.text.opacity(theme.outlinedBorderOpacity), lineWidth: Tokens.Sizes.inviteWebDimensionButtonOutlinedBorder))
                }
                .buttonStyle(InvitePressStyle())
            }
            .frame(minHeight: Tokens.Sizes.inviteWebDimensionButtonMediumHeight)
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: Tokens.Sizes.inviteWebDimensionAvatar, maximum: Tokens.Sizes.inviteWebDimensionAvatar),
                                   spacing: Tokens.Sizes.inviteWebDimensionAvatarGap, alignment: .leading)],
                alignment: .leading,
                spacing: Tokens.Sizes.inviteWebDimensionAvatarGap
            ) {
                ForEach(Array(preview.members.enumerated()), id: \.offset) { _, member in
                    InviteMemberAvatar(member: member, theme: theme)
                        .accessibilityLabel(Text(member.firstName ?? ""))
                        .accessibilityHidden(member.firstName == nil)
                }
            }
            .padding(.top, Tokens.Sizes.inviteWebDimensionHeaderToAvatars)
            if showsAllMembers {
                VStack(alignment: .leading, spacing: Tokens.Sizes.inviteWebDimensionUserRowListGap) {
                    ForEach(Array(preview.members.enumerated()), id: \.offset) { _, member in
                        HStack(spacing: Tokens.Sizes.inviteWebDimensionUserRowColumnGap) {
                            InviteMemberAvatar(member: member, theme: theme)
                                .accessibilityHidden(true)
                            Text(member.firstName ?? "")
                                .dsTextStyle(InviteStyle.userRowName)
                        }
                        .padding(.vertical, Tokens.Sizes.inviteWebDimensionUserRowPaddingV)
                    }
                }
            }
        }
        .foregroundStyle(theme.text)
    }

    // MARK: Members-only card (Partiful "Restricted Access")

    private var gateCard: some View {
        VStack(spacing: 0) {
            Image(systemName: Tokens.Icons.inviteWebIconLock)
                .resizable()
                .scaledToFit()
                .frame(height: Tokens.Sizes.inviteWebDimensionGateCardGlyph)
                .accessibilityHidden(true)
            Text(Copy.inviteWebGateTitle)
                .dsTextStyle(InviteStyle.sectionHeader)
                .padding(.top, Tokens.Sizes.inviteWebDimensionGateCardGlyphToTitle)
            Text(Copy.inviteWebGateBody)
                .dsTextStyle(InviteStyle.detail)
                .foregroundStyle(theme.text.opacity(Tokens.Opacities.inviteWebOpacityTextBody))
                .padding(.top, Tokens.Sizes.inviteWebDimensionGateCardTitleToBody)
            InviteFilledButton(title: Copy.inviteAppclipJoin, theme: theme, action: onJoin)
                .accessibilityIdentifier("invite.join")
                .padding(.top, Tokens.Sizes.inviteWebDimensionGateCardBodyToButton)
        }
        .multilineTextAlignment(.center)
        .foregroundStyle(theme.text)
        .padding(Tokens.Sizes.inviteWebDimensionGateCardPadding)
        .frame(maxWidth: .infinity)
        .background(theme.gateCard, in: RoundedRectangle(cornerRadius: Tokens.Radii.inviteWebRadiusGateCard))
    }
}

/// A member's photo, or the initials disc (first grapheme on `invite.web.opacity.avatar.minimal.fill.*`).
struct InviteMemberAvatar: View {
    let member: WebInvitePreview.Member
    let theme: InviteTheme

    var body: some View {
        Group {
            if let url = member.avatarURL {
                URLImage(url: url) { disc }
            } else {
                disc
            }
        }
        .frame(width: Tokens.Sizes.inviteWebDimensionAvatar, height: Tokens.Sizes.inviteWebDimensionAvatar)
        .clipShape(Circle())
    }

    private var disc: some View {
        ZStack {
            Circle().fill(theme.text.opacity(theme.initialsFillOpacity))
            Text(member.firstName.map { String($0.prefix(1)) } ?? "")
                .dsTextStyle(InviteStyle.body)
                .foregroundStyle(theme.text.opacity(Tokens.Opacities.inviteWebOpacityAvatarMinimalText))
        }
    }
}

/// Partiful's state page (NF): header space, centred glyph, uppercase title, body, optional large filled action.
struct InviteStateView: View {
    let state: InvitePreviewState
    var onRetry: (() -> Void)?

    private var theme: InviteTheme { .standard }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: Tokens.Sizes.inviteWebDimensionStateHeaderSpace)
            Text(glyph)
                .dsTextStyle(InviteStyle.stateGlyph)
                .accessibilityLabel(Text(glyphLabel))
            Text(title)
                .textCase(.uppercase)
                .dsTextStyle(InviteStyle.stateTitle)
                .foregroundStyle(theme.text)
                .padding(.top, Tokens.Sizes.inviteWebDimensionStateGlyphToTitle)
                .accessibilityAddTraits(.isHeader)
            if let detail = bodyText {
                Text(detail)
                    .dsTextStyle(InviteStyle.detail)
                    .foregroundStyle(theme.text.opacity(Tokens.Opacities.inviteWebOpacityTextBody))
                    .padding(.top, Tokens.Sizes.inviteWebDimensionGateCardTitleToBody)
            }
            if let onRetry, showsRetry {
                InviteFilledButton(title: Copy.inviteWebErrorRetry, theme: theme, fullWidth: false, action: onRetry)
                    .padding(.top, Tokens.Sizes.inviteWebDimensionStateBodyToAction)
            }
            Spacer(minLength: 0)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, Tokens.Sizes.inviteWebDimensionMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background.ignoresSafeArea())
        .accessibilityIdentifier("invite.state")
    }

    private var glyph: String { state == .full ? Copy.inviteAppclipFullGlyph : Copy.inviteWebStateGlyph }
    private var glyphLabel: String { state == .full ? Copy.inviteAppclipFullGlyphLabel : Copy.inviteWebStateGlyphLabel }

    private var title: String {
        switch state {
        case .unavailable: return Copy.inviteWebUnavailableTitle
        case .notFound: return Copy.inviteWebNotFoundTitle
        case .full: return Copy.inviteAppclipFullTitle
        default: return Copy.inviteWebErrorTitle
        }
    }

    private var bodyText: String? {
        switch state {
        case .unavailable: return Copy.inviteWebUnavailableBody
        case .notFound: return nil
        case .full: return Copy.inviteAppclipFullBody
        case .rateLimited: return Copy.inviteWebRateLimitedBody
        case .offline: return Copy.inviteAppclipOfflineBody
        default: return Copy.inviteWebErrorBody
        }
    }

    private var showsRetry: Bool { state == .error || state == .offline }
}

/// The preview area for any state: platform progress while loading, the preview, or the state page.
struct InvitePreviewScreen: View {
    let state: InvitePreviewState
    var showsJoin = true
    let onJoin: () -> Void
    let onRetry: () -> Void

    var body: some View {
        switch state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(InviteTheme.standard.background.ignoresSafeArea())
                .accessibilityIdentifier("invite.loading")
        case let .valid(preview):
            InvitePreviewContent(preview: preview, showsJoin: showsJoin, onJoin: onJoin)
        default:
            InviteStateView(state: state, onRetry: onRetry)
        }
    }
}
