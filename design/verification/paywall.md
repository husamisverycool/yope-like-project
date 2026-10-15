# Verification — `paywall` (iOS)

Premium paywall and plan sheet — `Features/Account/Paywall/PaywallScreen.swift` (RevenueCat via `RevenueCatPurchases`).

Checklist written from the spec (`design/surfaces/paywall.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/account/<surface>-<state>.png` (AccountSnapshotTests), then `tools/sidebyside.py` makes `design/verification/paywall.png` next to the reference image(s) below. The "what the snapshot shows" column states what the code draws for that value; it is to be confirmed on the image.

Reference image(s): `references/auto/locket/mobbin/locket-mobbin-paywall-screen.png`, `references/auto/locket/mobbin/locket-mobbin-gold-flow-2.png`, `references/auto/locket/mobbin/locket-mobbin-gold-flow-3.png`, `references/auto/locket/lazyweb/locket-lazyweb-20260803-cap-plan-picker.png`, `references/auto/locket/lazyweb/locket-lazyweb-20260803-autocap-21.png`, `references/auto/locket/lazyweb/locket-lazyweb-20260803-autocap-25.png`

Snapshots (CI): `paywall-loading.png`, `paywall-loaded.png`, `paywall-plans.png`, `paywall-plans-unavailable.png`, `paywall-plans-offline.png`

**Summary: 79 matched · 4 approximated · 9 not matched (BLOCKED or not buildable) · 2 not applicable on iOS / placed by another pass.**

| status | kind | token / copy | reference value | element | what the snapshot shows (iOS implementation) |
|---|---|---|---|---|---|
| matched | token | `paywall.layout.promptRule` | settingsEntry: always opens (navigation the person chose; not counted); lockedFeature: the first tap on a locked perk per session opens the paywall (SessionP… (SOURCED) | when the paywall may appear | settings entry always opens; `AppRouter.presentPaywallForLockedFeature` uses `SessionPromptGate` (once per session, never during capture / onboarding) and leaves the camera tab first |
| matched | token | `paywall.color.backgroundTop` | #030101 (SOURCED) | background gradient stop at 0.078 of the screen height (x = 20) | `Tokens.…paywallColorBackgroundTop` in PaywallScreen.swift |
| matched | token | `paywall.color.backgroundUpper` | #0E0803 (SOURCED) | background gradient stop at 0.274 of the screen height (x = 20) | `Tokens.…paywallColorBackgroundUpper` in PaywallScreen.swift |
| matched | token | `paywall.color.backgroundLower` | #1E1404 (SOURCED) | background gradient stop at 0.587 of the screen height (x = 20) | `Tokens.…paywallColorBackgroundLower` in PaywallScreen.swift |
| matched | token | `paywall.color.backgroundBottom` | #372805 (SOURCED) | background gradient stop at 0.861 of the screen height (x = 20) | `Tokens.…paywallColorBackgroundBottom` in PaywallScreen.swift |
| matched | token | `paywall.size.perkMarginH` | 20 pt (SOURCED) | perk card side margin (card width 353 pt on 393) | `Tokens.…paywallSizePerkMarginH` in PaywallScreen.swift |
| not matched | token | `paywall.size.iconTile` | 76 pt (SOURCED) | app-icon tile at the top (rounded square) | the tile is omitted with its art (`paywall.layout.iconTileArt` BLOCKED → `DesignGaps.showsPaywallIconTile` = false); the title moves up |
| not matched | token | `paywall.layout.iconTileArt` | None (BLOCKED) | artwork inside the icon tile (our app icon) | BLOCKED: omitted in release builds |
| not matched | copy | `paywall.title` | “{app_name} Premium” (SOURCED) |  | uses {app_name}: DEBUG builds only via `AccountBlockedCopy` (PaywallScreen.swift, AccountBlockedCopy.swift); omitted in release |
| not matched | copy | `paywall.subtitle` | “Members have so much more fun on {app_name}!” (SOURCED) |  | uses {app_name}: DEBUG builds only via `AccountBlockedCopy` (PaywallScreen.swift, AccountBlockedCopy.swift); omitted in release |
| matched | token | `paywall.size.perkHeight` | 78 pt (SOURCED) | perk card height | `Tokens.…paywallSizePerkHeight` in PaywallScreen.swift |
| matched | token | `paywall.size.perkGap` | 4 pt (SOURCED) | gap between perk cards | `Tokens.…paywallSizePerkGap` in PaywallScreen.swift |
| matched | token | `paywall.radius.perkOuter` | 23 pt (SOURCED) | outer corners of the perk stack (top of the first card, bottom of the last) | `Tokens.…paywallRadiusPerkOuter` in PaywallScreen.swift |
| matched | token | `paywall.radius.perkInner` | 6 pt (SOURCED) | inner corners between stacked perk cards | `Tokens.…paywallRadiusPerkInner` in PaywallScreen.swift |
| matched | token | `paywall.size.perkIcon` | 30 pt (SOURCED) | perk emoji size (centre 39 pt from the card's leading edge) | `Tokens.…paywallSizePerkIcon` in PaywallScreen.swift |
| matched | token | `paywall.size.perkTextInset` | 73 pt (SOURCED) | perk text leading inset from the card edge | `Tokens.…paywallSizePerkTextInset` in PaywallScreen.swift |
| matched | copy | `paywall.legal.renews` | “Subscription renews automatically. Cancel anytime.” (SOURCED) |  | `Copy.…paywallLegalRenews` in PaywallScreen.swift |
| matched | copy | `paywall.legal.billing.ios` | “{price} per {period}. Plan automatically renews until canceled. Cancel anytime in Settings at least a day before each renewal date.” (VERIFIED) |  | `Copy.…paywallLegalBillingIos` in PaywallModel.swift |
| n/a | copy | `paywall.legal.billing.android` | “{price} per {period}. Renews automatically until you cancel. Cancel anytime in your subscription settings.” (VERIFIED) |  | Android only |
| not matched | copy | `paywall.legal.optional` | “You don’t need a subscription to use {app_name}.” (VERIFIED) |  | uses {app_name}: DEBUG builds only via `AccountBlockedCopy` (PaywallScreen.swift, AccountBlockedCopy.swift); omitted in release |
| matched | copy | `paywall.restore` | “Restore Purchases” (VERIFIED) |  | `Copy.…paywallRestore` in PaywallScreen.swift |
| matched | copy | `paywall.terms` | “Terms of Use” (VERIFIED) |  | `Copy.…paywallTerms` in PaywallScreen.swift |
| matched | copy | `paywall.privacy` | “Privacy Policy” (VERIFIED) |  | `Copy.…paywallPrivacy` in PaywallScreen.swift |
| not matched | copy | `paywall.cta` | “Upgrade your {app_name}” (SOURCED) |  | uses {app_name}: DEBUG builds only via `AccountBlockedCopy` (AccountBlockedCopy.swift); omitted in release |
| matched | token | `paywall.icon.ctaUnlock` | ios: lock.open.fill; android: Rounded.LockOpen (PLATFORM) | open-padlock glyph after the CTA label | `Tokens.…paywallIconCtaUnlock` in PaywallScreen.swift |
| matched | copy | `paywall.dismiss` | “No thanks!” (SOURCED) |  | `Copy.…paywallDismiss` in PaywallScreen.swift |
| matched | token | `paywall.layout.planSheet` | ios: sheet with presentationDetents([.medium]) and presentationDragIndicator(.visible); system corner radius; android: ModalBottomSheet with the M3 drag hand… (PLATFORM) | 'Subscribe to …' plan sheet container | sheet .presentationDetents([.medium]), visible grabber, system corner radius |
| matched | token | `paywall.color.planSheetTop` | #292824 (SOURCED) | plan sheet fill at its top (warms downwards to paywall.color.planSheetBottom) | `Tokens.…paywallColorPlanSheetTop` in PaywallScreen.swift |
| matched | token | `paywall.color.planSheetBottom` | #312C1F (SOURCED) | plan sheet fill beside the second plan card | `Tokens.…paywallColorPlanSheetBottom` in PaywallScreen.swift |
| not matched | copy | `paywall.plans.title` | “Subscribe to {app_name} Premium” (SOURCED) |  | uses {app_name}: DEBUG builds only via `AccountBlockedCopy` (PaywallScreen.swift, AccountBlockedCopy.swift); omitted in release |
| matched | token | `paywall.size.planMarginH` | 16 pt (SOURCED) | plan card side margin (370 pt wide on a 402-pt screen) | `Tokens.…paywallSizePlanMarginH` in PaywallScreen.swift |
| matched | copy | `paywall.plans.yearly.title` | “1 Year” (SOURCED) |  | `Copy.…paywallPlansYearlyTitle` in PaywallScreen.swift |
| matched | copy | `paywall.plans.yearly.detail` | “12 mo • {monthly_equivalent}/mo” (SOURCED) |  | `Copy.…paywallPlansYearlyDetail` in PaywallScreen.swift |
| matched | copy | `paywall.plans.yearly.price` | “{yearly_price}/yr” (SOURCED) |  | `Copy.…paywallPlansYearlyPrice` in PaywallScreen.swift |
| matched | token | `paywall.size.planSelectedHeight` | 81 pt (SOURCED) | plan card height with a detail line (selected plan) | `Tokens.…paywallSizePlanSelectedHeight` in PaywallScreen.swift |
| matched | copy | `paywall.plans.monthly.title` | “1 Month” (SOURCED) |  | `Copy.…paywallPlansMonthlyTitle` in PaywallScreen.swift |
| matched | copy | `paywall.plans.monthly.price` | “{monthly_price}/mo” (SOURCED) |  | `Copy.…paywallPlansMonthlyPrice` in PaywallScreen.swift |
| matched | token | `paywall.size.planHeight` | 58 pt (SOURCED) | plan card height without a detail line | `Tokens.…paywallSizePlanHeight` in PaywallScreen.swift |
| matched | token | `paywall.color.planSelected` | #2C2922 (SOURCED) | selected plan card fill | `Tokens.…paywallColorPlanSelected` in PaywallScreen.swift |
| matched | token | `paywall.size.planBorder` | 3 pt (SOURCED) | selected plan card border width (paywall.color.planBorder) | `Tokens.…paywallSizePlanBorder` in PaywallScreen.swift |
| matched | token | `paywall.color.planBorder` | #FFB800 (SOURCED) | selected plan card border | `Tokens.…paywallColorPlanBorder` in PaywallScreen.swift |
| matched | token | `paywall.color.plan` | #3B3627 (SOURCED) | unselected plan card fill | `Tokens.…paywallColorPlan` in PaywallScreen.swift |
| matched | token | `radius.global.card` | 17 pt (SOURCED) | list card corners (home conversation / group cards, inline permission card) | `Tokens.…globalCard` in PaywallScreen.swift, PermissionCard.swift |
| matched | copy | `paywall.plans.subscribe` | “Subscribe” (SOURCED) |  | `Copy.…paywallPlansSubscribe` in PaywallScreen.swift |
| matched | token | `paywall.size.subscribeHeight` | 58 pt (SOURCED) | 'Subscribe' capsule height on the plan sheet (margins paywall.size.planMarginH) | `Tokens.…paywallSizeSubscribeHeight` in PaywallScreen.swift |
| matched | token | `paywall.color.subscribe` | #F4BB40 (SOURCED) | 'Subscribe' capsule fill | `Tokens.…paywallColorSubscribe` in PaywallScreen.swift |
| matched | token | `paywall.fontSize.subscribeLabel` | 19 pt (SOURCED) | 'Subscribe' label (bold) | `Tokens.…paywallFontSizeSubscribeLabel` in PaywallScreen.swift |
| matched | token | `paywall.color.subscribeLabel` | #302506 (SOURCED) | 'Subscribe' label colour | `Tokens.…paywallColorSubscribeLabel` in PaywallScreen.swift |
| matched | token | `paywall.color.dismiss` | #BAAA82 (SOURCED) | 'No thanks!' colour; also the legal footer text and links | `Tokens.…paywallColorDismiss` in PaywallScreen.swift |
| matched | copy | `paywall.welcome.title` | “Welcome to Premium!” (SOURCED) |  | `Copy.…paywallWelcomeTitle` in PaywallScreen.swift |
| not matched | copy | `paywall.welcome.body` | “You now have access to all {app_name} Premium features.” (SOURCED) |  | uses {app_name}: DEBUG builds only via `AccountBlockedCopy` (PaywallScreen.swift, AccountBlockedCopy.swift); omitted in release |
| matched | copy | `paywall.welcome.done` | “Done” (SOURCED) |  | `Copy.…paywallWelcomeDone` in PaywallScreen.swift |
| matched | token | `paywall.fontSize.title` | 30 pt (SOURCED) | title ('{app_name} Premium'), bold | `Tokens.…paywallFontSizeTitle` in PaywallScreen.swift |
| matched | token | `paywall.color.title` | #FDEAB8 (SOURCED) | title colour (cream gold); also the plan-sheet title, plan names and prices | `Tokens.…paywallColorTitle` in PaywallScreen.swift |
| matched | token | `paywall.fontSize.subtitle` | 17 pt (SOURCED) | subtitle (2 lines, regular, centred) | `Tokens.…paywallFontSizeSubtitle` in PaywallScreen.swift |
| matched | token | `paywall.lineHeight.subtitle` | 22 pt (SOURCED) | subtitle line pitch | `Tokens.…paywallLineHeightSubtitle` in PaywallScreen.swift |
| matched | token | `paywall.color.subtitle` | #B2AA8C (SOURCED) | subtitle colour | `Tokens.…paywallColorSubtitle` in PaywallScreen.swift |
| matched | token | `paywall.color.perk` | #211B13 (SOURCED) | perk card fill (upper cards) | `Tokens.…paywallColorPerk` in PaywallScreen.swift |
| matched | token | `paywall.fontSize.perkTitle` | 17 pt (SOURCED) | perk title (semibold) | `Tokens.…paywallFontSizePerkTitle` in PaywallScreen.swift |
| matched | token | `paywall.fontWeight.perkTitle` | semibold (SOURCED) | perk title weight | `Tokens.…paywallFontWeightPerkTitle` in PaywallScreen.swift |
| matched | token | `paywall.color.perkTitle` | #F5F1EB (SOURCED) | perk title colour | `Tokens.…paywallColorPerkTitle` in PaywallScreen.swift |
| matched | token | `paywall.fontSize.perkSubtitle` | 15 pt (SOURCED) | perk subtitle (regular) | `Tokens.…paywallFontSizePerkSubtitle` in PaywallScreen.swift |
| matched | token | `paywall.color.perkSubtitle` | #918A80 (SOURCED) | perk subtitle colour | `Tokens.…paywallColorPerkSubtitle` in PaywallScreen.swift |
| matched | token | `paywall.size.ctaHeight` | 56 pt (SOURCED) | primary CTA capsule height (full width, margins paywall.size.perkMarginH) | `Tokens.…paywallSizeCtaHeight` in PaywallScreen.swift |
| matched | token | `paywall.color.cta` | #FEB900 (SOURCED) | primary CTA fill | `Tokens.…paywallColorCta` in PaywallScreen.swift |
| matched | token | `radius.global.capsule` | shape: capsule; radius: height / 2 (SOURCED) | full pill: header title capsule, composer text field, chat bubbles, tab-bar capsule, tooltip ends, white se… | Capsule() shape |
| matched | token | `paywall.fontSize.ctaLabel` | 18 pt (SOURCED) | CTA label (bold) + trailing unlock glyph | `Tokens.…paywallFontSizeCtaLabel` in PaywallScreen.swift |
| matched | token | `paywall.color.ctaLabel` | #2A1E05 (SOURCED) | CTA label and glyph colour | `Tokens.…paywallColorCtaLabel` in PaywallScreen.swift |
| matched | token | `paywall.fontSize.dismiss` | 16 pt (SOURCED) | 'No thanks!' text button (regular) | `Tokens.…paywallFontSizeDismiss` in PaywallScreen.swift |
| matched | token | `fontSize.global.caption` | 12 pt (SOURCED) | small meta text: voice-message duration ('00:38'), legal footer under sign-up | `Tokens.…globalCaption` in PaywallScreen.swift, TextRoles.swift |
| matched | token | `lineHeight.global.caption` | 15.2 pt (SOURCED) | line pitch of the 3-line legal footer under sign-up (12 pt text) | `Tokens.…globalCaption` in PaywallScreen.swift, TextRoles.swift |
| matched | token | `paywall.fontSize.planName` | 18 pt (SOURCED) | plan name ('1 Year', '1 Month'), bold, paywall.color.title | `Tokens.…paywallFontSizePlanName` in PaywallScreen.swift |
| matched | token | `paywall.fontSize.planPrice` | 17 pt (SOURCED) | plan price, trailing, bold, paywall.color.title | `Tokens.…paywallFontSizePlanPrice` in PaywallScreen.swift |
| matched | token | `paywall.fontSize.planDetail` | 15 pt (SOURCED) | plan detail line under the name (regular) | `Tokens.…paywallFontSizePlanDetail` in PaywallScreen.swift |
| matched | token | `paywall.color.planDetail` | #BFB598 (SOURCED) | plan detail colour | `Tokens.…paywallColorPlanDetail` in PaywallScreen.swift |
| matched | token | `haptic.global.select` | ios: selection; android: SEGMENT_TICK (PLATFORM) | a recipient / group toggled, a segmented choice, picker scrubbing | `Tokens.…globalSelect` in CheckRow.swift, PaywallScreen.swift, SegmentedPills.swift |
| n/a | copy | `paywall.locked.badge` | “Premium” (SOURCED) |  | drawn on the locked controls by their passes (camera.capture, widgets) |
| matched | token | `paywall.layout.requiredDisclosures` | price: the store's localized price for each plan's period (StoreKit Product.displayPrice + subscription.subscriptionPeriod / Play ProductDetails.Subscription… (VERIFIED) | store-required elements on the paywall and plan sheet | store-localised price per plan (`PlanOption.price` from RevenueCat `localizedPriceString`), billing line `paywall.legal.billing.ios`, restore, terms/privacy links; never a hard-coded price |
| matched | copy | `paywall.retry` | “Try Again” (VERIFIED) |  | `Copy.…paywallRetry` in PaywallScreen.swift |
| matched | copy | `paywall.error.products` | “Plans aren’t available right now. Try again in a moment.” (SOURCED) |  | `Copy.…paywallErrorProducts` in PaywallScreen.swift |
| matched | copy | `paywall.offline` | “You’re offline. Connect to the internet to see plans.” (SOURCED) |  | `Copy.…paywallOffline` in PaywallModel.swift, PaywallScreen.swift |
| matched | copy | `paywall.error.purchase` | “Your purchase didn’t go through. Try again in a moment.” (SOURCED) |  | `Copy.…paywallErrorPurchase` in PaywallModel.swift |
| matched | copy | `paywall.pending` | “Your purchase is waiting for approval.” (VERIFIED) |  | `Copy.…paywallPending` in PaywallModel.swift |
| matched | copy | `paywall.restore.done` | “Your subscription is back!” (SOURCED) |  | `Copy.…paywallRestoreDone` in PaywallModel.swift |
| matched | copy | `paywall.restore.none` | “We couldn’t find a subscription to restore.” (SOURCED) |  | `Copy.…paywallRestoreNone` in PaywallModel.swift |
| matched | token | `haptic.global.success` | ios: notification.success; android: CONFIRM (PLATFORM) | any task completed successfully (same generator as send) | `Tokens.…globalSuccess` in PaywallScreen.swift |
| matched | token | `haptic.global.error` | ios: notification.error; android: REJECT (PLATFORM) | a task failed (send failed) | `Tokens.…globalError` in BlockConfirmation.swift, PaywallScreen.swift |
| matched | copy | `paywall.plans.selected.accessibilityLabel` | “selected” (VERIFIED) |  | iOS: the selected plan card carries the .isSelected trait (the key is the Android value) |
| matched | token | `settings.account.layout.manageSubscription` | ios: AppStore.showManageSubscriptions(in:) (manageSubscriptionsSheet); android: open https://play.google.com/store/account/subscriptions?sku={productId}&pack… (VERIFIED) | 'Manage Subscription' destination | .manageSubscriptionsSheet(isPresented:) |
| not matched | copy | `paywall.perk.history.emoji` | “{history_emoji}” (BLOCKED) |  | BLOCKED: DEBUG builds only via `AccountBlockedCopy` (AccountBlockedCopy.swift); omitted in release |

## Approximations

- Legal link labels at `paywall.fontWeight.perkTitle` (spec approximation).
- Subscribe label at `fontWeight.global.button` (Locket weight not measured).
- Plan card corners `radius.global.card` (not measured); plan card gap = planMarginH; perk emoji frame = perkTextInset.
- Plan period unit from StoreKit 2 `Product.SubscriptionPeriod.Unit.localizedDescription` (needs an on-device check).

## Not matched

- `paywall.size.iconTile` — the tile is omitted with its art (`paywall.layout.iconTileArt` BLOCKED → `DesignGaps.showsPaywallIconTile` = false); the title moves up
- `paywall.layout.iconTileArt` — BLOCKED: omitted in release builds
- `paywall.title` — uses {app_name}: DEBUG builds only via `AccountBlockedCopy` (PaywallScreen.swift, AccountBlockedCopy.swift); omitted in release
- `paywall.subtitle` — uses {app_name}: DEBUG builds only via `AccountBlockedCopy` (PaywallScreen.swift, AccountBlockedCopy.swift); omitted in release
- `paywall.legal.optional` — uses {app_name}: DEBUG builds only via `AccountBlockedCopy` (PaywallScreen.swift, AccountBlockedCopy.swift); omitted in release
- `paywall.cta` — uses {app_name}: DEBUG builds only via `AccountBlockedCopy` (AccountBlockedCopy.swift); omitted in release
- `paywall.plans.title` — uses {app_name}: DEBUG builds only via `AccountBlockedCopy` (PaywallScreen.swift, AccountBlockedCopy.swift); omitted in release
- `paywall.welcome.body` — uses {app_name}: DEBUG builds only via `AccountBlockedCopy` (PaywallScreen.swift, AccountBlockedCopy.swift); omitted in release
- `paywall.perk.history.emoji` — BLOCKED: DEBUG builds only via `AccountBlockedCopy` (AccountBlockedCopy.swift); omitted in release
