// Surface: invite.appclip (and the installed app's invite sheet) — the invite card of invite.web (mobile), drawn
// natively. Visual reference: Retro's `/u/[username]` page (references/auto/retro/web/retro.app-u-nathan-iphone.png,
// WEBU: card inset 6 / radius ≈ 36, 112-pt avatar, serif "Nathan Invited You!", 62 %-white line, translucent 56-pt pill
// "Let's go", tiny white footer; CSS .page_mobileProfilePageContent, .page_invitePillButton, .page_mobileInviteFooter)
// and its App Clip card (RP §7). design/surfaces/invite.appclip.md, invite.web.md. Shared by the App Clip and
// `InviteScreen`.
import DesignSystem
import SwiftUI

/// Text styles of the card (`invite.web.*` + `global.*`). Dynamic Type: headline `largeTitle`, line `subheadline`,
/// pill `headline` (invite.appclip Accessibility); the footer scales with `caption2`.
enum InviteCardStyle {
    /// `font.global.displayNarrow`, `fontSize.global.displayMedium` (34.4) / `invite.web.lineHeight.headline` (32), regular.
    static let headline = DSTextStyle(
        family: Tokens.Fonts.globalDisplayNarrow,
        size: Tokens.FontSizes.globalDisplayMedium,
        weight: Tokens.FontWeights.fontWeightGlobalDisplayMedium,
        relativeTo: Font.TextStyle(tokenName: Tokens.Layouts.GlobalTextStyleMap.displayMedium),
        lineHeight: Tokens.LineHeights.inviteWebLineHeightHeadline
    )
    /// `invite.web.fontSize.body` (14) / `invite.web.lineHeight.body` (19.6), tracking `invite.web.letterSpacing.body`.
    static let line = DSTextStyle(
        family: Tokens.Fonts.globalFamily,
        size: Tokens.FontSizes.inviteWebFontSizeBody,
        weight: Tokens.FontWeights.fontWeightGlobalBody,
        relativeTo: .subheadline,
        lineHeight: Tokens.LineHeights.inviteWebLineHeightBody,
        tracking: Tokens.Tracking.inviteWebLetterSpacingBody
    )
    /// `invite.web.fontSize.pill` (16) / `invite.web.fontWeight.pill`.
    static let pill = DSTextStyle(
        family: Tokens.Fonts.globalFamily,
        size: Tokens.FontSizes.inviteWebFontSizePill,
        weight: Tokens.FontWeights.inviteWebFontWeightPill,
        relativeTo: .headline
    )
    /// `invite.web.fontSize.footer` (8), `fontWeight.global.body`.
    static let footer = DSTextStyle(
        family: Tokens.Fonts.globalFamily,
        size: Tokens.FontSizes.inviteWebFontSizeFooter,
        weight: Tokens.FontWeights.fontWeightGlobalBody,
        relativeTo: .caption2
    )
}

/// What the card's column shows (invite.web Structure, States).
struct InviteCardContent: Hashable {
    /// The blurred photo behind the card; nil → `color.global.backgroundDeep`.
    var backdrop: PhotoSource?
    /// `invite.web.cover.alt` when the backdrop is the group's cover.
    var backdropLabel: String?
    /// The inviter's avatar circle (the placeholder circle when `avatar` is nil); state cards show none.
    var showsAvatar: Bool
    var avatar: PhotoSource?
    var avatarLabel: String?
    var headline: String
    var line: String?
    /// Members in joining order (C-23 stack, as many as fit `invite.web.size.textMaxWidth`).
    var members: [PhotoSource?]
    var membersLabel: String?

