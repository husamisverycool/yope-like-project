# `paywall` — premium screen and perks

Reference: **Locket (Gold)** for layout, palette and voice (`docs/SURFACES.md`); store-required elements from
Apple / Google (`docs/PLATFORM_CONSTRAINTS.md` §8). Research: `design/research/locket.md` §10–11;
`design/research/platform.md` §paywall. Directive Part 6 perks only. API: `docs/API.md` §5.22 (entitlements),
§6.4 `group_history_weeks` (free window), §12 item 4; `docs/SPEC_FLAGS.md` T1. Tokens: `paywall.*`. Copy: `paywall.*`.

**At most one premium prompt per session, never blocking the core** (`paywall.layout.promptRule`,
`SessionPromptGate`). Only this app's perks are listed; Locket's ads removal, "who viewed", streak restoration, badges,
unlimited friends, app icons and camera themes are not.

## References

| id | file | used for |
|---|---|---|
| MB | `references/auto/locket/mobbin/locket-mobbin-paywall-screen.png` (2025-10, @3x) | all paywall values: gradient, icon tile, title, subtitle, perk cards, CTA, "No thanks!" |
| MB2 | `references/auto/locket/mobbin/locket-mobbin-gold-flow-2.png` | lower perks and their emoji, CTA pinned at the bottom while the cards scroll |
| MB3–6 | `references/auto/locket/mobbin/locket-mobbin-gold-flow-3.png` … `-6.png` | plan sheet, system success alert, "Welcome to Gold!" sheet |
| LZP | `references/auto/locket/lazyweb/locket-lazyweb-20260803-cap-plan-picker.png` (2026-08, @3x) | plan sheet values (measured in this pass) |
| LZ21 | `references/auto/locket/lazyweb/locket-lazyweb-20260803-autocap-21.png` | entry row in the profile; "Gold" badge on locked rows |
| LZ25 | `references/auto/locket/lazyweb/locket-lazyweb-20260803-autocap-25.png` | system purchase sheet text (renewal sentence) |

## Structure — paywall (full screen)

Background: vertical gradient `paywall.color.backgroundTop` (0.078) → `.backgroundUpper` (0.274) → `.backgroundLower`
(0.587) → `.backgroundBottom` (0.861 and below).

Scrolling content (centred, side margins `paywall.size.perkMarginH`):
1. Icon tile `paywall.size.iconTile` (art `paywall.layout.iconTileArt`, BLOCKED → tile omitted until the app icon exists).
2. Title `paywall.title`.
3. Subtitle `paywall.subtitle` (2 lines).
4. Perk stack, cards `paywall.size.perkHeight` tall, gap `paywall.size.perkGap`, outer corners `paywall.radius.perkOuter`
   (top of the first, bottom of the last), inner corners `paywall.radius.perkInner`; order: video, widgets, history
   (only while `free_history_days` is set), export. Each card: emoji (`paywall.size.perkIcon`, centred 39 pt from the
   leading edge) · title + subtitle at `paywall.size.perkTextInset`.
