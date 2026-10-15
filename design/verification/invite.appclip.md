# Verification — `invite.appclip` (iOS)

Invite preview, join sheet, code step and join — `ios/AppClip/Sources/InviteClipApp.swift`, `Features/Account/Shared/InvitePreview/`, in-app `Screens/InviteScreen.swift`.

Checklist written from the spec (`design/surfaces/invite.appclip.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/account/<surface>-<state>.png` (AccountSnapshotTests), then `tools/sidebyside.py` makes `design/verification/invite.appclip.png` next to the reference image(s) below. The "what the snapshot shows" column states what the code draws for that value; it is to be confirmed on the image.

Reference image(s): `references/auto/partiful/store/partiful-store-04.png`, `references/auto/partiful/web/pf-web-public-light-rsvp-sheet.png`, `references/auto/partiful/js/partiful-web-js-excerpt-2026-10-15.js`

Snapshots (CI): `invite.appclip-join-sheet.png`, `invite.appclip-loading.png`, `invite.appclip-valid.png`, `invite.appclip-unavailable.png`, `invite.appclip-not-found.png`, `invite.appclip-rate-limited.png`, `invite.appclip-error.png`, `invite.appclip-offline.png`, `invite.appclip-full.png`

**Summary: 32 matched · 2 approximated · 0 not matched (BLOCKED or not buildable) · 6 not applicable on iOS / placed by another pass.**

| status | kind | token / copy | reference value | element | what the snapshot shows (iOS implementation) |
|---|---|---|---|---|---|
| n/a | copy | `invite.appclip.card.subtitle` | “Make memories” (SOURCED) |  | App Clip card metadata, set in App Store Connect (not in code) |
| n/a | copy | `invite.appclip.card.action` | “View” (SOURCED) |  | App Clip card metadata, set in App Store Connect (not in code) |
| n/a | token | `invite.appclip.layout.cardLimits` | headerImage: 1800×1200 px, no transparency, no text; titleMaxCharacters: 30; subtitleMaxCharacters: 56 (PLATFORM) | App Clip card metadata limits (App Store Connect) | App Store Connect App Clip card limits (owner upload) |
| n/a | token | `invite.appclip.layout.messagesCard` | header: cover on a blurred backdrop with a domain chip; footer: clip icon, title, subtitle, action button (SOURCED) | App Clip card in Messages (drawn by iOS) | drawn by iOS Messages from the page metadata (invite.web pass) |
| matched | copy | `invite.appclip.join` | “Join” (VERIFIED) |  | `Copy.…inviteAppclipJoin` in InvitePreviewView.swift |
| n/a | copy | `invite.web.getApp` | “Get the app” (VERIFIED) |  | web page button (invite.web pass); the clip offers the full app through SKOverlay |
| matched | copy | `invite.appclip.sheet.name` | “Your Name” (VERIFIED) |  | `Copy.…inviteAppclipSheetName` in InviteJoinSheet.swift |
| matched | copy | `invite.appclip.sheet.phone` | “Phone Number” (VERIFIED) |  | `Copy.…inviteAppclipSheetPhone` in InviteJoinSheet.swift |
| matched | copy | `invite.appclip.sheet.helper` | “Just for group updates. No spam.” (VERIFIED) |  | `Copy.…inviteAppclipSheetHelper` in InviteJoinSheet.swift |
| matched | copy | `invite.appclip.sheet.cancel` | “Cancel” (VERIFIED) |  | `Copy.…inviteAppclipSheetCancel` in InviteJoinSheet.swift |
| matched | copy | `invite.appclip.sheet.continue` | “Continue” (VERIFIED) |  | `Copy.…inviteAppclipSheetContinue` in InviteJoinSheet.swift |
| matched | token | `invite.appclip.layout.fullAppOverlay` | position: bottom; when: after join_group succeeds (a natural pause); never before the person has joined (PLATFORM) | offer of the full app over the App Clip (SKOverlay.AppClipConfiguration) | `Tokens.…InviteAppclipLayoutFullAppOverlay` in InviteClipApp.swift |
| matched | token | `invite.web.dimension.button.large.height` | 48 pt (VERIFIED) | large button height (gate card action, error retry) | `Tokens.…inviteWebDimensionButtonLargeHeight` in InviteJoinSheet.swift, InvitePreviewView.swift |
| matched | token | `invite.web.dimension.button.large.paddingH` | 24 pt (VERIFIED) | large button horizontal padding | `Tokens.…inviteWebDimensionButtonLargePaddingH` in InviteJoinSheet.swift, InvitePreviewView.swift |
| matched | token | `invite.web.radius.button.large` | 4 pt (VERIFIED) | large button corners | `Tokens.…inviteWebRadiusButtonLarge` in InvitePreviewView.swift |
| matched | token | `invite.web.fontWeight.button` | semibold (VERIFIED) | button and link labels (600) | `Tokens.…inviteWebFontWeightButton` in InvitePreviewView.swift |
| matched | token | `invite.appclip.fontSize.sheetInput` | 24 pt (VERIFIED) | join sheet text input value and placeholder | `Tokens.…inviteAppclipFontSizeSheetInput` in InviteJoinSheet.swift |
| matched | token | `invite.appclip.opacity.sheetPlaceholder.light` | 0.3 (VERIFIED) | join sheet placeholder alpha on light themes | `Tokens.…inviteAppclipOpacitySheetPlaceholderLight` in InviteTheme.swift |
| matched | token | `invite.appclip.opacity.sheetPlaceholder.dark` | 0.4 (VERIFIED) | join sheet placeholder alpha on dark themes | `Tokens.…inviteAppclipOpacitySheetPlaceholderDark` in InviteTheme.swift |
| matched | token | `invite.appclip.fontSize.sheetHelper` | 14.4 pt (VERIFIED) | join sheet helper line ('Just for group updates. No spam.') | `Tokens.…inviteAppclipFontSizeSheetHelper` in InviteJoinSheet.swift |
| matched | token | `invite.appclip.opacity.sheetHelper.light` | 0.3 (VERIFIED) | join sheet helper alpha on light themes | `Tokens.…inviteAppclipOpacitySheetHelperLight` in InviteTheme.swift |
| matched | token | `invite.appclip.opacity.sheetHelper.dark` | 0.4 (VERIFIED) | join sheet helper alpha on dark themes | `Tokens.…inviteAppclipOpacitySheetHelperDark` in InviteTheme.swift |
| matched | token | `invite.web.fontSize.body` | 16 pt (VERIFIED) | body text ('Invited by' row, initials, names, footer link, large button label) | `Tokens.…inviteWebFontSizeBody` in InvitePreviewView.swift |
| matched | copy | `invite.web.state.glyph` | “😬” (VERIFIED) |  | `Copy.…inviteWebStateGlyph` in InvitePreviewView.swift |
| matched | copy | `invite.web.unavailable.title` | “This link no longer works” (VERIFIED) |  | `Copy.…inviteWebUnavailableTitle` in InvitePreviewView.swift |
| matched | copy | `invite.web.unavailable.body` | “Ask a member for another link” (VERIFIED) |  | `Copy.…inviteWebUnavailableBody` in InvitePreviewView.swift |
| matched | copy | `invite.web.notFound.title` | “Invite not found” (VERIFIED) |  | `Copy.…inviteWebNotFoundTitle` in InvitePreviewView.swift |
| matched | copy | `invite.web.error.title` | “Something went wrong” (VERIFIED) |  | `Copy.…inviteWebErrorTitle` in InvitePreviewView.swift |
| matched | copy | `invite.web.error.body` | “Please try again.” (VERIFIED) |  | `Copy.…inviteWebErrorBody` in InvitePreviewView.swift |
| matched | copy | `invite.web.error.retry` | “Try again” (VERIFIED) |  | `Copy.…inviteWebErrorRetry` in InvitePreviewView.swift |
| matched | copy | `invite.appclip.offline.body` | “This usually occurs due to a poor internet connection - try again in a few minutes” (VERIFIED) |  | `Copy.…inviteAppclipOfflineBody` in InvitePreviewView.swift |
| matched | copy | `invite.appclip.full.glyph` | “😭” (VERIFIED) |  | `Copy.…inviteAppclipFullGlyph` in InvitePreviewView.swift |
| matched | copy | `invite.appclip.full.glyphLabel` | “Loudly crying face” (VERIFIED) |  | `Copy.…inviteAppclipFullGlyphLabel` in InvitePreviewView.swift |
| matched | copy | `invite.appclip.full.title` | “Couldn't join” (VERIFIED) |  | `Copy.…inviteAppclipFullTitle` in InvitePreviewView.swift |
| matched | copy | `invite.appclip.full.body` | “Group is full” (VERIFIED) |  | `Copy.…inviteAppclipFullBody` in InvitePreviewView.swift |
| matched | token | `invite.web.opacity.button.active` | 0.4 (VERIFIED) | every button: opacity while pressed | `Tokens.…inviteWebOpacityButtonActive` in InvitePreviewView.swift |
| matched | token | `invite.web.duration.button.opacity` | 100 ms (VERIFIED) | button opacity transition (press feedback) | `Tokens.…inviteWebDurationButtonOpacity` in InvitePreviewView.swift |
| n/a | token | `invite.appclip.layout.association` | aasaAppClips: appclips.apps = [TEAM_ID.BUNDLE_ID.Clip]; aasaAppLinks: applinks.details[0].components: exclude /i/*/* (page sub-resources), then /i/*; banner:… (VERIFIED) | App Clip / universal link / App Link association | AASA / web banner (invite.web + infrastructure); the clip reads the invocation URL |

## Approximations

- Preview title size: port of the web title-fit estimator (`InviteTitleFit`) with the invite.web tokens.
- The installed app has no preview.json without the domain (BLOCKED in config/app.json) and falls back to the `invite_preview` RPC text (no images, standard theme).