    /// A valid invite (`joined`: the App Clip's joined state — `invite.appclip.joined.*`, no pill).
    static func invite(_ preview: WebInvitePreview, joined: Bool = false) -> InviteCardContent {
        let headline: String
        let line: String
        if joined {
            headline = Copy.inviteAppclipJoinedTitle(groupName: preview.groupName)
            line = Copy.inviteAppclipJoinedBody
        } else {
            headline = preview.inviterFirstName.map { Copy.inviteWebInvitedBy(firstName: $0) } ?? Copy.inviteWebInvitedFallback
            line = Copy.inviteWebBody(groupName: preview.groupName)
        }
        return InviteCardContent(
            backdrop: preview.backdropSource,
            backdropLabel: preview.coverSource == nil ? nil : Copy.inviteWebCoverAlt(groupName: preview.groupName),
            showsAvatar: true,
            avatar: preview.inviterAvatarSource,
            avatarLabel: preview.inviterFirstName.map { Copy.inviteWebAvatarAlt(firstName: $0) },
            headline: headline,
            line: line,
            members: preview.members.indices.map { preview.avatarSource(of: $0) },
            membersLabel: preview.members.isEmpty ? nil : Copy.inviteWebMembersTitle(groupName: preview.groupName)
        )
    }

    /// A state card: the state's title and explanation on `color.global.backgroundDeep`, no avatar, no members.
    static func state(_ state: InvitePreviewState) -> InviteCardContent {
        let headline: String
        let line: String?
        switch state {
        case .unavailable:
            headline = Copy.inviteWebUnavailableTitle
            line = Copy.inviteWebUnavailableBody
        case .notFound:
            headline = Copy.inviteWebNotFoundTitle
            line = nil
        case .rateLimited:
            headline = Copy.inviteWebErrorTitle
            line = Copy.inviteWebRateLimitedBody
        case .offline:
            headline = Copy.inviteWebErrorTitle
            line = Copy.inviteAppclipOfflineBody
        case .full:
            headline = Copy.inviteAppclipFullTitle
            line = Copy.inviteAppclipFullBody
        case .loading, .valid, .error:
            headline = Copy.inviteWebErrorTitle
            line = Copy.inviteWebErrorBody
        }
        return InviteCardContent(
            backdrop: nil, backdropLabel: nil, showsAvatar: false, avatar: nil, avatarLabel: nil,
            headline: headline, line: line, members: [], membersLabel: nil
        )
    }
}

/// The card's pill: "Let's go" (`invite.web.cta`; busy `invite.web.opening`) or "Try again" (`invite.web.error.retry`).
struct InviteCardPill {
    let title: String
    var busyTitle: String?
    var isBusy = false
    var identifier: String
    let action: () -> Void
}

/// Pill background `invite.web.color.pill`, `invite.web.color.pillHover` while pressed (the web's hover), over
/// `invite.web.duration.pill` with `invite.web.easing.pill`; Reduce Motion: no transition.
private struct InvitePillStyle: ButtonStyle {
    private static let press = DSAnimation.timing(duration: Tokens.Durations.inviteWebDurationPill, easing: Tokens.Easings.inviteWebEasingPill)

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Tokens.Colors.inviteWebColorPillHover : Tokens.Colors.inviteWebColorPill, in: Capsule())
            .dsAnimation(Self.press, value: configuration.isPressed)
    }
}

/// The card's colour field (`invite.web.layout.backdrop`, MERGE L-6): the photo aspect-filled, extended 3σ past the card
/// so the blur has no faded edge, Gaussian-blurred at σ = `blurSigmaToWidth` × the card width, under
/// `color.global.backdropDim`; `color.global.backgroundDeep` while it loads. Not the recap's mild C-34 blur
/// (`BlurredBackdrop`, σ `size.global.backdropBlur`).
struct InviteBackdrop: View {
    let source: PhotoSource?

    /// The blur's standard deviation for a card `width` wide.
    static func sigma(width: CGFloat) -> CGFloat {
        width * Tokens.Layouts.InviteWebLayoutBackdrop.blurSigmaToWidth
    }

