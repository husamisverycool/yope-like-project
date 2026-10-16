# `paywall` — Premium screen

Visual reference: **Retro Premium paywall** (inventory #27, PAY — RAW iOS, locked-feature variant "Share Video"): full-screen
blurred, colour-rich backdrop made from the feature's media; product title at the top with a glass close circle; the
benefit's media card; serif headline + description; a pager of translucent-white plan cards (36 corners, 27 padding,
black 60 pt capsule 16 in, next card peeking after 8); footer "Cancel anytime. No questions asked." Mechanics: StoreKit /
Play Billing purchase sheets (PLATFORM). Tokens: `paywall.*` + `global.*`. Copy: `paywall.*`.

**Owner decision 7 (2026-10-16):** $3.99 a month and $35.99 a year (`config/app.json` `premium`; the screen always shows the
store's localized prices); a **1-week free trial on the annual plan** on both stores (App Store introductory offer, Play
free-trial offer — `docs/OWNER_SETUP.md` §1.6 / §2.3); Retro's purple kept for premium-only accents (the "FREE" pill,
`color.global.premium`); **T1: no history window** (`free_history_days` stays NULL, so the history perk is never listed).

**At most one paywall per session, never blocking the core** (`paywall.layout.promptRule`, `SessionPromptGate`). Only this
app's perks are listed (directive Part 6): video, unlimited history (only while `free_history_days` is set), widget
styles, full-quality downloads.

## References

| id | file | used for |
|---|---|---|
| PAY | `references/auto/retro/lazyweb/retro-lazyweb-20260529-paywall.png` (RAW iOS, Display P3 → sRGB, 3.000 px/pt) | every value below: media card 248 wide r 27, title 17 semibold, headline cap 22.3 (displayMedium), description 17, plan card x 60–1144 y 1386–2456, card text #090A0A / #757A7D / #A5ABAF, title 24 bold, price 22 heavy, body 15, steps 17, footnote 15, capsule 60, "FREE" pill, footer |
| APK-S | `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt` | `retro_membership_paywall_*` benefits, plan names / subtitles / bullets, CTAs, "Cancel anytime", "Restore purchase", welcome |
| APK-W | `references/auto/retro/apk/retro_membership_paywall_graphic.webp` | benefit graphics exist (Retro assets, not copied) |

## Structure (full-screen modal; media surface: text white in both appearances)

1. **Backdrop** (C-34): the current benefit's media, blurred to a colour field over `color.global.backgroundDeep`
   (`layout.global.materials.backdrop`); no media → `color.global.backgroundDeep` alone.
2. **Header row** at the top safe area: title `paywall.title` (text role `sheetTitle`, `color.global.textOnMedia`), centred;
   close circle C-11 glass small (`size.global.circleButtonSmall` 32, `color.global.glass`, `icon.global.close`
   `color.global.textOnMedia`) at the trailing margin, centred on the title.
