# `invite.appclip` — iOS App Clip: the invite preview, then join

References: **Partiful** (App Clip card, invite page, RSVP sheet) + **Apple HIG / App Clips** (`docs/SURFACES.md`).
Research: `design/research/wrapped-tribute-partiful.md` §5–§6; platform: `docs/PLATFORM_CONSTRAINTS.md` §3.
Tokens: `design/tokens/invite.json` (`invite.appclip.*`, and every `invite.web.*` token for the preview itself).
Copy: `design/copy/invite.json` (`invite.appclip.*`, and the `invite.web.*` strings named below).
Code: `ios/AppClip/Sources/InviteClipApp.swift` (container; fills `InviteClipContainer`).

## References

| id | file / URL | used for |
|---|---|---|
| C1 | `references/auto/partiful/store/partiful-store-04.png` (crop y 1400–2688) | App Clip card in Messages: header image (poster on blurred backdrop) with domain chip; clip icon, title "Book Club", subtitle "Make memories", action "View" |
| C2 | https://partiful.com/.well-known/apple-app-site-association (fetched 2026-10-15) | `appclips.apps` entry + `applinks` components with an exclude rule — same shape as ours |
| C3 | P1–P3 page HTML: `<meta name="apple-itunes-app" content="app-id=…, app-clip-bundle-id=…">` | banner/card on the invite page |
| P4 | `references/auto/partiful/web/pf-web-public-light-rsvp-sheet.png`, `pf-web-public-dark-rsvp-sheet.png` (+ computed styles) | join sheet: name and phone fields, helper line, Cancel / Continue |
| W | `design/surfaces/invite.web.md` and its references (P3, P1, P2, NF) | the preview inside the clip (same anatomy, tokens and copy) |
| JS | `references/auto/partiful/js/partiful-web-js-excerpt-2026-10-15.js` [B], [E], [I], [J], [K] | state glyphs and strings: not found, capacity ("Couldn't RSVP" / "Event is full"), offline, "Join" |
| HIG | https://developer.apple.com/design/human-interface-guidelines/app-clips ; https://developer.apple.com/documentation/appclip | card limits, invocation, SKOverlay, ephemeral notifications |

Partiful's App Clip screens themselves were **not found** (App Clips cannot be launched in the capture environment).

## Structure