    var body: some View {
        GeometryReader { proxy in
            let sigma = Self.sigma(width: proxy.size.width)
            let bleed = sigma * Self.bleedSigmas
            ZStack {
                Tokens.Colors.globalBackgroundDeep
                PhotoView(source: source)
                    .frame(width: proxy.size.width + bleed * 2, height: proxy.size.height + bleed * 2)
                    .blur(radius: sigma)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                Tokens.Colors.globalBackdropDim
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .accessibilityHidden(true)
    }

    /// "extended 3σ past the card" (`invite.web.layout.backdrop.source`).
    private static let bleedSigmas: CGFloat = 3 // provenance-ok: the token's "3σ" extension, stated in its source text
}

/// The invite card on the white page (invite.web mobile): inset `invite.web.size.cardInset` from every screen edge,
/// corners `invite.web.radius.card`, filled with the blurred colour field (`InviteBackdrop`) or
/// `color.global.backgroundDeep`. A centred column: the inviter's avatar centred in the space above the text block;
/// the headline, the line and the member stack anchored `invite.web.size.bodyToPill` above the pill; the pill
/// `invite.web.size.pillToFooter` above the footer "Terms & Privacy" (`invite.web.size.footerMargin` around it).
/// Retro's web page has no dark scheme: the card is the same in both appearances.
struct InviteCard: View {
    let content: InviteCardContent
    var pill: InviteCardPill?
    /// Loading: the empty card with the white platform activity indicator centred (C-28).
    var isLoading = false
    var termsURL: URL?
    var privacyURL: URL?

    @State private var browserLink: BrowserLink?

    var body: some View {
        ZStack {
            Tokens.Colors.globalBackground
                .ignoresSafeArea()
            card
                .clipShape(DSShape.rounded(Tokens.Radii.inviteWebRadiusCard))
                .padding(Tokens.Sizes.inviteWebSizeCardInset)
                .ignoresSafeArea()
            if isLoading {
                ProgressView()
                    .tint(Tokens.Colors.globalTextOnMedia)
                    .accessibilityLabel(Text(Copy.globalA11yLoading))
                    .accessibilityAddTraits(.updatesFrequently)
                    .accessibilityIdentifier("invite.loading")
            } else {
                column
                    .id(content)
                    .dsTransition(.opacity)
            }
        }
        // invite.appclip Motion: the joined state cross-fades the card content (`duration.global.fade`).
        .dsAnimation(ComponentMotion.fade, value: content)
        .environment(\.colorScheme, .light)
        .sheet(item: $browserLink) { link in
            SafariView(url: link.url)
                .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private var card: some View {
        if let backdrop = content.backdrop {
            InviteBackdrop(source: backdrop)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(content.backdropLabel ?? ""))
                .accessibilityAddTraits(.isImage)
                .accessibilityHidden(content.backdropLabel == nil)
        } else {
            Tokens.Colors.globalBackgroundDeep
        }
    }

    private var column: some View {
        VStack(spacing: 0) {
            ZStack {
                if content.showsAvatar { avatar }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            textBlock
            if let pill {
                pillButton(pill)
                    .padding(.horizontal, Tokens.Sizes.inviteWebSizePillInset)
                    .padding(.top, Tokens.Sizes.inviteWebSizeBodyToPill)
                footer
                    .padding(.top, Tokens.Sizes.inviteWebSizePillToFooter)
            } else {
                footer
                    .padding(.top, Tokens.Sizes.inviteWebSizeBodyToPill)
            }
        }
        .padding(.horizontal, Tokens.Sizes.inviteWebSizeCardInset)
        .multilineTextAlignment(.center)
    }

    /// `invite.web.size.avatar` circle, aspect-fill; `invite.web.color.avatarPlaceholder` without a photo.
    private var avatar: some View {
        ZStack {
            Circle().fill(Tokens.Colors.inviteWebColorAvatarPlaceholder)
            if let source = content.avatar {
                PhotoView(source: source)
            }
        }
        .frame(width: Tokens.Sizes.inviteWebSizeAvatar, height: Tokens.Sizes.inviteWebSizeAvatar)
        .clipShape(Circle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(content.avatarLabel ?? ""))
        .accessibilityAddTraits(.isImage)
        .accessibilityHidden(content.avatarLabel == nil)
    }

    private var textBlock: some View {
        VStack(spacing: Tokens.Sizes.inviteWebSizeHeadlineToBody) {
            Text(content.headline)
                .dsTextStyle(InviteCardStyle.headline)
                .foregroundStyle(Tokens.Colors.globalTextOnMedia)
                .frame(maxWidth: Tokens.Sizes.inviteWebSizeTextMaxWidth)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("invite.headline")
            if let line = content.line {
                Text(line)
                    .dsTextStyle(InviteCardStyle.line)
                    .foregroundStyle(Tokens.Colors.inviteWebColorBody)
                    .frame(maxWidth: Tokens.Sizes.inviteWebSizeTextMaxWidth)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !content.members.isEmpty {
                AvatarStack(sources: content.members, maxWidth: Tokens.Sizes.inviteWebSizeTextMaxWidth)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(content.membersLabel ?? ""))
                    .accessibilityHidden(content.membersLabel == nil)
            }
        }
    }

    /// Height `invite.web.size.pillHeight`, width = card − 2 × `invite.web.size.pillInset`, capsule; label white
    /// (`color.global.textOnMedia`); busy: the busy label at `invite.web.opacity.pillDisabled`.
    private func pillButton(_ pill: InviteCardPill) -> some View {
        Button(action: pill.action) {
            Text(pill.isBusy ? pill.busyTitle ?? pill.title : pill.title)
                .dsTextStyle(InviteCardStyle.pill)
                .foregroundStyle(Tokens.Colors.globalTextOnMedia)
                .frame(maxWidth: .infinity, minHeight: Tokens.Sizes.inviteWebSizePillHeight)
                .contentShape(Capsule())
        }
        .buttonStyle(InvitePillStyle())
        .opacity(pill.isBusy ? Tokens.Opacities.inviteWebOpacityPillDisabled : 1)
        .disabled(pill.isBusy)
        .accessibilityAddTraits(pill.isBusy ? .updatesFrequently : [])
        .accessibilityIdentifier(pill.identifier)
    }

    /// "Terms & Privacy": `invite.web.fontSize.footer`, white, each link padded to a 44 × 44 hit area; opens the legal
    /// URL (config/app.json) in the in-app browser. A link whose URL is not configured yet (owner) does nothing.
    private var footer: some View {
        HStack(spacing: 0) {
            legalLink(Copy.inviteWebFooterTerms, url: termsURL)
            Text(verbatim: "\u{00A0}&\u{00A0}") // provenance-ok: the spec's joining ampersand between the two copy strings ("Terms & Privacy", web footer)
                .accessibilityHidden(true)
            legalLink(Copy.inviteWebFooterPrivacy, url: privacyURL)
        }
        .dsTextStyle(InviteCardStyle.footer)
        .foregroundStyle(Tokens.Colors.globalTextOnMedia)
        .padding(Tokens.Sizes.inviteWebSizeFooterMargin)
    }

    private func legalLink(_ title: String, url: URL?) -> some View {
        Button {
            if let url { browserLink = BrowserLink(url: url) }
        } label: {
            Text(title)
        }
        .buttonStyle(.plain)
        .minimumHitArea(drawn: .zero)
        .accessibilityAddTraits(.isLink)
    }
}

/// The invite card for any state: loading, the invite (pill "Let's go"), the joined state (no pill) or a state card
/// (retry pill for errors and offline).
struct InvitePreviewScreen: View {
    let state: InvitePreviewState
    /// The App Clip's joined state (`invite.appclip.joined.*`).
    var isJoined = false
    /// "Let's go" is busy (`invite.web.opening`) while the installed app joins.
    var isBusy = false
    var termsURL: URL?
    var privacyURL: URL?
    let onContinue: () -> Void
    let onRetry: () -> Void

    var body: some View {
        InviteCard(content: content, pill: pill, isLoading: state == .loading, termsURL: termsURL, privacyURL: privacyURL)
            .accessibilityIdentifier(identifier)
    }

    private var content: InviteCardContent {
        if case let .valid(preview) = state { return .invite(preview, joined: isJoined) }
        return .state(state)
    }

    private var pill: InviteCardPill? {
        switch state {
        case .valid:
            guard !isJoined else { return nil }
            return InviteCardPill(title: Copy.inviteWebCta, busyTitle: Copy.inviteWebOpening, isBusy: isBusy, identifier: "invite.join", action: onContinue)
        case .error, .offline:
            return InviteCardPill(title: Copy.inviteWebErrorRetry, identifier: "invite.retry", action: onRetry)
        case .loading, .unavailable, .notFound, .rateLimited, .full:
            return nil
        }
    }

    private var identifier: String {
        switch state {
        case .loading: return "invite.loadingCard"
        case .valid: return isJoined ? "invite.joined" : "invite.preview"
        default: return "invite.state"
        }
    }
}
