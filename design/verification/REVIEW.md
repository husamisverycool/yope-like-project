# Pass 5 — design review (lead)

Every rebuilt screen was placed next to its Retro reference (`design/verification/retro-reference-map.json`;
`tools/sidebyside.py OUT --ours LIGHT DARK --ref REF…`) at full size: iOS from the macOS CI artifact (`ios-results`,
`ios/build/snapshots/<group>/<surface>-<state>-<light|dark>.png`), Android from the Roborazzi baselines
(`android/**/src/test/snapshots/`). Per-surface checklists (matched / approximated / not matched, token by token) are
the `design/verification/<surface>.md` (iOS) and `<surface>.android.md` (Android) files the Pass 4 agents regenerated;
this file records what the side-by-side review found across screens and what was changed because of it. The
side-by-side images are local only (git-ignored: the reference half is third-party material).

## Findings fixed in this pass

| # | finding (screen vs Retro) | evidence | fix |
|---|---|---|---|
| 1 | Every serif title read as a different product: Noto Serif / New York are ~36 % wider than Retro's titles at the same cap height, lighter, with a lower x-height. | H43 / H22 "Week 43 / 22", retro.app invite headline | **L-8**: the two display roles now use Roboto Serif instances matched to Retro's Roslindale Retro (titles) and Display Narrow (headlines) by measured glyph features; sizes re-fitted to Retro's cap heights. All platforms, worker and web. |
| 2 | Recap preview backdrop: iOS drew a frosted material, Android a 32-dp placeholder blur; Retro shows the photo mildly blurred and dimmed. | ST-04 (same photo sharp in the card and blurred behind it) | **L-5**: σ 1.8 pt + 22 % black, fitted on ST-04 (R² 0.987); `BlurredBackdrop` on both platforms. |
| 3 | The invite card's photo stayed readable behind white text; Retro's card is a soft colour field. | retro.app bg2.jpeg, OG image | **L-6**: σ = 0.08 × card width (web, App Clip, Android join card). |
| 4 | The collage screen blurred the composed grid behind the grid card (busy grid on grid). | ST-04 single photo; TC-REC wash | **L-7**: the backdrop is the collage's first photo. |
| 5 | Paywall backdrop too weak (photo readable). | PAY RAW: no edge sharper than σ ≈ 100 px | **L-9**: shared `ColourFieldBackdrop` (σ = 0.08 × width). |
| 6 | Group and album names used the lighter headline cut after L-8. | retro.app sets album titles in Roslindale Retro | `displayTitle` text role (title cut at displayMedium size) on both platforms. |
| 7 | Avatar placeholders disappeared on grouped rows (placeholder fill = row fill, both appearances). | Android dark settings, iOS settings groups | Placeholder fill raised to `color.global.controlRaised` inside grouped containers (CompositionLocal / environment). |
| 8 | Page dots of the recap preview sat on the Share pill's line in the spec text; ST-04 shows them 16.3 pt below the page. | ST-04 full-resolution measurement | RC-19, `RecapDots.BelowPage` default (both platforms). |
| 9 | iOS review images showed no blur at all (App Clip backdrop sharp) although the code blurs. | snapshot of invite.appclip | `SnapshotRecorder` draws through the key window (`drawHierarchy`) so Core Animation filters render; not an app bug. |
| 10 | Recap list week cards ("Week 41" on the cover) used the light headline cut and washed out on bright covers; the C-34 library card's year did too. | TC-2023-12 recaps: "December" / "November" and the card's "2023" are the heavy title cut | Week cards → `displayTitle`; C-34 card year → `headerTitle` (as memory's recap card, RM-8). |
| 11 | Paywall media card ended in a hard edge; Retro's card fades into the colour field at the bottom. | PAY rows 700–1050 (card vs backdrop colour distance; linear ramp y 805 → 950) | `paywall.size.mediaCardFade` (48 pt) alpha mask on both platforms. |
| 12 | iOS circle glyphs filled the 24-pt box: the "+" on group rows was 0.66 of its circle, the sheet "×" 0.67; Retro's are 0.377 and 0.302. | ED-W3 "+" 52 px in 138 px; ST-04 / ST-03 "×" 26 px in 86 px | `size.global.circleGlyph` (13.6) and `size.global.circleCloseGlyph` (10.9), scaled with the diameter, as the iOS `CircleButtonStyle` default; the hand-set `iconSmall` overrides removed. Android already draws Retro's Android 24-dp glyph box (0.389 / 0.361). |

## Reviewed and kept (matches the reference or the spec)

- **Camera, send-to, daily capture** (both platforms): serif "Week N", 3:4 viewfinder with 18-pt corners, Retro's
  postcard composer layout for send-to (title, close / save circles, photo with "Add a message" pill, check rows,
  white Send capsule). Media surfaces stay black in both appearances, as Retro's media screens do.
- **onthisday** (Rewind): full-bleed photo, serif date + "On this day · name", glass ••• / share / shuffle, 44-tick
  dial — near-identical composition to RWA / RWB. Our page is pushed (no tab bar), so the controls sit at Retro's
  distance from the bottom edge rather than above a tab bar (spec).
- **groups.list / groups.screen / albums**: thumbnail rows with "+" circles and avatar stacks (ED-A), journal-style
  page with book cover, serif name, outline capsules and week strip (TC-J1 + ST-01).
- **walls**: serif name, avatar, week sections with "Week N + range" and tile strips (ST-02). Retro's counts ("Weeks
  Posted: 32") and public "Share Profile" are left out by the tenets; the lone settings capsule sits under the
  avatar.
- **chat**: Retro's comment rows (no bubbles), serif header, comment field with own avatar (ENG-M + C-13).
- **photo.viewer**: dark page, header avatar + name + week, position pill, close, full-width photo, footer and
  comment field (TC-2B). Footer content below the fold scrolls under the comment field (as in Retro).
- **week.recap / year.story / collage**: the shared recap preview (media page, close, white card or collage, dots
  below the page, white pill), memory's white recap card in the title cut ("Week 41", "2026").
- **paywall / birthday.request**: plan card on a backdrop with a black capsule (PAY).
- **invite (web + App Clip + Android)**: Retro's /u/ card: colour field, avatar, serif headline, "Let's go" pill;
  desktop QR column in Retro's order.
- **Android dark page #1C1C1E** vs iOS #000000: Retro's own Android default dark scheme (R-3); Retro's true black is
  offered in Android Settings → Appearance → True Black (owner decision 21; `groups.list/default-trueBlack-dark`,
  `settings.root/trueBlackOn-dark` next to Retro's iOS black page: same #000000 page, #262626 rows and controls).
- **paywall trial** (owner decision 7): both platforms show the annual plan's 1-week trial — the FREE pill at Retro's
  19.5-pt inset (PAY), "Try 1 week free", "And then billed $35.99 yearly after"; people no longer eligible see the plain
  card (`paywall/default-noTrial`). Android reads Play's free offer phase (core:billing); iOS checks StoreKit eligibility.

## Known visible gaps (not fixable without the owner or new captures)

- Landing (auth.phone): no wordmark or mark until the owner names the app (BLOCKED `{app_name}`); the screen reads
  sparse in release.
- Debug builds show `{app_name}` placeholders where copy names the app (release omits those elements).
- Display faces are the closest free match, not Roslindale itself (licence: owner).
- Component gaps logged by the Pass 4 agents (local variants built from tokens): 64-pt dark circle, header action
  state, grouped-row value/height variants, people-row check slot, white loading indicator
  on media, sheet header with a leading close, reply-bar internals. Each is drawn from tokens; consolidating them into
  the libraries is follow-up work, not a visual difference.
