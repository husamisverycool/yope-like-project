# Verification — `paywall` (iOS, Pass 4 — Retro redesign)

Premium paywall — `Features/Account/Paywall/PaywallScreen.swift` (`PaywallView`, `PlanCard`), `PaywallModel.swift`, `Session/PlatformSeams.swift` (RevenueCat).

Checklist written from the spec (`design/surfaces/paywall.md`) against the iOS code: every token and copy key the spec names, its reference value, and where the iOS code uses it. The snapshot step is the lead's: macOS CI records `ios/build/snapshots/account/<surface>-<state>-<light|dark>.png` (AccountSnapshotTests: every state in light, the primary state also in dark), then `tools/sidebyside.py` makes `design/verification/paywall.png` next to the reference image(s) below.

Reference image(s): `references/auto/retro/lazyweb/retro-lazyweb-20260529-paywall.png`, `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt`, `references/auto/retro/apk/retro_membership_paywall_graphic.webp`

Snapshots (CI, `ios/build/snapshots/account/`): `paywall-loading-light.png`, `paywall-default-light.png`, `paywall-default-dark.png`, `paywall-default-noTrial-light.png`, `paywall-unavailable-light.png`, `paywall-offline-light.png`, `paywall-welcome-light.png`, `paywall-welcome-restored-light.png` (fixtures: $35.99 a year with the 1-week trial, $3.99 a month — owner decision 7; no history perk — T1).

**Summary: 61 matched · 1 approximated · 0 not matched · 3 not applicable on iOS / owner / another pass.** (2026-10-16, owner decisions 7: +3 rows — pill inset, trial eligibility, history perk hidden.)