5. Legal block (under the cards; scrolls): `paywall.legal.renews`, the platform billing line
   (`paywall.legal.billing.ios` / `.android`, with the selected plan's price and period once known),
   `paywall.legal.optional`, then a row of three text buttons `paywall.restore` · `paywall.terms` · `paywall.privacy`.

Pinned at the bottom (over the scroll, as MB2):
6. CTA capsule `paywall.cta` + `paywall.icon.ctaUnlock`, full width minus `paywall.size.perkMarginH`.
7. `paywall.dismiss` text button under it.

## Structure — plan sheet (`paywall.layout.planSheet`, opened by the CTA)

Sheet fill gradient `paywall.color.planSheetTop` → `.planSheetBottom`; system grabber.
1. Title `paywall.plans.title` (2 lines).
2. Plan cards, side margin `paywall.size.planMarginH`, 16 pt apart (LZP gap 1951→1999 px = 16 pt): yearly card
   (name `paywall.plans.yearly.title`, detail `paywall.plans.yearly.detail`, trailing price `paywall.plans.yearly.price`;
   height `paywall.size.planSelectedHeight`) and monthly card (`paywall.plans.monthly.title`, price
   `paywall.plans.monthly.price`; height `paywall.size.planHeight`). Selected card: fill `paywall.color.planSelected`,
   border `paywall.size.planBorder` in `paywall.color.planBorder`; unselected: fill `paywall.color.plan`. Default
   selection: yearly (Locket's default). Corners: not measured (see Gaps) → `radius.global.card` (approximation).
3. Subscribe capsule `paywall.plans.subscribe`, height `paywall.size.subscribeHeight`, fill `paywall.color.subscribe`,
   label `paywall.fontSize.subscribeLabel` in `paywall.color.subscribeLabel`, margins `paywall.size.planMarginH`.
4. Legal billing line for the selected plan (`paywall.legal.billing.*`) under the button (caption, `paywall.color.dismiss`).

After purchase: iOS shows the system purchase sheet and its own confirmation (PLATFORM); then the "welcome" sheet:
`paywall.welcome.title`, `paywall.welcome.body`, button `paywall.welcome.done` (Locket's heart rain is not copied).

## Elements

| element | tokens | copy | behaviour |
|---|---|---|---|
| title | `paywall.fontSize.title` bold, `paywall.color.title` | `paywall.title` | — |
| subtitle | `paywall.fontSize.subtitle`, `paywall.lineHeight.subtitle`, `paywall.color.subtitle` | `paywall.subtitle` | — |
| perk card | `paywall.color.perk`, `.size.perkHeight`, `.radius.perkOuter`/`.perkInner`, `.size.perkIcon`, `.size.perkTextInset`; title `paywall.fontSize.perkTitle` `paywall.fontWeight.perkTitle` `paywall.color.perkTitle`; subtitle `paywall.fontSize.perkSubtitle` `paywall.color.perkSubtitle` | `paywall.perk.video.*`, `paywall.perk.widgets.*`, `paywall.perk.history.*` (emoji BLOCKED), `paywall.perk.export.*` | static |
| CTA | `paywall.size.ctaHeight`, `paywall.color.cta`, `radius.global.capsule`, label `paywall.fontSize.ctaLabel` bold `paywall.color.ctaLabel`, `paywall.icon.ctaUnlock` | `paywall.cta` | opens the plan sheet |
| No thanks! | `paywall.fontSize.dismiss`, `paywall.color.dismiss` | `paywall.dismiss` | closes the paywall |
| legal block | `fontSize.global.caption`, `lineHeight.global.caption`, `paywall.color.dismiss`; links underlined? not observed → same colour, `paywall.fontWeight.perkTitle` (approximation) | `paywall.legal.*`, `paywall.restore`, `paywall.terms`, `paywall.privacy` | restore → `Purchases.restorePurchases()`; links open `config/app.json` legal URLs |
| plan cards | `paywall.size.plan*`, `paywall.color.plan*`, names `paywall.fontSize.planName` (bold, `paywall.color.title`), price `paywall.fontSize.planPrice` (bold, `paywall.color.title`), detail `paywall.fontSize.planDetail` `paywall.color.planDetail` | plan strings | tap selects (`haptic.global.select`) |
| Subscribe | `paywall.size.subscribeHeight`, `paywall.color.subscribe`, `paywall.fontSize.subscribeLabel`, `paywall.color.subscribeLabel` | `paywall.plans.subscribe` | `Purchases.purchase(package:)` (RevenueCat, entitlement `premium`) |
| locked badge (on other surfaces) | capsule, `paywall.color.cta` fill, `paywall.color.ctaLabel` text, `fontSize.global.caption` (approximation; Locket's badge size not measured) | `paywall.locked.badge` | marks: video recording (`camera.capture`), extra widget styles (`widget.*` configuration), weeks beyond the free window (`week.history`), full-quality export (`albums.view`) |

Prices: always the store's localized strings at runtime (`paywall.layout.requiredDisclosures`); `{monthly_equivalent}`
is the yearly price ÷ 12 in the product's currency. `config/app.json` prices are defaults for the store setup only.

## States

| state | design | copy |
|---|---|---|
| loading products | perks shown; plan prices and billing line replaced by a native progress indicator; CTA enabled (sheet shows progress) | — |
| products unavailable / error | legal block shows the message + `paywall.retry`; Subscribe disabled | `paywall.error.products` |
| offline | same place | `paywall.offline`, `paywall.retry` |
| purchasing | Subscribe shows native progress (Locket MB4: spinner in the button) | — |
| purchase failed | message under Subscribe | `paywall.error.purchase` |
| user cancelled | sheet stays, no message | — |
| pending (Ask to Buy / parental approval) | message under Subscribe; the sheet can be closed | `paywall.pending` |
| success | welcome sheet; entitlement refreshed | `paywall.welcome.*` |
| restored / nothing to restore | message in the legal block | `paywall.restore.done` / `paywall.restore.none` |
| already premium | the paywall is not shown; settings shows Manage Subscription | — |
| empty / permission-denied | not applicable | — |

## Motion

Paywall: native modal presentation (`.fullScreenCover` / full-screen destination); plan and welcome sheets native.
No celebration animation (Locket's 💛 rain uses Locket's heart art). Reduce Motion: platform.

## Haptics

Plan selected → `haptic.global.select`; purchase or restore succeeded → `haptic.global.success`; failed → `haptic.global.error`.

## Accessibility

- Emoji hidden (decorative); each perk card one element (title, subtitle). Plan cards: buttons with the selected trait
  (`paywall.plans.selected.accessibilityLabel` as value on Android). Prices read as the store string.
- Dynamic Type (F-13): title 30 → `title1`; subtitle 17 → `body`; perk title 17 semibold → `headline`; perk subtitle 15 →
  `subheadline`; CTA 18 bold → `headline`; dismiss 16 → `callout`; plan sheet title 24.5 → `title2`; plan name 18 → `headline`;
  price 17 → `headline`; detail 15 → `subheadline`; Subscribe 19 → `title3`; legal → `caption`. Cards grow with text.
- Focus order: tile → title → subtitle → perks → legal block → CTA → No thanks!; sheet: title → plans → Subscribe → legal.
- Contrast (node tools/contrast.mjs): title 16.72:1, subtitle 8.55:1, perk title 15.16:1, perk subtitle 5.00:1, CTA label
  9.45:1, CTA vs page 10.50:1, dismiss / legal 6.24:1, sheet title 12.39:1, plan detail 7.10:1, plan text 12.19:1 /
  10.12:1, selected border 8.37:1, Subscribe label 8.64:1, Subscribe vs sheet 7.96:1, legal on sheet 6.06:1 — pass;
  perk card vs page 1.17:1 and unselected plan vs sheet 1.15:1 **FAIL** (non-text; text identifies each).

## Data & actions

- RevenueCat (`config/app.json` `revenuecat`, entitlement `premium`, products `premium_monthly`, `premium_yearly`):
  offerings → packages; purchase; restore. Server truth: `entitlements` (own rows; webhook `apply_revenuecat_event`).
- `public_app_config.free_history_days` decides whether the history perk is listed.
- In: `settings.root` premium row (always allowed, not counted); the first locked-feature tap of a session outside
  capture/onboarding (`SessionPromptGate`). Never on launch, after posting, or on a timer. Out: back to the caller;
  after purchase, the locked action continues.

## Platform notes

- iOS: StoreKit purchase sheet and success alert are system UI; `AppStore.showManageSubscriptions` for management.
- Android: Play Billing sheet; settings link to the Play Subscription Center (`settings.account.layout.manageSubscription`);
  the "No thanks!" dismiss is always visible (Play: clear dismiss).
- Billing amount prominence (3.1.2): the yearly card shows `{yearly_price}/yr` as the big price and the monthly
  equivalent only in the detail line (MERGE account A-2).

## Do-not-copy

Locket perks: Remove ads / "Never see an ad in History!", Locket views / "See who's opened your Lockets", streak
restoration, Membership / Custom Gold badge, Unlimited friends + "Early access!", Custom app icon, Camera themes, Send
longer captions, "Plus so much more..." chips; the gold heart icon art; the 💛 heart rain; "check back soon"; Locket's
"$2.99/mo"-first yearly price.

## Gaps

| item | status | smallest capture / owner input |
|---|---|---|
| icon tile art (`paywall.layout.iconTileArt`) | BLOCKED | the app icon |
| history perk emoji (`paywall.perk.history.emoji`) | BLOCKED (perk hidden while history is unlimited) | owner picks one emoji, or no icon |
| legal block look (Locket shows none) | approximation (Locket muted colour at the caption role) | a 20-s iPhone recording of Locket Gold scrolled to the bottom |
| plan card corner radius, gap | radius not measured (`radius.global.card` approximation); gap 16 pt read from LZP | lossless crop of LZP corners (available: can be measured by the next pass) |
| paywall prompt frequency in Locket | not observed (our rule: one per session) | same 20-s recording does not show it; none needed |
| tenet check of "Members have so much more fun" | owner | — |
| tier name "Premium" | generic noun replacing "Gold"; owner may name the tier | owner |
| palette (Locket gold) vs app lime | MERGE account A-1 | owner |
