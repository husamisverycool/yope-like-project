# `invite.web` — invite link page (before install; Android and desktop fallback)

Visual reference: **Retro's `/u/[username]` invite page** (inventory #35; retro.app CSS and Playwright captures, RP §7):
mobile — a rounded card filled with a blurred photo, the inviter's 112-pt avatar, a serif headline "Nathan Invited
You!", a 62 %-white line, a translucent-white 56-pt pill "Let's go" (busy: "Opening Retro..."), a tiny white footer;
desktop — white page, 48-px serif headline, grey line, QR code; link previews — a 600 × 600 image (blurred colour field,
round avatar, serif name, domain). On iOS "Let's go" opens Retro's **App Clip** card. Retro's web has **no dark
scheme** (RP §7): the page is the same in both appearances. Tokens: `design/tokens/invite.json` (`invite.web.*`) +
`global.*`. Copy: `design/copy/invite.json` (`invite.web.*`).

This app's link joins a **group**: the card shows the group's cover as the backdrop, the inviter's avatar and name, the
group in the line under the headline and the members' avatars (first names only in their alt text; no counts, SPEC_FLAGS T7).

## References

| id | file | used for |
|---|---|---|
| WEBU | `references/auto/retro/web/retro.app-u-nathan-iphone.png` (390 CSS px at 3×), `…-pixel7.png` | card inset 6 / radius ≈ 36, pill 302 × 56, text positions; photo blocked by ORB in the capture |
| WEBD | `references/auto/retro/web/retro.app-u-nathan-desktop.png` | desktop layout (QR + headline + line) |
| CSS | `references/auto/retro/web/retro.app-5bff8a0be69f7ec7.css` (same rules in the other build CSS files) | `.page_mobileProfilePageContent`, `.page_invitePillButton`, `.page_mobileInviteFooter`, `.page_newProfilePageContent`, `.page_profilePicture`, breakpoint 840 |
| WEBX | `references/auto/retro/web/retro.app-web-copy-excerpts.txt` | copy, meta tags (`apple-itunes-app … app-clip-display=card`), OG title / description, computed styles |
| OG | `references/auto/retro/web/retro.app-og-userogsquare-nathan.png` | 600 × 600 share image (`invite.web.layout.ogImage`) |
| BG | `references/auto/retro/web/retro.app-invite-background-bg2.jpeg` | Retro's blurred backdrop (a stock image; ours is the group cover — not copied) |

## Structure — mobile (viewport ≤ `invite.web.size.breakpoint` 840)

Page background #FFFFFF (`color.global.background` light value, both schemes — Retro's web has no dark scheme).

1. **Card**: inset `invite.web.size.cardInset` (6) from every viewport edge, corners `invite.web.radius.card` (36),
   full height; fill = the group cover blurred to a colour field (`invite.web.layout.backdrop`: Gaussian σ = 0.08 × the
   card width under `color.global.backdropDim`, the photo extended 3σ past the card; MERGE_DECISIONS L-6 — not the
   recap's `size.global.backdropBlur`); no cover → the inviter's avatar blurred the same way; neither →
   `color.global.backgroundDeep`. Content is a centred column (`text-align: center`).
2. **Avatar**: the inviter's photo (`invite_preview.inviter_avatar_path`, the invite creator's avatar), `invite.web.size.avatar` (112) circle, object-fit cover, placeholder
   `invite.web.color.avatarPlaceholder`; centred in the space above the text block (Retro's capture lost the image —
   position approximated, Gaps). No photo → C-23 initials fallback is a Gap; the placeholder circle shows.
3. **Text block**, anchored above the pill:
   - headline `invite.web.invitedBy` (or `invite.web.invitedFallback`): `font.global.displayNarrow` (Roboto Serif
     Headline served as WOFF2, `ui-serif`, `serif` fallbacks; L-8), `fontSize.global.displayMedium` (34.4) /
     `invite.web.lineHeight.headline` (32), regular,
     #FFFFFF, max width `invite.web.size.textMaxWidth` (260);
   - `invite.web.size.headlineToBody` (16) below: line `invite.web.body` — `invite.web.fontSize.body` (14) /
     `invite.web.lineHeight.body` (19.6), tracking `invite.web.letterSpacing.body`, colour `invite.web.color.body`
     (white 62 %), max width 260;
   - `invite.web.size.headlineToBody` below: member avatar stack (C-23: `size.global.avatarSmall`,
     `size.global.avatarStackOverlap`, white ring), joining order, as many as fit 260 (no "+N");
   - `invite.web.size.bodyToPill` (38) below.
