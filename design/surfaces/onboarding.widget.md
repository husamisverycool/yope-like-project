# `onboarding.widget` — guided add-the-widget step

Visual reference: Retro Settings → **Widgets** (inventory #28, VID-SET: rounded widget thumbnails) and Retro's widget art
and upsell (inventory #34: `apk/widget_preview_*.webp`, 22 dp corners; APK-S `home_widget_nux_upsell_*`, `widget_add`,
`widget_added`, `widget_pin_failed`). Mechanics: Locket's add-widget steps (content pattern
`locket.onboarding.widgetSteps`). Composition: `level: SOURCED`, `method: "composition of Retro components C-33
(onboarding page title), widget preview art (34), C-11 numbered circles, C-05, C-08 in Locket's step order"`.
Tokens: `onboarding.widget.*`. Copy: `onboarding.widget.*`.

## References

| id | file / URL | used for |
|---|---|---|
| W34 | `references/auto/retro/apk/widget_preview_friends.webp` (158 × 158 dp art) | preview tile size `onboarding.widget.size.preview`; full-bleed photo look |
| APK-X | `references/auto/retro/apk/retro-android-2026.10.1150-excerpts.txt` (qmh.java, Glance corner 22 dp) | `onboarding.widget.radius.preview` |
| VID-SET | `references/auto/retro/video/ig-DJXvmqRv2_N-referrals-sheet-f042-059.png` | Widgets section in Settings (entry point) |
| APK-S | `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt` | upsell title / message, "Add Widget", toasts |
| HC | https://help.locket.com/en/articles/7914857 ; Locket Android 1.243.0 strings | step text |

## Structure (page `color.global.background` / `.background.android`; scrolls when the steps do not fit)

1. C-02 header row: back chevron only when opened from `settings.root`; none inside onboarding.
2. Title `onboarding.widget.title` (`font.global.display`, `displayMedium`), leading, baseline `size.global.titleTop`.
3. Explanation `onboarding.widget.detail` under it (`body`, `color.global.textSecondary`).
4. `size.global.titleToContent` below: **preview tile** `onboarding.widget.size.preview` (158) square, corners
   `onboarding.widget.radius.preview` (22, `layout.global.cornerStyle`), centred: the newest photo from the person's
   groups, aspect-fill, with the widget's bottom scrim (`layout.global.photoScrim`) and the sender's first name in
   text role `listTitle` `color.global.textOnMedia` bottom-trailing (Retro widget art: name stack bottom-right). No photo
   yet → `color.global.control` fill with `icon.global.gallery` centred in `color.global.textSecondary`.
5. `size.global.titleToContent` below: **steps**, one row each (iOS `onboarding.widget.step.ios.1` … `.5`; Android
   `.step.android.1` … `.3`): a 36 pt circle (`size.global.circleButton`, `color.global.control`) holding the numeral in
   text role `listTitle` `color.global.textPrimary`, then the step text (text role `body`, `color.global.textPrimary`)
   starting `size.global.rowThumbGap` (17) after the circle; rows `size.global.sectionHeaderToContent` (11.7) apart.
   After the last step: `onboarding.widget.done` (text role `listTitle`).
6. Flexible space.
7. Bottom (frame of the `auth.*` capsules): iOS — C-05 `onboarding.widget.continue`. Android — C-05
   `onboarding.widget.add` (pin request) and, `auth.phone.size.capsuleToLink` below, C-08 `onboarding.widget.skip`.

## Elements

| element | tokens / component | copy | behaviour |
|---|---|---|---|
| preview | `onboarding.widget.size.preview`, `onboarding.widget.radius.preview`, `layout.global.photoScrim`, `color.global.textOnMedia`; fallback `color.global.control` + `icon.global.gallery` | `onboarding.widget.preview.accessibilityLabel` | decorative preview of what the widget shows |
| step rows | C-11 circle (`size.global.circleButton`, `color.global.control`), text roles `listTitle` / `body` | step keys; `onboarding.widget.stepNumber.accessibilityLabel` | static |
| Next (iOS) | C-05 | `onboarding.widget.continue` | moves on whether or not a widget was added (no check, no gate) |
| Add Widget (Android) | C-05 | `onboarding.widget.add`; result toasts `onboarding.widget.added` / `onboarding.widget.pinFailed` (C-26) | `AppWidgetManager.requestPinAppWidget` (when `isRequestPinAppWidgetSupported`), then moves on; unsupported launcher → the steps are the path |
| Maybe later (Android) | C-08 | `onboarding.widget.skip` | moves on |

## States

| state | design |
|---|---|
| default | as Structure |
| no photo yet | preview fallback |
| back from the Home Screen | unchanged (no "did you add it?" question) |
| pin failed (Android) | toast `onboarding.widget.pinFailed`; the page stays |
| loading / empty / error / offline / permission-denied | not applicable (the preview uses cached data or the fallback) |

## Motion

Onboarding page transition in / out (`duration.global.pageTransition`, fade + expand). From Settings: native push.
Preview photo fades in `duration.global.fade`. Reduce Motion: cross-fades.

## Haptics

Presses → `haptic.global.tap` (Android). Widget added → `haptic.global.success`.

## Accessibility

- Each step is one element: "Step {number}, <text>". The preview is one image with its label.
- Dynamic Type: title `largeTitle`, explanation and steps `subheadline`, capsule `headline`.
- Focus order: title → explanation → preview → steps → capsule → link.
- Contrast: steps 21:1 (row 1); numeral on the #F1F1F1 / #262626 circle 18.59:1 / 15.13:1 (row 9); explanation light
  **2.85:1 FAIL** (row 3); preview name on photo: photo-dependent (white over the bottom scrim, failure 8 of CONTRAST).

## Data & actions

No API (the preview reads the newest cached post across the person's groups). In: `onboarding.permission.notifications`
(onboarding) or `settings.root` → Widgets row. Out: pending invite → `join_group(token)` → `groups.screen`; else `groups.list`;
from Settings: back.

## Platform notes

- iOS steps name the current system UI ("Edit", "Add Widget"). Android pins through the launcher, as Retro's Android app
  does (`AppWidgetPinReceiver`).

## Do-not-copy

- "Have you enabled the widget?" gates; "doesn't work unless you add the widget" pressure; Retro's "Post to see" widget
  lock; Retro's and Locket's illustrations.

## Gaps

| item | status | smallest capture |
|---|---|---|
| Retro's in-app widget education (Settings → Widgets tap) | not captured | one screenshot after tapping a widget thumbnail in Retro's Settings (iOS) |
