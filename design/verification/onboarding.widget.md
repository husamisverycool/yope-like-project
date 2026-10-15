# Verification — `onboarding.widget` (iOS)

Add-the-widget guide — `Features/Account/Onboarding/WidgetGuideScreen.swift`.

Checklist written from the spec (`design/surfaces/onboarding.widget.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/account/<surface>-<state>.png` (AccountSnapshotTests), then `tools/sidebyside.py` makes `design/verification/onboarding.widget.png` next to the reference image(s) below. The "what the snapshot shows" column states what the code draws for that value; it is to be confirmed on the image.

Reference image(s): `references/auto/locket/lazyweb/locket-lazyweb-20260821-cap-welcome.png`, `references/owner/locket-add-widget-steps.jpg`, `references/auto/locket/lazyweb/locket-lazyweb-20260821-cap-personalization-3.png`

Snapshots (CI): `onboarding.widget-default.png`

**Summary: 28 matched · 1 approximated · 0 not matched (BLOCKED or not buildable) · 2 not applicable on iOS / placed by another pass.**

| status | kind | token / copy | reference value | element | what the snapshot shows (iOS implementation) |
|---|---|---|---|---|---|
| matched | token | `onboarding.widget.color.backgroundTop` | #0E0A07 (SOURCED) | screen background, top (warm near-black) | `Tokens.…onboardingWidgetColorBackgroundTop` in WidgetGuideScreen.swift |
| matched | token | `onboarding.widget.color.backgroundBottom` | #0B090B (SOURCED) | screen background, bottom | `Tokens.…onboardingWidgetColorBackgroundBottom` in WidgetGuideScreen.swift |
| matched | copy | `onboarding.widget.title` | “Add the widget to your home screen” (SOURCED) |  | `Copy.…onboardingWidgetTitle` in WidgetGuideScreen.swift |
| matched | token | `groups.create.size.sheetTopToTitle` | 71 pt (SOURCED) | sheet top edge to the title's cap top (also the safe-area top to the title on full-screen onboarding steps) | `Tokens.…groupsCreateSizeSheetTopToTitle` in WidgetGuideScreen.swift |
| matched | token | `groups.create.size.titleToContent` | 34 pt (SOURCED) | title text bottom (descender) to the first content element | `Tokens.…groupsCreateSizeTitleToContent` in WidgetGuideScreen.swift |
| matched | copy | `onboarding.widget.step.ios.1` | “From your Home Screen, touch and hold a widget or empty area until the apps jiggle.” (SOURCED) |  | `Copy.…onboardingWidgetStepIos1` in WidgetGuideScreen.swift |
| matched | copy | `onboarding.widget.step.ios.5` | “Select a widget size, then tap Add Widget.” (SOURCED) |  | `Copy.…onboardingWidgetStepIos5` in WidgetGuideScreen.swift |
| n/a | copy | `onboarding.widget.step.android.1` | “Hold down on an empty space on your Home Screen” (SOURCED) |  | Android only |
| n/a | copy | `onboarding.widget.step.android.3` | “Search for {app_name} and add the widget” (SOURCED) |  | Android only |
| matched | copy | `onboarding.widget.done` | “You're done!” (SOURCED) |  | `Copy.…onboardingWidgetDone` in WidgetGuideScreen.swift |
| matched | token | `onboarding.widget.lineHeight.step` | 32 pt (SOURCED) | step line pitch | `Tokens.…onboardingWidgetLineHeightStep` in WidgetGuideScreen.swift |
| matched | token | `paywall.size.perkMarginH` | 20 pt (SOURCED) | perk card side margin (card width 353 pt on 393) | `Tokens.…paywallSizePerkMarginH` in WidgetGuideScreen.swift |
| matched | copy | `onboarding.widget.continue` | “Continue” (SOURCED) |  | `Copy.…onboardingWidgetContinue` in WidgetGuideScreen.swift |
| matched | token | `groups.create.size.fieldToButton` | 18 pt (SOURCED) | form field bottom to the primary button top | `Tokens.…groupsCreateSizeFieldToButton` in WidgetGuideScreen.swift |
| matched | token | `onboarding.widget.fontSize.title` | 33 pt (SOURCED) | title ('Add the widget\nto your home screen'), bold, white, centred | `Tokens.…onboardingWidgetFontSizeTitle` in WidgetGuideScreen.swift |
| matched | token | `onboarding.widget.fontWeight.title` | bold (SOURCED) | title weight | `Tokens.…onboardingWidgetFontWeightTitle` in WidgetGuideScreen.swift |
| matched | token | `onboarding.widget.color.title` | #FFFFFF (SOURCED) | title colour | `Tokens.…onboardingWidgetColorTitle` in WidgetGuideScreen.swift |
| matched | token | `onboarding.widget.fontSize.step` | 22 pt (SOURCED) | step lines (welcome tagline style), centred | `Tokens.…onboardingWidgetFontSizeStep` in WidgetGuideScreen.swift |
| matched | token | `onboarding.widget.fontWeight.step` | semibold (SOURCED) | step line weight | `Tokens.…onboardingWidgetFontWeightStep` in WidgetGuideScreen.swift |
| matched | token | `onboarding.widget.color.step` | #B8B6B2 (SOURCED) | step text colour | `Tokens.…onboardingWidgetColorStep` in WidgetGuideScreen.swift |
| matched | token | `onboarding.widget.size.ctaHeight` | 54 pt (SOURCED) | content-width yellow capsule CTA height | `Tokens.…onboardingWidgetSizeCtaHeight` in WidgetGuideScreen.swift |
| matched | token | `onboarding.widget.color.cta` | #FFB800 (SOURCED) | CTA capsule fill | `Tokens.…onboardingWidgetColorCta` in WidgetGuideScreen.swift |
| matched | token | `onboarding.widget.fontSize.ctaLabel` | 18 pt (SOURCED) | CTA label (bold) | `Tokens.…onboardingWidgetFontSizeCtaLabel` in WidgetGuideScreen.swift |
| matched | token | `onboarding.widget.color.ctaLabel` | #332500 (SOURCED) | CTA label and arrow colour | `Tokens.…onboardingWidgetColorCtaLabel` in WidgetGuideScreen.swift |
| matched | token | `onboarding.widget.icon.ctaArrow` | ios: arrow.right; android: AutoMirrored.Rounded.ArrowForward (PLATFORM) | trailing arrow in the CTA ('→') | `Tokens.…onboardingWidgetIconCtaArrow` in WidgetGuideScreen.swift |
| matched | token | `onboarding.widget.size.ctaArrow` | 17 pt (SOURCED) | CTA arrow glyph width | `Tokens.…onboardingWidgetSizeCtaArrow` in WidgetGuideScreen.swift |
| matched | token | `onboarding.widget.size.ctaArrowGap` | 17 pt (SOURCED) | gap between the CTA label and the arrow | `Tokens.…onboardingWidgetSizeCtaArrowGap` in WidgetGuideScreen.swift |
| matched | token | `onboarding.widget.size.ctaPaddingH` | 18 pt (SOURCED) | CTA horizontal padding (capsule edge to label / to arrow) | `Tokens.…onboardingWidgetSizeCtaPaddingH` in WidgetGuideScreen.swift |
| matched | token | `radius.global.capsule` | shape: capsule; radius: height / 2 (SOURCED) | full pill: header title capsule, composer text field, chat bubbles, tab-bar capsule, tooltip ends, white se… | Capsule() shape |
| matched | copy | `onboarding.widget.stepNumber.accessibilityLabel` | “step {number}” (SOURCED) |  | `Copy.…onboardingWidgetStepNumberAccessibilityLabel` in WidgetGuideScreen.swift |

## Approximations

- Step-list layout taken from the welcome screen of the same Locket flow (spec Gaps); steps are numbered by position because step 4 (iOS) is BLOCKED copy and omitted in release.
