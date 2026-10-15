# `onboarding.widget` — guided add-the-widget step

Reference: **Locket** (`docs/SURFACES.md`). Research: `design/research/locket.md` §8, §11; `design/copy-patterns.md`
`locket.onboarding.widgetSteps`; MERGE_DECISIONS F-18 (Locket's Sentence case governs here). Tokens: `onboarding.widget.*`.
Copy: `onboarding.widget.*`.

**Locket's in-app widget tutorial screens were not seen as images** (locket §8); their copy comes from Locket's Android
bundle and help centre. The layout below uses the **welcome screen of the same Locket onboarding flow** (LZ welcome:
text block + content-width yellow capsule) — an approximation noted in Gaps.

## References

| id | file / URL | used for |
|---|---|---|
| LW | `references/auto/locket/lazyweb/locket-lazyweb-20260821-cap-welcome.png` | background, title line (33 pt bold white), tagline style (22 pt, #B8B6B2, 32 pt pitch), yellow CTA 54 pt with → |
| LT | `references/owner/locket-add-widget-steps.jpg` (TT 2023, CAPTURED) | numbered steps "1. Edit Home Screen / 2. Click on + in left corner / 3. …" |
| HC | https://help.locket.com/en/articles/7914857 | iPhone and Android step text, "You're done!" |
| APK | Locket Android 1.243.0 string table | title "Add the widget\nto your home screen", Android steps |
| LP3 | `references/auto/locket/lazyweb/locket-lazyweb-20260821-cap-personalization-3.png` | "Continue" |

## Structure (full screen, vertical gradient `onboarding.widget.color.backgroundTop` → `.backgroundBottom`)

1. Status bar (light).
2. Title `onboarding.widget.title` (2 lines), centred, cap top `groups.create.size.sheetTopToTitle` below the safe area.
3. Gap `groups.create.size.titleToContent`.
4. Steps, centred, one paragraph each, each prefixed "1.", "2.", … (numeral + period, LT):
   - iOS: `onboarding.widget.step.ios.1` … `.5`;
   - Android: `onboarding.widget.step.android.1` … `.3`;
   - then `onboarding.widget.done` (no number).
   Paragraph spacing = one line pitch (`onboarding.widget.lineHeight.step`). Side margins `paywall.size.perkMarginH` (Locket 20 pt).
5. Flexible space.
6. CTA capsule `onboarding.widget.continue` + trailing arrow, content width, centred, bottom of the safe area minus
   `groups.create.size.fieldToButton`.

## Elements

| element | tokens | copy | behaviour |
|---|---|---|---|
| background | `onboarding.widget.color.backgroundTop`, `.backgroundBottom` (linear, top → bottom) | — | — |
| title | `onboarding.widget.fontSize.title`, `.fontWeight.title`, `.color.title` | `onboarding.widget.title` | static |
| steps | `onboarding.widget.fontSize.step`, `.fontWeight.step`, `.lineHeight.step`, `.color.step` | step keys above | static text; the numerals are part of the rendered text |
| CTA | height `onboarding.widget.size.ctaHeight`, fill `.color.cta`, label `.fontSize.ctaLabel` bold in `.color.ctaLabel`, arrow `.icon.ctaArrow` in `.color.ctaLabel`, shape `radius.global.capsule`, horizontal padding = (214 − label − arrow) / 2 as in LW (label-to-arrow gap ≈ 12 pt in LW, not tokenised: see Gaps) | `onboarding.widget.continue` | always enabled; moves on whether or not a widget was added (no check, no gate) |

## States

| state | design |
|---|---|
| default | as Structure |
| returning to the app from the Home Screen | same screen, unchanged (no "did you add it?" question) |
| loading / empty / error / offline / permission-denied | not applicable (static, no network, no permission) |

## Motion

Native push in/out. No animation on this screen (the tutorial's motion was not observed). Reduce Motion: unchanged.

## Haptics

None (no sourced interaction beyond a button press; `haptic.global.*` are for outcomes).

## Accessibility

- Each step is one element; VoiceOver/TalkBack reads `onboarding.widget.stepNumber.accessibilityLabel` ("step {number}")
  then the text. The arrow is decorative (hidden).
- Dynamic Type (F-13 rule): title 33 → `largeTitle`; steps 22 → `title2`; CTA 18 → `headline`. The steps scroll when
  they no longer fit.
- Focus order: title → steps → CTA.
- Contrast: title 19.72:1, steps 9.74:1 / 9.80:1, CTA label 8.62:1, CTA vs background 11.44:1 — all pass.

## Data & actions

No API. In: `onboarding.permission.notifications`. Out: pending invite → `join_group(token)` → `groups.screen`;
otherwise `groups.list` (whose empty state offers `groups.create`).

## Platform notes

- iOS steps name the current iPhone system UI ("Edit", "Add Widget"); Android steps follow Locket's Android strings.
  Android could add a pin request (`AppWidgetManager.requestPinAppWidget`), but Locket's use of it was not observed, so it
  is not part of this spec.
- Case: Locket's Sentence case here, mid-onboarding after Yope's lowercase screens (F-18, owner to confirm).

## Do-not-copy

- "Have you enabled the widget?" / "I've enabled the widget" gate; "Locket doesn't work unless you add the widget to your
  home screen." (pressure); Locket's logo, the phone illustration, the help-centre drawings, Proxima Soft.

## Gaps

| item | status | smallest capture |
|---|---|---|
| tutorial screen layout (title size, step style, illustration) | approximation from the welcome screen of the same flow | screenshots (or a 30-s recording) of Locket's in-app Settings → "Widget Tutorial" on an iPhone |
| CTA inner spacing (label ↔ arrow, side padding) | measured only as the total 214 pt for another label | same capture |
| illustration | none (Locket's art is do-not-copy) | owner art, optional |