## Structure

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `color.global.premium` | #B02EC1 (SOURCED) | `Tokens.Colors.globalPremium` in MediaPills.swift |
| matched | `paywall.layout.promptRule` | settingsEntry: always opens (navigation the person chose; not counted); lockedFeature: the first tap on a locked perk per session opens the paywall at that p… (SOURCED) | `AppRouter.presentPaywallForLockedFeature` (once per session, never during capture / onboarding, never for premium) |
| matched | `color.global.backgroundDeep` | #000000 (SOURCED) | `Tokens.Colors.globalBackgroundDeep` in BackdropCard.swift, FullBleedMediaPage.swift, GroupScreen.swift, InvitePreviewView.swift … |
| matched | `paywall.title` | “{app_name} Premium” (SOURCED) | `AccountBlockedCopy.paywallTitle` (BLOCKED {app_name}: release omits the title) |
| matched | `color.global.textOnMedia` | #FFFFFF (SOURCED) | `Tokens.Colors.globalTextOnMedia` in CircleButton.swift, FullBleedMediaPage.swift, GroupScreen.swift, InvitePreviewView.swift … |
| matched | `size.global.circleButtonSmall` | 32 pt (SOURCED) | `Tokens.Sizes.globalCircleButtonSmall` in CircleButton.swift, PaywallScreen.swift |
| matched | `color.global.glass` | #FFFFFF1F (SOURCED) | `Tokens.Colors.globalGlass` in CircleButton.swift |
| matched | `icon.global.close` | ios: xmark; android: Rounded.Close (PLATFORM) | `Tokens.Icons.globalClose` in PaywallScreen.swift, PermissionCard.swift, SheetChrome.swift, ViewerChrome.swift |
| approximated | `paywall.size.mediaCardWidth` | 248 pt (SOURCED) | `Tokens.Sizes.paywallSizeMediaCardWidth` in PaywallScreen.swift — width exact; height has no token (C-15 proportion, see notes) |
| matched | `paywall.radius.mediaCard` | 27 pt (SOURCED) | `Tokens.Radii.paywallRadiusMediaCard` in PaywallScreen.swift |
| matched | `size.global.titleToContent` | 30 pt (SOURCED) | `Tokens.Sizes.globalTitleToContent` in AccountGroupedRows.swift, AgeGateForm.swift, GroupCreateScreen.swift, GroupInviteScreen.swift … |
| matched | `font.global.display` | ios: system-serif; android: serif (PLATFORM) | `Tokens.Fonts.globalDisplay` in InvitePreviewView.swift, PhoneScreen.swift, TextRoles.swift |
| matched | `color.global.pageDotInactive` | light: #DDDDDD; dark: #808080 (SOURCED) | `Tokens.Colors.globalPageDotInactive` in PageDots.swift |
| matched | `paywall.layout.planCard` | fill: color.global.surfaceLight (#FFFFFF) in both appearances (Retro's card reads translucent white over the backdrop; its alpha is not derivable — C-34 Gap)… (SOURCED) | `PlanCard` in the plan pager (PaywallScreen.swift) |
| matched | `size.global.buttonMarginH` | 20 pt (SOURCED) | `Tokens.Sizes.globalButtonMarginH` in BackdropCard.swift, GroupCreateScreen.swift, GroupInviteScreen.swift, OnboardingTitle.swift … |
| matched | `size.global.planCardGap` | 8 pt (SOURCED) | `Tokens.Sizes.globalPlanCardGap` in PaywallScreen.swift |
| matched | `color.global.surfaceLight` | #FFFFFF (SOURCED) | `Tokens.Colors.globalSurfaceLight` in LightPill.swift, MediaPills.swift, PaywallScreen.swift, PrimaryButton.swift |
| matched | `radius.global.cardLarge` | 36 pt (SOURCED) | `Tokens.Radii.globalCardLarge` in BackdropCard.swift, PaywallScreen.swift |
| matched | `size.global.planCardPadding` | 27 pt (SOURCED) | `Tokens.Sizes.globalPlanCardPadding` in BackdropCard.swift, PaywallScreen.swift |
| matched | `paywall.fontSize.planTitle` | 24 pt (SOURCED) | `Tokens.FontSizes.paywallFontSizePlanTitle` in PaywallScreen.swift |
| matched | `paywall.fontWeight.planTitle` | bold (SOURCED) | `Tokens.FontWeights.paywallFontWeightPlanTitle` in PaywallScreen.swift |
| matched | `paywall.color.planText` | #090A0A (SOURCED) | `Tokens.Colors.paywallColorPlanText` in PaywallScreen.swift |
| matched | `paywall.plans.trial.badge` | “FREE” (SOURCED) | `Copy.paywallPlansTrialBadge` in PaywallScreen.swift |
| matched | `paywall.size.planPillInset` | 19.5 pt (SOURCED, PAY) | `PremiumPill … .offset(x: planCardPadding − paywallSizePlanPillInset)` in PlanCard (PaywallScreen.swift) |
| matched | free trial shown only when eligible (paywall.md Plan cards → Free trial) | StoreKit introductory free trial + RevenueCat eligibility `.eligible` | `PurchasesService.isEligibleForIntroOffer` → `RevenueCatPurchases.plans()` sets `trialDuration` only then; `PlanOption.trialDuration(_:)` "1 week" (AccountSettingsTests) |
| matched | `paywall.fontSize.planSubtitle` | 15 pt (SOURCED) | `Tokens.FontSizes.paywallFontSizePlanSubtitle` in PaywallScreen.swift |
| matched | `paywall.color.planTextSecondary` | #757A7D (SOURCED) | `Tokens.Colors.paywallColorPlanTextSecondary` in PaywallScreen.swift |
| matched | `paywall.fontSize.planBullet` | 17 pt (SOURCED) | `Tokens.FontSizes.paywallFontSizePlanBullet` in PaywallScreen.swift |
| matched | `paywall.fontSize.planPrice` | 22 pt (SOURCED) | `Tokens.FontSizes.paywallFontSizePlanPrice` in PaywallScreen.swift |
| matched | `paywall.fontWeight.planPrice` | heavy (SOURCED) | `Tokens.FontWeights.paywallFontWeightPlanPrice` in PaywallScreen.swift |
| matched | `paywall.fontSize.planFootnote` | 15 pt (SOURCED) | `Tokens.FontSizes.paywallFontSizePlanFootnote` in PaywallScreen.swift |
| matched | `paywall.color.planTextTertiary` | #A5ABAF (SOURCED) | `Tokens.Colors.paywallColorPlanTextTertiary` in PaywallScreen.swift |
| matched | `paywall.plans.subscribe` | “Continue” (SOURCED) | `Copy.paywallPlansSubscribe` in PaywallScreen.swift |
| matched | `paywall.plans.trial.cta` | “Try {trial_duration} free” (SOURCED) | `Copy.paywallPlansTrialCta` in PaywallScreen.swift |
| matched | `paywall.footer` | “Cancel anytime. No questions asked.” (SOURCED) | `Copy.paywallFooter` in PaywallScreen.swift |
| matched | `paywall.legal.billing.ios` | “{price} per {period}. Plan automatically renews until canceled. Cancel anytime in Settings.” (VERIFIED) | `Copy.paywallLegalBillingIos` in PaywallModel.swift |
| n/a | `paywall.legal.optional` | “You don't need a subscription to use {app_name}.” (VERIFIED) | Android only (BLOCKED {app_name}) |
| matched | `paywall.restore` | “Restore purchase” (SOURCED) | `Copy.paywallRestore` in PaywallScreen.swift |
| matched | `paywall.terms` | “Terms” (SOURCED) | `Copy.paywallTerms` in PaywallScreen.swift |
| matched | `paywall.privacy` | “Privacy” (SOURCED) | `Copy.paywallPrivacy` in PaywallScreen.swift |

## Elements

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `paywall.close.accessibilityLabel` | “Close” (VERIFIED) | `Copy.paywallCloseAccessibilityLabel` in PaywallScreen.swift |
| matched | `layout.global.premiumGradient` | top: #D543DE; bottom: #A327B8; direction: vertical (SOURCED) | `Tokens.Layouts.GlobalPremiumGradient` in MediaPills.swift |
| matched | `color.global.onBadge` | #FFFFFF (SOURCED) | `Tokens.Colors.globalOnBadge` in Badge.swift, MediaPills.swift, ScreenHeader.swift |
| n/a | `paywall.locked.badge` | “Premium” (SOURCED) | badge on locked controls, placed by the passes that own them (C-25 PremiumPill) |
| matched | `paywall.layout.requiredDisclosures` | price: the store's localized price for each plan's period (StoreKit Product.displayPrice + subscription.subscriptionPeriod / Play ProductDetails.Subscription… (VERIFIED) | billing line of the selected plan + Terms / Privacy / Restore under the capsule |

## States

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `color.global.controlRaised` | light: #CCCCCC; dark: #4D4D4D (SOURCED) | `Tokens.Colors.globalControlRaised` in CapsuleButton.swift, PrimaryButton.swift |
| matched | `paywall.error.products` | “Plans aren't available right now. Please try again.” (SOURCED) | `Copy.paywallErrorProducts` in PaywallScreen.swift |
| matched | `paywall.retry` | “Try again” (SOURCED) | `Copy.paywallRetry` in PaywallScreen.swift |
| matched | `paywall.offline` | “Could not connect. Check your connection and try again.” (SOURCED) | `Copy.paywallOffline` in PaywallModel.swift, PaywallScreen.swift |
| matched | `paywall.error.purchase` | “Your purchase didn't go through. Please try again.” (SOURCED) | `Copy.paywallErrorPurchase` in PaywallModel.swift |
| matched | `auth.phone.error.dismiss` | “OK” (VERIFIED) | `Copy.authPhoneErrorDismiss` in CodeScreen.swift, FormErrorAlert.swift, ReportFlow.swift |
| matched | `paywall.pending` | “Your purchase is waiting for approval.” (VERIFIED) | `Copy.paywallPending` in PaywallModel.swift |
| matched | `paywall.welcome.title` | “Welcome to Premium!” (SOURCED) | `Copy.paywallWelcomeTitle` in PaywallScreen.swift |
| matched | `paywall.welcome.body` | “You've unlocked all Premium features.” (SOURCED) | `Copy.paywallWelcomeBody` in PaywallScreen.swift |
| matched | `paywall.welcome.done` | “Done” (SOURCED) | `Copy.paywallWelcomeDone` in PaywallScreen.swift |
| matched | history perk while `free_history_days` is NULL (T1, owner decision 7) | not listed | `PaywallModel.showsHistoryPerk` false → `PaywallPerk.listed` = video, widgets, export (AccountSettingsTests.testHistoryPerkStaysHiddenWhileFreeHistoryDaysIsNull) |
| matched | `paywall.restore.done` | “Welcome back to Premium!” (SOURCED) | `Copy.paywallRestoreDone` in PaywallModel.swift, PaywallScreen.swift |
| matched | `paywall.restore.none` | “No previous purchases found” (SOURCED) | `Copy.paywallRestoreNone` in PaywallModel.swift |

## Motion

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `duration.global.fade` | 150 ms (SOURCED) | `Tokens.Durations.globalFade` in ComponentSupport.swift, GroupCreateScreen.swift, GroupInviteScreen.swift, PaywallScreen.swift … |
| matched | `duration.global.pageTransition` | 500 ms (SOURCED) | `Tokens.Durations.globalPageTransition` in PaywallScreen.swift, PhoneScreen.swift, ProfileScreen.swift |
| matched | `layout.global.reduceMotion` | ios: UIAccessibility.isReduceMotionEnabled / @Environment(\.accessibilityReduceMotion); android: Settings.Global.ANIMATOR_DURATION_SCALE == 0 or ValueAnimato… (PLATFORM) | `dsAnimation` / `dsTransition` (DesignSystem) drop movement under Reduce Motion, keep cross-fades |

## Haptics

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| n/a | `haptic.global.tap` | ios: none; android: VIRTUAL_KEY (PLATFORM) | Android only — iOS presses play no haptic |
| matched | `haptic.global.select` | ios: selection; android: SEGMENT_FREQUENT_TICK (PLATFORM) | `Tokens.Haptics.globalSelect` in CapsuleButton.swift, CheckRow.swift, GroupCreateScreen.swift, PaywallScreen.swift … |
| matched | `haptic.global.success` | ios: notification.success; android: CONFIRM (PLATFORM) | `Tokens.Haptics.globalSuccess` in AgeGateForm.swift, CodeScreen.swift, GroupCreateScreen.swift, InviteClipApp.swift … |
| matched | `haptic.global.error` | ios: notification.error; android: REJECT (PLATFORM) | `Tokens.Haptics.globalError` in AgeGateForm.swift, BlockConfirmation.swift, CodeScreen.swift, GroupCreateScreen.swift … |

## Notes

- Benefit media card height: no token (Retro ≈ 248 × 183) — `paywall.size.mediaCardWidth` × the C-15 cover proportion turned landscape (approximated).