3. **Benefit pager** (one page per perk; opened from a locked feature, that perk's page first), centred in the space
   between the header and the plan cards:
   - media card `paywall.size.mediaCardWidth` (248), `paywall.radius.mediaCard` (27), aspect-fill: the newest photo from
     the person's groups (no photo → no card); its bottom `paywall.size.mediaCardFade` (48) fades linearly to clear into
     the backdrop (PAY rows 805–950; Pass 5 review);
   - `size.global.titleToContent` below: headline = `paywall.perk.<perk>.title` (`font.global.display`,
     `displayMedium`, `color.global.textOnMedia`, centred);
   - directly under it: `paywall.perk.<perk>.subtitle` (text role `textButton` 17 regular, `color.global.textOnMedia`,
     centred, ≤ 2 lines);
   - page dots (C-31 on media: active `color.global.textOnMedia`, inactive `color.global.pageDotInactive` dark value)
     under the description when there is more than one perk.
4. **Plan cards** (`paywall.layout.planCard`), a horizontal pager: Annual (default, first) and Monthly, width = screen − 2 ×
   `size.global.buttonMarginH`, the next card peeking after `size.global.planCardGap`. Card: fill
   `color.global.surfaceLight`, `radius.global.cardLarge`, padding `size.global.planCardPadding`;
   - title `paywall.plans.<plan>.title` (`paywall.fontSize.planTitle`, `paywall.fontWeight.planTitle`,
     `paywall.color.planText`) + trailing premium pill C-25 `paywall.plans.trial.badge` only on a plan with a free trial,
     centred on the title's cap middle, its trailing edge `paywall.size.planPillInset` (19.5) from the card's edge — outside
     the 27-pt text padding (PAY);
   - subtitle `paywall.plans.<plan>.subtitle` (`paywall.fontSize.planSubtitle`, `paywall.color.planTextSecondary`);
   - bullets `paywall.plans.<plan>.bullet1` / `.bullet2` (`paywall.fontSize.planBullet`, `paywall.color.planText`), one
     per line, no marker (Retro's numbered circles mark referral steps, which these lines are not);
   - price `paywall.plans.<plan>.price` (`paywall.fontSize.planPrice`, `paywall.fontWeight.planPrice`, `paywall.color.planText`);
   - footnote `paywall.plans.<plan>.detail` (trial: `.trialDetail`) (`paywall.fontSize.planFootnote`, `paywall.color.planTextTertiary`);
   - capsule C-05 with the light values pinned (#000000 fill, #FFFFFF label; `paywall.layout.planCard.padding`):
     `paywall.plans.subscribe` (trial: `paywall.plans.trial.cta`, "Try 1 week free").
   - No per-month breakdown line: the billed amount is the price (App Store 3.1.2 / HIG, MERGE A-2); Retro's card shows
     none either (PAY).

   **Free trial.** A plan "has a free trial" when the store offers this person one: iOS — the product's StoreKit introductory
   offer with payment mode free trial and `checkTrialOrIntroDiscountEligibility` = eligible (RevenueCat: on an unknown status
   "display the non-intro pricing"); Android — the free phase (`priceAmountMicros` 0, before the recurring phase) of the
   offer RevenueCat buys for the package (`StoreProduct.defaultOption`: Play's eligible offer with the longest free trial),
   its `billingPeriod` (`P1W`) giving `{trial_duration}` in the locale's full units (iOS `DateComponentsFormatter` `.full`,
   Android ICU `MeasureFormat` WIDE: "1 week"; PLATFORM). Not eligible (trial already used) → the plain card ("Continue",
   `.detail`, no pill).
5. **Footer** under the cards, centred, text role `caption`, `color.global.textOnMedia`: `paywall.footer`; then the billing
   line of the visible plan (`paywall.legal.billing.ios` / `.android`); Android: `paywall.legal.optional`; then a row of
   C-08 text buttons `paywall.restore` · `paywall.terms` · `paywall.privacy` (same style, ≥ 44 / 48 hit areas).

## Elements

| element | tokens / component | copy | behaviour |
|---|---|---|---|
| close | C-11 glass small | `paywall.close.accessibilityLabel` | dismiss (always visible) |
| benefit page | `paywall.size.mediaCardWidth`, `paywall.radius.mediaCard`, `displayMedium`, `textButton`, C-31 | `paywall.perk.video.*`, `.history.*` (only when `free_history_days` is set), `.widgets.*`, `.export.*` | swipe between perks; the backdrop follows the page |
| plan card | `paywall.layout.planCard` + `paywall.fontSize.*` / `paywall.color.*` | `paywall.plans.yearly.*`, `paywall.plans.monthly.*` | swipe between plans |
| Continue / Try free | C-05 (light values) | `paywall.plans.subscribe` / `paywall.plans.trial.cta` ({trial_duration} from the store) | `Purchases.purchase(package:)` (RevenueCat, entitlement `premium`) → system purchase sheet |
| premium pill | C-25 (`layout.global.premiumGradient`, `color.global.premium`, `pillSmall`, `color.global.onBadge`), `paywall.size.planPillInset` | `paywall.plans.trial.badge` | static; only on a plan with a free trial the person is eligible for |
| footer | `caption`, `color.global.textOnMedia`, C-08 | `paywall.footer`, `paywall.legal.*`, `paywall.restore`, `paywall.terms`, `paywall.privacy` | restore → `Purchases.restorePurchases()`; links → `config/app.json` legal URLs |
| locked pill (other surfaces) | C-25 premium pill | `paywall.locked.badge` | marks: video recording (`camera.capture`), extra widget styles (widget configuration), weeks beyond the free window (`week.history`), full-quality downloads (`albums.view`) |

Prices: the store's localized strings at runtime (`paywall.layout.requiredDisclosures`); the billed amount is the
largest price on each card.

## States

| state | design | copy |
|---|---|---|
| loading products | plan cards drawn; price and footnote replaced by the platform activity indicator (C-28, `paywall.color.planTextTertiary`); capsule disabled (C-05 disabled light values: `color.global.controlRaised` light #CCCCCC fill) | — |
| free trial (annual) | pill + trial capsule + `.trialDetail` footnote (Plan cards) | `paywall.plans.trial.*`, `paywall.plans.yearly.trialDetail` |
| products unavailable / error | the card pager is replaced by one line + C-09 light pill on media | `paywall.error.products` + `paywall.retry` |
| offline | same place | `paywall.offline` + `paywall.retry` |
| purchasing | the purchased plan's capsule busy (C-05); a second tap does nothing | — |
| purchase failed | message-only alert | `paywall.error.purchase` + `auth.phone.error.dismiss` |
| cancelled by the person | nothing changes | — |
| pending (Ask to Buy) | message-only alert; the paywall can be closed | `paywall.pending` |
| success / restored | benefit pager and cards cross-fade to a welcome block on the same backdrop: headline `paywall.welcome.title` (`displayMedium`, white), `paywall.welcome.body` (`textButton`, white), C-09 light capsule `paywall.welcome.done` | `paywall.welcome.*` (restore: `paywall.restore.done` as the headline) |
| nothing to restore | message-only alert (also when the store fails to restore while online) | `paywall.restore.none` |
| restore offline | message-only alert | `paywall.offline` |
| already premium | the paywall is not shown; Settings shows "Your Subscription" | — |
| empty / permission-denied | not applicable | — |

## Motion

- Presentation: native full-screen modal (`.fullScreenCover` / full-screen destination; system motion).
- Benefit and plan pagers: native paging; the backdrop cross-fades `duration.global.fade` (150 ms) per page.
- Success: cross-fade `duration.global.pageTransition` (500 ms, Retro's onboarding / reveal duration). Retro's recap
  fan-out and heart-pulse animations are tied to its own graphics and are not used.
- Reduce Motion: cross-fades only (`layout.global.reduceMotion`).

## Haptics

Presses → `haptic.global.tap` (Android). Page changes → `haptic.global.select` (a step on either pager — benefits or plans). Purchase / restore
succeeded → `haptic.global.success`; failed → `haptic.global.error`.

## Accessibility

- Header title is a header; close labelled. Each benefit page reads headline then description; the pager announces
  "page N of M". Each plan card reads title, subtitle, bullets, price, footnote, then its button; prices read as the
  store's strings.
- Dynamic Type: title `headline`; headline `largeTitle`; description `body`; plan title `title2`; price `title2`;
  subtitle / footnote `subheadline`; bullets `body`; footer `subheadline`. Cards grow in height; the pager scrolls.
- Focus order: close → title → benefit page → plan cards (content, button) → footer text → Restore → Terms → Privacy.
- Contrast:

| pair | both appearances |
|---|---|
| plan title / bullets / price `#090A0A` on white card | 19.82:1 pass |
| subtitle `#757A7D` on white card | **4.34:1 FAIL** (15 pt) |
| footnote `#A5ABAF` on white card | **2.32:1 FAIL** |
| capsule label #FFFFFF on #000000 | 21:1 pass |
| white text on the backdrop | photo-dependent (the backdrop is a blurred photo; Retro's own) |
| glass close: white glyph on white 12 % over a mid-tone photo | 3.72:1 pass at #7D7263 (RWA sample) |

  Failures are Retro's measured card colours (PAY): reported, not adjusted.

## Data & actions

- RevenueCat (`config/app.json` `revenuecat`, entitlement `premium`, products `premium_monthly`, `premium_yearly`):
  offerings → packages; purchase; restore. Server truth: `entitlements` (docs/API.md §5.22).
- `public_app_config.free_history_days` decides whether the history perk is listed; it stays NULL (T1, owner decision 7),
  so the paywall lists video, widget styles and full-quality downloads.
- Media: the newest post across the person's groups (cached).
- In: `settings.root` Subscription row (always allowed); the first locked-feature tap of a session outside capture /
  onboarding (`SessionPromptGate`). Out: back; after purchase, the locked action continues.

## Platform notes

- iOS: StoreKit purchase sheet and its confirmation are system UI; `AppStore.showManageSubscriptions` for management.
- Android: Play Billing sheet; Play needs a clear dismiss (the close circle) and the "usable without a subscription" line.

## Do-not-copy

- Retro's referral plan card and steps ("Invite 5 friends…", "Refer N friends"), "Join thousands of subscribers" ratings,
  "Popular" / "Flexible" badges, "Popular with serious memory-keepers" and "Easy to stop or pause" bullets, the
  "No Weekly Post-to-See" and "Unlimited Keys" perks, the two-part "Retro Premium" wordmark, benefit graphics and the
  heart-pulse animation.

## Gaps

| item | status | smallest capture / owner input |
|---|---|---|
| plan card translucency | opaque white (alpha not derivable — C-34 Gap) | none from stills |
| backdrop blur radius | not measurable (C-34 Gap) | none from stills |
| purple premium accent | kept (`color.global.premium`); used only on the trial pill and locked pills | decided (owner decision 7) |
| subscription-plan paywall (non-referral) as an image | PAY shows the referral card | one raw screenshot of Retro's paywall with Annual / Monthly cards |
| tier name "Premium" | Retro's noun kept | owner may rename |
