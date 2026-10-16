# `invite.appclip` — iOS App Clip: invite preview, sign-in, join

Visual reference: Retro's `/u/[username]` page and its **App Clip card** (`io.lonepalm.Retro.Clip`, `app-clip-display=card`;
RP §7) — the clip shows the same invite card as `invite.web` (mobile), natively. Mechanics: Apple HIG (App Clips:
card limits, full-app overlay after the task). Sign-in reuses the onboarding form screens (`auth.phone` B, `auth.code`,
`auth.agegate`, `auth.profile` step 1). Tokens: `invite.appclip.*`, `invite.web.*` (card) + `global.*`. Copy:
`invite.appclip.*`, `invite.web.*`.

## References

| id | file / URL | used for |
|---|---|---|
| WEBX | `references/auto/retro/web/retro.app-web-copy-excerpts.txt` | `apple-itunes-app … app-clip-display=card`; "Let's go" → `appclip.apple.com/id?p=io.lonepalm.Retro.Clip&…` |
| WEBU | `references/auto/retro/web/retro.app-u-nathan-iphone.png` | the card drawn by the clip |
| HIG | https://developer.apple.com/design/human-interface-guidelines/app-clips | card text limits, preset verbs, SKOverlay after the task |
| APK-S | `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt` | `onboarding_post_invite_welcome_title` ("Welcome to Retro"), error patterns |

## Structure

1. **App Clip card** (system, from Safari / Messages / QR): header image (App Store Connect, no text), title (≤ 30),
   subtitle `invite.appclip.card.subtitle`, action `invite.appclip.card.action` (`invite.appclip.layout.messagesCard`,
   `invite.appclip.layout.cardLimits`).
2. **Invite card** (first screen of the clip): exactly `invite.web` mobile (card inset, radius, blurred cover, avatar,
   headline `invite.web.invitedBy`, line `invite.web.body`, member stack, pill `invite.web.cta`), drawn in SwiftUI with the
   `invite.web.*` tokens; the footer links (Terms, Privacy) open `SFSafariViewController`. Fed by
   `GET /i/:token/preview.json`. The page around the card is #FFFFFF (Retro's web page; the clip shows the same page).
3. "Let's go" → **sign-in**: `auth.phone` state B → `auth.code` → `auth.agegate` (new accounts) → `auth.profile` step 1
   (name; the photo step is left to the full app) — pushed in the clip's `NavigationStack`, unchanged.
4. **Join**: `join_group(token)`; while it runs the last form capsule stays busy (C-05).
5. **Joined**: the invite card returns with headline `invite.appclip.joined.title` ({group_name}), line
   `invite.appclip.joined.body`, no pill; the full-app overlay (`SKOverlay`, `invite.appclip.layout.fullAppOverlay`)
   rises at the bottom.

## Elements

| element | tokens / component | copy | behaviour |
|---|---|---|---|
| card (system) | `invite.appclip.layout.messagesCard`, `.cardLimits` | `invite.appclip.card.action`, `.card.subtitle` | opens the clip with the invite URL |
| invite card | `invite.web.*` (mobile) | `invite.web.*` | as `invite.web` |
| sign-in screens | `auth.*` specs | `auth.*` | as those specs |
| joined state | invite card without pill | `invite.appclip.joined.title`, `.joined.body` | SKOverlay once per launch |
| full-app overlay | `invite.appclip.layout.fullAppOverlay` (system) | system text | App Store install; the full app reads the invite token from the shared App Group container and finishes onboarding (photo, notifications, widget) |

## States

| state | design | copy |
|---|---|---|
| loading preview | invite card with `color.global.backgroundDeep` fill and the platform activity indicator centred (C-28, white) | — |
| link no longer works / not found | card states as `invite.web` (410 / 404) | `invite.web.unavailable.*` / `invite.web.notFound.title` |
| group full (`group_full`) | card: headline `invite.appclip.full.title`, line `invite.appclip.full.body`, no pill | `invite.appclip.full.*` |
| offline | card: headline `invite.web.error.title`, line `invite.appclip.offline.body`, pill `invite.web.error.retry` | — |
| error (other) | as `invite.web` 503 | `invite.web.error.*` |
| joined | joined state | `invite.appclip.joined.*` |
| permission-denied | not applicable (the clip asks no permission; notifications wait for the full app) | — |

## Motion

Card → sign-in: native push. Joined: cross-fade `duration.global.fade` (150 ms) of the card content; SKOverlay: system.
Pill background: as `invite.web` on press (`invite.web.duration.pill`). Reduce Motion: cross-fades.

## Haptics

Pill press → none (iOS; `haptic.global.tap` is Android-only). Joined → `haptic.global.success`; failed → `haptic.global.error`.

## Accessibility

- As `invite.web` (one header, the line, the pill as a button with its label); the member stack is one element labelled
  `invite.web.members.title`.
- Dynamic Type: headline `largeTitle` (32 pt base), line `subheadline`, pill `headline`. Contrast: as `invite.web`
  (photo-dependent on the backdrop; pill fill **1.80:1 FAIL** non-text).

## Data & actions

- `GET https://<domain>/i/<token>/preview.json` (signed image URLs from the web origin) — before sign-in.
- Sign-in: `signInWithOTP` / `verifyOTP` / `confirm_age` / profile update (docs/API.md §2). Join: `join_group(p_token)`
  (§6.1, §9.3; errors `invite_not_found`, `invite_revoked`, `invite_expired`, `group_full`).
- The token and the session are written to the App Group container so the full app continues without asking again.
- Association: `invite.appclip.layout.association` (AASA `appclips` + advanced experience for `https://<domain>/i/`).

## Platform notes

- App Clip size limit and no background push; notifications, widget and photo step happen in the full app.
- Android has no App Clip: `invite.web` → Play (Install Referrer carries the token).

## Do-not-copy

- Retro's App Clip artwork and name; repeated install prompts (one overlay after the task only).

## Gaps

| item | status | smallest capture |
|---|---|---|
| Retro's App Clip screens | not captured (only its link and card meta) | screenshots of Retro's App Clip opened from a `/u/` link on an iPhone without Retro |
| card title / header image | owner (App Store Connect) | app name and art |