4. **Pill** "Let's go" (`invite.web.cta`): height `invite.web.size.pillHeight` (56), width = card − 2 ×
   `invite.web.size.pillInset` (38), capsule (radius 28), fill `invite.web.color.pill` (white 20 %; hover
   `invite.web.color.pillHover`, transition `invite.web.duration.pill` + `invite.web.easing.pill`), label
   `invite.web.fontSize.pill` / `invite.web.fontWeight.pill` #FFFFFF; busy: label `invite.web.opening`, opacity
   `invite.web.opacity.pillDisabled`, `aria-busy="true"`. `invite.web.size.pillToFooter` (20) below.
5. **Footer**: `invite.web.footer.terms` & `invite.web.footer.privacy` links ("Terms & Privacy"),
   `invite.web.fontSize.footer` (8) #FFFFFF, margin `invite.web.size.footerMargin` (18), centred; each link padded to a
   44 × 44 hit area.

## Structure — desktop (viewport > 840)

White page, centred column (`.page_newProfilePageContent`), in the order of the WEBD capture and Retro's DOM
(`[QR(data, profilePhotoURL), h1, p]`, WEBX; RA-29): QR code of the invite URL (`invite.web.size.qrDesktop` 250, black
on white, error correction H) with the inviter's avatar (`invite.web.size.avatarDesktop` 70 circle, placeholder
`invite.web.color.avatarPlaceholder`) centred over it → headline (`invite.web.invitedBy`,
`invite.web.fontSize.headlineDesktop` 51.5 / line 48, `font.global.displayNarrow`, #000000, `invite.web.size.headlineTopDesktop`
70 below the QR) → line `invite.web.desktop.scan` (`invite.web.fontSize.bodyDesktop` 20 /
`invite.web.lineHeight.bodyDesktop` 28, `invite.web.color.bodyDesktop`, tracking −0.4, max width
`invite.web.size.bodyMaxWidthDesktop` 300, `invite.web.size.headlineToBody` above, `invite.web.size.bodyToQrDesktop`
(Retro's p margin-bottom 30) below) → link `invite.web.getApp` (App Store / Play listing; Retro shows store badges
here) → footer links (Terms, Privacy) at text role `caption`, #000000 57 % (Retro 50 %, owner decision 20), at the bottom of the page. The column is
centred vertically between the page top and the footer.

## Elements

| element | tokens | copy | behaviour |
|---|---|---|---|
| card backdrop | `invite.web.size.cardInset`, `invite.web.radius.card`, `invite.web.layout.backdrop` | `invite.web.cover.alt` (on the backdrop image, `role="img"`) | static |
| avatar | `invite.web.size.avatar` / `.avatarDesktop`, `invite.web.color.avatarPlaceholder` | `invite.web.avatar.alt` ({first_name}) | static |
| headline | `fontSize.global.displayMedium` / `invite.web.fontSize.headlineDesktop`, `invite.web.lineHeight.headline` | `invite.web.invitedBy` ({first_name}) / `invite.web.invitedFallback` | `<h1>` |
| line | `invite.web.fontSize.body`, `.lineHeight.body`, `.letterSpacing.body`, `.color.body` | `invite.web.body` / `invite.web.desktop.scan` ({group_name}) | static |
| members | C-23 stack | `invite.web.members.title` (aria-label), each avatar alt = first name | static |
| Let's go | `invite.web.size.pill*`, `invite.web.color.pill*`, `invite.web.opacity.pillDisabled`, `invite.web.duration.pill`, `invite.web.easing.pill`, `invite.web.fontSize.pill`, `invite.web.fontWeight.pill` | `invite.web.cta`, busy `invite.web.opening` | iOS Safari: App Clip (`https://appclip.apple.com/id?p=<bundle id>.Clip&token=<token>`); Android: Play listing with `referrer=invite_token%3D<token>`; installed app: the universal link / App Link opens the app before this page loads |
| QR (desktop) | `invite.web.size.qrDesktop` | `invite.web.desktop.scan` | encodes `https://<domain>/i/<token>` |
| footer | `invite.web.fontSize.footer`, `invite.web.size.footerMargin` | `invite.web.footer.terms`, `.privacy` | legal URLs (`config/app.json`) in a new tab |
| link preview | `invite.web.layout.linkPreview`, `invite.web.layout.ogImage` | `invite.web.documentTitle`, `invite.web.og.title`, `invite.web.og.description` | server-rendered meta + `GET /i/:token/og.png` |

## States

Every state uses the same card (mobile) or column (desktop): the headline line carries the state's title, the 62 % line
its explanation, and the pill its action when one exists; no avatar, no members, no backdrop photo
(`color.global.backgroundDeep` card).

| state | HTTP | copy | notes |
|---|---|---|---|
| valid | 200 | as above | `Cache-Control: private, max-age=INVITE_CACHE_SECONDS` (60 s) |
| link no longer works (expired or revoked) | 410 | `invite.web.unavailable.title`, `invite.web.unavailable.body`; no pill | same page for both (does not reveal which) |
| not found (unknown / malformed token) | 404 | `invite.web.notFound.title`; `<title>` `invite.web.notFound.documentTitle`; no pill | malformed tokens never reach the database |
| error (Supabase unreachable) | 503 | `invite.web.error.title`, `invite.web.error.body`, pill `invite.web.error.retry` (reloads) | never cached |
| too many requests | 429 | `invite.web.error.title`, `invite.web.rateLimited.body`; no pill | `Retry-After` |
| loading / offline / permission-denied | — | — | server-rendered page; the browser shows its own offline page; no permission |

## Motion

Pill background transition `invite.web.duration.pill` / `invite.web.easing.pill` (Retro CSS). No other motion;
`prefers-reduced-motion: reduce` removes the transition.

## Haptics

None (web).

## Accessibility

- One `<h1>` (headline); the line is a `<p>`; the pill is a link (`<a>`) with its visible text; `aria-busy` while opening.
- Contrast (`node tools/contrast.mjs`):

| pair | result |
|---|---|
| headline #FFFFFF on the backdrop (sampled #4A1D17 in Retro's capture) | 14.20:1 pass (large) — photo-dependent |
| line white 62 % on #4A1D17 | 6.30:1 pass; on a lighter backdrop (#8A4A3A) **3.67:1 FAIL** — photo-dependent |
| pill label #FFFFFF on white 20 % over #5D2C24 | 6.30:1 pass |
| pill fill vs backdrop (non-text) | **1.80:1 FAIL** (the label identifies it) |
| desktop line black 57 % on white (Retro 50 %, raised by owner decision 20) | 5.10:1 pass |
| footer 8 px white on the backdrop | photo-dependent; below any recommended size (Retro's own) |

  Reported, not adjusted (Retro's values). The backdrop is the photo under `color.global.backdropDim` (black 22 %,
  `invite.web.layout.backdrop`); no further scrim is sourced for this card.

## Data & actions

- `GET /i/:token` → `invite_preview(p_token)` with the anon key (docs/API.md §6.1); cover / avatar paths signed with the
  service role and served from this origin (no storage path, user id, Supabase URL or key in the HTML).
- Only `group_name`, `group_kind` (JSON only), `cover_path`, `inviter_first_name`, `inviter_avatar_path` (migration
  0016: the invite creator's avatar while a member — the same path as their `members[]` entry), `members[].first_name`,
  `members[].avatar_path` are read (`web/src/supabase.ts parsePreview`).
- `GET /i/:token/preview.json` — the same preview for the App Clip and the apps before joining.
- `GET /i/:token/og.png` — the 600 × 600 link-preview image (`invite.web.layout.ogImage`).
- Joining happens in the app or the App Clip: `join_group(p_token)` after phone sign-in (§9.3).
- Navigation in: `https://<domain>/i/<token>` (universal link / App Link when installed — iOS `DeepLinkParser`, Android
  `DeepLink.INVITE_PATH`). Out: App Clip card / App Store / Play.
- Cache: valid page, images and JSON `private, max-age=60`; every other state `no-store`. `noindex, noimageindex`.

## Platform notes

- iOS Safari shows the App Clip card from the `apple-itunes-app` meta tag (`app-clip-display=card`, as Retro does).
- Android: App Links (`/.well-known/assetlinks.json`) open the installed app; otherwise this page → Play.
- Association files are generated at start-up from `config/app.json` (`web/src/wellKnown.ts`).

## Do-not-copy

- Retro's 3-D "R" mark (top-left of the card), its wordmark, stock backdrops (`/invite-background/bg1–6.jpeg`), the
  "© Lone Palm Labs" footer, and its `/j/` page counts ("7 members • 24 photos").

## Gaps

| gap | handled as | owner capture / decision |
|---|---|---|
| avatar position on the mobile card | approximated (centred above the text block) | one iPhone Safari screenshot of a retro.app/u/<username> page with the photo loaded |
| app mark on the card | none (Retro shows its mark top-left) | owner's app icon / mark (decision 0.2) |
| App name, domain, App Store id, Team ID, Android fingerprints | `invite.web.documentTitle` BLOCKED; association entries omitted in development | `config/app.json` |
| initials avatar when the inviter has no photo | placeholder circle | one raw screenshot of a friend without a photo (C-23 Gap) |
| backdrop blur radius | closed: `invite.web.layout.backdrop` (MERGE_DECISIONS L-6) | — |
| OG image name weight | display face at ≈ 52 px (ink-height estimate) | Retro's `/api/userogsquare` source (not public) |