1. **App Clip card** (drawn by iOS — Safari banner/card from the page's `apple-itunes-app` meta, or Messages):
   header image, title, subtitle `invite.appclip.card.subtitle`, action `invite.appclip.card.action` ("View").
   Limits `invite.appclip.layout.cardLimits` (1800×1200 image without text, title ≤ 30, subtitle ≤ 56 characters).
   Card anatomy `invite.appclip.layout.messagesCard`. Values are entered in App Store Connect (default experience +
   advanced experience for the URL prefix `https://<domain>/i/`, `docs/OWNER_SETUP.md` §1.5).
2. **Preview** — the `invite.web` page anatomy rendered natively, top to bottom: title (auto-fit), cover, "Invited by"
   row, Member List (avatars, View all → member rows), members-only card. Every element, token and copy key is in the
   `invite.web` Elements table; the only change is the card's action:
   - card button label `invite.appclip.join` ("Join", Partiful's RSVP-control label) instead of `invite.web.getApp`;
   - no footer and no "Get the app" link (the clip is the app's stand-in; Apple: no install requirement to finish a task).
3. **Join sheet** (Partiful's RSVP sheet P4 without its Going / Maybe / Can't Go choices, which have no counterpart —
   joining is one action): name field placeholder `invite.appclip.sheet.name`, phone field placeholder
   `invite.appclip.sheet.phone`, helper `invite.appclip.sheet.helper`, actions `invite.appclip.sheet.cancel` /
   `invite.appclip.sheet.continue`. Then the SMS code step of `auth.code` (Yope), then `join_group`.
4. **After joining**: offer the full app with `SKOverlay.AppClipConfiguration` per `invite.appclip.layout.fullAppOverlay`
   (position bottom, only after the join succeeded).

## Elements

| element | tokens | copy | behaviour |
|---|---|---|---|
| card (iOS) | `invite.appclip.layout.messagesCard`, `invite.appclip.layout.cardLimits` | `invite.appclip.card.subtitle`, `invite.appclip.card.action` | App Store Connect metadata; the header image is the owner's asset (no text) |
| preview | all `invite.web.*` layout, type, colour and theme tokens | `invite.web.*` as on the web | theme = mean colour of the cover (`preview.json` → `theme`) |
| join button | `invite.web.dimension.button.large.height` / `.paddingH`, `invite.web.radius.button.large`, `invite.web.color.button.filled.*`, `invite.web.fontWeight.button` | `invite.appclip.join` | opens the join sheet |
| name / phone fields | `invite.appclip.fontSize.sheetInput`, `invite.appclip.opacity.sheetPlaceholder.light` / `.dark` | `invite.appclip.sheet.name`, `invite.appclip.sheet.phone` | phone uses `textContentType(.telephoneNumber)`; the code step autofills `.oneTimeCode` (`auth.code`) |
| helper | `invite.appclip.fontSize.sheetHelper`, `invite.appclip.opacity.sheetHelper.light` / `.dark` | `invite.appclip.sheet.helper` | — |
| Cancel / Continue | `invite.web.fontSize.body`, `invite.web.fontWeight.button`; Continue = filled large button | `invite.appclip.sheet.cancel`, `invite.appclip.sheet.continue` | Cancel closes the sheet |
| full-app offer | `invite.appclip.layout.fullAppOverlay` | — (system UI) | `fullAppOverlay(isPresented:position:)` in `InviteClipApp.swift` |

## States

| state | when | design | copy |
|---|---|---|---|
| loading | fetching `preview.json` | platform `ProgressView` (Apple HIG; Partiful's clip not observable) | — |
| valid | 200 | preview | as above |
| link no longer works | 410 | `invite.web` state layout | `invite.web.state.glyph`, `invite.web.unavailable.title`, `invite.web.unavailable.body` |
| not found | 404 (or a launch without a valid invite URL) | `invite.web` state layout | `invite.web.state.glyph`, `invite.web.notFound.title` |
| error | 5xx | state layout + retry button | `invite.web.error.title`, `invite.web.error.body`, `invite.web.error.retry` |
| offline | no connection | state layout + retry button | `invite.web.error.title`, `invite.appclip.offline.body`, `invite.web.error.retry` |
| group full | `join_group` → `group_full` | state layout, glyph `invite.appclip.full.glyph` (label `invite.appclip.full.glyphLabel`) | `invite.appclip.full.title`, `invite.appclip.full.body` |
| invite expired/revoked at join time | `join_group` → `invite_expired` / `invite_revoked` | as "link no longer works" | as above |
| permission-denied | ephemeral notifications are the only permission (`NSAppClipRequestEphemeralUserNotification`); none is required to join | — | — |

## Motion

Sheet presentation and dismissal are the platform's (`.sheet`); button press feedback per `invite.web` Motion (opacity
`invite.web.opacity.button.active`, `invite.web.duration.button.opacity`). Reduce Motion: platform behaviour.

## Haptics

None sourced (Partiful's web page has none; its clip was not observable).

## Accessibility

As `invite.web` (labels, glyph names, contrast results in `design/verification/invite.web.md`). Dynamic Type scaling
follows the foundations' text-role mechanism (`design/tokens/README.md` → "A text role"); Partiful gives no evidence for
native scaling. The join sheet fields have visible placeholders and accessibility labels equal to them.

## Data & actions

1. Invocation URL `https://<domain>/i/<token>` (`NSUserActivityTypeBrowsingWeb`; `DeepLinkParser`) → token.
2. `GET https://<domain>/i/<token>/preview.json` (web service): `{group_name, group_kind, inviter_first_name,
   cover:{url,width,height}|null, members:[{first_name, avatar_url|null}], theme:{background, scheme}}`; images are on the
   web origin, re-encoded, valid while the invite is (cache ≤ 60 s). HTTP 404 / 410 / 429 / 5xx map to the states above.
3. Phone OTP (`docs/API.md` §2), then `join_group(p_token)` (§6.1); errors `group_full`, `invite_expired`,
   `invite_revoked`.
4. Hand-off: store the session and the joined group id in the shared App Group / keychain
   (`docs/PLATFORM_CONSTRAINTS.md` §3); the full app also receives the invocation URL.
5. Association: AASA `appclips.apps = ["TEAM_ID.BUNDLE_ID.Clip"]`, applinks `/i/*` (sub-resources `/i/*/*` excluded) —
   generated by the web service from `config/app.json` (`invite.appclip.layout.association`).

## Platform notes

- iOS 17+, ≤ 100 MB uncompressed (digital invocations only) — `docs/PLATFORM_CONSTRAINTS.md` §3.
- No Photos, Contacts, background modes or in-app purchase in the clip; ephemeral notifications only (8 h).
- Android has no App Clip equivalent (Play Instant ended December 2025): the `invite.web` page + Play install referrer.

## Do-not-copy

Partiful's RSVP choice buttons (Going / Maybe / Can't Go) and attendee count field ("1 attendee"), "+Post a comment",
"Follow event organizer to stay in the loop", guest counts — joining is one action and nothing is counted.

## Gaps

| gap | handled as | owner capture / decision |
|---|---|---|
| Partiful's App Clip screens (after "View") | invite page anatomy + RSVP sheet | research §8.3: a 15-s iPhone recording of tapping a Partiful link in Messages (card → clip) |
| Whether Messages builds the card from the page's Open Graph tags or only from App Store Connect | both are provided (og tags on the page; ASC metadata) | same capture |
| Card header image, title | owner assets in App Store Connect | `docs/OWNER_SETUP.md` §1.5 |
| App name in the clip | `{app_name}` strings BLOCKED | owner decision 0.1 |
