# Verification — `invite.appclip` (iOS, Pass 4 — Retro redesign)

App Clip: invite card, sign-in, join — `Features/Account/Shared/InvitePreview/InvitePreviewView.swift` (`InviteCard`, `InviteBackdrop`, `InvitePreviewScreen`), `InvitePreviewLoader.swift`, `ios/AppClip/Sources/InviteClipApp.swift`, `Screens/InviteScreen.swift` (installed app).

Checklist written from the spec (`design/surfaces/invite.appclip.md`) against the iOS code: every token and copy key the spec names, its reference value, and where the iOS code uses it. The snapshot step is the lead's: macOS CI records `ios/build/snapshots/account/<surface>-<state>-<light|dark>.png` (AccountSnapshotTests: every state in light, the primary state also in dark), then `tools/sidebyside.py` makes `design/verification/invite.appclip.png` next to the reference image(s) below.

Reference image(s): `references/auto/retro/web/retro.app-web-copy-excerpts.txt`, `references/auto/retro/web/retro.app-u-nathan-iphone.png`, `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt`

Snapshots (CI, `ios/build/snapshots/account/`): `invite.appclip-default-light.png`, `invite.appclip-default-dark.png`, `invite.appclip-opening-light.png`, `invite.appclip-no-cover-light.png`, `invite.appclip-joined-light.png`, `invite.appclip-joined-dark.png`, `invite.appclip-loading-light.png`, `invite.appclip-unavailable-light.png`, `invite.appclip-not-found-light.png`, `invite.appclip-rate-limited-light.png`, `invite.appclip-error-light.png`, `invite.appclip-offline-light.png`, `invite.appclip-full-light.png`

**Summary: 58 matched · 1 approximated · 0 not matched · 7 not applicable on iOS / owner / another pass.**


## Structure

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| n/a | `invite.appclip.card.subtitle` | “Photos with friends and family” (SOURCED) | App Store Connect card subtitle (owner enters the copy) |
| n/a | `invite.appclip.card.action` | “View” (VERIFIED) | App Store Connect card verb (owner) |
| n/a | `invite.appclip.layout.messagesCard` | header: the App Clip card image (App Store Connect header image) — no text in the image; title: App Store Connect card title (≤ 30 characters); subtitle: cop… (PLATFORM) | App Store Connect App Clip experience (owner), not app code |
| n/a | `invite.appclip.layout.cardLimits` | headerImage: 1800×1200 px, no transparency, no text; titleMaxCharacters: 30; subtitleMaxCharacters: 56; actions: Open \| View \| Play (one of the preset verbs) (PLATFORM) | App Store Connect card limits (owner) |
| matched | `invite.web.invitedBy` | “{first_name} Invited You!” (SOURCED) | `Copy.inviteWebInvitedBy` in InvitePreviewView.swift |
| matched | `invite.web.body` | “See what {group_name} is up to this week.” (SOURCED) | `Copy.inviteWebBody` in InvitePreviewView.swift |
| matched | `invite.web.cta` | “Let's go” (SOURCED) | `Copy.inviteWebCta` in InvitePreviewView.swift |
| matched | `invite.appclip.joined.title` | “Welcome to {group_name}!” (SOURCED) | `Copy.inviteAppclipJoinedTitle` in InvitePreviewView.swift |
| matched | `invite.appclip.joined.body` | “Get the full app to see everyone's photos and your daily invitation.” (SOURCED) | `Copy.inviteAppclipJoinedBody` in InvitePreviewView.swift |
| matched | `invite.appclip.layout.fullAppOverlay` | position: bottom; when: after join_group succeeds (a natural pause: the 'Welcome to {group_name}!' state), never before; api: SKOverlay(configuration: SKOver… (PLATFORM) | `Tokens.Layouts.InviteAppclipLayoutFullAppOverlay` in InviteClipApp.swift |

## States

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `color.global.backgroundDeep` | #000000 (SOURCED) | `Tokens.Colors.globalBackgroundDeep` in BackdropCard.swift, FullBleedMediaPage.swift, GroupScreen.swift, InvitePreviewView.swift … |
| matched | `invite.web.notFound.title` | “Couldn't find invite” (SOURCED) | `Copy.inviteWebNotFoundTitle` in InvitePreviewView.swift |
| matched | `invite.appclip.full.title` | “Couldn't join” (SOURCED) | `Copy.inviteAppclipFullTitle` in InvitePreviewView.swift |
| matched | `invite.appclip.full.body` | “This group is full.” (SOURCED) | `Copy.inviteAppclipFullBody` in InvitePreviewView.swift |
| matched | `invite.web.error.title` | “Something went wrong” (SOURCED) | `Copy.inviteWebErrorTitle` in InvitePreviewView.swift |
| matched | `invite.appclip.offline.body` | “Could not connect. Check your connection and try again.” (SOURCED) | `Copy.inviteAppclipOfflineBody` in InvitePreviewView.swift |
| matched | `invite.web.error.retry` | “Try again” (SOURCED) | `Copy.inviteWebErrorRetry` in InvitePreviewView.swift |

## Motion

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `duration.global.fade` | 150 ms (SOURCED) | `Tokens.Durations.globalFade` in ComponentSupport.swift, GroupCreateScreen.swift, GroupInviteScreen.swift, PaywallScreen.swift … |
| matched | `invite.web.duration.pill` | 300 ms (SOURCED) | `Tokens.Durations.inviteWebDurationPill` in InvitePreviewView.swift |

## Haptics

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| n/a | `haptic.global.tap` | ios: none; android: VIRTUAL_KEY (PLATFORM) | Android only — iOS presses play no haptic |
| matched | `haptic.global.success` | ios: notification.success; android: CONFIRM (PLATFORM) | `Tokens.Haptics.globalSuccess` in AgeGateForm.swift, CodeScreen.swift, GroupCreateScreen.swift, InviteClipApp.swift … |
| matched | `haptic.global.error` | ios: notification.error; android: REJECT (PLATFORM) | `Tokens.Haptics.globalError` in AgeGateForm.swift, BlockConfirmation.swift, CodeScreen.swift, GroupCreateScreen.swift … |

## Accessibility

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `invite.web.members.title` | “Members of {group_name}” (VERIFIED) | `Copy.inviteWebMembersTitle` in InvitePreviewView.swift |

## Data & actions

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| n/a | `invite.appclip.layout.association` | aasaAppClips: appclips.apps = [TEAM_ID.BUNDLE_ID.Clip]; aasaAppLinks: applinks.details[].components = [{"/": "/i/*"}] for the full app; invocation: Safari Ap… (VERIFIED) | AASA `appclips` entry and advanced experience, generated by web/src/wellKnown.ts from config/app.json |

## Invite card (invite.web mobile)

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| n/a | `invite.web.size.breakpoint` | 840 pt (SOURCED) | web only (the clip is the mobile card) |
| matched | `color.global.background` | light: #FFFFFF; dark: #000000 (SOURCED) | `Tokens.Colors.globalBackground` in AccountGroupedRows.swift, GroupCreateScreen.swift, GroupInviteScreen.swift, GroupScreen.swift … |
| matched | `invite.web.size.cardInset` | 6 pt (SOURCED) | `Tokens.Sizes.inviteWebSizeCardInset` in InvitePreviewView.swift |
| matched | `invite.web.radius.card` | 36 pt (SOURCED) | `Tokens.Radii.inviteWebRadiusCard` in InvitePreviewView.swift |
| matched | `invite.web.layout.backdrop` | blurSigmaToWidth: 0.08; dim: color.global.backdropDim; source: the group cover photo, object-fit cover, extended 3σ past the card so the blur has no faded edge (SOURCED) | `Tokens.Layouts.InviteWebLayoutBackdrop` in InvitePreviewView.swift |
| matched | `color.global.backdropDim` | #00000039 (SOURCED) | `Tokens.Layouts.globalBackdropDim` in BackdropCard.swift, InvitePreviewView.swift |
| matched | `size.global.backdropBlur` | 1.8 pt (SOURCED) | `Tokens.Layouts.globalBackdropBlur` in BackdropCard.swift |
| approximated | `invite.web.size.avatar` | 112 pt (SOURCED) | `Tokens.Sizes.inviteWebSizeAvatar` in InvitePreviewView.swift — size exact; position centred above the text block (spec Gap: Retro's capture lost the photo) |
| matched | `invite.web.color.avatarPlaceholder` | #EDEDED (SOURCED) | `Tokens.Colors.inviteWebColorAvatarPlaceholder` in InvitePreviewView.swift |
| matched | `invite.web.invitedFallback` | “You're Invited!” (SOURCED) | `Copy.inviteWebInvitedFallback` in InvitePreviewView.swift |
| matched | `font.global.display` | ios: system-serif; android: serif (PLATFORM) | `Tokens.Fonts.globalDisplay` in InvitePreviewView.swift, PhoneScreen.swift, TextRoles.swift |
| matched | `fontSize.global.displayMedium` | 32 pt (SOURCED) | `Tokens.FontSizes.globalDisplayMedium` in InvitePreviewView.swift, TextRoles.swift |
| matched | `invite.web.lineHeight.headline` | 32 pt (SOURCED) | `Tokens.LineHeights.inviteWebLineHeightHeadline` in InvitePreviewView.swift |
| matched | `invite.web.size.textMaxWidth` | 260 pt (SOURCED) | `Tokens.Sizes.inviteWebSizeTextMaxWidth` in InvitePreviewView.swift |
| matched | `invite.web.size.headlineToBody` | 16 pt (SOURCED) | `Tokens.Sizes.inviteWebSizeHeadlineToBody` in InvitePreviewView.swift |
| matched | `invite.web.fontSize.body` | 14 pt (SOURCED) | `Tokens.FontSizes.inviteWebFontSizeBody` in InvitePreviewView.swift |
| matched | `invite.web.lineHeight.body` | 19.6 pt (SOURCED) | `Tokens.LineHeights.inviteWebLineHeightBody` in InvitePreviewView.swift |
| matched | `invite.web.letterSpacing.body` | -0.4 pt (SOURCED) | `Tokens.Tracking.inviteWebLetterSpacingBody` in InvitePreviewView.swift |
| matched | `invite.web.color.body` | #FFFFFF9E (SOURCED) | `Tokens.Colors.inviteWebColorBody` in InvitePreviewView.swift |
| matched | `size.global.avatarSmall` | 22.6 pt (SOURCED) | `Tokens.Sizes.globalAvatarSmall` in Avatar.swift, GroupScreen.swift, GroupsHomeScreen.swift |
| matched | `size.global.avatarStackOverlap` | 3 pt (SOURCED) | `Tokens.Sizes.globalAvatarStackOverlap` in Avatar.swift, GroupsHomeScreen.swift |
| matched | `invite.web.size.bodyToPill` | 38 pt (SOURCED) | `Tokens.Sizes.inviteWebSizeBodyToPill` in InvitePreviewView.swift |
| matched | `invite.web.size.pillHeight` | 56 pt (SOURCED) | `Tokens.Sizes.inviteWebSizePillHeight` in InvitePreviewView.swift |
| matched | `invite.web.size.pillInset` | 38 pt (SOURCED) | `Tokens.Sizes.inviteWebSizePillInset` in InvitePreviewView.swift |
| matched | `invite.web.color.pill` | #FFFFFF33 (SOURCED) | `Tokens.Colors.inviteWebColorPill` in InvitePreviewView.swift |
| matched | `invite.web.color.pillHover` | #FFFFFF4D (SOURCED) | `Tokens.Colors.inviteWebColorPillHover` in InvitePreviewView.swift |
| matched | `invite.web.easing.pill` | x1: 0.25; y1: 0.1; x2: 0.25; y2: 1 (SOURCED) | `Tokens.Easings.inviteWebEasingPill` in InvitePreviewView.swift |
| matched | `invite.web.fontSize.pill` | 16 pt (SOURCED) | `Tokens.FontSizes.inviteWebFontSizePill` in InvitePreviewView.swift |
| matched | `invite.web.fontWeight.pill` | semibold (SOURCED) | `Tokens.FontWeights.inviteWebFontWeightPill` in InvitePreviewView.swift |
| matched | `invite.web.opening` | “Opening…” (SOURCED) | `Copy.inviteWebOpening` in InvitePreviewView.swift |
| matched | `invite.web.opacity.pillDisabled` | 0.75 (SOURCED) | `Tokens.Opacities.inviteWebOpacityPillDisabled` in InvitePreviewView.swift |
| matched | `invite.web.size.pillToFooter` | 20 pt (SOURCED) | `Tokens.Sizes.inviteWebSizePillToFooter` in InvitePreviewView.swift |
| matched | `invite.web.footer.terms` | “Terms” (SOURCED) | `Copy.inviteWebFooterTerms` in InvitePreviewView.swift |
| matched | `invite.web.footer.privacy` | “Privacy” (SOURCED) | `Copy.inviteWebFooterPrivacy` in InvitePreviewView.swift |
| matched | `invite.web.fontSize.footer` | 8 pt (SOURCED) | `Tokens.FontSizes.inviteWebFontSizeFooter` in InvitePreviewView.swift |
| matched | `invite.web.size.footerMargin` | 18 pt (SOURCED) | `Tokens.Sizes.inviteWebSizeFooterMargin` in InvitePreviewView.swift |
| matched | `invite.web.cover.alt` | “{group_name} cover” (VERIFIED) | `Copy.inviteWebCoverAlt` in InvitePreviewView.swift |
| matched | `invite.web.avatar.alt` | “{first_name}” (VERIFIED) | `Copy.inviteWebAvatarAlt` in InvitePreviewView.swift |
| matched | `invite.web.unavailable.title` | “This link no longer works” (SOURCED) | `Copy.inviteWebUnavailableTitle` in InvitePreviewView.swift |
| matched | `invite.web.unavailable.body` | “Contact the sender for a new link.” (SOURCED) | `Copy.inviteWebUnavailableBody` in InvitePreviewView.swift |
| matched | `invite.web.error.body` | “There was a problem. Please try again.” (SOURCED) | `Copy.inviteWebErrorBody` in InvitePreviewView.swift |
| matched | `invite.web.rateLimited.body` | “You've tried too many times. Please try again later.” (SOURCED) | `Copy.inviteWebRateLimitedBody` in InvitePreviewView.swift |

## Notes

- Avatar position (spec Gap): centred in the space above the text block, as the web page.
- No-photo avatar: the `invite.web.color.avatarPlaceholder` circle (initials fallback is a C-23 Gap).
- Light status bar over the card: `.mediaStatusBar()` while the card is on top; the sign-in screens follow the system appearance.
- The card's photos come from `preview.json` URLs (signed on the web origin); the snapshots use sample photos.
